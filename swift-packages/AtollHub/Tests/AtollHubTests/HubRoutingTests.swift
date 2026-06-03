import XCTest
@testable import AtollHub

@MainActor
final class HubRoutingTests: XCTestCase {
  final class FakeTodo: TodoProvider, @unchecked Sendable {
    var doneCalls: [(String, Bool)] = []
    func tasks() async throws -> [UnifiedTask] { [] }
    func setDone(taskId: String, isDone: Bool) async throws { doneCalls.append((taskId, isDone)) }
  }
  final class FakeCalendar: CalendarProvider, @unchecked Sendable {
    var created: [EventDraft] = []
    func events(in interval: DateInterval) async throws -> [UnifiedEvent] { [] }
    func createEvent(_ draft: EventDraft) async throws -> UnifiedEvent {
      created.append(draft)
      return UnifiedEvent(id: "apple:new", source: AccountRef(accountId: "a", type: .apple),
                          title: draft.title, start: draft.start, end: draft.end,
                          isAllDay: draft.isAllDay, location: draft.location)
    }
  }

  private func account(_ id: String, _ type: AccountType) -> Account {
    Account(id: id, type: type, displayName: id, capabilities: [.todo, .calendar])
  }

  func test_setTaskDone_routesToMatchingSource() async throws {
    let apple = FakeTodo(), atoll = FakeTodo()
    let hub = Hub()
    hub.connect(AccountConnection(account: account("apple", .apple), todo: apple))
    hub.connect(AccountConnection(account: account("atoll", .atoll), todo: atoll))
    let task = UnifiedTask(id: "atoll:42", source: AccountRef(accountId: "atoll", type: .atoll),
                           title: "x", due: nil, isDone: false)
    try await hub.setTaskDone(task, done: true)
    XCTAssertEqual(atoll.doneCalls.count, 1)
    XCTAssertEqual(atoll.doneCalls.first?.0, "atoll:42")
    XCTAssertEqual(atoll.doneCalls.first?.1, true)
    XCTAssertTrue(apple.doneCalls.isEmpty)
  }

  func test_createEvent_routesToAppleCalendar() async throws {
    let cal = FakeCalendar()
    let hub = Hub()
    hub.connect(AccountConnection(account: account("apple", .apple), calendar: cal))
    let draft = EventDraft(title: "Meeting", start: Date(timeIntervalSince1970: 0),
                           end: Date(timeIntervalSince1970: 3600))
    let ev = try await hub.createEvent(draft)
    XCTAssertEqual(cal.created.count, 1)
    XCTAssertEqual(ev.title, "Meeting")
  }

  func test_setTaskDone_throwsWhenNoMatchingConnection() async {
    let hub = Hub()
    let task = UnifiedTask(id: "atoll:1", source: AccountRef(accountId: "atoll", type: .atoll),
                           title: "x", due: nil, isDone: false)
    do { try await hub.setTaskDone(task, done: true); XCTFail("should throw") }
    catch { /* expected */ }
  }
}
