//
// FITToUDDFMapper.swift
// DiveLog Pro
//
// Layer-1.5 of the dive-computer import pipeline. Maps a Garmin FIT-SDK
// `FitMessages` collection into the same `UDDFFile` struct that Phase A's
// `UDDFParser` produces, so downstream layers (`UDDFDiveMapper` →
// `DiveComputerImportSheet`) consume one canonical representation regardless of
// source format.
//
// Phase A (UDDF):  XML data -> UDDFParser     -> UDDFFile
// Phase B (FIT):   FIT data -> FIT-SDK decode -> FitMessages
//                                            -> FITToUDDFMapper -> UDDFFile
//
// This file currently implements only the enum skeleton + generator
// extraction (Task 3). Gas / dive-site / dive extraction are stubs that
// return empty collections and get filled in by Tasks 4-8.
//

import Foundation
import FITSwiftSDK

/// Maps a decoded Garmin FIT-SDK `FitMessages` collection into a `UDDFFile`.
///
/// Mirrors the role of `UDDFParser` in Phase A: a single static entry
/// point that produces the canonical `UDDFFile` representation consumed
/// by `UDDFDiveMapper`.
enum FITToUDDFMapper {

    /// Single public entry point. Builds the canonical `UDDFFile` from a
    /// decoded `FitMessages` aggregate. Never throws — fields the FIT
    /// recording omits are surfaced as empty collections / nil so
    /// downstream layers can decide how to handle them.
    static func makeUDDFFile(from messages: FitMessages) -> UDDFFile {
        let generator = extractGenerator(messages)
        let gasDefs = extractGasDefinitions(messages)
        let sites = extractDiveSites(messages)
        // For Task 6 we attach every dive in the file to the first
        // extracted site, if any. MK3i fixtures only ever ship a single
        // SessionMesg, so the mapping is unambiguous for our current
        // fleet. A future task may revisit per-dive site assignment.
        let siteId = sites.keys.sorted().first
        return UDDFFile(
            generator: generator,
            gasDefinitions: gasDefs,
            diveSites: sites,
            dives: extractDives(messages, gasDefs: gasDefs, siteId: siteId)
        )
    }

    // MARK: - Generator

    /// Best-effort identifier of the device + manufacturer that produced
    /// the FIT file. Preference order:
    ///   1. DeviceInfoMesg.getProductName()  → "Garmin <product>"
    ///   2. FileIdMesg.getManufacturer()     → "Garmin" (if Garmin)
    ///   3. Fallback                          → "FIT"
    static func extractGenerator(_ messages: FitMessages) -> String {
        // 1. Prefer a real product name from a DeviceInfo message.
        for device in messages.deviceInfoMesgs {
            if let name = device.getProductName(), !name.isEmpty {
                // The FIT product name typically lacks the "Garmin" prefix
                // (e.g. "Descent Mk3i"). Add it for parity with UDDF generators
                // like "Subsurface Divelog v3".
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.lowercased().contains("garmin") {
                    return trimmed
                }
                return "Garmin \(trimmed)"
            }
        }

        // 2. Fall back to the file-id manufacturer field. Garmin's
        //    FIT-SDK exposes the manufacturer profile type as an enum; we
        //    inspect its String description so this code stays correct
        //    whether the getter returns `Manufacturer?`, `UInt16?`, or
        //    another representation.
        for fileId in messages.fileIdMesgs {
            if let manufacturer = fileId.getManufacturer() {
                let desc = String(describing: manufacturer).lowercased()
                if desc.contains("garmin") {
                    return "Garmin"
                }
                // Manufacturer code 1 == Garmin in the FIT profile.
                if desc == "1" || desc == "optional(1)" {
                    return "Garmin"
                }
                // Some other manufacturer — surface the raw description
                // so it's at least non-empty and informative.
                let cleaned = desc.replacingOccurrences(of: "optional(", with: "")
                                  .replacingOccurrences(of: ")", with: "")
                if !cleaned.isEmpty {
                    return cleaned
                }
            }
        }

        // 3. Final fallback so the field is never empty.
        return "FIT"
    }

    // MARK: - Stubs filled by Tasks 4-8

