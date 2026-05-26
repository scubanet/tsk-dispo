import XCTest
@testable import AtollCard

@MainActor
final class MutationDrainerTests: XCTestCase {

  /// Test-double `LeadRepository` — `updateStatus` records each call and
  /// can be programmed to throw the next call via `failNext`. Other
  /// protocol members are no-ops because the drainer only exercises
  /// `updateStatus`.
  final class MockLeadRepo: LeadRepository, @unchecked Sendable {
    var failNext: Error?
    var calls: [(UUID, LeadStatus)] = []

    func fetchAll() async throws -> [Lead] { [] }
    func fetch(id: UUID) async throws -> Lead? { nil }
    func upsert(_ lead: Lead) async throws {}
    func updateStatus(id: UUID, status: LeadStatus) async throws {
      calls.append((id, status))
      if let err = failNext {
        failNext = nil
        throw err
      }
    }
    func markImported(id: UUID) async throws {}
  }

  func test_drain_happy_path_removes_mutation() async throws {
    let cache = try CacheStore()
    let mock  = MockLeadRepo()
    let drainer = MutationDrainer(cache: cache, remote: mock)
    cache.enqueue(PendingLeadStatusMutation(
      id: UUID(), leadId: UUID(),
      newStatus: "opened",
      enqueuedAt: .now, attempts: 0
    ))

    await drainer.drain()

    XCTAssertEqual(mock.calls.count, 1)
    XCTAssertNil(cache.nextPendingMutation())
  }

  func test_drain_records_failure_on_throw() async throws {
    let cache = try CacheStore()
    let mock  = MockLeadRepo()
    mock.failNext = NSError(domain: "net", code: 500)
    let drainer = MutationDrainer(cache: cache, remote: mock)
    let m = PendingLeadStatusMutation(
      id: UUID(), leadId: UUID(),
      newStatus: "spam", enqueuedAt: .now, attempts: 0
    )
    cache.enqueue(m)

    await drainer.drain()

    let after = cache.nextPendingMutation()
    XCTAssertNotNil(after)
    XCTAssertEqual(after?.attempts, 1)
  }

  func test_drain_marks_dead_after_5_attempts() async throws {
    let cache = try CacheStore()
    let mock  = MockLeadRepo()
    mock.failNext = NSError(domain: "net", code: 500)
    let drainer = MutationDrainer(cache: cache, remote: mock)
    let m = PendingLeadStatusMutation(
      id: UUID(), leadId: UUID(),
      newStatus: "spam", enqueuedAt: .now, attempts: 4
    )
    cache.enqueue(m)

    await drainer.drain()

    XCTAssertNil(cache.nextPendingMutation())
    XCTAssertEqual(cache.deadLetters().count, 1)
  }

  func test_drain_unknown_status_marks_dead() async throws {
    let cache = try CacheStore()
    let mock  = MockLeadRepo()
    let drainer = MutationDrainer(cache: cache, remote: mock)
    cache.enqueue(PendingLeadStatusMutation(
      id: UUID(), leadId: UUID(),
      newStatus: "not-a-real-status",
      enqueuedAt: .now, attempts: 0
    ))

    await drainer.drain()

    XCTAssertEqual(mock.calls.count, 0)
    XCTAssertNil(cache.nextPendingMutation())
    XCTAssertEqual(cache.deadLetters().count, 1)
  }

  func test_drain_auth_error_bails_without_burning_attempt() async throws {
    let cache = try CacheStore()
    let mock  = MockLeadRepo()
    mock.failNext = NSError(domain: "auth", code: 401,
                            userInfo: [NSLocalizedDescriptionKey: "401 Unauthorized"])
    let drainer = MutationDrainer(cache: cache, remote: mock)
    let m = PendingLeadStatusMutation(
      id: UUID(), leadId: UUID(),
      newStatus: "opened", enqueuedAt: .now, attempts: 0
    )
    cache.enqueue(m)

    await drainer.drain()

    let after = cache.nextPendingMutation()
    XCTAssertNotNil(after, "mutation should still be in the queue")
    XCTAssertEqual(after?.attempts, 0, "auth errors must not increment attempts")
  }

  func test_retryDeadLetter_resets_and_drains() async throws {
    let cache = try CacheStore()
    let mock  = MockLeadRepo()
    let drainer = MutationDrainer(cache: cache, remote: mock)
    let m = PendingLeadStatusMutation(
      id: UUID(), leadId: UUID(),
      newStatus: "opened", enqueuedAt: .now,
      attempts: 5, lastError: "boom", isDead: true
    )
    cache.enqueue(m)
    XCTAssertEqual(cache.deadLetters().count, 1)

    await drainer.retryDeadLetter(mutationId: m.id)

    XCTAssertEqual(mock.calls.count, 1, "retry should re-attempt the call")
    XCTAssertEqual(cache.deadLetters().count, 0)
    XCTAssertNil(cache.nextPendingMutation())
  }
}
