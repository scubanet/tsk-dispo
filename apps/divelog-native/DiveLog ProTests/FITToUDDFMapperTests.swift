//
// FITToUDDFMapperTests.swift
// DiveLog ProTests
//
// Tests for FITToUDDFMapper (Phase B, Task 3): the Layer-1.5 mapper that
// translates a Garmin FIT-SDK FitMessages collection into the same
// UDDFFile struct produced by Phase A's UDDFParser. This task covers
// only the enum skeleton + extractGenerator. Gas/site/dive extraction
// is filled in by Tasks 4-8.
//

import Testing
import Foundation
import FITSwiftSDK
@testable import DiveLog_Pro

// MARK: - File-private fixture helpers shared across suites in this file

private enum FixtureError: Error { case notFound(String) }

/// Resolve a FIT fixture from the test bundle, regardless of whether
/// Xcode flattens the `Fixtures/fit/` subdirectory or preserves it.
fileprivate func fixtureURL(named name: String) throws -> URL {
    let bundle = Bundle(for: BundleMarker.self)
    if let url = bundle.url(forResource: name, withExtension: "fit") {
        return url
    }
    if let url = bundle.url(forResource: name,
                            withExtension: "fit",
                            subdirectory: "Fixtures/fit") {
        return url
    }
    if let url = bundle.url(forResource: name,
                            withExtension: "fit",
                            subdirectory: "fit") {
        return url
    }
    throw FixtureError.notFound(name)
}

/// Decode a `.fit` file into the SDK's FitMessages aggregate.
fileprivate func decodeFitMessages(from data: Data) throws -> FitMessages {
    let stream = FITSwiftSDK.InputStream(data: data)
    let decoder = Decoder(stream: stream)
    let listener = FitListener()
    decoder.addMesgListener(listener)
    try decoder.read()
    return listener.fitMessages
}

fileprivate func uddf(forFixture name: String) throws -> UDDFFile {
    let url = try fixtureURL(named: name)
    let data = try Data(contentsOf: url)
    let messages = try decodeFitMessages(from: data)
    return FITToUDDFMapper.makeUDDFFile(from: messages)
}

// Marker class so we can resolve the test bundle via Bundle(for:).
private final class BundleMarker {}

@Suite("FITToUDDFMapper — generator")
struct FITToUDDFMapperTests {

    // MARK: - Tests

    @Test("generator string for 8762 Singlegas-Tauchgang contains 'garmin' (case-insensitive)")
    func generator_isGarmin() throws {
        let file = try uddf(forFixture: "8762 Singlegas-Tauchgang")
        #expect(file.generator.lowercased().contains("garmin"),
                "expected generator to mention Garmin, got '\(file.generator)'")
    }

    @Test("generator is non-empty for every fixture we ship")
    func generator_isNonEmpty_forAllFixtures() throws {
        let names = [
            "8753 IDC 126",
            "8757 Mamutic Island",
            "8762 Singlegas-Tauchgang"
        ]
        for name in names {
            let file = try uddf(forFixture: name)
            #expect(!file.generator.isEmpty,
                    "expected non-empty generator for \(name), got '\(file.generator)'")
        }
    }
}

@Suite("FITToUDDFMapper — gases")
struct FITToUDDFMapperGasTests {

    @Test("single-gas dive (8762) has at least one gas with air-range O2 and zero He")
    func singleGasDive_hasOneAirGas() throws {
        let file = try uddf(forFixture: "8762 Singlegas-Tauchgang")
        #expect(!file.gasDefinitions.isEmpty,
                "expected at least one gas definition for single-gas fixture")

        // At least one gas should look like air (O2 in [0.19, 0.23], He == 0).
        let airish = file.gasDefinitions.values.first { gas in
            gas.o2 >= 0.19 && gas.o2 <= 0.23 && gas.he == 0
        }
        #expect(airish != nil,
                "expected one air-range gas, got: \(file.gasDefinitions.values.map { "(o2:\($0.o2), he:\($0.he))" })")
    }

    @Test("gas IDs are stable and unique across the dict for 8757 Mamutic Island")
    func gasIds_areStableAndUnique() throws {
        let file = try uddf(forFixture: "8757 Mamutic Island")
        let ids = file.gasDefinitions.values.map(\.id)
        let uniqueIds = Set(ids)
        #expect(ids.count == uniqueIds.count,
                "expected gas IDs to be unique, got \(ids)")
        // Dict keys should also match the gas.id values exactly (sanity).
        #expect(Set(file.gasDefinitions.keys) == uniqueIds,
                "expected dict keys == gas.id values, keys=\(file.gasDefinitions.keys) ids=\(uniqueIds)")
    }
}

