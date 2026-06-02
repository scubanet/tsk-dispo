import XCTest
@testable import AtollHub

final class AppleMappersTests: XCTestCase {
  func test_event_mapsFieldsAndTagsAppleSource() {
    let start = Date(timeIntervalSince1970: 1_000)
    let end = Date(timeIntervalSince1970: 4_600)
    let e = AppleEventMapper.event(accountId: "icloud", identifier: "ek-1",
                                   title: "Tauchgang", start: start, end: end,
                                   isAllDay: false, location: "Hausriff")
    XCTAssertEqual(e.id, "apple:ek-1")
    XCTAssertEqual(e.source, AccountRef(accountId: "icloud", type: .apple))
    XCTAssertEqual(e.title, "Tauchgang")
    XCTAssertEqual(e.location, "Hausriff")
    XCTAssertFalse(e.isAllDay)
  }

  func test_event_fallsBackToPlaceholderTitleWhenEmpty() {
    let e = AppleEventMapper.event(accountId: "icloud", identifier: "x",
                                   title: "", start: Date(timeIntervalSince1970: 0),
                                   end: Date(timeIntervalSince1970: 1),
                                   isAllDay: true, location: nil)
    XCTAssertEqual(e.title, "(Ohne Titel)")
  }

  func test_contact_buildsUnifiedWithAppleSource() {
    let c = AppleContactMapper.contact(accountId: "icloud", identifier: "cn-9",
                                       givenName: "Anna", familyName: "Muster",
                                       emails: ["Anna@Example.com", ""],
                                       phones: ["+41 79 123 45 67"])
    XCTAssertEqual(c.id, "apple:cn-9")
    XCTAssertEqual(c.source.type, .apple)
    XCTAssertEqual(c.firstName, "Anna")
    XCTAssertEqual(c.lastName, "Muster")
    XCTAssertEqual(c.emails, ["Anna@Example.com"])
    XCTAssertEqual(c.phones, ["+41 79 123 45 67"])
  }
}
