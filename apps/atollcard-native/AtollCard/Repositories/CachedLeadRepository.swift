import Foundation
import OSLog

/// Decorator around a remote `LeadRepository` that funnels reads through the
/// SwiftData `CacheStore` and queues `updateStatus(id:status:)` writes through
/// a `PendingLeadStatusMutation` FIFO + `MutationDrainer` so the app stays
/// usable offline.
///
/// Read behaviour: returns whatever is in the cache immediately, and — if
/// `ReachabilityMonitor` reports online — kicks off a detached background
/// refresh against the remote. The cache is the source of truth for the UI;
/// the refresh is opportunistic.
///
/// Write behaviour:
/// - `updateStatus`: applied to the cache + appended to the mutation queue;
///   `MutationDrainer.drain()` is triggered if online. The remote-call result
///   never round-trips back through this method (fire-and-forget by design —
///   the drainer is the only path that talks to `remote.updateStatus`).
/// - `upsert` / `markImported`: write-through (remote first, then cache).
///   These are not queued because the app only exposes them as user-initiated
///   online actions today; an offline tap is a UX dead-end which is acceptable
///   per the spec.
final class CachedLeadRepository: LeadRepository {
  private let remote:  LeadRepository
  private let cache:   CacheStore
  private let drainer: MutationDrainer
  private let reach:   ReachabilityMonitor
  private static let logger = Logger(subsystem: "swiss.atoll.card", category: "cached-lead-repo")

  init(remote: LeadRepository, cache: CacheStore,
       drainer: MutationDrainer, reach: ReachabilityMonitor) {
    self.remote  = remote
    self.cache   = cache
    self.drainer = drainer
    self.reach   = reach
  }

  // MARK: - Reads

  func fetchAll() async throws -> [Lead] {
    let cached  = await MainActor.run { cache.leads() }
    let online  = await MainActor.run { reach.isConnected }
    if online {
      Task.detached { [weak self] in await self?.refreshAll() }
    }
    return cached
  }

  func fetch(id: UUID) async throws -> Lead? {
    let cached = await MainActor.run { cache.leads().first(where: { $0.id == id }) }
    let online = await MainActor.run { reach.isConnected }
    if online {
      Task.detached { [weak self] in
        guard let self else { return }
        if let lead = try? await self.remote.fetch(id: id) {
          await MainActor.run { self.cache.upsertLead(lead) }
        }
      }
    }
    return cached
  }

  private func refreshAll() async {
    guard let fresh = try? await remote.fetchAll() else { return }
    await MainActor.run {
      for lead in fresh { cache.upsertLead(lead) }
    }
  }

  // MARK: - Writes

  func upsert(_ lead: Lead) async throws {
    // Write-through: remote first so failures surface to the caller; cache
    // mirrors the success.
    try await remote.upsert(lead)
    await MainActor.run { cache.upsertLead(lead) }
  }

  /// Optimistic + queued: cache reflects the new status immediately, a
  /// `PendingLeadStatusMutation` lands in the FIFO, and the drainer is poked
  /// when online. Offline calls still succeed locally — the drainer will
  /// catch up on the next reachability edge or scenePhase trigger.
  func updateStatus(id: UUID, status: LeadStatus) async throws {
    let mutation = PendingLeadStatusMutation(
      id: UUID(),
      leadId: id,
      newStatus: status.rawValue,
      enqueuedAt: .now,
      attempts: 0
    )
    let online = await MainActor.run {
      cache.updateLeadStatus(leadId: id, status: status)
      cache.enqueue(mutation)
      return reach.isConnected
    }
    if online {
      Task.detached { [weak self] in await self?.drainer.drain() }
    }
  }

  /// Online-only by spec — server-side logic owns the address-book idempotency
  /// key, so a queued offline version could double-import on retry. Cache
  /// follows the server result.
  func markImported(id: UUID) async throws {
    try await remote.markImported(id: id)
    await MainActor.run { cache.updateLeadStatus(leadId: id, status: .imported) }
  }
}