@Suite("FITToUDDFMapper — sites")
struct FITToUDDFMapperSiteTests {

    @Test("8757 Mamutic Island yields no site because MK3i firmware did not write GPS to FIT")
    func mamuticIsland_yieldsNoSite_whenFITLacksGPS() throws {
        // Diagnostic note: our 7 MK3i fixtures (including this one) ship
        // without GPS in the SessionMesg — startPositionLat/Long are nil.
        // Phase A's UDDF had Mamutic coordinates only because Subsurface
        // enriches from its dive-site database on export, not because
        // the underlying FIT had them. This test pins that behavior:
        // when the FIT lacks GPS, `extractDiveSites` correctly returns
        // an empty dictionary rather than fabricating a (0,0) entry.
        let file = try uddf(forFixture: "8757 Mamutic Island")
        #expect(file.diveSites.isEmpty,
                "MK3i did not write GPS for this fixture — expected no extracted site, got \(file.diveSites.count)")
    }

    @Test("8763 OWD Dry Tg2 (dry pool) yields no sites OR sites with nil lat/lon")
    func dryPoolDive_noGPS() throws {
        let file = try uddf(forFixture: "8763 OWD Dry Tg2")
        // Either zero sites OR every site has nil lat AND nil lon.
        let allNoGPS = file.diveSites.values.allSatisfy { site in
            site.latitude == nil && site.longitude == nil
        }
        #expect(file.diveSites.isEmpty || allNoGPS,
                "expected zero sites or all-nil GPS for dry pool dive, got: \(file.diveSites.values.map { "(lat:\(String(describing: $0.latitude)), lon:\(String(describing: $0.longitude)))" })")
    }

    @Test("semicircles → decimal degrees conversion math is correct")
    func gpsConversion_math_isCorrect() throws {
        // Zero semicircles == zero degrees.
        #expect(FITToUDDFMapper.semicirclesToDegrees(0) == 0)

        // Full positive range: Int32.max ≈ +180°.
        #expect(abs(FITToUDDFMapper.semicirclesToDegrees(Int32.max) - 180.0) < 0.001)

        // Full negative range: -Int32.max ≈ -180°.
        #expect(abs(FITToUDDFMapper.semicirclesToDegrees(-Int32.max) + 180.0) < 0.001)

        // Mamutic Island reference: lat ≈ 10.21° (Cebu Strait, Philippines).
        // 10.21° = 10.21 / 180 × 2^31 ≈ 121,832,232 semicircles.
        #expect(abs(FITToUDDFMapper.semicirclesToDegrees(121_832_232) - 10.21) < 0.01)
    }
}

@Suite("FITToUDDFMapper — dive header")
struct FITToUDDFMapperDiveHeaderTests {

    @Test("each FIT fixture produces exactly one UDDFDive")
    func produces_exactlyOneDive_perFITFile() throws {
        let names = [
            "8753 IDC 126",
            "8762 Singlegas-Tauchgang",
            "8757 Mamutic Island"
        ]
        for name in names {
            let file = try uddf(forFixture: name)
            #expect(file.dives.count == 1,
                    "expected exactly one dive for \(name), got \(file.dives.count)")
        }
    }

    @Test("8757 Mamutic Island dive datetime falls within the fleet's plausible range")
    func dive_datetime_isReasonable() throws {
        let file = try uddf(forFixture: "8757 Mamutic Island")
        let dive = try #require(file.dives.first,
                                "expected a dive for 8757 Mamutic Island")

        // 2024-01-01 00:00:00 UTC
        let lower = Date(timeIntervalSince1970: 1_704_067_200)
        // 2026-06-04 00:00:00 UTC
        let upper = Date(timeIntervalSince1970: 1_780_531_200)
        #expect(dive.datetime > lower,
                "datetime \(dive.datetime) should be after 2024-01-01")
        #expect(dive.datetime < upper,
                "datetime \(dive.datetime) should be before 2026-06-04")
    }

    @Test("8757 Mamutic Island dive maxDepth is positive and recreational (<100 m)")
    func dive_maxDepth_isPositive_andRecreational() throws {
        let file = try uddf(forFixture: "8757 Mamutic Island")
        let dive = try #require(file.dives.first,
                                "expected a dive for 8757 Mamutic Island")
        #expect(dive.maxDepthMeters > 0,
                "maxDepth should be > 0, got \(dive.maxDepthMeters)")
        #expect(dive.maxDepthMeters < 100,
                "maxDepth should be < 100 m (recreational), got \(dive.maxDepthMeters)")
    }

    @Test("8762 Singlegas-Tauchgang dive duration is positive and under 2 h")
    func dive_duration_isPositive() throws {
        let file = try uddf(forFixture: "8762 Singlegas-Tauchgang")
        let dive = try #require(file.dives.first,
                                "expected a dive for 8762 Singlegas-Tauchgang")
        #expect(dive.durationSeconds > 0,
                "durationSeconds should be > 0, got \(dive.durationSeconds)")
        #expect(dive.durationSeconds < 7200,
                "durationSeconds should be < 7200 (2 h), got \(dive.durationSeconds)")
    }
}

