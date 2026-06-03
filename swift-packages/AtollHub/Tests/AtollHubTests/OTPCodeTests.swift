import XCTest
@testable import AtollHub

final class OTPCodeTests: XCTestCase {
  func test_validSixDigits() {
    XCTAssertTrue(OTPCode.isValid("123456"))
  }

  func test_rejectsWrongLengthOrNonDigits() {
    XCTAssertFalse(OTPCode.isValid("12345"))
    XCTAssertFalse(OTPCode.isValid("1234567"))
    XCTAssertFalse(OTPCode.isValid("12a456"))
    XCTAssertFalse(OTPCode.isValid(""))
  }

  func test_sanitizeKeepsOnlyDigits() {
    XCTAssertEqual(OTPCode.sanitize(" 12 34-56 "), "123456")
  }
}