    /// Build the dive's gas definitions from `messages.diveGasMesgs`.
    ///
    /// Each `DiveGasMesg` maps to one `UDDFGas`, keyed by `"fit-gas-<index>"`
    /// where `<index>` is the message's 0-based position in the array — this
    /// keeps IDs stable and unique within a single FIT file.
    ///
    /// Name classification from the O2/He fractions:
    ///   - `he > 0`     → `"trimix"`
    ///   - `o2 < 0.22`  → `"air"`
    ///   - otherwise    → `"ean<percent>"` (e.g. `"ean32"`)
    ///
    /// If the FIT file shipped no gas messages (older firmware corner case;
    /// the MK3i fixtures all carry at least one), synthesize a single
    /// `"fit-gas-default"` air entry so downstream code never has to handle
    /// the empty case.
    static func extractGasDefinitions(_ messages: FitMessages) -> [String: UDDFGas] {
        var result: [String: UDDFGas] = [:]

        for (index, msg) in messages.diveGasMesgs.enumerated() {
            // SDK getters return UInt8? for the percent fields. Default
            // missing oxygen to 21% (air) and missing helium to 0%.
            let o2Percent = Double(msg.getOxygenContent() ?? 21)
            let hePercent = Double(msg.getHeliumContent() ?? 0)

            let id = "fit-gas-\(index)"
            let o2 = o2Percent / 100.0
            let he = hePercent / 100.0

            let name: String
            if he > 0.001 {
                name = "trimix"
            } else if o2 < 0.22 {
                name = "air"
            } else {
                name = "ean\(Int(o2Percent.rounded()))"
            }

            result[id] = UDDFGas(id: id, name: name, o2: o2, he: he)
        }

        if result.isEmpty {
            let id = "fit-gas-default"
            result[id] = UDDFGas(id: id, name: "air", o2: 0.21, he: 0)
        }
        return result
    }

    /// Convert FIT's native angular unit (Int32 semicircles) to decimal
    /// degrees. `degrees = semicircles * 180 / 2^31`. Exposed as a static
    /// helper so the conversion math can be unit-tested independently of
    /// fixture content — our current MK3i fixtures don't carry GPS, so
    /// without a direct entry point there's no way to exercise this code
    /// path from a fixture-driven test.
    static func semicirclesToDegrees(_ semicircles: Int32) -> Double {
        Double(semicircles) * 180.0 / 2_147_483_648.0
    }

    /// Build the dive's site dictionary from `messages.sessionMesgs`.
    ///
    /// Each `SessionMesg` carries a `startPositionLat/Long` pair encoded as
    /// `Int32` semicircles (FIT's native angular unit). We convert to
    /// decimal degrees via `semicirclesToDegrees`, key the result by
    /// `"fit-site-<index>"` where `<index>` is the 0-based session
    /// position, and skip sessions with no GPS lock. Site name is left
    /// empty — FIT has no site-name field, so the user fills it in
    /// post-import.
    ///
    /// "No GPS lock" is detected by three sentinels:
    ///   1. `nil`           — field absent from the FIT message entirely
    ///   2. `Int32.max`     — field present but marked invalid by the SDK
    ///   3. `(lat, lon) == (0, 0)` — some firmware writes zeros instead of
    ///      Int32.max for a missing fix (dry-pool dives, indoor sessions).
    ///
    /// Empirically, our MK3i fixtures from Phase B fall into category (1):
    /// the firmware that produced them either failed to obtain a fix at
    /// the surface or chose not to log it to FIT at all. Phase A's UDDF
    /// shipped GPS for the same dives only because Subsurface enriches
    /// from its site database on export.
    static func extractDiveSites(_ messages: FitMessages) -> [String: UDDFSite] {
        var result: [String: UDDFSite] = [:]

        for (index, session) in messages.sessionMesgs.enumerated() {
            guard let rawLat = session.getStartPositionLat(),
                  let rawLon = session.getStartPositionLong(),
                  rawLat != Int32.max,
                  rawLon != Int32.max,
                  !(rawLat == 0 && rawLon == 0)
            else { continue }

            let lat = semicirclesToDegrees(rawLat)
            let lon = semicirclesToDegrees(rawLon)

            let id = "fit-site-\(index)"
            result[id] = UDDFSite(id: id, name: "", latitude: lat, longitude: lon)
        }

        return result
    }

