import XCTest
@testable import AtollHub

@MainActor
final class HubTests: XCTestCase {
  private var fullWindow: DateInterval {
    DateInterval(start: Date(timeIntervalSince1970: 0),
                 end: Date(timeIntervalSince1970: 1_000_000))
  }

  func test_allEvents_mergesAcrossAccountsAndSortsByStart() async {
    let apple = Account(id: "icloud", type: .apple, displayName: "iCloud",
                        capabilities: [.calendar])
    let atoll = Account(id: "atoll", type: .atoll, displayName: "Atoll",
                        capabilities: [.calendar])
    let hub = Hub()
    hub.connect(AccountConnection(account: apple,
      calendar: FakeCalendar([makeEvent("late", type: .apple, start: 500)])))
    hub.connect(AccountConnection(account: atoll,
      calendar: FakeCalendar([makeEvent("early", type: .atoll, start: 100)])))

    let merged = await hub.allEvents(in: fullWindow)

    XCTAssertEqual(merged.map(\.id), ["early", "late"])
    XCTAssertTrue(hub.lastErrors.isEmpty)
  }

  func test_allEvents_skipsFailingProviderButKeepsOthers() async {
    let ok = Account(id: "icloud", type: .apple, displayName: "iCloud",
                     capabilities: [.calendar])
    let bad = Account(id: "atoll", type: .atoll, displayName: "Atoll",
                      capabilities: [.calendar])
    let hub = Hub()
    hub.connect(AccountConnection(account: ok,
      calendar: FakeCalendar([makeEvent("ok", type: .apple, start: 1)])))
    hub.connect(AccountConnection(account: bad, calendar: FailingCalendar()))

    let merged = await hub.allEvents(in: fullWindow)

    XCTAssertEqual(merged.map(\.id), ["ok"])
    XCTAssertEqual(hub.lastErrors.count, 1)
  }

  func test_allTasks_onlyQueriesConnectionsWithTodoProvider() async {
    let apple = Account(id: "icloud", type: .apple, displayName: "iCloud",
                        capabilities: [.todo])
    let calOnly = Account(id: "x", type: .google, displayName: "G",
                          capabilities: [.calendar])
    let hub = Hub()
    hub.connect(AccountConnection(account: apple,
      todo: FakeTodo([UnifiedTask(id: "t1", source: apple.ref, title: "Tank fuellen",
                                  due: nil, isDone: false)])))
    hub.connect(AccountConnection(account: calOnly,
      calendar: FakeCalendar([])))

    let tasks = await hub.allTasks()

    XCTAssertEqual(tasks.map(\.id), ["t1"])
  }
}
