import XCTest
@testable import AtollHub

final class CalendarFilterTests: XCTestCase {
  private func ev(_ id: String, cal: String?) -> UnifiedEvent {
    UnifiedEvent(id: id, source: AccountRef(accountId: "x", type: .apple), title: id,
                 start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSince1970: 1),
                 isAllDay: false, location: nil, calendarId: cal)
  }

  func test_keepsOnlyEnabledCalendars() {
    let events = [ev("a", cal: "c1"), ev("b", cal: "c2"), ev("c", cal: "atoll")]
    let r = CalendarFilter.apply(events, enabledIds: ["c1", "atoll"])
    XCTAssertEqual(r.map(\.id), ["a", "c"])
  }

  func test_nilEnabledKeepsEverything() {
    let events = [ev("a", cal: "c1"), ev("b", cal: nil)]
    XCTAssertEqual(CalendarFilter.apply(events, enabledIds: nil).count, 2)
  }

  func test_eventWithoutCalendarIdAlwaysKept() {
    let events = [ev("a", cal: nil), ev("b", cal: "c2")]
    XCTAssertEqual(CalendarFilter.apply(events, enabledIds: ["c1"]).map(\.id), ["a"])
  }

  // — disabled-Variante (appweiter Hub-Filter) —

  func test_disabledHidesMatching() {
    let events = [ev("a", cal: "c1"), ev("b", cal: "c2"), ev("c", cal: "atoll")]
    let r = CalendarFilter.apply(events, disabledIds: ["c2"])
    XCTAssertEqual(r.map(\.id), ["a", "c"])
  }

  func test_emptyDisabledKeepsEverything() {
    let events = [ev("a", cal: "c1"), ev("b", cal: nil)]
    XCTAssertEqual(CalendarFilter.apply(events, disabledIds: []).count, 2)
  }

  func test_disabled_eventWithoutCalendarIdAlwaysKept() {
    let events = [ev("a", cal: nil), ev("b", cal: "c2")]
    XCTAssertEqual(CalendarFilter.apply(events, disabledIds: ["c2"]).map(\.id), ["a"])
  }
}

@MainActor
final class HubCalendarFilterTests: XCTestCase {
  private final class FakeCal: CalendarProvider {
    let events: [UnifiedEvent]
    init(_ e: [UnifiedEvent]) { events = e }
    func events(in interval: DateInterval) async throws -> [UnifiedEvent] { events }
  }
  private func ev(_ id: String, cal: String?) -> UnifiedEvent {
    UnifiedEvent(id: id, source: AccountRef(accountId: "x", type: .apple), title: id,
                 start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSince1970: 1),
                 isAllDay: false, location: nil, calendarId: cal)
  }

  func test_allEvents_appliesDisabledFilterAppWide() async {
    let hub = Hub()
    hub.connect(AccountConnection(
      account: Account(id: "apple", type: .apple, displayName: "A", capabilities: [.calendar]),
      calendar: FakeCal([ev("a", cal: "c1"), ev("b", cal: "c2")])))
    hub.disabledCalendarIds = ["c2"]
    let out = await hub.allEvents(in: DateInterval(start: Date(timeIntervalSince1970: 0),
                                                   end: Date(timeIntervalSince1970: 10)))
    XCTAssertEqual(out.map(\.id), ["a"])
  }
}
