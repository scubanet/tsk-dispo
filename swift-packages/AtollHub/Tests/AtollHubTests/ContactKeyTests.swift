import XCTest
@testable import AtollHub

final class ContactKeyTests: XCTestCase {
  func test_email_lowercasesAndTrims() {
    XCTAssertEqual(ContactKey.email("  Anna@Example.COM "), "anna@example.com")
  }

  func test_email_rejectsEmptyOrInvalid() {
    XCTAssertNil(ContactKey.email("   "))
    XCTAssertNil(ContactKey.email("not-an-email"))
  }

  func test_phone_keepsLeadingPlusAndStripsFormatting() {
    XCTAssertEqual(ContactKey.phone("+41 (079) 123-45 67"), "+41079123 4567".replacingOccurrences(of: " ", with: ""))
    XCTAssertEqual(ContactKey.phone("+41 79 123 45 67"), "+41791234567")
  }

  func test_phone_stripsNonDigitsWhenNoPlus() {
    XCTAssertEqual(ContactKey.phone("079/123 45 67"), "0791234567")
  }

  func test_phone_rejectsTooShort() {
    XCTAssertNil(ContactKey.phone("123"))
  }
}
