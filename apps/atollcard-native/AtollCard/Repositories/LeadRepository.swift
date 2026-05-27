import Foundation

public protocol LeadRepository: Sendable {
  func fetchAll() async throws -> [Lead]
  func fetch(id: UUID) async throws -> Lead?
  func upsert(_ lead: Lead) async throws
  func updateStatus(id: UUID, status: LeadStatus) async throws
  func markImported(id: UUID) async throws
}

// MARK: - Mock

public final class MockLeadRepository: LeadRepository, @unchecked Sendable {
  private var leads: [Lead] = MockSeed.leads

  public init() {}

  public func fetchAll() async throws -> [Lead] {
    leads.sorted { $0.capturedAt > $1.capturedAt }
  }

  public func fetch(id: UUID) async throws -> Lead? {
    leads.first { $0.id == id }
  }

  public func upsert(_ lead: Lead) async throws {
    if let idx = leads.firstIndex(where: { $0.id == lead.id }) {
      leads[idx] = lead
    } else {
      leads.append(lead)
    }
  }

  public func updateStatus(id: UUID, status: LeadStatus) async throws {
    if let idx = leads.firstIndex(where: { $0.id == id }) {
      leads[idx].status = status
    }
  }

  public func markImported(id: UUID) async throws {
    if let idx = leads.firstIndex(where: { $0.id == id }) {
      leads[idx].importedToAddressBook = true
      leads[idx].status = .imported
    }
  }
}

// MARK: - Supabase

import Supabase
import AtollCore

/// Postgrest-backed `LeadRepository`. Talks to `public.card_leads`.
public final class SupabaseLeadRepository: LeadRepository, @unchecked Sendable {
  public init() {}

  private var client: SupabaseClient { .shared }

  public func fetchAll() async throws -> [Lead] {
    try await client
      .from("card_leads")
      .select()
      .order("captured_at", ascending: false)
      .execute()
      .value
  }

  public func fetch(id: UUID) async throws -> Lead? {
    let rows: [Lead] = try await client
      .from("card_leads")
      .select()
      .eq("id", value: id)
      .limit(1)
      .execute()
      .value
    return rows.first
  }

  public func upsert(_ lead: Lead) async throws {
    try await client
      .from("card_leads")
      .upsert(lead)
      .execute()
  }

  public func updateStatus(id: UUID, status: LeadStatus) async throws {
    try await client
      .from("card_leads")
      .update(["status": status.rawValue])
      .eq("id", value: id)
      .execute()
  }

  public func markImported(id: UUID) async throws {
    struct Patch: Encodable {
      let imported_to_address_book: Bool
      let status: String
    }
    try await client
      .from("card_leads")
      .update(Patch(imported_to_address_book: true, status: LeadStatus.imported.rawValue))
      .eq("id", value: id)
      .execute()
  }
}
