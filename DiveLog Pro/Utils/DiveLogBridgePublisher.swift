import Foundation
import SwiftData
import os

/// Assembles the DiveLog snapshot from SwiftData and publishes it to the
/// App Group via DiveLogBridge.
///
/// Runs on the main actor because SwiftData's mainContext is main-actor
/// bound; the IO itself happens on the bridge actor.
@MainActor
final class DiveLogBridgePublisher {
    private let container: ModelContainer
    private let bridge: DiveLogBridge

    private static let logger = Logger(
        subsystem: "com.weckherlin.DiveLogPro",
        category: "AtollBridge"
    )

    init(container: ModelContainer, bridge: DiveLogBridge) {
        self.container = container
        self.bridge = bridge
    }

    /// Round to whole seconds so the snapshot is lossless across the
    /// `.iso8601` encoder/decoder boundary (Atoll Hub side uses the same
    /// strategy and would fail to parse fractional-second timestamps).
    private static func truncatedToSecond(_ date: Date) -> Date {
        Date(timeIntervalSince1970: floor(date.timeIntervalSince1970))
    }

    /// Builds the current snapshot and writes it. No-op when the user
    /// isn't signed in with Apple yet — without an apple_user_id the
    /// snapshot can't be matched on the Atoll Hub side.
    func publish() async {
        guard let appleUserID = AppleSignInService.shared.currentUserID else {
            Self.logger.debug("publish skipped — no Apple user ID")
            return
        }

        let ctx = container.mainContext
        let profile = (try? ctx.fetch(FetchDescriptor<DiverProfile>()))?.first

        var diveDescriptor = FetchDescriptor<Dive>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        diveDescriptor.fetchLimit = 1
        let lastDive = (try? ctx.fetch(diveDescriptor))?.first

        // Count is a separate cheap query — fetchCount avoids loading all dives.
        let countDescriptor = FetchDescriptor<Dive>()
        let totalDives = (try? ctx.fetchCount(countDescriptor)) ?? 0

        let certifications: [SharedDiveLogSnapshot.Certification] = profile.map {
            [.init(agency: "PADI", level: $0.certLevel, issuedAt: nil)]
        } ?? []

        let languages: [String] = profile.map { [$0.language] } ?? []

        let snapshot = SharedDiveLogSnapshot(
            schemaVersion: 1,
            appleUserId: appleUserID,
            displayName: profile?.name ?? "",
            avatarFileName: nil,                   // avatar copy: future enhancement
            diveLogHandle: nil,                    // v1: no handle concept on DiveLog side
            loggedDivesCount: totalDives,
            lastDiveDate: lastDive.map { Self.truncatedToSecond($0.date) },
            certifications: certifications,
            specialties: [],                       // v1: no per-user specialties
            languagesSpoken: languages,
            homeBase: nil,                         // v1: not on DiverProfile yet
            conservationProjects: [],              // v1: not modelled
            snapshotUpdatedAt: Self.truncatedToSecond(Date())
        )

        do {
            try await bridge.writeDiveLogSnapshot(snapshot)
            Self.logger.info("published snapshot — dives=\(totalDives), name='\(snapshot.displayName, privacy: .private)'")
        } catch {
            Self.logger.error("publish failed: \(error.localizedDescription)")
        }
    }
}