@Suite("FITToUDDFMapper — samples")
struct FITToUDDFMapperSampleTests {

    @Test("8762 Singlegas-Tauchgang dive has > 100 samples")
    func samples_areNotEmpty() throws {
        let file = try uddf(forFixture: "8762 Singlegas-Tauchgang")
        let dive = try #require(file.dives.first,
                                "expected a dive for 8762 Singlegas-Tauchgang")
        #expect(dive.samples.count > 100,
                "expected > 100 samples, got \(dive.samples.count)")
    }

    @Test("8762 Singlegas-Tauchgang sample times are monotonically non-decreasing")
    func sample_timeSeconds_isMonotonic() throws {
        let file = try uddf(forFixture: "8762 Singlegas-Tauchgang")
        let dive = try #require(file.dives.first,
                                "expected a dive for 8762 Singlegas-Tauchgang")
        let samples = dive.samples
        #expect(!samples.isEmpty, "expected non-empty samples")
        for i in 1..<samples.count {
            #expect(samples[i].timeSeconds >= samples[i - 1].timeSeconds,
                    "sample times should be non-decreasing at i=\(i): prev=\(samples[i - 1].timeSeconds), curr=\(samples[i].timeSeconds)")
        }
    }

    @Test("8762 Singlegas-Tauchgang first 5 samples start shallow (< 5 m)")
    func sample_atTime0_shallow() throws {
        let file = try uddf(forFixture: "8762 Singlegas-Tauchgang")
        let dive = try #require(file.dives.first,
                                "expected a dive for 8762 Singlegas-Tauchgang")
        let firstFive = Array(dive.samples.prefix(5))
        #expect(firstFive.count == 5,
                "expected at least 5 samples, got \(firstFive.count)")
        for (idx, s) in firstFive.enumerated() {
            #expect(s.depthMeters < 5,
                    "first 5 samples should be < 5 m deep; sample[\(idx)] depth=\(s.depthMeters)")
        }
    }

    @Test("8757 Mamutic Island samples with temperature fall in tropical (15, 35) °C")
    func sample_temperatures_tropical() throws {
        let file = try uddf(forFixture: "8757 Mamutic Island")
        let dive = try #require(file.dives.first,
                                "expected a dive for 8757 Mamutic Island")
        let temps = dive.samples.compactMap(\.temperatureCelsius)
        #expect(!temps.isEmpty,
                "expected at least some samples to carry temperature for Mamutic Island")
        for t in temps {
            #expect(t > 15 && t < 35,
                    "tropical temperature out of (15, 35) °C: \(t)")
        }
    }
}

@Suite("FITToUDDFMapper — tank pressures")
struct FITToUDDFMapperTankTests {

    /// All 7 MK3i fixtures we ship — duplicated from FITSDKSmokeTests
    /// (its `fixtureNames` is `private static`, not file-private).
    private static let fixtureNames: [String] = [
        "8753 IDC 126",
        "8754 IDC 126",
        "8756 Mamutic Island",
        "8757 Mamutic Island",
        "8758 OWD Dry Tg1",
        "8762 Singlegas-Tauchgang",
        "8763 OWD Dry Tg2"
    ]