    /// Build the dive headers from `messages.sessionMesgs` paired with
    /// `messages.diveSummaryMesgs`.
    ///
    /// Produces one `UDDFDive` per `SessionMesg` (FIT files can carry
    /// multiple sessions in theory; the MK3i fleet always ships exactly
    /// one). DiveSummary entries are paired by ordinal index — for our
    /// fixtures that's a 1:1 match, and the helper falls back gracefully
    /// to Session-only values when a summary is missing.
    ///
    /// Per-field source preferences (verified against SDK source
    /// 2026-05-10):
    ///   - **datetime**: `Session.getStartTime()`, fallback
    ///     `Session.getTimestamp()`. DiveSummary's timestamp records the
    ///     post-processing moment, not the dive start.
    ///   - **durationSeconds**: `Session.getTotalElapsedTime()` as
    ///     `Int(seconds.rounded())`. DiveSummary's `bottomTime` excludes
    ///     descent/ascent, which UDDF's `durationSeconds` *does* include.
    ///   - **maxDepth / avgDepth**: prefer `DiveSummary` (post-processed
    ///     and more accurate); fall back to `Session`.
    ///
    /// `samples` is left empty (Task 7) and `tankStartBar`/`tankEndBar`
    /// are left `nil` (Task 8).
    static func extractDives(_ messages: FitMessages,
                             gasDefs: [String: UDDFGas],
                             siteId: String?) -> [UDDFDive] {
        let sessions = messages.sessionMesgs
        let summaries = messages.diveSummaryMesgs
        // Stable choice of "the" gas to attach to the dive header for now —
        // the gas IDs are "fit-gas-<index>", so sorted lexicographically
        // we get fit-gas-0 first, matching the FIT message order.
        let firstGasId = gasDefs.keys.sorted().first

        return sessions.enumerated().map { (i, session) in
            // 1. datetime — prefer startTime, fall back to timestamp,
            //    fall back defensively to now (should never happen with
            //    a well-formed Garmin Session).
            let datetime: Date = {
                if let dt = session.getStartTime() { return dt.date }
                if let dt = session.getTimestamp() { return dt.date }
                return Date()
            }()

            // 2. duration — Float64 seconds → Int via rounding.
            let durationSec: Int = {
                if let secs = session.getTotalElapsedTime() {
                    return Int(secs.rounded())
                }
                return 0
            }()

            // 3. depth — pair the session with the i-th DiveSummary if
            //    one exists at that index; otherwise Session-only.
            let summary: DiveSummaryMesg? = (i < summaries.count) ? summaries[i] : nil

            let maxDepth: Double = {
                if let d = summary?.getMaxDepth() { return d }
                if let d = session.getMaxDepth() { return d }
                return 0
            }()

            let avgDepth: Double = {
                if let d = summary?.getAvgDepth() { return d }
                if let d = session.getAvgDepth() { return d }
                return 0
            }()

            return UDDFDive(
                datetime: datetime,
                siteRef: siteId,
                gasRef: firstGasId,
                leadKg: nil,
                tankVolumeLiters: nil,
                maxDepthMeters: maxDepth,
                avgDepthMeters: avgDepth,
                durationSeconds: durationSec,
                notes: nil,
                samples: buildSamples(for: session, in: messages),
                tankStartBar: extractTankStart(messages),
                tankEndBar: extractTankEnd(messages)
            )
        }
    }

    // MARK: - Samples

    /// Convert all `RecordMesg` entries to `UDDFSample`, computing each
    /// sample's time relative to the session start. Records without a
    /// valid timestamp or with a timestamp earlier than session start are
    /// skipped (defensive; FIT-spec normally guarantees chronological
    /// record order strictly after the session start time).
    ///
    /// No explicit sort: the FIT spec emits record messages in chronological
    /// order and the SDK preserves that. With 3889 records in the Mamutic
    /// fixture, re-sorting on every import would be wasted work.
    private static func buildSamples(for session: SessionMesg,
                                     in messages: FitMessages) -> [UDDFSample] {
        guard let startDT = session.getStartTime() else { return [] }
        let startSec = Int(startDT.timestamp)

        return messages.recordMesgs.compactMap { rec -> UDDFSample? in
            guard let ts = rec.getTimestamp() else { return nil }
            let timeSec = Int(ts.timestamp) - startSec
            guard timeSec >= 0 else { return nil }

            let depth = rec.getDepth() ?? 0
            let tempC: Double? = rec.getTemperature().map(Double.init)

            return UDDFSample(
                depthMeters: depth,
                timeSeconds: timeSec,
                temperatureCelsius: tempC,
                gasSwitchRef: nil
            )
        }
    }

    // MARK: - Tank pressures (Task 8)

    /// Start pressure from the first TankSummaryMesg. SDK provides
    /// Float64 bar (already descaled from FIT's uint16 × 100). Rounds
    /// to nearest Int bar — UDDFDive carries Int.
    ///
    /// Multi-tank (sidemount/twinset) writes one TankSummaryMesg per
    /// sensor; for now we take the first only — single-tank is the
    /// common case for the MK3i fleet, and a Task-9-aware follow-up
    /// can handle multi-tank later.
    private static func extractTankStart(_ messages: FitMessages) -> Int? {
        guard let ts = messages.tankSummaryMesgs.first,
              let bar = ts.getStartPressure() else { return nil }
        return Int(bar.rounded())
    }

    /// End pressure from the first TankSummaryMesg. See `extractTankStart`
    /// for unit-handling and multi-tank notes.
    private static func extractTankEnd(_ messages: FitMessages) -> Int? {
        guard let ts = messages.tankSummaryMesgs.first,
              let bar = ts.getEndPressure() else { return nil }
        return Int(bar.rounded())
    }
}
