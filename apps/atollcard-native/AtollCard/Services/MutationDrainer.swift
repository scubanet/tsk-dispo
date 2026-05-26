import Foundation
import Observation
import OSLog

/// Drains the `PendingLeadStatusMutation` FIFO queue into the remote
/// `LeadRepository`. Stays single-flight: a second concurrent `drain()` call
/// while a drain is already in progress short-circuits.
///
/// Failure policy (matches spec §4):
/// - 401 / auth-shaped errors: bail without burning an attempt; the next
///   reachability edge or token-refresh retry will pick the row up again.
/// - Other errors: increment `attempts`, abort the current drain, and if
///   the row has now hit ≥ 5 attempts it gets marked `isDead = true`.
///
/// `MainActor`-bound for the same reason `CacheStore` is — the cache's
/// `ModelContext` only lives on the main actor.
@MainActor
@Observable
final class MutationDrainer {
  private let cache:  CacheStore
  private let remote: LeadRepository
  private var isDraining = false
  private static let logger = Logger(subsystem: "swiss.atoll.card", category: "drainer")

  init(cache: CacheStore, remote: LeadRepository) {
    self.cache  = cache
    self.remote = remote
  }

  /// Pulls mutations in FIFO order and applies them remotely. Stops the
  /// loop on the first non-auth error so we don't hammer the server in a
  /// retry tight-loop; the next `drain()` trigger (reach edge, scenePhase)
  /// re-enters the queue.
  func drain() async {
    guard !isDraining else {
      Self.logger.debug("drain() — already draining, skip")
      return
    }
    isDraining = true
    defer { isDraining = false }

    while let mutation = cache.nextPendingMutation() {
      guard let status = LeadStatus(rawValue: mutation.newStatus) else {
        // Unknown enum value — mark dead, can't recover from a string we
        // don't know how to map back to the typed status.
        Self.logger.error("Unknown status \(mutation.newStatus, privacy: .public) — marking dead")
        cache.markDead(mutationId: mutation.id)
        continue
      }
      let leadId      = mutation.leadId
      let mutationId  = mutation.id
      let attempts    = mutation.attempts
      do {
        try await remote.updateStatus(id: leadId, status: status)
        cache.removePendingMutation(id: mutationId)
      } catch {
        if isAuthError(error) {
          // 401 — don't burn attempts, just bail until next reach edge
          // or token refresh.
          Self.logger.warning("auth error during drain, bailing without incrementing")
          return
        }
        cache.recordFailure(mutationId: mutationId, error: error)
        if (attempts + 1) >= 5 {
          cache.markDead(mutationId: mutationId)
          continue
        }
        return
      }
    }
  }

  /// Bring a dead-lettered mutation back to life and immediately try the
  /// queue again. Called by the `DeadLetterView` retry button.
  func retryDeadLetter(mutationId: UUID) async {
    cache.resetMutation(mutationId: mutationId)
    await drain()
  }

  private func isAuthError(_ error: Error) -> Bool {
    let ns = error as NSError
    // Postgrest surfaces 401 via the localized description on the wrapping
    // error, URLSession surfaces it differently; a string-match covers both
    // and avoids a hard dependency on Supabase error types from this layer.
    return ns.localizedDescription.contains("401")
        || ns.localizedDescription.contains("Unauthorized")
        || ns.localizedDescription.contains("JWT")
  }
}