    @Test("tank pressures are realistic when present in the 3 main fixtures")
    func tankPressures_realistic_whenAvailable() throws {
        let main = [
            "8753 IDC 126",
            "8757 Mamutic Island",
            "8762 Singlegas-Tauchgang"
        ]
        var report: [String] = []
        for name in main {
            let file = try uddf(forFixture: name)
            let dive = try #require(file.dives.first,
                                    "expected a dive for \(name)")
            let start = dive.tankStartBar
            let end = dive.tankEndBar
            report.append("\(name): start=\(start.map(String.init) ?? "nil") end=\(end.map(String.init) ?? "nil")")
            // Allow nils — not every fixture might have AirIntegration.
            if let s = start, let e = end {
                if !(s > 0 && s <= 300) {
                    Issue.record("start pressure out of (0, 300] bar for \(name): \(s)\n\(report.joined(separator: "\n"))")
                }
                if !(e > 0 && e <= 300) {
                    Issue.record("end pressure out of (0, 300] bar for \(name): \(e)\n\(report.joined(separator: "\n"))")
                }
                if !(s >= e) {
                    Issue.record("start pressure must be >= end pressure for \(name): start=\(s), end=\(e)\n\(report.joined(separator: "\n"))")
                }
            }
        }
    }

    @Test("at least one fixture across the 7 ships AirIntegration TankSummary data")
    func atLeastOneFixture_hasTankData() throws {
        var report: [String] = []
        var anyPopulated = false
        for name in Self.fixtureNames {
            let url = try fixtureURL(named: name)
            let data = try Data(contentsOf: url)
            let msgs = try decodeFitMessages(from: data)
            let file = FITToUDDFMapper.makeUDDFFile(from: msgs)
            let dive = file.dives.first
            let start = dive?.tankStartBar
            let end = dive?.tankEndBar
            report.append("\(name): start=\(start.map(String.init) ?? "nil") end=\(end.map(String.init) ?? "nil") (tankSummary count=\(msgs.tankSummaryMesgs.count))")
            if start != nil { anyPopulated = true }
        }
        if !anyPopulated {
            Issue.record("no fixture carried AirIntegration TankSummary data\n\(report.joined(separator: "\n"))")
        }
    }
}

@Suite("FITToUDDFMapper — golden soll vs test.uddf")
// ============================================================================
// Golden-soll cross-validation: FIT-direct pipeline vs Phase A's UDDF pipeline.
//
// Discovery during Task 9: **Subsurface strips timezone offsets when exporting
// UDDF.** It stores local-time wall-clock values as if they were UTC. The
// resulting datetimes are off by:
//   - Philippines dives: +8h (PHT is UTC+8, no DST)
//   - Germany pool dives: +2h (CEST is UTC+2 in April)
//
// Concrete examples from test.uddf vs our FIT decode:
//   FIT 8757 Mamutic: 2026-03-12 06:25:42 UTC  ↔  UDDF[4]: 14:25:42 "UTC"  (Δ=8h)
//   FIT 8758 OWD Pool: 2026-04-25 09:29:56 UTC ↔  UDDF[5]: 11:29:56 "UTC"  (Δ=2h)
//
// Our FIT pipeline is CORRECT (extracts the real UTC timestamp); the UDDF
// baseline carries a Subsurface export bug. We accept this and pair the two
// pipelines by **sort-and-index** instead of date proximity. Physical
// parameters (maxDepth, durationSeconds) are unaffected by the tz bug and
// remain valid cross-checks.
// ============================================================================
struct FITToUDDFMapperGoldenTests {

    /// All 7 MK3i fixtures we ship — matches the list in FITToUDDFMapperTankTests.
    private static let fixtureNames: [String] = [
        "8753 IDC 126",
        "8754 IDC 126",
        "8756 Mamutic Island",
        "8757 Mamutic Island",
        "8758 OWD Dry Tg1",
        "8762 Singlegas-Tauchgang",
        "8763 OWD Dry Tg2"
    ]

    private func decodeFIT(_ name: String) throws -> FitMessages {
        let url = try fixtureURL(named: name)
        let data = try Data(contentsOf: url)
        return try decodeFitMessages(from: data)
    }

    /// Load Phase A's `test.uddf` (Subsurface export of the same 7 physical dives).
    /// Mirrors UDDFParserTests' loading pattern but tolerates either bundle layout.
    private func loadUDDF() throws -> UDDFFile {
        let bundle = Bundle(for: BundleMarker.self)
        let url: URL
        if let u = bundle.url(forResource: "test", withExtension: "uddf") {
            url = u
        } else if let u = bundle.url(forResource: "test",
                                     withExtension: "uddf",
                                     subdirectory: "Fixtures/uddf") {
            url = u
        } else if let u = bundle.url(forResource: "test",
                                     withExtension: "uddf",
                                     subdirectory: "uddf") {
            url = u
        } else {
            throw FixtureError.notFound("test.uddf")
        }
        return try UDDFParser().parse(url: url)
    }

