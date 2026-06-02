import XCTest
import AtollHub
@testable import ComHub

@MainActor
final class SmokeTests: XCTestCase {
  func test_hubStartsEmpty() {
    let hub = Hub()
    XCTAssertTrue(hub.connections.isEmpty)
  }

  func test_moduleRailHasAllModules() {
    XCTAssertEqual(ComHubModule.allCases.count, 7)
  }
}
