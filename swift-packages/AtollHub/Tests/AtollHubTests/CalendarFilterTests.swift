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
}
