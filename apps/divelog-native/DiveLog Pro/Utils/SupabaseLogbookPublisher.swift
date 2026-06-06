import Foundation
import SwiftData
import os
import AtollCore
import Supabase

private let logger = Logger(subsystem: "com.weckherlin.DiveLogPro", category: "AtollSync")

// ═══════════════════════════════════════
// MARK: - Supabase Logbook Publisher
// ═══════════════════════════════════════
//
// Phase 4 der Atoll-Integration (Iteration 1): One-Way-Publish des
// Logbuchs nach Supabase (`public.dives`). CloudKit bleibt SSOT des
// privaten Logbuchs (Entscheidung E1 „Hybrid") — diese Klasse spiegelt
// nur. Kein Pull. Fehler sind non-fatal; Retry beim nächsten Trigger
// (App-Start oder Dive-Save), Upserts sind idempotent.
//
// Idempotenz: Upsert über (owner, client_id). `Dive.clientID` wird hier
// lazily backgefüllt — als optionale Property eine CloudKit-sichere
// Schema-Evolution, die pro Dive genau einmal gesetzt wird und dann
// über CloudKit auf alle Geräte synct.
//
// TODO(v2): Lösch-Sync (gelöschte Dives verschwinden derzeit nicht aus
// dem Spiegel) + inkrementelles Publish statt Voll-Upsert.

@MainActor
final class SupabaseLogbookPublisher {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    /// Voll-Publish: backfillt fehlende clientIDs, mappt alle Dives und
    /// upsertet in 100er-Blöcken. No-op ohne Supabase-Session.
    func publishAll() async {
        let owner: UUID
        do {
            owner = try await SupabaseClient.shared.auth.session.user.id
        } catch {
            logger.debug("publish übersprungen — keine Atoll-Session")
            return
        }

        let ctx = container.mainContext
        let dives: [Dive]
        do {
            dives = try ctx.fetch(FetchDescriptor<Dive>())
        } catch {
            logger.error("Dive-Fetch fehlgeschlagen: \(error.localizedDescription)")
            return
        }
        guard !dives.isEmpty else { return }

        // clientID-Backfill (einmalig, danach stabil).
        var backfilled = 0
        for dive in dives where dive.clientID == nil {
            dive.clientID = UUID()
            backfilled += 1
        }
        if backfilled > 0 {
            try? ctx.save()
            logger.info("clientID-Backfill für \(backfilled) Dives")
        }

        let rows = dives.compactMap { DiveRow(dive: $0, owner: owner) }
        guard !rows.isEmpty else { return }

        var published = 0
        var index = 0
        while index < rows.count {
            let chunk = Array(rows[index..<min(index + 100, rows.count)])
            do {
                try await SupabaseClient.shared
                    .from("dives")
                    .upsert(chunk, onConflict: "owner,client_id", returning: .minimal)
                    .execute()
                published += chunk.count
            } catch {
                logger.error("Upsert-Block fehlgeschlagen (\(published)/\(rows.count)): \(error.localizedDescription)")
                return // Rest beim nächsten Trigger — idempotent.
            }
            index += 100
        }
        logger.info("Logbuch-Spiegel publiziert: \(published)/\(rows.count) Dives")
    }
}

// ═══════════════════════════════════════
// MARK: - Wire format (public.dives)
// ═══════════════════════════════════════
//
// Feld-Ownership: DiveLog schreibt alle Felder, niemand sonst (One-Way).
// Bedingungen/Gas als jsonb gebündelt — Schema siehe Migration
// 20260606140000_divelog_logbook.sql.

private struct DiveRow: Encodable {
    let owner: UUID
    let clientId: UUID
    let number: Int
    let date: Date
    let siteName: String
    let siteLocation: String
    let latitude: Double
    let longitude: Double
    let maxDepth: Double
    let avgDepth: Double
    let bottomTime: Int
    let totalTime: Int
    let diveType: String
    let conditions: Conditions
    let gas: Gas
    let notes: String

    struct Conditions: Encodable {
        let weather: String
        let current: String
        let waves: String
        let visibility: Int
        let airTemp: Double
        let waterTempSurface: Double
        let waterTempBottom: Double
        let waterType: String
        let suit: String
        let entryType: String

        enum CodingKeys: String, CodingKey {
            case weather, current, waves, visibility, suit
            case airTemp = "air_temp"
            case waterTempSurface = "water_temp_surface"
            case waterTempBottom = "water_temp_bottom"
            case waterType = "water_type"
            case entryType = "entry_type"
        }
    }

    struct Gas: Encodable {
        let gas: String
        let cylinderType: String
        let cylinderSizeLiters: Double
        let weightKg: Double
        let tankStartBar: Int
        let tankEndBar: Int
        let sacRate: Double

        enum CodingKeys: String, CodingKey {
            case gas
            case cylinderType = "cylinder_type"
            case cylinderSizeLiters = "cylinder_size_liters"
            case weightKg = "weight_kg"
            case tankStartBar = "tank_start_bar"
            case tankEndBar = "tank_end_bar"
            case sacRate = "sac_rate"
        }
    }

    enum CodingKeys: String, CodingKey {
        case owner, number, date, latitude, longitude, conditions, gas, notes
        case clientId = "client_id"
        case siteName = "site_name"
        case siteLocation = "site_location"
        case maxDepth = "max_depth"
        case avgDepth = "avg_depth"
        case bottomTime = "bottom_time"
        case totalTime = "total_time"
        case diveType = "dive_type"
    }

    init?(dive: Dive, owner: UUID) {
        guard let clientId = dive.clientID else { return nil }
        self.owner = owner
        self.clientId = clientId
        self.number = dive.number
        self.date = dive.date
        self.siteName = dive.siteName
        self.siteLocation = dive.siteLocation
        self.latitude = dive.latitude
        self.longitude = dive.longitude
        self.maxDepth = dive.maxDepth
        self.avgDepth = dive.avgDepth
        self.bottomTime = dive.bottomTime
        self.totalTime = dive.totalTime
        self.diveType = dive.diveType
        self.conditions = Conditions(
            weather: dive.weather,
            current: dive.current,
            waves: dive.waves,
            visibility: dive.visibility,
            airTemp: dive.airTemp,
            waterTempSurface: dive.waterTempSurface,
            waterTempBottom: dive.waterTempBottom,
            waterType: dive.waterType,
            suit: dive.suit,
            entryType: dive.entryType
        )
        self.gas = Gas(
            gas: dive.gas,
            cylinderType: dive.cylinderType,
            cylinderSizeLiters: dive.cylinderSizeLiters,
            weightKg: dive.weightKg,
            tankStartBar: dive.tankStartBar,
            tankEndBar: dive.tankEndBar,
            sacRate: dive.sacRate
        )
        self.notes = dive.notes
    }
}
