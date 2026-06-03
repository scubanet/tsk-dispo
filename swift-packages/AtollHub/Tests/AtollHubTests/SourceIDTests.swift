import XCTest
@testable import AtollHub

final class SourceIDTests: XCTestCase {
  func test_stripsApplePrefix() {
    XCTAssertEqual(SourceID.raw(from: "apple:ABC-123"), "ABC-123")
  }
  func test_stripsAtollPrefix() {
    XCTAssertEqual(SourceID.raw(from: "atoll:d1e2f3"), "d1e2f3")
  }
  func test_keepsValueAfterFirstColonOnly() {
    XCTAssertEqual(SourceID.raw(from: "apple:has:colons"), "has:colons")
  }
  func test_noPrefixReturnsWholeString() {
    XCTAssertEqual(SourceID.raw(from: "plainid"), "plainid")
  }
}
