import Foundation

/// Repository contract for card CRUD. Implementations:
///   • `MockCardRepository` — seeded demo data, no network
///   • `SupabaseCardRepository` — talks to the `cards` table via PostgREST
public protocol CardRepository: Sendable {
  func fetchAll() async throws -> [Card]
  func fetch(id: UUID) async throws -> Card?
  func upsert(_ card: Card) async throws
  func delete(id: UUID) async throws
  func setDefault(id: UUID) async throws
}

// MARK: - Mock

public final class MockCardRepository: CardRepository, @unchecked Sendable {
  private var cards: [Card] = MockSeed.cards

  public init() {}

  public func fetchAll() async throws -> [Card] { cards }

  public func fetch(id: UUID) async throws -> Card? {
    cards.first { $0.id == id }
  }

  public func upsert(_ card: Card) async throws {
    if let idx = cards.firstIndex(where: { $0.id == card.id }) {
      cards[idx] = card
    } else {
      cards.append(card)
    }
  }

  public func delete(id: UUID) async throws {
    cards.removeAll { $0.id == id }
  }

  public func setDefault(id: UUID) async throws {
    cards = cards.map { c in
      var copy = c
      copy.isDefault = (c.id == id)
      return copy
    }
  }
}

// MARK: - Supabase

import Supabase
import AtollCore

/// Postgrest-backed `CardRepository`. Talks to `public.cards`.
///
/// RLS keeps the queries scoped to the authenticated user automatically —
/// we never have to filter by `person_id`, the policy does it.
public final class SupabaseCardRepository: CardRepository, @unchecked Sendable {
  public init() {}

  private var client: SupabaseClient { .shared }

  public func fetchAll() async throws -> [Card] {
    try await client
      .from("cards")
      .select()
      .order("is_default", ascending: false)
      .order("title", ascending: true)
      .execute()
      .value
  }

  public func fetch(id: UUID) async throws -> Card? {
    let rows: [Card] = try await client
      .from("cards")
      .select()
      .eq("id", value: id)
      .limit(1)
      .execute()
      .value
    return rows.first
  }

  public func upsert(_ card: Card) async throws {
    try await client
      .from("cards")
      .upsert(card)
      .execute()
  }

  public func delete(id: UUID) async throws {
    try await client
      .from("cards")
      .delete()
      .eq("id", value: id)
      .execute()
  }

  /// Setting a card as default is a two-step: clear `is_default` on every
  /// card belonging to the same person, then set it on the target. The
  /// unique partial index `idx_cards_one_default_per_person` enforces the
  /// invariant — without the clear-first step the second update would fail
  /// with a uniqueness violation.
  public func setDefault(id: UUID) async throws {
    // Step 1: find the person_id of the target so we know whose cards to
    // touch. Doing it from the client side keeps the policy simple.
    guard let target = try await fetch(id: id) else {
      throw RepositoryError.notFound
    }

    // Step 2: clear all defaults for that person except the target.
    try await client
      .from("cards")
      .update(["is_default": false])
      .eq("person_id", value: target.personId)
      .neq("id", value: id)
      .execute()

    // Step 3: ensure the target is marked default.
    try await client
      .from("cards")
      .update(["is_default": true])
      .eq("id", value: id)
      .execute()
  }
}

public enum RepositoryError: Error, LocalizedError {
  case notImplemented(String)
  case notFound
  case unauthenticated

  public var errorDescription: String? {
    switch self {
    case .notImplemented(let what): "Not implemented: \(what)"
    case .notFound: "Not found"
    case .unauthenticated: "Du bist nicht eingeloggt"
    }
  }
}
