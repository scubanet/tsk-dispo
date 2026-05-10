//
// DiveComputerImportDispatchTests.swift
// DiveLog ProTests
//
// Phase B / Task 10 — verifies UDDFImportCoordinator.prepareImport dispatches
// by file extension:
//   - .uddf / .xml  → UDDFParser
//   - .fit          → FITSwiftSDK + FITToUDDFMapper
//   - other         → throws
//
// Both .uddf and .fit must produce the same downstream pipeline:
// UDDFFile → [ImportCandidate] via UDDFDiveMapper.
//

import Testing
import Foundation
@testable import DiveLog_Pro

@Suite("ImportCoordinator dispatch")
struct DiveComputerImportDispatchTests {

    @Test @MainActor
    func dispatch_uddf_yieldsCandidates() async throws {
        let url = Bundle(for: BundleMarker.self)
            .url(forResource: "test", withExtension: "uddf", subdirectory: "Fixtures/uddf")
            ?? Bundle(for: BundleMarker.self).url(forResource: "test", withExtension: "uddf")!
        let (file, candidates) = try await UDDFImportCoordinator.prepareImport(
            from: url, existingDives: [])
        #expect(file.dives.count == 7)
        #expect(candidates.count == 7)
    }

    @Test @MainActor
    func dispatch_fit_yieldsCandidates() async throws {
        let url = Bundle(for: BundleMarker.self)
            .url(forResource: "8762 Singlegas-Tauchgang", withExtension: "fit", subdirectory: "Fixtures/fit")
            ?? Bundle(for: BundleMarker.self).url(forResource: "8762 Singlegas-Tauchgang", withExtension: "fit")!
        let (file, candidates) = try await UDDFImportCoordinator.prepareImport(
            from: url, existingDives: [])
        #expect(file.dives.count == 1)
        #expect(candidates.count == 1)
        #expect(file.generator.lowercased().contains("garmin"))
    }

    @Test @MainActor
    func dispatch_unknownExtension_throws() async {
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("garbage-\(UUID().uuidString).xyz")
        try? "<not-a-divefile>".write(to: tmpURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmpURL) }
        await #expect(throws: Error.self) {
            try await UDDFImportCoordinator.prepareImport(
                from: tmpURL, existingDives: [])
        }
    }
}

// Marker class so we can resolve the test bundle via Bundle(for:).
private final class BundleMarker {}
