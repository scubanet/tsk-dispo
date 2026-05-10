//
// FITSDKSmokeTests.swift
// DiveLog ProTests
//
// Smoke tests for Garmin's Swift FIT SDK (FITSwiftSDK, v21.202.0), pinned
// via SwiftPM in the Xcode project. These tests prove the SDK can decode
// our 7 fixture .fit files end-to-end and lock in the API surface used by
// all subsequent Phase-B tasks (FITToUDDFMapper, Tasks 3-9).
//
// ===========================================================================
// Confirmed API surface (verified against passing tests, 2026-05-10)
// ===========================================================================
//
//   import FITSwiftSDK
//
//   // Construct the SDK's InputStream. Qualify the type to avoid
//   // ambiguity with Foundation.InputStream (the SDK's stream is its
//   // own class and does NOT require .open()):
//   let stream = FITSwiftSDK.InputStream(data: fileData)
//
//   // Decoder + listener pipeline:
//   let decoder = Decoder(stream: stream)
//   let listener = FitListener()
//   decoder.addMesgListener(listener)
//   try decoder.read()                       // throws Decoder.DecoderError
//
//   // Pre-decode probes (also throwing):
//   try decoder.isFIT()                      // Bool — header recognises FIT
//   try decoder.checkIntegrity()             // Bool — CRC + structure
//
//   // Access typed Mesg arrays via the listener:
//   let messages = listener.fitMessages
//   messages.sessionMesgs                    // [SessionMesg]
//   messages.recordMesgs                     // [RecordMesg]
//   messages.diveSummaryMesgs                // [DiveSummaryMesg]
//   messages.diveGasMesgs                    // [DiveGasMesg]
//   messages.diveSettingsMesgs               // [DiveSettingsMesg]
//   messages.diveAlarmMesgs                  // [DiveAlarmMesg]
//   messages.diveApneaAlarmMesgs             // [DiveApneaAlarmMesg]
//   messages.tankSummaryMesgs                // [TankSummaryMesg]
//   messages.tankUpdateMesgs                 // [TankUpdateMesg]
//   messages.deviceInfoMesgs                 // [DeviceInfoMesg]
//   messages.fileIdMesgs                     // [FileIdMesg]
//
//   // Field accessors on each Mesg are GETTER-STYLE METHODS (not properties)
//   // returning Optionals. Examples confirmed by the passing tests:
//   session.getStartTime()                   // Date?
//   session.getTotalElapsedTime()            // Float?  (seconds)
//   // Mappers in Tasks 3-9 will follow the same getXxx() pattern.
//
//   // Decoder error type:
//   public enum Decoder.DecoderError: Error {
//       case isNotFitFile
//       case crcFailed
//       case compressedTimestampDataMessageNotSupported
//       case messageDefinitionNotFound(localMesgNum: LocalMesgNum)
//   }
//
// ===========================================================================

import Testing
import Foundation
import FITSwiftSDK
@testable import DiveLog_Pro

@Suite("FITSwiftSDK Smoke Tests")
struct FITSDKSmokeTests {

    // MARK: - Fixture helpers

    /// All FIT fixtures bundled with the test target (names without extension).
    private static let fixtureNames: [String] = [
        "8753 IDC 126",
        "8754 IDC 126",
        "8756 Mamutic Island",
        "8757 Mamutic Island",
        "8758 OWD Dry Tg1",
        "8762 Singlegas-Tauchgang",
        "8763 OWD Dry Tg2"
    ]

    /// Resolve a FIT fixture from the test bundle, regardless of whether
    /// Xcode flattens the `Fixtures/fit/` subdirectory or preserves it.
    private static func fixtureURL(named name: String) throws -> URL {
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

    private enum FixtureError: Error { case notFound(String) }

    /// Decode a `.fit` file into the SDK's FitMessages aggregate.
    private static func decodeFitMessages(from data: Data) throws -> FitMessages {
        let stream = FITSwiftSDK.InputStream(data: data)
        let decoder = Decoder(stream: stream)
        let listener = FitListener()
        decoder.addMesgListener(listener)
        try decoder.read()
        return listener.fitMessages
    }

    // MARK: - Tests

    @Test("at least one FIT fixture is bundled and loadable")
    func fixturesAreBundled() throws {
        let url = try Self.fixtureURL(named: Self.fixtureNames[0])
        let data = try Data(contentsOf: url)
        #expect(data.count > 0)
    }

    @Test("Decoder recognises every fixture as a FIT file")
    func recognisesFitFiles() throws {
        for name in Self.fixtureNames {
            let url = try Self.fixtureURL(named: name)
            let data = try Data(contentsOf: url)
            let stream = FITSwiftSDK.InputStream(data: data)
            let decoder = Decoder(stream: stream)
            let isFit = try decoder.isFIT()
            #expect(isFit, "\(name) should be recognised as FIT")
        }
    }

    @Test("Decoder.checkIntegrity passes on every fixture")
    func integrityChecks() throws {
        for name in Self.fixtureNames {
            let url = try Self.fixtureURL(named: name)
            let data = try Data(contentsOf: url)
            let stream = FITSwiftSDK.InputStream(data: data)
            let decoder = Decoder(stream: stream)
            let ok = try decoder.checkIntegrity()
            #expect(ok, "\(name) failed checkIntegrity")
        }
    }

    @Test("decoding a fixture yields a session with start time and elapsed time")
    func decodeYieldsSession() throws {
        let url = try Self.fixtureURL(named: "8756 Mamutic Island")
        let data = try Data(contentsOf: url)
        let msgs = try Self.decodeFitMessages(from: data)

        // A dive computer file should produce at least one session.
        #expect(msgs.sessionMesgs.count >= 1,
                "expected >=1 sessionMesg, got \(msgs.sessionMesgs.count)")

        let session = msgs.sessionMesgs[0]
        let start = session.getStartTime()
        let elapsed = session.getTotalElapsedTime()
        #expect(start != nil, "session.getStartTime() should not be nil")
        #expect(elapsed != nil, "session.getTotalElapsedTime() should not be nil")
        if let e = elapsed {
            #expect(e > 0, "elapsed time should be positive, got \(e)")
        }
    }

    @Test("decoding yields record samples and a fileId")
    func decodeYieldsRecordsAndFileId() throws {
        let url = try Self.fixtureURL(named: "8756 Mamutic Island")
        let data = try Data(contentsOf: url)
        let msgs = try Self.decodeFitMessages(from: data)

        #expect(msgs.fileIdMesgs.count >= 1, "expected at least one fileIdMesg")
        #expect(msgs.recordMesgs.count > 0,
                "dive computer FIT should contain record samples; got \(msgs.recordMesgs.count)")
    }
}

// Marker class so we can resolve the test bundle via Bundle(for:).
private final class BundleMarker {}
