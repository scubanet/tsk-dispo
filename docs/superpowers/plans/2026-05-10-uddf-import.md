# UDDF Import — Plan A Implementation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Import dives from `.uddf` files into the SwiftData logbook end-to-end. User shares a UDDF file with the app, sees a preview of detected dives, picks which to import, confirms — dives land in the store with full data fidelity from UDDF (date, depth, duration, gas, site, samples).

**Architecture:** Three-layer pipeline. Layer 2 (UDDF Parser) consumes the .uddf file via Foundation `XMLParser` and produces an internal `UDDFFile` Swift struct. Layer 3 (Mapper) turns each `UDDFDive` into an unsaved `Dive` SwiftData object, applying unit conversions and defaults. Layer 4 (Import UI + Coordinator) handles file-picker, conflict detection (datetime ±5 min AND maxDepth ±0.5 m), preview sheet with per-dive checkboxes, and the final insert + renumberDives.

**Tech Stack:** Swift 5.9+, SwiftUI, SwiftData + CloudKit, iOS 17+, Xcode 26 / iOS 26 SDK, Foundation `XMLParser`, Swift Testing framework. No external dependencies.

**Reference Spec:** `docs/superpowers/specs/2026-05-10-divecomputer-import-design.md`

**Branch:** `feat/divecomputer-import` (already created, HEAD `3517f41` with spec + test fixtures).

**Out of scope (Phase B, separate plan):** FIT-direct parser, FitDataProtocol extension, eliminating Subsurface intermediate step.

---

## File Structure

**New files:**

```
DiveLog Pro/Utils/UDDF/
├── UDDFFile.swift               (~30 LoC, structs only)
├── UDDFParser.swift             (~250 LoC, XMLParserDelegate)
├── UDDFDiveMapper.swift         (~150 LoC)
├── UDDFImportCoordinator.swift  (~100 LoC, orchestration)

DiveLog Pro/Views/Screens/
├── UDDFImportSheet.swift        (~250 LoC)

DiveLog Pro/Models/Dive.swift   (no changes — Dive model already covers everything)

DiveLog ProTests/
├── UDDFParserTests.swift        (~200 LoC)
├── UDDFDiveMapperTests.swift    (~120 LoC)
├── UDDFImportConflictTests.swift (~80 LoC)
```

**Modified files:**

- `DiveLog Pro/Info.plist` — register `.uddf` as `CFBundleDocumentTypes` so iOS share-sheets know about us
- `DiveLog Pro/Utils/DiveLogProApp.swift` — `.onOpenURL` handler routing `.uddf` files to the import sheet
- `DiveLog Pro/Views/Components/ProfileTab/DataManagementCard.swift` — neue Row „Tauchgänge importieren" + callback

---

## Task 1: Internal UDDF Data Structures

**Files:**
- Create: `DiveLog Pro/Utils/UDDF/UDDFFile.swift`

- [ ] **Step 1.1: Create the file with internal data structures**

```swift
import Foundation

/// Internal representation of a parsed UDDF file. Layer 2 (UDDFParser) produces
/// this; Layer 3 (UDDFDiveMapper) consumes it. Units are normalised to App
/// units (Celsius, liters, decimal degrees, seconds for sample times,
/// minutes for dive duration only at the Layer-3 boundary).
struct UDDFFile {
    var generator: String           // e.g. "Subsurface Divelog v3"
    var gasDefinitions: [String: UDDFGas]   // by mix-id
    var diveSites: [String: UDDFSite]       // by site-id
    var dives: [UDDFDive]
}

struct UDDFGas {
    var id: String                  // "mix(21/0)"
    var name: String                // "air"
    var o2: Double                  // fraction 0..1
    var he: Double                  // fraction 0..1
}

struct UDDFSite {
    var id: String
    var name: String
    var latitude: Double?
    var longitude: Double?
}

struct UDDFDive {
    var datetime: Date              // ISO-8601 parsed
    var siteRef: String?
    var gasRef: String?
    var leadKg: Double?
    var tankVolumeLiters: Double?   // converted from m³ in Layer 2
    var maxDepthMeters: Double      // from <greatestdepth>
    var avgDepthMeters: Double
    var durationSeconds: Int        // from <diveduration>
    var notes: String?
    var samples: [UDDFSample]
    // Reserved for Phase B (FIT-direct populates these; UDDF leaves nil):
    var tankStartBar: Int?
    var tankEndBar: Int?
}

struct UDDFSample {
    var depthMeters: Double
    var timeSeconds: Int
    var temperatureCelsius: Double?
    var gasSwitchRef: String?
}
```

- [ ] **Step 1.2: Commit**

```bash
cd "/Users/dominik/Desktop/Developer/DiveLog Pro"
mkdir -p "DiveLog Pro/Utils/UDDF"
# (file created in step 1.1)
git add "DiveLog Pro/Utils/UDDF/UDDFFile.swift"
git commit -m "feat(uddf): internal data structures for UDDF parsing

UDDFFile aggregates dives, sites, and gas definitions parsed from
a .uddf file. UDDFDive has all fields populated from UDDF sources
plus two reserved fields (tankStartBar/tankEndBar) for Phase-B
FIT-direct import to populate. Units are normalised: meters for
depth, seconds for sample time, kg for weight, liters for tank,
Celsius for temperature, decimal degrees for GPS."
```

---

## Task 2: UDDF Parser — top-level + gas definitions

**Files:**
- Create: `DiveLog Pro/Utils/UDDF/UDDFParser.swift`
- Create: `DiveLog ProTests/UDDFParserTests.swift`

This task builds the parser shell, parses `<generator>` and `<gasdefinitions>`. Subsequent tasks expand to sites, dives, samples.

- [ ] **Step 2.1: Write failing tests for top-level + gas parsing**

Create `DiveLog ProTests/UDDFParserTests.swift`:

```swift
import Testing
import Foundation
@testable import DiveLog_Pro

@Suite("UDDFParser")
struct UDDFParserTests {

    private var fixtureURL: URL {
        Bundle(for: BundleMarker.self).url(forResource: "test", withExtension: "uddf")!
    }

    @Test("parses generator name from Subsurface fixture")
    func parsesGenerator() throws {
        let parser = UDDFParser()
        let file = try parser.parse(url: fixtureURL)
        #expect(file.generator.contains("Subsurface"))
    }

    @Test("parses single 'air' gas definition")
    func parsesAirGas() throws {
        let parser = UDDFParser()
        let file = try parser.parse(url: fixtureURL)
        let air = file.gasDefinitions["mix(21/0)"]
        #expect(air != nil)
        #expect(air?.name == "air")
        #expect(abs((air?.o2 ?? 0) - 0.21) < 0.001)
        #expect(abs(air?.he ?? 0) < 0.001)
    }
}

// Marker class so we can resolve the test bundle.
private final class BundleMarker {}
```

The fixture `test.uddf` is at `DiveLog ProTests/Fixtures/uddf/test.uddf` and needs to be added to the test target's resources. In Xcode (or by editing project settings), make sure the entire `Fixtures` folder is in the `DiveLog ProTests` target membership as a "blue folder reference" or via "Copy Bundle Resources". For Swift Package layout this is `resources` in the target.

(Note: depending on how your test target is set up, you may need to use `Bundle.module` or a different lookup. The above uses a marker-class technique that works for both XCTest and Swift Testing targets.)

- [ ] **Step 2.2: Run tests — verify they fail (no UDDFParser yet)**

```bash
cd "/Users/dominik/Desktop/Developer/DiveLog Pro"
xcodebuild test -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:"DiveLog ProTests/UDDFParserTests" 2>&1 | tail -10
```

Expected: compilation failure `cannot find 'UDDFParser' in scope`.

- [ ] **Step 2.3: Implement UDDFParser shell with top-level + gas**

Create `DiveLog Pro/Utils/UDDF/UDDFParser.swift`:

