import XCTest
@testable import AtollHub

final class DayWindowTests: XCTestCase {
  private var cal: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Zurich")!
    return c
  }
  private func at(_ hour: Int, _ minute: Int = 0) -> Date {
    cal.date(from: DateComponents(timeZone: cal.timeZone, year: 2026, month: 6, day: 2,
                                  hour: hour, minute: minute))!
  }
  private func ev(_ sH: Int, _ eH: Int) -> UnifiedEvent {
    UnifiedEvent(id: "\(sH)", source: AccountRef(accountId: "x", type: .apple),
                 title: "e", start: at(sH), end: at(eH), isAllDay: false, location: nil)
  }

  func test_defaultWhenNoEvents() {
    let w = DayWindow.hours(for: [], calendar: cal)
    XCTAssertEqual(w.startHour, 7); XCTAssertEqual(w.endHour, 19)
  }

  func test_expandsToEventsWithPadding() {
    let w = DayWindow.hours(for: [ev(9, 11), ev(14, 15)], calendar: cal)
    XCTAssertLessThanOrEqual(w.startHour, 8)
    XCTAssertGreaterThanOrEqual(w.endHour, 16)
    XCTAssertGreaterThanOrEqual(w.startHour, 6)
    XCTAssertLessThanOrEqual(w.endHour, 23)
  }

  func test_clampsExtremes() {
    let w = DayWindow.hours(for: [ev(0, 1), ev(22, 23)], calendar: cal)
    XCTAssertEqual(w.startHour, 6)
    XCTAssertEqual(w.endHour, 23)
  }

  func test_ignoresAllDay() {
    let allDay = UnifiedEvent(id: "ad", source: AccountRef(accountId: "x", type: .apple),
                              title: "ad", start: at(0), end: at(0), isAllDay: true, location: nil)
    let w = DayWindow.hours(for: [allDay], calendar: cal)
    XCTAssertEqual(w.startHour, 7); XCTAssertEqual(w.endHour, 19)
  }
}
