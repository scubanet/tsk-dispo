import XCTest
@testable import AtollHub

final class EventColumnsTests: XCTestCase {
  private func ev(_ id: String, _ startMin: Int, _ endMin: Int) -> UnifiedEvent {
    UnifiedEvent(id: id, source: AccountRef(accountId: "x", type: .apple),
                 title: id, start: Date(timeIntervalSince1970: Double(startMin) * 60),
                 end: Date(timeIntervalSince1970: Double(endMin) * 60),
                 isAllDay: false, location: nil)
  }

  func test_nonOverlapping_allSingleColumn() {
    let slots = EventColumns.layout([ev("a", 540, 600), ev("b", 660, 720)])
    XCTAssertEqual(slots.count, 2)
    XCTAssertTrue(slots.allSatisfy { $0.column == 0 && $0.columnCount == 1 })
  }

  func test_twoOverlapping_twoColumns() {
    let slots = EventColumns.layout([ev("a", 540, 660), ev("b", 600, 720)])
    let a = slots.first { $0.event.id == "a" }!
    let b = slots.first { $0.event.id == "b" }!
    XCTAssertEqual(a.column, 0); XCTAssertEqual(b.column, 1)
    XCTAssertEqual(a.columnCount, 2); XCTAssertEqual(b.columnCount, 2)
  }

  func test_thirdFitsFreedColumn() {
    let slots = EventColumns.layout([ev("a", 540, 600), ev("b", 540, 660), ev("c", 600, 660)])
    let c = slots.first { $0.event.id == "c" }!
    XCTAssertEqual(c.column, 0)
    XCTAssertTrue(slots.allSatisfy { $0.columnCount == 2 })
  }

  func test_allDayAndOutOfOrderHandled() {
    let allDay = UnifiedEvent(id: "ad", source: AccountRef(accountId: "x", type: .apple),
                              title: "ad", start: Date(timeIntervalSince1970: 0),
                              end: Date(timeIntervalSince1970: 86_400), isAllDay: true, location: nil)
    let slots = EventColumns.layout([ev("late", 660, 720), allDay, ev("early", 540, 600)])
    XCTAssertEqual(slots.map(\.event.id), ["early", "late"])
  }
}
