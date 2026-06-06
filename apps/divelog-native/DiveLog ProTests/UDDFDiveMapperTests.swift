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
        #expect(dive.depthProfile.count > 100)
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
}
