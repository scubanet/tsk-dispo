import Foundation

enum UDDFParseError: LocalizedError {
    case fileUnreadable(URL)
    case malformedXML(line: Int, message: String)
    case missingRequiredField(String)
    case dateParseFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileUnreadable(let url):       return "UDDF file unreadable: \(url.lastPathComponent)"
        case .malformedXML(let line, let m): return "UDDF XML invalid at line \(line): \(m)"
        case .missingRequiredField(let f):   return "UDDF missing required field: \(f)"
        case .dateParseFailed(let s):        return "UDDF datetime unparseable: \(s)"
        }
    }
}

/// ISO-8601 without timezone, the format used by Subsurface UDDF exports.
/// Examples: "2026-01-11T10:03:17", "2026-01-11T10:03:17.000".
fileprivate let uddfDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(secondsFromGMT: 0)
    f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    return f
}()

fileprivate func parseUDDFDate(_ s: String) -> Date? {
    if let d = uddfDateFormatter.date(from: s) { return d }
    if let dot = s.firstIndex(of: ".") {
        return uddfDateFormatter.date(from: String(s[..<dot]))
    }
    return nil
}

final class UDDFParser {

    /// Parses the UDDF file at `url`. Throws `UDDFParseError` on any failure.
    func parse(url: URL) throws -> UDDFFile {
        guard let parser = XMLParser(contentsOf: url) else {
            throw UDDFParseError.fileUnreadable(url)
        }
        let delegate = UDDFParserDelegate()
        parser.delegate = delegate
        guard parser.parse() else {
            let line = parser.lineNumber
            let msg = parser.parserError?.localizedDescription ?? "unknown error"
            throw UDDFParseError.malformedXML(line: line, message: msg)
        }
        if let err = delegate.error { throw err }
        return delegate.file
    }
}

/// XMLParserDelegate implementation. State-machine driven: tracks current
/// section and which element is open, accumulates text into the appropriate
/// field via parent-aware dispatch.
private final class UDDFParserDelegate: NSObject, XMLParserDelegate {

    // Parsed output (built incrementally)
    var file = UDDFFile(generator: "", gasDefinitions: [:], diveSites: [:], dives: [])
    var error: UDDFParseError?

    // Element-name stack — top is the currently open element
    private var elementStack: [String] = []
    private var charBuffer: String = ""

    // Per-element accumulators
    private var currentGas: UDDFGas?
    private var currentSite: UDDFSite?
    private var currentDive: UDDFDive?
    private var currentSample: UDDFSample?

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement name: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attrs: [String: String]) {
        elementStack.append(name)
        charBuffer = ""

        if name == "mix" {
            let id = attrs["id"] ?? ""
            currentGas = UDDFGas(id: id, name: "", o2: 0, he: 0)
        }
        if name == "site" {
            let id = (attrs["id"] ?? "").trimmingCharacters(in: .whitespaces)
            currentSite = UDDFSite(id: id, name: "", latitude: nil, longitude: nil)
        }

        if name == "dive" {
            currentDive = UDDFDive(
                datetime: Date.distantPast, siteRef: nil, gasRef: nil, leadKg: nil,
                tankVolumeLiters: nil, maxDepthMeters: 0, avgDepthMeters: 0,
                durationSeconds: 0, notes: nil, samples: [],
                tankStartBar: nil, tankEndBar: nil)
        }

        // <link ref="..."/> means different things depending on parent:
        //   - inside <informationbeforedive>: site reference
        //   - inside <tankdata>: gas reference
        // Self-closing tags trigger didStartElement only (no body to wait for),
        // so we read the ref attribute now.
        if name == "link" {
            let ref = attrs["ref"] ?? ""
            // elementStack already contains "link" at this point (we pushed it).
            // The parent is the element below "link" on the stack.
            let parentName = elementStack.dropLast().last ?? ""
            if parentName == "informationbeforedive" {
                currentDive?.siteRef = ref
            } else if parentName == "tankdata" {
                currentDive?.gasRef = ref
            }
        }

        if name == "waypoint" {
            currentSample = UDDFSample(depthMeters: 0, timeSeconds: 0,
                                       temperatureCelsius: nil, gasSwitchRef: nil)
        }
        if name == "switchmix" {
            let ref = attrs["ref"] ?? ""
            currentSample?.gasSwitchRef = ref
        }
    }

    func parser(_ parser: XMLParser, foundCharacters str: String) {
        charBuffer += str
    }

    func parser(_ parser: XMLParser, didEndElement name: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        defer { _ = elementStack.popLast(); charBuffer = "" }

        let trimmed = charBuffer.trimmingCharacters(in: .whitespacesAndNewlines)

        // Path-aware dispatch — we look at the parent to disambiguate generic tags.
        let parent = elementStack.dropLast().last ?? ""

        switch name {
        case "name":
            if parent == "generator" { file.generator = trimmed }
            if parent == "mix", currentGas != nil { currentGas!.name = trimmed }
            if parent == "site", currentSite != nil { currentSite!.name = trimmed }
        case "o2":
            if parent == "mix", currentGas != nil { currentGas!.o2 = Double(trimmed) ?? 0 }
        case "he":
            if parent == "mix", currentGas != nil { currentGas!.he = Double(trimmed) ?? 0 }
        case "latitude":
            if currentSite != nil { currentSite!.latitude = Double(trimmed) }
        case "longitude":
            if currentSite != nil { currentSite!.longitude = Double(trimmed) }
        case "datetime":
            if parent == "informationbeforedive", currentDive != nil {
                guard let d = parseUDDFDate(trimmed) else {
                    error = .dateParseFailed(trimmed)
                    parser.abortParsing()
                    return
                }
                currentDive!.datetime = d
            }
        case "leadquantity":
            if currentDive != nil { currentDive!.leadKg = Double(trimmed) }
        case "tankvolume":
            // UDDF stores tank volume in cubic meters; convert to liters
            if currentDive != nil, let m3 = Double(trimmed) {
                currentDive!.tankVolumeLiters = m3 * 1000.0
            }
        case "greatestdepth":
            if currentDive != nil { currentDive!.maxDepthMeters = Double(trimmed) ?? 0 }
        case "averagedepth":
            if currentDive != nil { currentDive!.avgDepthMeters = Double(trimmed) ?? 0 }
        case "diveduration":
            if currentDive != nil { currentDive!.durationSeconds = Int(trimmed) ?? 0 }
        case "mix":
            if let gas = currentGas { file.gasDefinitions[gas.id] = gas }
            currentGas = nil
        case "site":
            if let site = currentSite { file.diveSites[site.id] = site }
            currentSite = nil
        case "depth":
            if parent == "waypoint", currentSample != nil {
                currentSample!.depthMeters = Double(trimmed) ?? 0
            }
        case "divetime":
            if parent == "waypoint", currentSample != nil {
                currentSample!.timeSeconds = Int(trimmed) ?? 0
            }
        case "temperature":
            if parent == "waypoint", currentSample != nil {
                // UDDF stores temperature in Kelvin; convert to Celsius
                if let kelvin = Double(trimmed) {
                    currentSample!.temperatureCelsius = kelvin - 273.15
                }
            }
        case "waypoint":
            if let s = currentSample {
                currentDive?.samples.append(s)
            }
            currentSample = nil
        case "dive":
            if let dive = currentDive { file.dives.append(dive) }
            currentDive = nil
        default:
            break
        }
    }
}
