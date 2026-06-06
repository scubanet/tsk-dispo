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
