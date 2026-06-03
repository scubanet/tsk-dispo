import XCTest
@testable import AtollHub

final class CalendarLayoutTests: XCTestCase {
  private var cal: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Zurich")!
    c.firstWeekday = 2
    return c
  }
  private func date(_ s: String) -> Date {
    let f = DateFormatter(); f.calendar = cal; f.timeZone = cal.timeZone
    f.dateFormat = "yyyy-MM-dd HH:mm"; f.locale = Locale(identifier: "en_US_POSIX")
    return f.date(from: s)!
  }
  private func ev(_ id: String, _ start: String, allDay: Bool = false) -> UnifiedEvent {
    UnifiedEvent(id: id, source: AccountRef(accountId: "x", type: .apple),
                 title: id, start: date(start),
                 end: date(start).addingTimeInterval(3600),
                 isAllDay: allDay, location: nil)
  }

  func test_eventsByDay_groupsByLocalDay() {
    let events = [ev("a", "2026-06-10 09:00"), ev("b", "2026-06-10 14:00"),
                  ev("c", "2026-06-11 08:00")]
    let byDay = CalendarLayout.eventsByDay(events, calendar: cal)
    let d10 = cal.startOfDay(for: date("2026-06-10 00:00"))
    let d11 = cal.startOfDay(for: date("2026-06-11 00:00"))
    XCTAssertEqual(byDay[d10]?.map(\.id), ["a", "b"])
    XCTAssertEqual(byDay[d11]?.map(\.id), ["c"])
  }

  func test_eventsByDay_allDayBeforeTimed() {
    let events = [ev("timed", "2026-06-10 09:00"), ev("allday", "2026-06-10 00:00", allDay: true)]
    let byDay = CalendarLayout.eventsByDay(events, calendar: cal)
    let d10 = cal.startOfDay(for: date("2026-06-10 00:00"))
    XCTAssertEqual(byDay[d10]?.map(\.id), ["allday", "timed"])
  }

  func test_eventsByDay_overnightEventAppearsInBothDays() {
    let overnight = UnifiedEvent(id: "night", source: AccountRef(accountId: "x", type: .apple),
                                 title: "night", start: date("2026-06-10 22:00"),
                                 end: date("2026-06-11 01:00"), isAllDay: false, location: nil)
    let byDay = CalendarLayout.eventsByDay([overnight], calendar: cal)
    let d10 = cal.startOfDay(for: date("2026-06-10 00:00"))
    let d11 = cal.startOfDay(for: date("2026-06-11 00:00"))
    XCTAssertEqual(byDay[d10]?.map(\.id), ["night"])
    XCTAssertEqual(byDay[d11]?.map(\.id), ["night"])
  }

  func test_eventsByDay_multiDayAllDayAppearsInEachDay() {
    let ferien = UnifiedEvent(id: "ferien", source: AccountRef(accountId: "x", type: .apple),
                              title: "ferien", start: date("2026-06-10 00:00"),
                              end: date("2026-06-13 00:00"), isAllDay: true, location: nil)
    let byDay = CalendarLayout.eventsByDay([ferien], calendar: cal)
    for d in ["2026-06-10", "2026-06-11", "2026-06-12"] {
      let key = cal.startOfDay(for: date(d + " 00:00"))
      XCTAssertEqual(byDay[key]?.map(\.id), ["ferien"], "missing on \(d)")
    }
    let after = cal.startOfDay(for: date("2026-06-13 00:00"))
    XCTAssertNil(byDay[after])
  }

  func test_weekDays_sevenDaysFromMonday() {
    let days = CalendarLayout.weekDays(of: date("2026-06-10 12:00"), calendar: cal)
    XCTAssertEqual(days.count, 7)
    XCTAssertEqual(days.first, cal.startOfDay(for: date("2026-06-08 00:00")))
    XCTAssertEqual(days.last, cal.startOfDay(for: date("2026-06-14 00:00")))
  }

  func test_monthGrid_returnsWeeksOfSeven() {
    let grid = CalendarLayout.monthGrid(of: date("2026-06-10 12:00"), calendar: cal)
    XCTAssertTrue(grid.allSatisfy { $0.count == 7 })
    XCTAssertEqual(grid.first?.first, cal.startOfDay(for: date("2026-06-01 00:00")))
    XCTAssertEqual(grid.count, 5)
  }
}
