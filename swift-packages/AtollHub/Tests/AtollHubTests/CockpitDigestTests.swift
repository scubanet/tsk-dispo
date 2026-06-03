import XCTest
@testable import AtollHub

final class CockpitDigestTests: XCTestCase {
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
  private func task(_ id: String, due: String?, done: Bool) -> UnifiedTask {
    UnifiedTask(id: id, source: AccountRef(accountId: "x", type: .apple),
                title: id, due: due.map(date), isDone: done)
  }

  func test_todayEvents_keepsOnlyTodayAndSortsAllDayFirst() {
    let now = date("2026-06-10 09:00")
    let events = [
      ev("timed", "2026-06-10 14:00"),
      ev("allday", "2026-06-10 00:00", allDay: true),
      ev("yesterday", "2026-06-09 14:00"),
      ev("tomorrow", "2026-06-11 08:00"),
    ]
    let result = CockpitDigest.todayEvents(from: events, now: now, calendar: cal)
    XCTAssertEqual(result.map(\.id), ["allday", "timed"])
  }

  func test_openTasks_dropsDoneSortsByDueNilLastAndCaps() {
    let tasks = [
      task("done", due: "2026-06-10 10:00", done: true),
      task("late", due: "2026-06-12 10:00", done: false),
      task("early", due: "2026-06-10 10:00", done: false),
      task("noDue", due: nil, done: false),
    ]
    let result = CockpitDigest.openTasks(from: tasks, limit: 10)
    XCTAssertEqual(result.map(\.id), ["early", "late", "noDue"])
  }

  func test_openTasks_capsAtLimit() {
    let tasks = (0..<5).map { task("t\($0)", due: "2026-06-1\($0) 10:00", done: false) }
    XCTAssertEqual(CockpitDigest.openTasks(from: tasks, limit: 3).count, 3)
  }
}
