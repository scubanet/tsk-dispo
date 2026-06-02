import XCTest
@testable import AtollHub

final class ComHubModuleTests: XCTestCase {
  func test_orderStartsWithHeuteAndEndsWithEinstellungen() {
    XCTAssertEqual(ComHubModule.allCases.first, .heute)
    XCTAssertEqual(ComHubModule.allCases.last, .einstellungen)
  }

  func test_everyModuleHasTitleAndSymbol() {
    for module in ComHubModule.allCases {
      XCTAssertFalse(module.title.isEmpty, "\(module) ohne Titel")
      XCTAssertFalse(module.systemImage.isEmpty, "\(module) ohne Symbol")
    }
  }

  func test_heuteTitleIsLocalisedLabel() {
    XCTAssertEqual(ComHubModule.heute.title, "Heute")
    XCTAssertEqual(ComHubModule.kombox.title, "Kombox")
  }
}
