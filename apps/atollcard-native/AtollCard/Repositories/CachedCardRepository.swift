import Foundation
import OSLog

/// Decorator around a remote `CardRepository` that reads through the
/// SwiftData `CacheStore`. Cards are not queued for offline write — the spec
/// keeps card edits as an online-only flow, so all writes are write-through
/// (remote first, cache mirrors success).
///
/// Read behaviour matches `CachedLeadRepository`: cache returns immediately,
/// and an opportunistic background refresh runs when online.
final class CachedCardRepository: CardRepository {
  private let remote: CardRepository
  private let cache:  CacheStore
  private let reach:  ReachabilityMonitor
  private static let logger = Logger(subsystem: "swiss.atoll.card", category: "cached-card-repo")

  init(remote: CardRepository, cache: CacheStore, reach: ReachabilityMonitor) {
    self.remote = remote
    self.cache  = cache
    self.reach  = reach
  }

  // MARK: - Reads

  func fetchAll() async throws -> [Card] {
    let cached = await MainActor.run { cache.cards() }
    let online = await MainActor.run { reach.isConnected }
    if online {
      Task.detached { [weak self] in await self?.refreshAll() }
    }
    return cached
  }

  func fetch(id: UUID) async throws -> Card? {
    let cached = await MainActor.run { cache.card(id: id) }
    let online = await MainActor.run { reach.isConnected }
    if online {
      Task.detached { [weak self] in
        guard let self else { return }
        if let fresh = try? await self.remote.fetch(id: id), let card = fresh {
          await MainActor.run { self.cache.upsertCard(card) }
        }
      }
    }
    return cached
  }

  private func refreshAll() async {
    guard let fresh = try? await remote.fetchAll() else { return }
    await MainActor.run {
      for card in fresh { cache.upsertCard(card) }
    }
  }

  // MARK: - Writes (online-only, write-through)

  func upsert(_ card: Card) async throws {
    try await remote.upsert(card)
    await MainActor.run { cache.upsertCard(card) }
  }

  func delete(id: UUID) async throws {
    try await remote.delete(id: id)
    await MainActor.run { cache.deleteCard(id: id) }
  }

  /// Mirrors the server-side two-step in the cache: clear `isDefault` on
  /// siblings, then set it on the target. Matches the invariant enforced by
  /// `idx_cards_one_default_per_person` so the local view stays consistent
  /// after a `setDefault` even before the next refresh.
  func setDefault(id: UUID) async throws {
    try await remote.setDefault(id: id)
    await MainActor.run {
      let cards = cache.cards()
      for card in cards {
        let shouldBeDefault = (card.id == id)
        if card.isDefault != shouldBeDefault {
          var updated = card
          updated.isDefault = shouldBeDefault
          cache.upsertCard(updated)
        }
      }
    }
  }
}
