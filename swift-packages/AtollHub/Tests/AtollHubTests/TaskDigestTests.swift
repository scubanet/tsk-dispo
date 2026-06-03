import XCTest
@testable import AtollHub

final class TaskDigestTests: XCTestCase {
  private var cal: Calendar {
    var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Europe/Zurich")!; return c
  }
  private func day(_ s: String) -> Date {
    let f = DateFormatter(); f.calendar = cal; f.timeZone = cal.timeZone
    f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX"); return f.date(from: s)!
  }
  private func task(_ id: String, due: Date?, done: Bool = false, flagged: Bool = false,
                    list: String? = nil) -> UnifiedTask {
    UnifiedTask(id: id, source: AccountRef(accountId: "x", type: .apple), title: id,
                due: due, isDone: done, listName: list, isFlagged: flagged)
  }

  func test_smartToday_keepsDueToday() {
    let now = day("2026-06-02")
    let tasks = [task("t", due: day("2026-06-02")), task("m", due: day("2026-06-03")), task("n", due: nil)]
    let r = TaskDigest.filter(tasks, smart: .today, list: nil, now: now, calendar: cal)
    XCTAssertEqual(r.open.map(\.id), ["t"])
  }

  func test_smartFlagged() {
    let tasks = [task("a", due: nil, flagged: true), task("b", due: nil)]
    let r = TaskDigest.filter(tasks, smart: .flagged, list: nil, now: day("2026-06-02"), calendar: cal)
    XCTAssertEqual(r.open.map(\.id), ["a"])
  }

  func test_splitOpenDone_andListFilter() {
    let tasks = [task("o", due: nil, list: "Schule"), task("d", due: nil, done: true, list: "Schule"),
                 task("x", due: nil, list: "Privat")]
    let r = TaskDigest.filter(tasks, smart: .all, list: "Schule", now: day("2026-06-02"), calendar: cal)
    XCTAssertEqual(r.open.map(\.id), ["o"])
    XCTAssertEqual(r.done.map(\.id), ["d"])
  }

  func test_lists_groupsWithOpenCount() {
    let tasks = [task("a", due: nil, list: "Schule"), task("b", due: nil, done: true, list: "Schule"),
                 task("c", due: nil, list: "Privat")]
    let lists = TaskDigest.lists(tasks)
    XCTAssertEqual(lists.map(\.name), ["Privat", "Schule"])
    XCTAssertEqual(lists.first { $0.name == "Schule" }?.openCount, 1)
  }
}
