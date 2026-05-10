import Foundation
import SwiftData
import FITSwiftSDK

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
        let isDE = L10n.currentLanguage == "de"
        switch self {
        case .skip:      return isDE ? "Überspringen" : "Skip"
        case .overwrite: return isDE ? "Überschreiben" : "Overwrite"
        case .keepBoth:  return isDE ? "Beide behalten" : "Keep both"
        }
    }
}

extension UDDFImportCoordinator {

    /// Full pipeline: parse the dive-computer file at `url`, map each
    /// UDDFDive to a Dive, check each against `existingDives` for duplicates.
    /// Returns the candidate list ready for UI presentation.
    ///
    /// Dispatches by file extension:
    ///   - `.uddf` / `.xml` → UDDFParser
    ///   - `.fit`            → FITSwiftSDK + FITToUDDFMapper
    ///   - other             → throws UDDFParseError.fileUnreadable
    ///
    /// Both paths produce the same internal `UDDFFile`, so downstream
    /// mapping (UDDFDiveMapper + DiveComputerImportSheet) is identical.
    @MainActor
    static func prepareImport(from url: URL, existingDives: [Dive]) async throws -> (UDDFFile, [ImportCandidate]) {
        let ext = url.pathExtension.lowercased()
        let file: UDDFFile

        switch ext {
        case "uddf", "xml":
            // Parsing is CPU-bound; run on a background priority to keep UI snappy.
            file = try await Task.detached(priority: .userInitiated) {
                try UDDFParser().parse(url: url)
            }.value
        case "fit":
            file = try await Task.detached(priority: .userInitiated) { () throws -> UDDFFile in
                // Security-scoped — required when URL comes from .fileImporter.
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                let stream = FITSwiftSDK.InputStream(data: data)
                let decoder = Decoder(stream: stream)
                let listener = FitListener()
                decoder.addMesgListener(listener)
                try decoder.read()
                return FITToUDDFMapper.makeUDDFFile(from: listener.fitMessages)
            }.value
        default:
            throw UDDFParseError.fileUnreadable(url)
        }

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
