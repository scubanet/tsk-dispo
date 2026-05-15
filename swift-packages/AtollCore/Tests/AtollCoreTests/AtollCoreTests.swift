import XCTest
@testable import AtollCore

final class AtollCoreSmokeTests: XCTestCase {
  func test_packageImports() {
    // Wenn diese Test-Datei kompiliert + ausgeführt wird, kann die Library importiert werden.
    XCTAssertTrue(true)
  }
}
