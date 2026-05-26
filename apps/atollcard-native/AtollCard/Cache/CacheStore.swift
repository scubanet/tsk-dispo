import Foundation
import SwiftData

/// Thin SwiftData wrapper used by the `Cached*Repository` decorators.
///
/// Owns one `ModelContainer` for the app process (file-backed). Reads return
/// domain structs (converted via `CacheConverters`); writes upsert by id.
///
/// `MainActor`-bound because `ModelContext.save()` and `FetchDescriptor`
/// fetches need to run on the same actor as the container's main context.
@MainActor
@Observable
final class CacheStore {
  let container: ModelContainer
  private var context: ModelContext { container.mainContext }

  init() throws {
    let schema = Schema([
      CardEntity.self, LeadEntity.self, ScanEntity.self,
      PendingLeadStatusMutation.self,
    ])
    self.container = try ModelContainer(
      for: schema,
      configurations: ModelConfiguration(isStoredInMemoryOnly: false)
    )
  }

  // MARK: - Cards

  func cards() -> [Card] {
    let descriptor = FetchDescriptor<CardEntity>(
      sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
    )
    return (try? context.fetch(descriptor))?.compactMap { try? Card(entity: $0) } ?? []
  }

  func card(id: UUID) -> Card? {
    let descriptor = FetchDescriptor<CardEntity>(predicate: #Predicate { $0.id == id })
    return (try? context.fetch(descriptor))?.first.flatMap { try? Card(entity: $0) }
  }

  func upsertCard(_ card: Card) {
    let cardId = card.id
    let descriptor = FetchDescriptor<CardEntity>(predicate: #Predicate { $0.id == cardId })
    if let existing = (try? context.fetch(descriptor))?.first {
      context.delete(existing)
    }
    if let entity = try? card.toEntity() {
      context.insert(entity)
    }
    try? context.save()
  }

  func deleteCard(id: UUID) {
    let descriptor = FetchDescriptor<CardEntity>(predicate: #Predicate { $0.id == id })
    if let existing = (try? context.fetch(descriptor))?.first {
      context.delete(existing)
      try? context.save()
    }
  }

  // MARK: - Leads

  func leads() -> [Lead] {
    let descriptor = FetchDescriptor<LeadEntity>(
      sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]
    )
    return (try? context.fetch(descriptor))?.compactMap { try? Lead(entity: $0) } ?? []
  }

  func upsertLead(_ lead: Lead) {
    let leadId = lead.id
    let descriptor = FetchDescriptor<LeadEntity>(predicate: #Predicate { $0.id == leadId })
    if let existing = (try? context.fetch(descriptor))?.first {
      context.delete(existing)
    }
    context.insert(lead.toEntity())
    try? context.save()
  }

  func updateLeadStatus(leadId: UUID, status: LeadStatus) {
    let descriptor = FetchDescriptor<LeadEntity>(predicate: #Predicate { $0.id == leadId })
    guard let entity = (try? context.fetch(descriptor))?.first else { return }
    entity.status = status.rawValue
    try? context.save()
  }

  func deleteLead(id: UUID) {
    let descriptor = FetchDescriptor<LeadEntity>(predicate: #Predicate { $0.id == id })
    if let existing = (try? context.fetch(descriptor))?.first {
      context.delete(existing)
      try? context.save()
    }
  }

  // MARK: - Scans

  func scans() -> [Scan] {
    let descriptor = FetchDescriptor<ScanEntity>(
      sortBy: [SortDescriptor(\.scannedAt, order: .reverse)]
    )
    return (try? context.fetch(descriptor))?.compactMap { try? Scan(entity: $0) } ?? []
  }

  func upsertScan(_ scan: Scan) {
    let scanId = scan.id
    let descriptor = FetchDescriptor<ScanEntity>(predicate: #Predicate { $0.id == scanId })
    if let existing = (try? context.fetch(descriptor))?.first {
      context.delete(existing)
    }
    context.insert(scan.toEntity())
    try? context.save()
  }

  // MARK: - Mutations

  func enqueue(_ mutation: PendingLeadStatusMutation) {
    context.insert(mutation)
    try? context.save()
  }

  func nextPendingMutation() -> PendingLeadStatusMutation? {
    var descriptor = FetchDescriptor<PendingLeadStatusMutation>(
      predicate: #Predicate { $0.isDead == false },
      sortBy: [SortDescriptor(\.enqueuedAt, order: .forward)]
    )
    descriptor.fetchLimit = 1
    return (try? context.fetch(descriptor))?.first
  }

  func removePendingMutation(id: UUID) {
    let descriptor = FetchDescriptor<PendingLeadStatusMutation>(predicate: #Predicate { $0.id == id })
    if let m = (try? context.fetch(descriptor))?.first {
      context.delete(m)
      try? context.save()
    }
  }

  func recordFailure(mutationId: UUID, error: Error) {
    let descriptor = FetchDescriptor<PendingLeadStatusMutation>(predicate: #Predicate { $0.id == mutationId })
    guard let m = (try? context.fetch(descriptor))?.first else { return }
    m.attempts += 1
    m.lastError = error.localizedDescription
    m.lastAttemptAt = .now
    try? context.save()
  }

  func markDead(mutationId: UUID) {
    let descriptor = FetchDescriptor<PendingLeadStatusMutation>(predicate: #Predicate { $0.id == mutationId })
    guard let m = (try? context.fetch(descriptor))?.first else { return }
    m.isDead = true
    try? context.save()
  }

  func deadLetters() -> [PendingLeadStatusMutation] {
    let descriptor = FetchDescriptor<PendingLeadStatusMutation>(
      predicate: #Predicate { $0.isDead == true }
    )
    return (try? context.fetch(descriptor)) ?? []
  }

  func pendingCount() -> Int {
    let descriptor = FetchDescriptor<PendingLeadStatusMutation>(
      predicate: #Predicate { $0.isDead == false }
    )
    return (try? context.fetchCount(descriptor)) ?? 0
  }

  /// Used by `MutationDrainer.retryDeadLetter` — clears the death flag and
  /// resets attempt counters so a follow-up `drain()` picks the row up again.
  func resetMutation(mutationId: UUID) {
    let descriptor = FetchDescriptor<PendingLeadStatusMutation>(predicate: #Predicate { $0.id == mutationId })
    guard let m = (try? context.fetch(descriptor))?.first else { return }
    m.attempts = 0
    m.lastError = nil
    m.lastAttemptAt = nil
    m.isDead = false
    try? context.save()
  }

  /// Used by the Dead-Letter UI's "Verwerfen" action — drops the mutation
  /// from the queue entirely.
  func discardMutation(mutationId: UUID) {
    let descriptor = FetchDescriptor<PendingLeadStatusMutation>(predicate: #Predicate { $0.id == mutationId })
    if let m = (try? context.fetch(descriptor))?.first {
      context.delete(m)
      try? context.save()
    }
  }
}