```swift
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
/// section (top-level, gasdefinitions, divesite, profiledata) and which
/// element is open, accumulates text into the appropriate field.
private final class UDDFParserDelegate: NSObject, XMLParserDelegate {

    // Parsed output (built incrementally)
    var file = UDDFFile(generator: "", gasDefinitions: [:], diveSites: [:], dives: [])
    var error: UDDFParseError?

    // Element-name stack — top is the currently open element
    private var elementStack: [String] = []
    private var charBuffer: String = ""

    // Per-element accumulators
    private var currentGas: UDDFGas?

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
            // <generator><name>Subsurface Divelog</name>...
            if parent == "generator" {
                file.generator = trimmed
            }
            // <mix><name>air</name>...
            if parent == "mix", currentGas != nil {
                currentGas!.name = trimmed
            }
        case "o2":
            if parent == "mix", currentGas != nil {
                currentGas!.o2 = Double(trimmed) ?? 0
            }
        case "he":
            if parent == "mix", currentGas != nil {
                currentGas!.he = Double(trimmed) ?? 0
            }
        case "mix":
            if let gas = currentGas {
                file.gasDefinitions[gas.id] = gas
            }
            currentGas = nil
        default:
            break
        }
    }
}
```

- [ ] **Step 2.4: Run tests — verify both pass**

```bash
xcodebuild test -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:"DiveLog ProTests/UDDFParserTests/parsesGenerator" \
  -only-testing:"DiveLog ProTests/UDDFParserTests/parsesAirGas" 2>&1 | tail -10
```

Expected: both tests pass.

If the fixture is not found, add `DiveLog ProTests/Fixtures/uddf/test.uddf` to the test target's "Copy Bundle Resources" build phase in Xcode (Targets → DiveLog ProTests → Build Phases → Copy Bundle Resources → +).

- [ ] **Step 2.5: Commit**

```bash
git add "DiveLog Pro/Utils/UDDF/UDDFParser.swift" \
        "DiveLog ProTests/UDDFParserTests.swift"
git commit -m "feat(uddf): parser shell + generator + gas-definitions parsing

XMLParserDelegate state-machine that tracks element stack and
dispatches on (parent, name) pairs. First slice: <generator><name>
into UDDFFile.generator and <gasdefinitions><mix> into the
dictionary by mix id. Tests verify against the Subsurface fixture."
```

---

## Task 3: UDDF Parser — dive sites

**Files:**
- Modify: `DiveLog Pro/Utils/UDDF/UDDFParser.swift`
- Modify: `DiveLog ProTests/UDDFParserTests.swift`

- [ ] **Step 3.1: Add failing test for sites**

In `UDDFParserTests`, append:

```swift
@Test("parses 5 dive sites with GPS coordinates")
func parsesDiveSites() throws {
    let parser = UDDFParser()
    let file = try parser.parse(url: fixtureURL)
    #expect(file.diveSites.count == 5)

    let mamutic = file.diveSites["7255e454"]
    #expect(mamutic != nil)
    #expect(abs((mamutic?.latitude ?? 0) - 9.190535) < 0.0001)
    #expect(abs((mamutic?.longitude ?? 0) - 123.271294) < 0.0001)
}
```

- [ ] **Step 3.2: Run — verify fails**

```bash
xcodebuild test -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:"DiveLog ProTests/UDDFParserTests/parsesDiveSites" 2>&1 | tail -10
```

Expected: `parsesDiveSites` fails with `file.diveSites.count == 0`.

- [ ] **Step 3.3: Extend the delegate for `<site>` parsing**

In `UDDFParserDelegate`, add a `currentSite: UDDFSite?` property next to `currentGas`:

```swift
private var currentSite: UDDFSite?
```

In `didStartElement`, add a branch for `site`:

```swift
if name == "site" {
    let id = attrs["id"]?.trimmingCharacters(in: .whitespaces) ?? ""
    currentSite = UDDFSite(id: id, name: "", latitude: nil, longitude: nil)
}
```

In `didEndElement`, add handling for `name` (parent `site`), `latitude`, `longitude`, and the closing `site` element. The full updated `switch` statement:

```swift
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
    // <geography><latitude>...</latitude></geography> — parent is "geography"
    if currentSite != nil { currentSite!.latitude = Double(trimmed) }
case "longitude":
    if currentSite != nil { currentSite!.longitude = Double(trimmed) }
case "mix":
    if let gas = currentGas { file.gasDefinitions[gas.id] = gas }
    currentGas = nil
case "site":
    if let site = currentSite { file.diveSites[site.id] = site }
    currentSite = nil
default:
    break
}
```

- [ ] **Step 3.4: Run — verify passes**

```bash
xcodebuild test -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:"DiveLog ProTests/UDDFParserTests" 2>&1 | tail -15
```

Expected: all 3 tests pass.

- [ ] **Step 3.5: Commit**

```bash
git add "DiveLog Pro/Utils/UDDF/UDDFParser.swift" \
        "DiveLog ProTests/UDDFParserTests.swift"
git commit -m "feat(uddf): parse <divesite><site> with GPS coordinates"
```

---

## Task 4: UDDF Parser — dive header + tank + summary

**Files:**
- Modify: `DiveLog Pro/Utils/UDDF/UDDFParser.swift`
- Modify: `DiveLog ProTests/UDDFParserTests.swift`

