import XCTest
@testable import AtollHub

final class DayClipTests: XCTestCase {
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
  private func ev(_ id: String, _ start: String, _ end: String, allDay: Bool = false) -> UnifiedEvent {
    UnifiedEvent(id: id, source: AccountRef(accountId: "x", type: .apple),
                 title: id, start: date(start), end: date(end),
                 isAllDay: allDay, location: nil)
  }
  private func day(_ s: String) -> Date { cal.startOfDay(for: date(s + " 12:00")) }

  // MARK: - segment

  func test_segment_sameDayEvent_returnsUnchanged() {
    let e = ev("a", "2026-06-10 09:00", "2026-06-10 10:00")
    let seg = DayClip.segment(event: e, on: day("2026-06-10"), calendar: cal)
    XCTAssertEqual(seg?.start, date("2026-06-10 09:00"))
    XCTAssertEqual(seg?.end, date("2026-06-10 10:00"))
  }

  func test_segment_overnightEvent_startDayClippedToMidnight() {
    let e = ev("a", "2026-06-10 22:00", "2026-06-11 01:00")
    let seg = DayClip.segment(event: e, on: day("2026-06-10"), calendar: cal)
    XCTAssertEqual(seg?.start, date("2026-06-10 22:00"))
    XCTAssertEqual(seg?.end, date("2026-06-11 00:00"))
  }

  func test_segment_overnightEvent_endDayClippedFromMidnight() {
    let e = ev("a", "2026-06-10 22:00", "2026-06-11 01:00")
    let seg = DayClip.segment(event: e, on: day("2026-06-11"), calendar: cal)
    XCTAssertEqual(seg?.start, date("2026-06-11 00:00"))
    XCTAssertEqual(seg?.end, date("2026-06-11 01:00"))
  }

  func test_segment_dayOutsideRange_returnsNil() {
    let e = ev("a", "2026-06-10 22:00", "2026-06-11 01:00")
    XCTAssertNil(DayClip.segment(event: e, on: day("2026-06-12"), calendar: cal))
    XCTAssertNil(DayClip.segment(event: e, on: day("2026-06-09"), calendar: cal))
  }

  func test_segment_eventEndingExactlyAtMidnight_excludesNextDay() {
    let e = ev("a", "2026-06-10 22:00", "2026-06-11 00:00")
    XCTAssertNotNil(DayClip.segment(event: e, on: day("2026-06-10"), calendar: cal))
    XCTAssertNil(DayClip.segment(event: e, on: day("2026-06-11"), calendar: cal))
  }

  // MARK: - overlappedDays

  func test_overlappedDays_singleDay() {
    let e = ev("a", "2026-06-10 09:00", "2026-06-10 10:00")
    XCTAssertEqual(DayClip.overlappedDays(event: e, calendar: cal), [day("2026-06-10")])
  }

  func test_overlappedDays_overnightSpansTwoDays() {
    let e = ev("a", "2026-06-10 22:00", "2026-06-11 01:00")
    XCTAssertEqual(DayClip.overlappedDays(event: e, calendar: cal),
                   [day("2026-06-10"), day("2026-06-11")])
  }

  func test_overlappedDays_multiDayAllDay() {
    // Apple all-day: end exclusive at midnight of day-after-last
    let e = ev("ferien", "2026-06-10 00:00", "2026-06-13 00:00", allDay: true)
    XCTAssertEqual(DayClip.overlappedDays(event: e, calendar: cal),
                   [day("2026-06-10"), day("2026-06-11"), day("2026-06-12")])
  }

  func test_overlappedDays_endAtMidnightDoesNotIncludeThatDay() {
    let e = ev("a", "2026-06-10 22:00", "2026-06-11 00:00")
    XCTAssertEqual(DayClip.overlappedDays(event: e, calendar: cal), [day("2026-06-10")])
  }
}
