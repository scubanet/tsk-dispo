import SwiftUI
import SwiftData
import Observation

// ═══════════════════════════════════════
// MARK: - DeleteUndoManager
// ═══════════════════════════════════════
//
// Keeps a "soft-deleted" Dive around for a few seconds so the user can tap
// Undo in a snackbar. When the grace period expires, we commit the actual
// SwiftData delete — which then propagates to CloudKit as a tombstone.
//
// Design notes:
//
//   • We DO NOT call `modelContext.delete()` at schedule time — we only do
//     it when the timer fires. This avoids the nightmare of trying to
//     recreate a deleted SwiftData object with all its relationships.
//
//   • The UI filters `pendingDive` out of the visible list, so it looks
//     deleted to the user while still being a live SwiftData object.
//
//   • If a second delete is scheduled while one is already pending, we
//     commit the old one immediately and start a fresh timer for the new
//     dive. Keeps behavior predictable.
//
//   • `commitImmediate()` is called from the app's scenePhase observer so
//     pending deletes don't linger across app relaunches.
//
@Observable
@MainActor
final class DeleteUndoManager {

    /// The dive currently in "pending delete" state. UI should filter this
    /// out of any list that reads from @Query.
    private(set) var pendingDive: Dive?

    /// Seconds between schedule and actual commit.
    let graceSeconds: Double = 4.0

    /// Timestamp when the current pending delete was scheduled. Used by the
    /// snackbar to drive its progress bar.
    private(set) var scheduledAt: Date?

    /// The task that will commit the delete. Cancelled on undo or when a
    /// fresh delete is scheduled.
    private var commitTask: Task<Void, Never>?

    // ─── Public API ───────────────────────

    /// Soft-delete a dive. UI hides it immediately; actual commit fires in
    /// `graceSeconds`. If another dive was already pending, it gets
    /// committed now.
    func schedule(_ dive: Dive, in context: ModelContext) {
        // Commit any prior pending delete first — keeps state consistent.
        if let prior = pendingDive, prior.persistentModelID != dive.persistentModelID {
            commitTask?.cancel()
            context.delete(prior)
            if let profile = (try? context.fetch(FetchDescriptor<DiverProfile>()))?.first {
                context.renumberDives(from: profile)
            }
            try? context.save()
        }

        pendingDive = dive
        scheduledAt = .now
        commitTask?.cancel()

        commitTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(self?.graceSeconds ?? 4.0))
            guard !Task.isCancelled, let self else { return }
            // Still pending the same dive? Commit it.
            if self.pendingDive?.persistentModelID == dive.persistentModelID {
                context.delete(dive)
                if let profile = (try? context.fetch(FetchDescriptor<DiverProfile>()))?.first {
                    context.renumberDives(from: profile)
                }
                try? context.save()
                self.pendingDive = nil
                self.scheduledAt = nil
                self.commitTask = nil
            }
        }
    }

    /// Cancel the pending delete — the dive stays put.
    func undo() {
        commitTask?.cancel()
        commitTask = nil
        pendingDive = nil
        scheduledAt = nil
    }

    /// Commit the pending delete right now (called on scenePhase .background
    /// so work-in-progress deletes don't disappear silently).
    func commitImmediate(in context: ModelContext) {
        guard let dive = pendingDive else { return }
        commitTask?.cancel()
        context.delete(dive)
        if let profile = (try? context.fetch(FetchDescriptor<DiverProfile>()))?.first {
            context.renumberDives(from: profile)
        }
        try? context.save()
        pendingDive = nil
        scheduledAt = nil
        commitTask = nil
    }
}
