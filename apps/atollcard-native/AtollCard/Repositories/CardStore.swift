import Foundation
import Observation
import OSLog

/// Owns the list of cards in memory + the current selection. UI binds to
/// `cards` / `selected`; mutations go through `upsert`, `delete`,
/// `setDefault`, never directly to the array — that way SwiftData / Supabase
/// stays in sync.
@MainActor
@Observable
public final class CardStore {
  public private(set) var cards: [Card] = []
  public private(set) var lastError: Error?
  public var selectedID: UUID?

  private let repository: CardRepository
  private static let logger = Logger(subsystem: "swiss.atoll.card", category: "cards")

  public init(repository: CardRepository) {
    self.repository = repository
  }

  public var selected: Card? {
    if let selectedID, let match = cards.first(where: { $0.id == selectedID }) {
      return match
    }
    return cards.first(where: { $0.isDefault }) ?? cards.first
  }

  public func refresh() async {
    do {
      let result = try await repository.fetchAll()
      cards = result.sorted { ($0.isDefault ? 0 : 1, $0.title) < ($1.isDefault ? 0 : 1, $1.title) }
      lastError = nil
      if selectedID == nil { selectedID = cards.first(where: { $0.isDefault })?.id ?? cards.first?.id }
      writeSnapshotForDefault()
    } catch {
      Self.logger.error("refresh failed: \(error.localizedDescription, privacy: .public)")
      lastError = error
    }
  }

  public func upsert(_ card: Card) async {
    do {
      try await repository.upsert(card)
      await refresh()
    } catch {
      lastError = error
    }
  }

  public func delete(id: UUID) async {
    do {
      try await repository.delete(id: id)
      if selectedID == id { selectedID = nil }
      await refresh()
    } catch {
      lastError = error
    }
  }

  public func setDefault(id: UUID) async {
    do {
      try await repository.setDefault(id: id)
      await refresh()
    } catch {
      lastError = error
    }
  }

  // MARK: - Widget snapshot

  /// Re-derives the current default card from `cards` and pushes a snapshot
  /// to the App Group + Widget. Safe to call repeatedly — the writer is
  /// idempotent.
  ///
  /// Note: AtollCard does not yet have a centralised `persons` map — every
  /// view that needs a `Person` reaches for `MockSeed.dominik`. The snapshot
  /// follows the same pattern. When a real persons-store lands, swap this
  /// lookup for the proper one (see CHANGELOG 0.11.0 follow-ups).
  private func writeSnapshotForDefault() {
    guard let defaultCard = cards.first(where: { $0.isDefault && $0.isActive }) else {
      SharedCardSnapshotWriter.write(nil)
      return
    }
    let snapshot = SharedCardSnapshot(
      slug:           defaultCard.slug,
      title:          defaultCard.title,
      badge:          defaultCard.badge,
      personInitials: MockSeed.dominik.initials,
      publicURL:      defaultCard.publicURL,
      updatedAt:      defaultCard.updatedAt
    )
    SharedCardSnapshotWriter.write(snapshot)
  }
}
