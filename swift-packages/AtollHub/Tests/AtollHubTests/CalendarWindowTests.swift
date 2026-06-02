import XCTest
@testable import AtollHub

final class CalendarWindowTests: XCTestCase {
  // Fester Kalender: Gregorian, Montag als Wochenstart, Zürich.
  private var cal: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Zurich")!
    c.firstWeekday = 2 // Montag
    return c
  }
  // 2026-06-10 ist ein Mittwoch.
  private func date(_ s: String) -> Date {
    let f = DateFormatter(); f.calendar = cal; f.timeZone = cal.timeZone
    f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX")
    return f.date(from: s)!
  }

  func test_day_spansExactlyOneDay() {
    let w = CalendarWindow.interval(for: date("2026-06-10"), kind: .day, calendar: cal)
    XCTAssertEqual(w.start, cal.startOfDay(for: date("2026-06-10")))
    XCTAssertEqual(w.end, cal.startOfDay(for: date("2026-06-11")))
  }

  func test_week_spansMondayToNextMonday() {
    let w = CalendarWindow.interval(for: date("2026-06-10"), kind: .week, calendar: cal)
    XCTAssertEqual(w.start, cal.startOfDay(for: date("2026-06-08")))
    XCTAssertEqual(w.end, cal.startOfDay(for: date("2026-06-15")))
  }

  func test_month_coversWholeWeeksAroundMonth() {
    let w = CalendarWindow.interval(for: date("2026-06-10"), kind: .month, calendar: cal)
    XCTAssertEqual(w.start, cal.startOfDay(for: date("2026-06-01")))
    XCTAssertEqual(w.end, cal.startOfDay(for: date("2026-07-06")))
  }
}
