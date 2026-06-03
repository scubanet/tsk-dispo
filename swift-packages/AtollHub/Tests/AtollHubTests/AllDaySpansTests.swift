import XCTest
@testable import AtollHub

final class AllDaySpansTests: XCTestCase {
  private var cal: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
    return c
  }
  private func day(_ d: Int) -> Date {
    DateComponents(calendar: cal, timeZone: cal.timeZone,
                   year: 2026, month: 6, day: d).date!
  }
  private func days(_ from: Int, _ count: Int) -> [Date] {
    (0..<count).map { day(from + $0) }
  }
  private func ev(_ id: String, start: Int, endExclusive: Int, allDay: Bool = true) -> UnifiedEvent {
    UnifiedEvent(id: id, source: AccountRef(accountId: "x", type: .apple), title: id,
                 start: day(start), end: day(endExclusive), isAllDay: allDay, location: nil)
  }

  func test_singleDayEvent_oneRowOneBar() {
    let rows = AllDaySpans.layout([ev("a", start: 3, endExclusive: 4)], days: days(1, 7), calendar: cal)
    XCTAssertEqual(rows.count, 1)
    XCTAssertEqual(rows[0].count, 1)
    XCTAssertEqual(rows[0][0].startIndex, 2)   // 3. Juni = Index 2 in [1..7]
    XCTAssertEqual(rows[0][0].span, 1)
  }

  func test_multiDayEvent_singleSpanningBar() {
    let rows = AllDaySpans.layout([ev("week", start: 1, endExclusive: 8)], days: days(1, 7), calendar: cal)
    XCTAssertEqual(rows.count, 1)
    XCTAssertEqual(rows[0][0].startIndex, 0)
    XCTAssertEqual(rows[0][0].span, 7)
  }

  func test_nonOverlappingSingleDays_packIntoOneRow() {
    let evs = [ev("mon", start: 1, endExclusive: 2), ev("wed", start: 3, endExclusive: 4)]
    let rows = AllDaySpans.layout(evs, days: days(1, 7), calendar: cal)
    XCTAssertEqual(rows.count, 1)
    XCTAssertEqual(rows[0].count, 2)
  }

  func test_overlappingEvents_separateRows() {
    let evs = [ev("a", start: 1, endExclusive: 4), ev("b", start: 2, endExclusive: 5)]
    let rows = AllDaySpans.layout(evs, days: days(1, 7), calendar: cal)
    XCTAssertEqual(rows.count, 2)
  }

  func test_clipsToWindow() {
    // Startet vor dem Fenster (30. Mai), endet im Fenster (3. Juni exkl.).
    let early = UnifiedEvent(id: "early", source: AccountRef(accountId: "x", type: .apple),
                             title: "early",
                             start: DateComponents(calendar: cal, year: 2026, month: 5, day: 30).date!,
                             end: day(3), isAllDay: true, location: nil)
    let rows = AllDaySpans.layout([early], days: days(1, 7), calendar: cal)
    XCTAssertEqual(rows[0][0].startIndex, 0)   // auf Spalte 0 geclippt
    XCTAssertEqual(rows[0][0].span, 2)         // 1. + 2. Juni
  }

  func test_ignoresTimedEvents() {
    let rows = AllDaySpans.layout([ev("timed", start: 3, endExclusive: 4, allDay: false)],
                                  days: days(1, 7), calendar: cal)
    XCTAssertTrue(rows.isEmpty)
  }

  func test_emptyDays_returnsEmpty() {
    XCTAssertTrue(AllDaySpans.layout([ev("a", start: 1, endExclusive: 2)], days: [], calendar: cal).isEmpty)
  }
}
