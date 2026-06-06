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
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
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

    @Test("first dive has samples with depth + time + (sparse) temperature")
    func firstDiveSamples() throws {
        let parser = UDDFParser()
        let file = try parser.parse(url: fixtureURL)
        let d0 = file.dives[0]

        // Test fixture has 9499 samples across 7 dives; first dive specifically
        // should have a substantial number.
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

        // ~45 temperature readings vs 9499 waypoints = sparse. Many samples
        // should have no temperature.
        let withoutTemp = d0.samples.filter { $0.temperatureCelsius == nil }
        #expect(withoutTemp.count > 0)
    }
}

// Marker class so we can resolve the test bundle via Bundle(for:).
private final class BundleMarker {}
