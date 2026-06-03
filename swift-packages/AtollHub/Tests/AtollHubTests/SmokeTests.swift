import XCTest
@testable import AtollHub

final class SmokeTests: XCTestCase {
  func test_packageImports() {
    XCTAssertEqual(AtollHub.version, "0.1.0")
  }
}