This parses everything inside `<dive>` *except* the per-sample waypoints (that's Task 5).

- [ ] **Step 4.1: Add failing tests for dive headers**

In `UDDFParserTests`:

```swift
@Test("parses 7 dives from fixture")
func parsesDiveCount() throws {
    let parser = UDDFParser()
    let file = try parser.parse(url: fixtureURL)
    #expect(file.dives.count == 7)
}

@Test("first dive has expected datetime / depth / duration")
func firstDiveHeader() throws {
    let parser = UDDFParser()
    let file = try parser.parse(url: fixtureURL)
    let d0 = file.dives[0]

    // <datetime>2026-01-11T10:03:17</datetime>
    let cal = Calendar(identifier: .gregorian)
    let comps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second],
                                   from: d0.datetime)
    #expect(comps.year == 2026)
    #expect(comps.month == 1)
    #expect(comps.day == 11)
    #expect(comps.hour == 10)
    #expect(comps.minute == 3)
    #expect(comps.second == 17)

    // <greatestdepth>19.446</greatestdepth>
    #expect(abs(d0.maxDepthMeters - 19.446) < 0.001)
    // <averagedepth>11.77</averagedepth>
    #expect(abs(d0.avgDepthMeters - 11.77) < 0.001)
    // <diveduration>2275</diveduration>
    #expect(d0.durationSeconds == 2275)
}

@Test("first dive has site ref and gas ref resolved")
func firstDiveRefs() throws {
    let parser = UDDFParser()
    let file = try parser.parse(url: fixtureURL)
    let d0 = file.dives[0]

    #expect(d0.siteRef == "7255e454")
    #expect(d0.gasRef == "mix(21/0)")
    // <tankvolume>0.012</tankvolume> = 12 liters
    #expect(abs((d0.tankVolumeLiters ?? 0) - 12.0) < 0.01)
    // <leadquantity>0</leadquantity>
    #expect(d0.leadKg == 0)
}
```

- [ ] **Step 4.2: Run — verify fails**

```bash
xcodebuild test -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:"DiveLog ProTests/UDDFParserTests/parsesDiveCount" 2>&1 | tail -10
```

Expected: fails, `file.dives.count == 0`.

- [ ] **Step 4.3: Add date-parsing helper + dive-header parsing**

Append to `UDDFParser.swift` (outside the class):

```swift
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
    // Try with seconds first, then with milliseconds suffix stripped
    if let d = uddfDateFormatter.date(from: s) { return d }
    if let dot = s.firstIndex(of: ".") {
        return uddfDateFormatter.date(from: String(s[..<dot]))
    }
    return nil
}
```

In `UDDFParserDelegate`, add accumulator state for the current dive:

```swift
private var currentDive: UDDFDive?
```

In `didStartElement`, add:

```swift
if name == "dive" {
    currentDive = UDDFDive(
        datetime: Date.distantPast, siteRef: nil, gasRef: nil, leadKg: nil,
        tankVolumeLiters: nil, maxDepthMeters: 0, avgDepthMeters: 0,
        durationSeconds: 0, notes: nil, samples: [],
        tankStartBar: nil, tankEndBar: nil)
}

// <link ref="..."/> can mean two things depending on parent:
//   - inside <informationbeforedive>: it's the site reference
//   - inside <tankdata>: it's the gas reference
// Self-closing tags get a didStartElement with no body; we read the ref attribute now.
if name == "link" {
    let ref = attrs["ref"] ?? ""
    if elementStack.dropLast().last == "informationbeforedive" {
        currentDive?.siteRef = ref
    } else if elementStack.dropLast().last == "tankdata" {
        currentDive?.gasRef = ref
    }
}
```

Extend the `didEndElement` switch with dive-specific cases:

```swift
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
case "dive":
    if let dive = currentDive { file.dives.append(dive) }
    currentDive = nil
```

- [ ] **Step 4.4: Run — verify passes**

```bash
xcodebuild test -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:"DiveLog ProTests/UDDFParserTests" 2>&1 | tail -15
```

Expected: all 6 tests pass.

- [ ] **Step 4.5: Commit**

```bash
git add "DiveLog Pro/Utils/UDDF/UDDFParser.swift" \
        "DiveLog ProTests/UDDFParserTests.swift"
git commit -m "feat(uddf): parse dive header — datetime, depth, duration, refs

Includes ISO-8601 datetime parsing, tankvolume cubic-meter → liter
conversion, and disambiguation of <link ref> by parent (site
reference under informationbeforedive vs. gas reference under
tankdata). Tests pin all values from the first fixture dive."
```

---

## Task 5: UDDF Parser — samples (waypoints) with Kelvin → Celsius

**Files:**
- Modify: `DiveLog Pro/Utils/UDDF/UDDFParser.swift`
- Modify: `DiveLog ProTests/UDDFParserTests.swift`

- [ ] **Step 5.1: Add failing tests for samples**

In `UDDFParserTests`:

```swift
@Test("first dive has samples with depth + time + (sparse) temperature")
func firstDiveSamples() throws {
    let parser = UDDFParser()
    let file = try parser.parse(url: fixtureURL)
    let d0 = file.dives[0]

    // Test fixture has 9499 samples across 7 dives; first dive specifically
    // should have a substantial number. We don't pin an exact count because
    // sampling rate isn't critical to this test.
    #expect(d0.samples.count > 100)

    // First sample: <depth>1.28</depth><divetime>1</divetime>
    //               <temperature>303.15</temperature>  (= 30.0 °C)
    let s0 = d0.samples[0]
    #expect(abs(s0.depthMeters - 1.28) < 0.01)
    #expect(s0.timeSeconds == 1)
    #expect(s0.temperatureCelsius != nil)
    if let t = s0.temperatureCelsius {
        #expect(abs(t - 30.0) < 0.1)
    }
}

@Test("samples contain only depth+time for waypoints without temperature")
func sparseTemperatureSamples() throws {
    let parser = UDDFParser()
    let file = try parser.parse(url: fixtureURL)
    let d0 = file.dives[0]

    // 45 temperature readings vs 9499 waypoints = sparse. Many samples
    // should have no temperature.
    let withoutTemp = d0.samples.filter { $0.temperatureCelsius == nil }
    #expect(withoutTemp.count > 0)
}
```

- [ ] **Step 5.2: Run — verify fails**

```bash
xcodebuild test -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:"DiveLog ProTests/UDDFParserTests/firstDiveSamples" 2>&1 | tail -10
```

Expected: fails because `samples` is empty.

- [ ] **Step 5.3: Implement waypoint parsing**

In `UDDFParserDelegate`, add accumulator state:

```swift
private var currentSample: UDDFSample?
```

In `didStartElement`, add:

```swift
if name == "waypoint" {
    currentSample = UDDFSample(depthMeters: 0, timeSeconds: 0,
                               temperatureCelsius: nil, gasSwitchRef: nil)
}
if name == "switchmix" {
    let ref = attrs["ref"] ?? ""
    currentSample?.gasSwitchRef = ref
}
```

Extend the `didEndElement` switch with sample-related cases. **Important:** `<depth>` appears both inside `<waypoint>` (sample-level) and inside `<informationafterdive><greatestdepth>` (already handled). Disambiguate by parent:

```swift
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
    if let s = currentSample { currentDive?.samples.append(s) }
    currentSample = nil
```

- [ ] **Step 5.4: Run — verify passes**

```bash
xcodebuild test -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:"DiveLog ProTests/UDDFParserTests" 2>&1 | tail -20
```

Expected: all 8 tests pass.

- [ ] **Step 5.5: Commit**

```bash
git add "DiveLog Pro/Utils/UDDF/UDDFParser.swift" \
        "DiveLog ProTests/UDDFParserTests.swift"
git commit -m "feat(uddf): parse <samples><waypoint> with Kelvin → Celsius conversion

Disambiguates <depth> by parent element (waypoint = sample depth
vs. greatestdepth = dive max). Temperature samples are sparse in
real UDDF — only ~45 of 9499 waypoints carry temperature in the
test fixture — so the field is optional."
```

---

## Task 6: UDDFDiveMapper — basic field mapping

**Files:**
- Create: `DiveLog Pro/Utils/UDDF/UDDFDiveMapper.swift`
- Create: `DiveLog ProTests/UDDFDiveMapperTests.swift`

- [ ] **Step 6.1: Write failing test**

Create `DiveLog ProTests/UDDFDiveMapperTests.swift`:

```swift
import Testing
import Foundation
@testable import DiveLog_Pro

@Suite("UDDFDiveMapper")
struct UDDFDiveMapperTests {

    private func makeUDDFFile() -> UDDFFile {
        var f = UDDFFile(generator: "Test", gasDefinitions: [:], diveSites: [:], dives: [])
        f.gasDefinitions["mix(21/0)"] = UDDFGas(id: "mix(21/0)", name: "air", o2: 0.21, he: 0)
        f.diveSites["site1"] = UDDFSite(id: "site1", name: "Test Reef",
                                        latitude: 9.190535, longitude: 123.271294)
        return f
    }

    private func makeDive() -> UDDFDive {
        UDDFDive(
            datetime: Date(timeIntervalSince1970: 1768122197), // 2026-01-11T10:03:17 UTC
            siteRef: "site1",
            gasRef: "mix(21/0)",
            leadKg: 4.0,
            tankVolumeLiters: 12.0,
            maxDepthMeters: 19.446,
            avgDepthMeters: 11.77,
            durationSeconds: 2275,
            notes: "Test note",
            samples: [],
            tankStartBar: nil,
            tankEndBar: nil
        )
    }

    @Test("maps basic header fields")
    func mapsBasics() {
        let file = makeUDDFFile()
        let uddf = makeDive()
        let dive = UDDFDiveMapper.makeDive(from: uddf, in: file)

        #expect(dive.date.timeIntervalSince1970 == 1768122197)
        #expect(abs(dive.maxDepth - 19.446) < 0.001)
        #expect(abs(dive.avgDepth - 11.77) < 0.001)
        // 2275 sec ≈ 37.9 min → rounded to 38
        #expect(dive.totalTime == 38)
        #expect(dive.bottomTime == 38)
        #expect(abs(dive.weightKg - 4.0) < 0.001)
        #expect(abs(dive.cylinderSizeLiters - 12.0) < 0.001)
        #expect(dive.notes == "Test note")
    }

    @Test("resolves site reference to name + GPS")
    func resolvesSite() {
        let file = makeUDDFFile()
        let uddf = makeDive()
        let dive = UDDFDiveMapper.makeDive(from: uddf, in: file)

        #expect(dive.siteName == "Test Reef")
        #expect(abs(dive.latitude - 9.190535) < 0.0001)
        #expect(abs(dive.longitude - 123.271294) < 0.0001)
    }

    @Test("missing site reference yields empty siteName")
    func missingSite() {
        let file = makeUDDFFile()
        var uddf = makeDive()
        uddf.siteRef = nil
        let dive = UDDFDiveMapper.makeDive(from: uddf, in: file)

        #expect(dive.siteName == "")
        #expect(dive.latitude == 0)
        #expect(dive.longitude == 0)
    }
}
```

- [ ] **Step 6.2: Run — verify fails**

```bash
xcodebuild test -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:"DiveLog ProTests/UDDFDiveMapperTests" 2>&1 | tail -10
```

Expected: compilation failure `cannot find 'UDDFDiveMapper' in scope`.

- [ ] **Step 6.3: Implement basic mapper**

Create `DiveLog Pro/Utils/UDDF/UDDFDiveMapper.swift`:

```swift
import Foundation

/// Translates a UDDF-parsed dive into a SwiftData `Dive` object ready to
/// be inserted. Applies defaults for fields UDDF doesn't carry and
/// resolves site/gas references against the parent UDDFFile.
enum UDDFDiveMapper {

    /// Build a fresh unsaved Dive from a UDDFDive. The caller is responsible
    /// for inserting it into a ModelContext.
    static func makeDive(from uddf: UDDFDive, in file: UDDFFile) -> Dive {
        let totalMin = Int((Double(uddf.durationSeconds) / 60.0).rounded())

        let site = uddf.siteRef.flatMap { file.diveSites[$0] }

        return Dive(
            number: 0,                               // renumberDives will assign
            date: uddf.datetime,
            diveType: "fun",                          // default; user can change after import
            siteName: site?.name ?? "",
            siteLocation: "",                         // UDDF has no city/country split
            latitude: site?.latitude ?? 0,
            longitude: site?.longitude ?? 0,
            diveCenterName: "",
            maxDepth: uddf.maxDepthMeters,
            avgDepth: uddf.avgDepthMeters,
            bottomTime: totalMin,                    // UDDF doesn't separate bottom vs total
            totalTime: totalMin,
            weightKg: uddf.leadKg ?? 2,
            cylinderSizeLiters: uddf.tankVolumeLiters ?? 12,
            notes: uddf.notes ?? ""
        )
    }
}
```

- [ ] **Step 6.4: Run — verify passes**

```bash
xcodebuild test -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:"DiveLog ProTests/UDDFDiveMapperTests" 2>&1 | tail -10
```

Expected: all 3 tests pass.

- [ ] **Step 6.5: Commit**

```bash
git add "DiveLog Pro/Utils/UDDF/UDDFDiveMapper.swift" \
        "DiveLog ProTests/UDDFDiveMapperTests.swift"
git commit -m "feat(uddf): map UDDFDive to SwiftData Dive — basics + site lookup

Header fields (date, depth, duration, weight, cylinder, notes)
plus site-reference resolution (name + GPS). Missing site
reference falls back to empty siteName and zero GPS."
```

---

## Task 7: UDDFDiveMapper — gas discretization, temperature, depth profile

**Files:**
- Modify: `DiveLog Pro/Utils/UDDF/UDDFDiveMapper.swift`
- Modify: `DiveLog ProTests/UDDFDiveMapperTests.swift`

- [ ] **Step 7.1: Add failing tests**

In `UDDFDiveMapperTests`:

```swift
@Test("discretizes gas — air")
func gasAir() {
    var file = makeUDDFFile()
    file.gasDefinitions["mix(21/0)"] = UDDFGas(id: "mix(21/0)", name: "air", o2: 0.21, he: 0)
    let dive = UDDFDiveMapper.makeDive(from: makeDive(), in: file)
    #expect(dive.gas == "air")
}

@Test("discretizes gas — nitrox 32")
func gasEan32() {
    var file = makeUDDFFile()
    file.gasDefinitions["mix(32/0)"] = UDDFGas(id: "mix(32/0)", name: "ean32", o2: 0.32, he: 0)
    var uddf = makeDive()
    uddf.gasRef = "mix(32/0)"
    let dive = UDDFDiveMapper.makeDive(from: uddf, in: file)
    #expect(dive.gas == "eanx32")
}

@Test("discretizes gas — trimix")
func gasTrimix() {
    var file = makeUDDFFile()
    file.gasDefinitions["mix(21/35)"] = UDDFGas(id: "mix(21/35)", name: "tx21/35", o2: 0.21, he: 0.35)
    var uddf = makeDive()
    uddf.gasRef = "mix(21/35)"
    let dive = UDDFDiveMapper.makeDive(from: uddf, in: file)
    #expect(dive.gas == "trimix")
}

@Test("aggregates temperature samples — min for bottom, max for surface")
func temperatureAggregation() {
    let file = makeUDDFFile()
    var uddf = makeDive()
    uddf.samples = [
        UDDFSample(depthMeters: 0, timeSeconds: 0, temperatureCelsius: 28.5, gasSwitchRef: nil),
        UDDFSample(depthMeters: 10, timeSeconds: 60, temperatureCelsius: nil, gasSwitchRef: nil),
        UDDFSample(depthMeters: 19, timeSeconds: 600, temperatureCelsius: 24.0, gasSwitchRef: nil),
        UDDFSample(depthMeters: 0, timeSeconds: 2275, temperatureCelsius: 28.0, gasSwitchRef: nil)
    ]
    let dive = UDDFDiveMapper.makeDive(from: uddf, in: file)

    #expect(abs(dive.waterTempSurface - 28.5) < 0.01)
    #expect(abs(dive.waterTempBottom - 24.0) < 0.01)
}

@Test("no temperature samples leaves defaults")
func temperatureDefaults() {
    let file = makeUDDFFile()
    var uddf = makeDive()
    uddf.samples = [
        UDDFSample(depthMeters: 0, timeSeconds: 0, temperatureCelsius: nil, gasSwitchRef: nil),
        UDDFSample(depthMeters: 10, timeSeconds: 60, temperatureCelsius: nil, gasSwitchRef: nil)
    ]
    let dive = UDDFDiveMapper.makeDive(from: uddf, in: file)

    #expect(abs(dive.waterTempSurface - 28) < 0.01)
    #expect(abs(dive.waterTempBottom - 27) < 0.01)
}

@Test("down-samples depth profile to at most 200 points")
func downsampleProfile() {
    let file = makeUDDFFile()
    var uddf = makeDive()
    uddf.samples = (0..<1356).map {
        UDDFSample(depthMeters: Double($0 % 20), timeSeconds: $0,
                   temperatureCelsius: nil, gasSwitchRef: nil)
    }
    let dive = UDDFDiveMapper.makeDive(from: uddf, in: file)

    #expect(dive.depthProfile.count <= 200)
    #expect(dive.depthProfile.count > 100)   // significant down-sample, not zero
}

@Test("small profile not down-sampled")
func smallProfileKeepsAll() {
    let file = makeUDDFFile()
    var uddf = makeDive()
    uddf.samples = (0..<50).map {
        UDDFSample(depthMeters: Double($0), timeSeconds: $0,
                   temperatureCelsius: nil, gasSwitchRef: nil)
    }
    let dive = UDDFDiveMapper.makeDive(from: uddf, in: file)

    #expect(dive.depthProfile.count == 50)
}
```

- [ ] **Step 7.2: Run — verify fails**

```bash
xcodebuild test -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:"DiveLog ProTests/UDDFDiveMapperTests" 2>&1 | tail -15
```

Expected: new tests fail.

- [ ] **Step 7.3: Extend the mapper**

Replace the `UDDFDiveMapper.makeDive` body with this expanded version:

```swift
enum UDDFDiveMapper {

    /// Max number of points kept in `Dive.depthProfile`. Sample arrays
    /// larger than this are uniformly down-sampled. 200 points is enough
    /// for a smooth chart and small enough to keep CloudKit sync cheap.
    static let maxProfilePoints = 200

    static func makeDive(from uddf: UDDFDive, in file: UDDFFile) -> Dive {
        let totalMin = Int((Double(uddf.durationSeconds) / 60.0).rounded())
        let site = uddf.siteRef.flatMap { file.diveSites[$0] }
        let gas = uddf.gasRef.flatMap { file.gasDefinitions[$0] }

        let (surfaceTemp, bottomTemp) = aggregateTemperatures(uddf.samples)
        let profile = downsampleDepthProfile(uddf.samples)

        return Dive(
            number: 0,
            date: uddf.datetime,
            diveType: "fun",
            siteName: site?.name ?? "",
            siteLocation: "",
            latitude: site?.latitude ?? 0,
            longitude: site?.longitude ?? 0,
            diveCenterName: "",
            maxDepth: uddf.maxDepthMeters,
            avgDepth: uddf.avgDepthMeters,
            bottomTime: totalMin,
            totalTime: totalMin,
            waterTempSurface: surfaceTemp,
            waterTempBottom: bottomTemp,
            weightKg: uddf.leadKg ?? 2,
            cylinderSizeLiters: uddf.tankVolumeLiters ?? 12,
            gas: discretizeGas(gas),
            tankStartBar: uddf.tankStartBar ?? 200,
            tankEndBar: uddf.tankEndBar ?? 50,
            notes: uddf.notes ?? "",
            depthProfile: profile
        )
    }

    // MARK: - Helpers

    /// Maps a UDDFGas (with o2/he fractions) to one of Dive.gas's
    /// canonical strings. Buckets at standard nitrox values, falls
    /// back to "air" if helium is zero and o2 ≈ 0.21.
    static func discretizeGas(_ gas: UDDFGas?) -> String {
        guard let gas else { return "air" }
        if gas.he > 0.001 { return "trimix" }
        switch gas.o2 {
        case 0.19..<0.22:  return "air"
        case 0.30..<0.34:  return "eanx32"
        case 0.34..<0.38:  return "eanx36"
        case 0.38..<0.42:  return "eanx40"
        default:           return "air"
        }
    }

    /// Returns (surfaceTemp, bottomTemp). Surface = max observed
    /// (warmest at the surface during entry/exit). Bottom = min
    /// observed. Falls back to App defaults if no temperature samples.
    static func aggregateTemperatures(_ samples: [UDDFSample]) -> (surface: Double, bottom: Double) {
        let temps = samples.compactMap(\.temperatureCelsius)
        guard !temps.isEmpty else { return (28, 27) }
        return (surface: temps.max() ?? 28, bottom: temps.min() ?? 27)
    }

    /// Uniform down-sample of the depth-vs-time series to at most
    /// `maxProfilePoints` entries. Preserves the first and last samples.
    static func downsampleDepthProfile(_ samples: [UDDFSample]) -> [Double] {
        let depths = samples.map(\.depthMeters)
        guard depths.count > maxProfilePoints else { return depths }

        let stride = Double(depths.count - 1) / Double(maxProfilePoints - 1)
        return (0..<maxProfilePoints).map { i in
            let idx = min(Int((Double(i) * stride).rounded()), depths.count - 1)
            return depths[idx]
        }
    }
}
```

- [ ] **Step 7.4: Run — verify passes**

```bash
xcodebuild test -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:"DiveLog ProTests/UDDFDiveMapperTests" 2>&1 | tail -20
```

Expected: all 10 tests pass.

- [ ] **Step 7.5: Commit**

```bash
git add "DiveLog Pro/Utils/UDDF/UDDFDiveMapper.swift" \
        "DiveLog ProTests/UDDFDiveMapperTests.swift"
git commit -m "feat(uddf): gas discretization + temperature + profile down-sample

- discretizeGas buckets o2/he fractions into Dive.gas strings
  (air, eanx32, eanx36, eanx40, trimix). Air is the safe default.
- aggregateTemperatures returns (max, min) of all temperature
  samples, defaulting to 28/27 °C when no samples carry temperature.
- downsampleDepthProfile uniform-samples sequences longer than 200
  points, preserving first and last. Short profiles pass through
  unchanged."
```

---

## Task 8: Conflict-Detection logic

**Files:**
- Create: `DiveLog Pro/Utils/UDDF/UDDFImportCoordinator.swift` (initial; expanded in Task 9)
- Create: `DiveLog ProTests/UDDFImportConflictTests.swift`

- [ ] **Step 8.1: Write failing tests for conflict detection**

Create `DiveLog ProTests/UDDFImportConflictTests.swift`:

```swift
import Testing
import Foundation
@testable import DiveLog_Pro

@Suite("UDDF Import Conflict Detection")
struct UDDFImportConflictTests {

    private func makeDive(date: Date, depth: Double) -> Dive {
        Dive(number: 100, date: date, maxDepth: depth)
    }

    @Test("identical datetime + depth is a duplicate")
    func exactMatch() {
        let date = Date()
        let existing = [makeDive(date: date, depth: 15.0)]
        let new = makeDive(date: date, depth: 15.0)
        let conflict = UDDFImportCoordinator.findConflict(for: new, in: existing)
        #expect(conflict != nil)
        #expect(conflict?.number == 100)
    }

    @Test("3-minute drift + same depth is a duplicate")
    func nearMatchWithinTolerance() {
        let date = Date()
        let drifted = date.addingTimeInterval(180)  // 3 min
        let existing = [makeDive(date: date, depth: 15.0)]
        let new = makeDive(date: drifted, depth: 15.0)
        #expect(UDDFImportCoordinator.findConflict(for: new, in: existing) != nil)
    }

    @Test("6-minute drift is NOT a duplicate")
    func driftBeyondTolerance() {
        let date = Date()
        let drifted = date.addingTimeInterval(360)  // 6 min
        let existing = [makeDive(date: date, depth: 15.0)]
        let new = makeDive(date: drifted, depth: 15.0)
        #expect(UDDFImportCoordinator.findConflict(for: new, in: existing) == nil)
    }

    @Test("same time but 1m depth difference is NOT a duplicate")
    func depthBeyondTolerance() {
        let date = Date()
        let existing = [makeDive(date: date, depth: 15.0)]
        let new = makeDive(date: date, depth: 16.0)
        #expect(UDDFImportCoordinator.findConflict(for: new, in: existing) == nil)
    }

    @Test("same time and 0.3m depth difference IS a duplicate")
    func depthWithinTolerance() {
        let date = Date()
        let existing = [makeDive(date: date, depth: 15.0)]
        let new = makeDive(date: date, depth: 15.3)
        #expect(UDDFImportCoordinator.findConflict(for: new, in: existing) != nil)
    }
}
```

- [ ] **Step 8.2: Run — verify fails**

```bash
xcodebuild test -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:"DiveLog ProTests/UDDFImportConflictTests" 2>&1 | tail -10
```

Expected: compilation failure `cannot find 'UDDFImportCoordinator' in scope`.

- [ ] **Step 8.3: Create the coordinator with conflict-detection**

Create `DiveLog Pro/Utils/UDDF/UDDFImportCoordinator.swift`:

```swift
import Foundation
import SwiftData

/// Orchestrates the UDDF import flow: parse, map, detect conflicts,
/// commit. Stateless static functions for now; if we need cross-call
/// state later (e.g. progress reporting), promote to an instance.
enum UDDFImportCoordinator {

    /// Max datetime drift (seconds) for which two dives are considered
    /// the same. 5 min covers typical timezone-offset cases.
    static let datetimeToleranceSeconds: TimeInterval = 300

    /// Max depth difference (meters) for which two dives are considered
    /// the same, given the datetime tolerance also matches.
    static let depthToleranceMeters: Double = 0.5

    /// If `candidate` matches an `existing` dive on (datetime ±5 min AND
    /// maxDepth ±0.5 m), returns that existing dive. Returns nil if no
    /// duplicate is found.
    static func findConflict(for candidate: Dive, in existing: [Dive]) -> Dive? {
        for d in existing {
            let dt = abs(d.date.timeIntervalSince(candidate.date))
            let depthDelta = abs(d.maxDepth - candidate.maxDepth)
            if dt <= datetimeToleranceSeconds, depthDelta <= depthToleranceMeters {
                return d
            }
        }
        return nil
    }
}
```

- [ ] **Step 8.4: Run — verify passes**

```bash
xcodebuild test -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:"DiveLog ProTests/UDDFImportConflictTests" 2>&1 | tail -15
```

Expected: all 5 tests pass.

- [ ] **Step 8.5: Commit**

```bash
git add "DiveLog Pro/Utils/UDDF/UDDFImportCoordinator.swift" \
        "DiveLog ProTests/UDDFImportConflictTests.swift"
git commit -m "feat(uddf): conflict detection — datetime ±5min AND maxDepth ±0.5m

UDDFImportCoordinator.findConflict matches a candidate dive against
the existing logbook using both criteria. Both must be within
tolerance for the candidate to be flagged as duplicate. Tests cover
exact match, near-match, drift-beyond-tolerance, depth-beyond-
tolerance, and depth-within-tolerance cases."
```

---

## Task 9: Coordinator orchestration — parse + map + classify

**Files:**
- Modify: `DiveLog Pro/Utils/UDDF/UDDFImportCoordinator.swift`

This task adds the orchestration that ties parser, mapper, and conflict-detection together into one async entry point.

- [ ] **Step 9.1: Extend coordinator with end-to-end orchestration**

Append to `UDDFImportCoordinator.swift`:

```swift
/// A single dive prepared for import, with its conflict status.
struct ImportCandidate: Identifiable {
    let id = UUID()
    let dive: Dive                       // unsaved
    let conflictWith: Dive?              // existing dive if duplicate
    var selected: Bool                   // user's choice in the preview UI
}

/// Strategy for handling duplicates at commit time.
enum ConflictStrategy: String, CaseIterable, Identifiable {
    case skip                            // ignore the new dive
    case overwrite                       // delete existing, insert new
    case keepBoth                        // insert new alongside; renumberDives fixes ordering

    var id: String { rawValue }

    var label: String {
        switch self {
        case .skip:      return "Duplikate überspringen"
        case .overwrite: return "Duplikate überschreiben"
        case .keepBoth:  return "Beide behalten"
        }
    }
}

extension UDDFImportCoordinator {

    /// Full pipeline: parse the .uddf at `url`, map each UDDFDive to a Dive,
    /// check each against `existingDives` for duplicates. Returns the
    /// candidate list ready for UI presentation. Throws UDDFParseError on
    /// parser failure.
    @MainActor
    static func prepareImport(from url: URL, existingDives: [Dive]) async throws -> (UDDFFile, [ImportCandidate]) {
        // Parsing is CPU-bound; run on a background priority to keep UI snappy.
        let file = try await Task.detached(priority: .userInitiated) {
            try UDDFParser().parse(url: url)
        }.value

        let candidates: [ImportCandidate] = file.dives.map { uddf in
            let dive = UDDFDiveMapper.makeDive(from: uddf, in: file)
            let conflict = findConflict(for: dive, in: existingDives)
            return ImportCandidate(dive: dive,
                                   conflictWith: conflict,
                                   selected: conflict == nil)  // duplicates start unchecked
        }
        return (file, candidates)
    }

    /// Commit the user's selected candidates into the model context.
    /// Applies the conflict strategy for marked duplicates. After all
    /// inserts, renumberDives is called once.
    static func commitImport(candidates: [ImportCandidate],
                             strategy: ConflictStrategy,
                             context: ModelContext,
                             profile: DiverProfile) -> (inserted: Int, skipped: Int) {
        var inserted = 0
        var skipped = 0

        for candidate in candidates where candidate.selected {
            if let existing = candidate.conflictWith {
                switch strategy {
                case .skip:
                    skipped += 1
                    continue
                case .overwrite:
                    context.delete(existing)
                    context.insert(candidate.dive)
                    inserted += 1
                case .keepBoth:
                    context.insert(candidate.dive)
                    inserted += 1
                }
            } else {
                context.insert(candidate.dive)
                inserted += 1
            }
        }

        if inserted > 0 {
            context.renumberDives(from: profile)
            try? context.save()
        }
        return (inserted, skipped)
    }
}
```

- [ ] **Step 9.2: Build check**

```bash
xcodebuild build -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'generic/platform=iOS' 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 9.3: Run the existing tests — verify they still pass**

```bash
xcodebuild test -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:"DiveLog ProTests/UDDFImportConflictTests" 2>&1 | tail -10
```

Expected: all 5 conflict tests still pass (we added orchestration without changing existing logic).

- [ ] **Step 9.4: Commit**

```bash
git add "DiveLog Pro/Utils/UDDF/UDDFImportCoordinator.swift"
git commit -m "feat(uddf): coordinator orchestration — prepareImport + commitImport

prepareImport runs parser + mapper + conflict detection off the main
actor and returns a list of ImportCandidate with their selection
state pre-filled (new dives selected, duplicates unselected).
commitImport applies the chosen ConflictStrategy (skip/overwrite/
keepBoth), inserts via ModelContext, and calls renumberDives once
at the end."
```

---

## Task 10: UDDFImportSheet — preview UI

**Files:**
- Create: `DiveLog Pro/Views/Screens/UDDFImportSheet.swift`

- [ ] **Step 10.1: Create the sheet view**

```swift
import SwiftUI
import SwiftData

/// Modal sheet that presents the result of parsing a .uddf file and
/// lets the user pick which dives to import, with a strategy for
/// resolving duplicates.
struct UDDFImportSheet: View {
    let fileURL: URL
    let onCompletion: (Int, Int) -> Void  // (inserted, skipped) — used for the success toast

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Dive.date, order: .reverse) private var existingDives: [Dive]
    @Query private var profiles: [DiverProfile]

    @State private var loading = true
    @State private var error: String?
    @State private var generatorName: String = ""
    @State private var candidates: [ImportCandidate] = []
    @State private var strategy: ConflictStrategy = .skip
    @State private var committing = false

    var body: some View {
        NavigationStack {
            ZStack {
                HeroBackground()
                content
            }
            .navigationTitle("UDDF-Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        commit()
                    } label: {
                        if committing { ProgressView() }
                        else { Text("Importieren (\(selectedCount))") }
                    }
                    .disabled(loading || selectedCount == 0 || committing)
                }
            }
            .task { await load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if loading {
            VStack(spacing: DSSpacing.l) {
                ProgressView()
                Text("UDDF wird gelesen…")
                    .foregroundStyle(.secondary)
            }
        } else if let error {
            VStack(spacing: DSSpacing.l) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)
                Text(error)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DSSpacing.xl)
            }
        } else {
            VStack(alignment: .leading, spacing: DSSpacing.l) {
                summary
                strategyPicker
                List($candidates) { $c in
                    candidateRow($c)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .padding(.top, DSSpacing.s)
        }
    }

    private var summary: some View {
        let total = candidates.count
        let dupes = candidates.filter { $0.conflictWith != nil }.count
        let news  = total - dupes
        return VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text(generatorName.isEmpty ? "Unbekannte Quelle" : "Quelle: \(generatorName)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(total) Tauchgänge gefunden")
                .font(.headline)
            Text("\(news) neu · \(dupes) Duplikate")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, DSSpacing.l)
    }

    private var strategyPicker: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text("Bei Duplikaten")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Picker("Strategie", selection: $strategy) {
                ForEach(ConflictStrategy.allCases) { s in
                    Text(s.label).tag(s)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, DSSpacing.l)
    }

    private func candidateRow(_ c: Binding<ImportCandidate>) -> some View {
        let dive = c.wrappedValue.dive
        let conflict = c.wrappedValue.conflictWith
        return HStack(spacing: DSSpacing.m) {
            Image(systemName: c.wrappedValue.selected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(c.wrappedValue.selected ? Color.appAccent : Color.secondary)
                .onTapGesture { c.wrappedValue.selected.toggle() }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(formattedDate(dive.date))
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(String(format: "%.1fm · %dmin", dive.maxDepth, dive.totalTime))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    if let conflict {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption2)
                        Text("Duplikat von #\(conflict.number)")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption2)
                        Text("Neu")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    if !dive.siteName.isEmpty {
                        Text("·").foregroundStyle(.tertiary)
                        Text(dive.siteName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(Color.clear)
    }

    private var selectedCount: Int {
        candidates.filter(\.selected).count
    }

    private func formattedDate(_ d: Date) -> String {
        d.formatted(.dateTime.day().month(.abbreviated).year().hour().minute())
    }

    // MARK: - Actions

    private func load() async {
        do {
            let (file, cands) = try await UDDFImportCoordinator.prepareImport(
                from: fileURL, existingDives: existingDives)
            generatorName = file.generator
            candidates = cands
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
        }
        loading = false
    }

    private func commit() {
        guard let profile = profiles.first else { return }
        committing = true
        let (inserted, skipped) = UDDFImportCoordinator.commitImport(
            candidates: candidates,
            strategy: strategy,
            context: ctx,
            profile: profile)
        committing = false
        onCompletion(inserted, skipped)
        dismiss()
    }
}
```

- [ ] **Step 10.2: Build check**

```bash
xcodebuild build -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'generic/platform=iOS' 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 10.3: Commit**

```bash
git add "DiveLog Pro/Views/Screens/UDDFImportSheet.swift"
git commit -m "feat(uddf): import sheet — preview, per-dive selection, conflict picker

NavigationStack-based modal with three states: loading (spinner +
caption), error (icon + message), and ready (summary header,
strategy segmented picker, list of candidate rows). Each row shows
date, max-depth, total-time, NEU/Duplikat-von badge, and site name
when present. Tap-to-toggle selection. Importieren button is
disabled when nothing is selected; shows count in label."
```

---

## Task 11: File-type registration + .onOpenURL handler

**Files:**
- Modify: `DiveLog Pro/Info.plist`
- Modify: `DiveLog Pro/Utils/DiveLogProApp.swift`

- [ ] **Step 11.1: Register .uddf in Info.plist**

Open `DiveLog Pro/Info.plist` and add (inside the top-level `<dict>`):

```xml
<key>CFBundleDocumentTypes</key>
<array>
    <dict>
        <key>CFBundleTypeName</key>
        <string>Universal Dive Data Format</string>
        <key>CFBundleTypeRole</key>
        <string>Viewer</string>
        <key>LSHandlerRank</key>
        <string>Alternate</string>
        <key>LSItemContentTypes</key>
        <array>
            <string>org.streit.uddf</string>
        </array>
    </dict>
</array>
<key>UTImportedTypeDeclarations</key>
<array>
    <dict>
        <key>UTTypeIdentifier</key>
        <string>org.streit.uddf</string>
        <key>UTTypeDescription</key>
        <string>Universal Dive Data Format</string>
        <key>UTTypeConformsTo</key>
        <array>
            <string>public.xml</string>
        </array>
        <key>UTTypeTagSpecification</key>
        <dict>
            <key>public.filename-extension</key>
            <array>
                <string>uddf</string>
            </array>
            <key>public.mime-type</key>
            <array>
                <string>application/vnd.uddf+xml</string>
            </array>
        </dict>
    </dict>
</array>
```

- [ ] **Step 11.2: Add `.onOpenURL` to DiveLogProApp**

In `DiveLog Pro/Utils/DiveLogProApp.swift`, find the root `WindowGroup`'s content view (typically `MainTabView()` or similar). Wrap it with `.onOpenURL` and `.sheet`:

```swift
@State private var pendingImportURL: URL?

var body: some Scene {
    WindowGroup {
        MainTabView()      // or whatever the existing root is
            .onOpenURL { url in
                guard url.pathExtension.lowercased() == "uddf" else { return }
                pendingImportURL = url
            }
            .sheet(item: Binding(
                get: { pendingImportURL.map { IdentifiableURL(url: $0) } },
                set: { pendingImportURL = $0?.url }
            )) { wrapper in
                UDDFImportSheet(fileURL: wrapper.url) { _, _ in
                    pendingImportURL = nil
                }
            }
        // ... existing modifiers (modelContainer, etc.)
    }
}

/// Identifiable wrapper so `.sheet(item:)` can present a URL.
private struct IdentifiableURL: Identifiable {
    let url: URL
    var id: URL { url }
}
```

(Place `IdentifiableURL` either as a private nested struct in `DiveLogProApp` or as a fileprivate struct at module level.)

- [ ] **Step 11.3: Build check**

```bash
xcodebuild build -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'generic/platform=iOS' 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 11.4: Commit**

```bash
git add "DiveLog Pro/Info.plist" "DiveLog Pro/Utils/DiveLogProApp.swift"
git commit -m "feat(uddf): register .uddf file type + onOpenURL handler

CFBundleDocumentTypes + UTImportedTypeDeclarations advertise our
app as a UDDF handler in iOS share-sheets. .onOpenURL routes
incoming UDDF URLs to UDDFImportSheet via a transient @State."
```

---

## Task 12: In-app entry-point via DataManagementCard

**Files:**
- Modify: `DiveLog Pro/Views/Components/ProfileTab/DataManagementCard.swift`
- Modify: `DiveLog Pro/Views/Tabs/ProfileTab.swift`

- [ ] **Step 12.1: Read the existing DataManagementCard to find the row-list location**

```bash
grep -n "settingsRow\|onLoadSampleData\|onExport" \
  "DiveLog Pro/Views/Components/ProfileTab/DataManagementCard.swift"
```

You'll find a series of `settingsRow(...)` calls. Insert a new row for "Tauchgänge importieren" alongside Export, with its own callback parameter.

- [ ] **Step 12.2: Add the onImport callback to DataManagementCard**

In `DiveLog Pro/Views/Components/ProfileTab/DataManagementCard.swift`:

1. Add a new parameter to the struct's properties:

```swift
let onImport: () -> Void
```

2. In the body, add a settingsRow above (or below) the export row:

```swift
Button {
    onImport()
} label: {
    settingsRow(icon: "square.and.arrow.down",
                label: L10n.currentLanguage == "de" ? "Tauchgänge importieren" : "Import dives",
                trailing: AnyView(Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)))
}
.buttonStyle(.plain)
```

(Adjust the surrounding HStack/VStack to match the style of the existing rows in the file. The exact placement and `settingsRow` signature is whatever the existing rows use.)

- [ ] **Step 12.3: Wire the callback in ProfileTab**

In `DiveLog Pro/Views/Tabs/ProfileTab.swift`, find the `DataManagementCard(...)` invocation in the body and add a new `@State` property + callback parameter:

```swift
@State private var showingUDDFPicker = false
@State private var pendingImportURL: URL?
```

Pass the callback to DataManagementCard:

```swift
DataManagementCard(
    dives: dives,
    isLogbookEmpty: dives.isEmpty,
    duplicateCount: duplicateCount,
    dedupeResultMessage: dedupeResultMessage,
    sampleLoadedMessage: sampleLoadedMessage,
    onExport: { showingExport = true },
    onImport: { showingUDDFPicker = true },           // ← new
    onLoadSampleData: { showingLoadSampleConfirm = true },
    onDedupe: { showingDedupeConfirm = true },
    onDeleteAll: { showingDeleteConfirm = true }
)
```

Add the file-importer modifier somewhere in the body chain (alongside the other `.sheet`/`.confirmationDialog` modifiers):

```swift
.fileImporter(isPresented: $showingUDDFPicker,
              allowedContentTypes: [.xml],   // .uddf inherits public.xml — broad to be safe
              allowsMultipleSelection: false) { result in
    switch result {
    case .success(let urls):
        if let url = urls.first {
            // Start security-scoped access
            _ = url.startAccessingSecurityScopedResource()
            pendingImportURL = url
        }
    case .failure:
        break
    }
}
.sheet(item: Binding(
    get: { pendingImportURL.map { IdentifiableURL(url: $0) } },
    set: { newValue in
        if newValue == nil, let url = pendingImportURL {
            url.stopAccessingSecurityScopedResource()
        }
        pendingImportURL = newValue?.url
    }
)) { wrapper in
    UDDFImportSheet(fileURL: wrapper.url) { _, _ in
        pendingImportURL = nil
    }
}
```

(Note: `IdentifiableURL` is defined in Task 11; if it's `fileprivate` to DiveLogProApp, either elevate it to internal or define a local copy in ProfileTab.)

- [ ] **Step 12.4: Build check**

```bash
xcodebuild build -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'generic/platform=iOS' 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 12.5: Commit**

```bash
git add "DiveLog Pro/Views/Components/ProfileTab/DataManagementCard.swift" \
        "DiveLog Pro/Views/Tabs/ProfileTab.swift"
git commit -m "feat(uddf): in-app entry — DataManagementCard row + file picker

DataManagementCard gains an onImport closure parameter and a new
'Tauchgänge importieren' row. ProfileTab wires it to a
.fileImporter that accepts XML-conforming files (UDDF), with
security-scoped resource access bracketed across the sheet
lifecycle to avoid leaks."
```

---

## Task 13: End-to-end manual smoke test

**Files:** none changed; manual verification only.

- [ ] **Step 13.1: Build to iPhone 17 Pro Max simulator**

In Xcode: Schema "DiveLog Pro" → Device-Picker on simulator → Cmd+R.

- [ ] **Step 13.2: Manually import test.uddf**

1. In the simulator's Files app, drag-and-drop the `test.uddf` from `DiveLog ProTests/Fixtures/uddf/` onto the simulator window (or use iCloud Drive).
2. In the Files app, tap on `test.uddf` → Share → DiveLog Pro (Atoll Log).
3. The UDDFImportSheet should open with "7 Tauchgänge gefunden". Source should say "Subsurface Divelog".
4. Verify: all 7 dives have plausible dates, depths, durations.
5. Tap "Importieren (7)".
6. Logbook should show 7 new dives, numbered fortlaufend.

Alternative path: Profile-Tab → Datenverwaltung → "Tauchgänge importieren" → Files-Picker → select test.uddf → same flow.

- [ ] **Step 13.3: Verify in DiveDetailView**

Tap on the first imported dive (2026-01-11, 19m). Verify:
- Site name = the GPS-coord-string from the fixture
- Lat/Lon non-zero
- Depth profile chart visible (down-sampled curve)
- Gas = "air"
- Tank size = 12 l, weight = 0 kg
- Bottom time ≈ 38 min

- [ ] **Step 13.4: Verify conflict-detection**

Import `test.uddf` again. The sheet should now show "7 Tauchgänge gefunden, 7 Duplikate, 0 neu". All checkboxes default to off. Strategy picker visible.

- [ ] **Step 13.5: Verify "Keep both" strategy**

Switch strategy to "Beide behalten", check one duplicate, tap Importieren. Verify the logbook now has 8 dives total, properly renumbered.

- [ ] **Step 13.6: Commit a manual-test log**

Append to `docs/operational/follow-ups-stabilize-2026-05-09.md` a new section:

```markdown
---

# UDDF Import — Manual Smoke-Test (2026-05-10)

**Setup:** Fresh simulator install. test.uddf shared via Files app.

**Test 1 (clean import):** 7 dives imported, numbered fortlaufend.
Dive 1 detail view shows depth profile chart, gas=air, weight=0,
volume=12l. Site GPS resolved correctly.

**Test 2 (duplicate detection):** Re-importing test.uddf shows
7/7 as Duplikat-von-#N.

**Test 3 (keep-both strategy):** One duplicate force-imported,
logbook expands to 8 dives, renumbering correct.

UDDF import via Plan A complete.
```

```bash
git add "docs/operational/follow-ups-stabilize-2026-05-09.md"
git commit -m "docs(uddf): manual smoke-test log for plan A"
```

---

## Task 14: Final verification + LoC summary

- [ ] **Step 14.1: Full build + test sweep**

```bash
cd "/Users/dominik/Desktop/Developer/DiveLog Pro"

xcodebuild build -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'generic/platform=iOS' 2>&1 | tail -5

xcodebuild test -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:"DiveLog ProTests/UDDFParserTests" \
  -only-testing:"DiveLog ProTests/UDDFDiveMapperTests" \
  -only-testing:"DiveLog ProTests/UDDFImportConflictTests" \
  -only-testing:"DiveLog ProTests/NumberingTests" \
  -only-testing:"DiveLog ProTests/PhotoStoreTests" 2>&1 | tail -20
```

Expected: BUILD SUCCEEDED and all UDDF tests + the pre-existing Numbering + Photo tests still green.

- [ ] **Step 14.2: LoC summary**

```bash
echo "=== New UDDF files ==="
wc -l "DiveLog Pro/Utils/UDDF/"*.swift
echo ""
echo "=== New UDDF tests ==="
wc -l "DiveLog ProTests/UDDF"*.swift
echo ""
echo "=== UDDFImportSheet ==="
wc -l "DiveLog Pro/Views/Screens/UDDFImportSheet.swift"
echo ""
echo "=== Branch commits since main ==="
git log --oneline main..HEAD
```

Expected: roughly 800-1000 LoC total of new code, ~8-10 commits since branching from main.

---

## Self-Review Checklist

- [ ] Spec coverage: Parser (Tasks 2-5), Mapper (Tasks 6-7), Conflict-Detection (Task 8), Coordinator (Task 9), Import-UI (Task 10), File-type-registration (Task 11), In-app-entry (Task 12), Manual verification (Task 13). All Phase-A spec sections covered.
- [ ] Test fixtures: `test.uddf` referenced by parser tests; mapper tests use synthetic data (faster, deterministic).
- [ ] TDD discipline: every code task has Write-Test → Run-Fail → Implement → Run-Pass → Commit cycle.
- [ ] Type consistency: `UDDFFile`/`UDDFDive`/`UDDFGas`/`UDDFSite`/`UDDFSample` defined in Task 1, referenced everywhere after. `ImportCandidate` + `ConflictStrategy` defined in Task 9, used in Task 10.
- [ ] No placeholders: every step has concrete code, exact file paths, exact commands.
- [ ] Existing tests preserved: Numbering + Photo + ModelContextExtensions tests are unaffected by Phase-A changes.
- [ ] Renumbering: `commitImport` calls `ctx.renumberDives(from: profile)` once after all inserts (Task 9), so imported dives integrate into the chronological sequence.
- [ ] CloudKit-safety: Insert via existing ModelContext, no new entity types — CloudKit-Sync works out of the box, no schema migration needed.

## Out-of-scope for this Plan

- **FIT-direct import** — Plan B, separate spec.
- **UDDF export** — Phase 4 polish.
- **Smart-Profile down-sampling** (LTTB or min/max-aware) — uniform sampling is sufficient for v1.
- **Pro-gating** — Phase 4 coverage audit.
- **Drag-and-drop into Logbook view** — Files-app share-sheet + Profile-Tab button cover the entry points.
- **Multi-file selection** — `fileImporter` is single-file for now; can iterate later.
