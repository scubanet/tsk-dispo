import XCTest
@testable import AtollHub

final class KomboxDigestTests: XCTestCase {
  private var cal: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Zurich")!
    c.firstWeekday = 2
    return c
  }
  private func ts(_ s: String) -> Date {
    let f = DateFormatter(); f.calendar = cal; f.timeZone = cal.timeZone
    f.dateFormat = "yyyy-MM-dd HH:mm"; f.locale = Locale(identifier: "en_US_POSIX")
    return f.date(from: s)!
  }
  private func ev(_ id: String, contact: String, name: String, _ time: String,
                  kind: KomboxKind = .whatsapp) -> KomboxEvent {
    KomboxEvent(id: id, contactId: contact, contactName: name, kind: kind,
                direction: .inbound, summary: id, body: nil, subject: nil,
                timestamp: ts(time), status: "open")
  }

  func test_conversations_latestPerContactSortedNewestFirst() {
    let events = [
      ev("a1", contact: "A", name: "Anna", "2026-06-02 09:00"),
      ev("a2", contact: "A", name: "Anna", "2026-06-02 15:00"),
      ev("b1", contact: "B", name: "Ben",  "2026-06-02 12:00"),
    ]
    let convs = KomboxDigest.conversations(from: events)
    XCTAssertEqual(convs.map(\.id), ["A", "B"])
    XCTAssertEqual(convs[0].lastEvent.id, "a2")
    XCTAssertEqual(convs[0].contactName, "Anna")
  }

  func test_threadSections_groupedByDayAscendingWithEventsAscending() {
    let events = [
      ev("d2", contact: "A", name: "Anna", "2026-06-02 15:00"),
      ev("d1b", contact: "A", name: "Anna", "2026-06-01 18:00"),
      ev("d1a", contact: "A", name: "Anna", "2026-06-01 09:00"),
    ]
    let sections = KomboxDigest.threadSections(events, calendar: cal)
    XCTAssertEqual(sections.count, 2)
    XCTAssertEqual(sections[0].day, cal.startOfDay(for: ts("2026-06-01 00:00")))
    XCTAssertEqual(sections[0].events.map(\.id), ["d1a", "d1b"])
    XCTAssertEqual(sections[1].events.map(\.id), ["d2"])
  }
}
