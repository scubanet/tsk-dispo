import XCTest
import SwiftData
@testable import AtollCard

@MainActor
final class CacheStoreTests: XCTestCase {
  func makeStore() throws -> CacheStore {
    // File-based ModelContainer; CacheStore() picks up the default location.
    // For full isolation in CI, a future variant should accept an injected
    // in-memory ModelConfiguration — out of scope for this task.
    return try CacheStore()
  }

  func test_enqueue_and_drain_FIFO() throws {
    let store = try makeStore()
    let leadId = UUID()
    let m1 = PendingLeadStatusMutation(id: UUID(), leadId: leadId, newStatus: "opened",
                                       enqueuedAt: Date(timeIntervalSince1970: 1000),
                                       attempts: 0)
    let m2 = PendingLeadStatusMutation(id: UUID(), leadId: leadId, newStatus: "contacted",
                                       enqueuedAt: Date(timeIntervalSince1970: 2000),
                                       attempts: 0)
    store.enqueue(m1)
    store.enqueue(m2)

    let first = store.nextPendingMutation()
    XCTAssertEqual(first?.newStatus, "opened")
  }

  func test_recordFailure_increments_attempts() throws {
    let store = try makeStore()
    let m = PendingLeadStatusMutation(id: UUID(), leadId: UUID(), newStatus: "spam",
                                      enqueuedAt: .now, attempts: 0)
    store.enqueue(m)
    store.recordFailure(mutationId: m.id, error: NSError(domain: "test", code: 500))

    let after = store.nextPendingMutation()
    XCTAssertEqual(after?.attempts, 1)
    XCTAssertNotNil(after?.lastError)
  }

  func test_markDead_removes_from_active_queue() throws {
    let store = try makeStore()
    let m = PendingLeadStatusMutation(id: UUID(), leadId: UUID(), newStatus: "spam",
                                      enqueuedAt: .now, attempts: 5)
    store.enqueue(m)
    store.markDead(mutationId: m.id)

    XCTAssertNil(store.nextPendingMutation())
    XCTAssertEqual(store.deadLetters().count, 1)
  }

  func test_pendingCount_excludes_dead() throws {
    let store = try makeStore()
    let live = PendingLeadStatusMutation(id: UUID(), leadId: UUID(), newStatus: "spam",
                                         enqueuedAt: .now, attempts: 0)
    let dead = PendingLeadStatusMutation(id: UUID(), leadId: UUID(), newStatus: "spam",
                                         enqueuedAt: .now, attempts: 5, isDead: true)
    store.enqueue(live)
    store.enqueue(dead)

    XCTAssertEqual(store.pendingCount(), 1)
  }
}