    /// Build all 7 FIT-derived dives sorted chronologically by UTC datetime.
    /// We pair these against the chronologically-sorted UDDF dives by index,
    /// NOT by date proximity — see the "Known Subsurface timezone bug" note above.
    private func sortedFITDives() throws -> [UDDFDive] {
        var dives: [UDDFDive] = []
        for name in Self.fixtureNames {
            let msgs = try decodeFIT(name)
            let file = FITToUDDFMapper.makeUDDFFile(from: msgs)
            if let dive = file.dives.first { dives.append(dive) }
        }
        return dives.sorted { $0.datetime < $1.datetime }
    }

    @Test func mamuticIsland_matches_UDDF_on_physicalParameters() throws {
        // Pair 8757 Mamutic — known to be UDDF[4] after sorting both lists
        // (UDDF strips +8h Philippines timezone, so UDDF[4]=14:25 UTC ↔ FIT=06:25 UTC).
        let msgs = try decodeFIT("8757 Mamutic Island")
        let fitFile = FITToUDDFMapper.makeUDDFFile(from: msgs)
        guard let fitDive = fitFile.dives.first else {
            Issue.record("FIT 8757 produced no dive")
            return
        }

        let uddf = try loadUDDF()
        let sortedUDDF = uddf.dives.sorted { $0.datetime < $1.datetime }
        // 8757 is the deepest Mamutic dive — should be UDDF[4] (Mar 12 14:25, depth 11.151).
        guard sortedUDDF.count > 4 else {
            Issue.record("UDDF has fewer than 5 dives — expected 7")
            return
        }
        let uddfDive = sortedUDDF[4]

        let depthDelta = abs(fitDive.maxDepthMeters - uddfDive.maxDepthMeters)
        #expect(depthDelta < 0.5, "maxDepth FIT=\(fitDive.maxDepthMeters) UDDF=\(uddfDive.maxDepthMeters) Δ=\(depthDelta)")

        // Duration tolerance is 180s because Subsurface trims surface-time
        // (descent before reaching 1m, ascent after surfacing) — FIT keeps the
        // full session length. Across all 7 fixtures we observed FIT > UDDF
        // by 60-117s consistently. 180s gives comfortable headroom.
        let durDelta = abs(fitDive.durationSeconds - uddfDive.durationSeconds)
        #expect(durDelta < 180, "duration delta \(durDelta)s FIT=\(fitDive.durationSeconds) UDDF=\(uddfDive.durationSeconds)")
    }

    @Test func allFixtures_pairByDate_agreeOnPhysicalParameters() throws {
        // Strategy: sort both lists chronologically (by UTC datetime as each
        // pipeline produces it), pair by index, validate depth+duration deltas.
        // We do NOT compare datetime — known Subsurface tz-stripping bug
        // (Philippines dives off by 8h, Germany pool dives off by 2h CEST).
        let uddf = try loadUDDF()
        let sortedUDDF = uddf.dives.sorted { $0.datetime < $1.datetime }
        let sortedFIT = try sortedFITDives()

        var report: [String] = []
        report.append("=== Sorted pair comparison (UDDF tz-stripped — pairing by index after sort) ===")

        var matched = 0
        let pairCount = min(sortedFIT.count, sortedUDDF.count)
        for i in 0..<pairCount {
            let fit = sortedFIT[i]
            let uddf = sortedUDDF[i]
            let depthDelta = abs(fit.maxDepthMeters - uddf.maxDepthMeters)
            let durDelta = abs(fit.durationSeconds - uddf.durationSeconds)
            let tzDelta = uddf.datetime.timeIntervalSince(fit.datetime)
            // Duration tolerance: 180s. See per-fixture comment in the
            // mamuticIsland test — Subsurface trims surface-time.
            let verdict = (depthDelta < 0.5 && durDelta < 180) ? "MATCH" : "NO MATCH"
            if verdict == "MATCH" { matched += 1 }
            report.append("  [\(i)] \(verdict) depthΔ=\(depthDelta)m durΔ=\(durDelta)s tzShift=\(tzDelta)s (FIT \(fit.datetime) d=\(fit.maxDepthMeters)m dur=\(fit.durationSeconds)s | UDDF \(uddf.datetime) d=\(uddf.maxDepthMeters)m dur=\(uddf.durationSeconds)s)")
        }

        // We tolerate up to 2 mismatches (e.g. one fixture might have post-
        // processing differences); 5/7 is the minimum confidence threshold.
        if matched < 5 {
            Issue.record("only \(matched)/\(pairCount) pairs matched on depth+duration\n\(report.joined(separator: "\n"))")
        }
    }
}
