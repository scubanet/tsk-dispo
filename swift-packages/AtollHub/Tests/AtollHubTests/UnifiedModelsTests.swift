import XCTest
@testable import AtollHub

final class UnifiedModelsTests: XCTestCase {
  func test_unifiedEvent_isConstructibleAndEquatable() {
    let ref = AccountRef(accountId: "a1", type: .apple)
    let start = Date(timeIntervalSince1970: 1_000)
    let end = Date(timeIntervalSince1970: 4_600)
    let e1 = UnifiedEvent(id: "e1", source: ref, title: "Tauchgang",
                          start: start, end: end, isAllDay: false, location: "Hausriff")
    let e2 = UnifiedEvent(id: "e1", source: ref, title: "Tauchgang",
                          start: start, end: end, isAllDay: false, location: "Hausriff")
    XCTAssertEqual(e1, e2)
    XCTAssertEqual(e1.source.type, .apple)
  }

  func test_unifiedMessage_carriesChannelAndDirection() {
    let ref = AccountRef(accountId: "atoll", type: .atoll)
    let m = UnifiedMessage(id: "m1", source: ref, channel: .whatsapp,
                           direction: .inbound, contactName: "Anna",
                           preview: "Hallo", timestamp: Date(timeIntervalSince1970: 5),
                           isUnread: true)
    XCTAssertEqual(m.channel, .whatsapp)
    XCTAssertEqual(m.direction, .inbound)
    XCTAssertTrue(m.isUnread)
  }
}
