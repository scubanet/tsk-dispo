import XCTest
@testable import AtollHub

final class SearchRankTests: XCTestCase {
  func test_prefixBeatsWordStartBeatsContains() {
    XCTAssertEqual(SearchRank.score("Anna Muster", query: "ann"), 3)   // prefix
    XCTAssertEqual(SearchRank.score("Anna Muster", query: "mus"), 2)   // word start
    XCTAssertEqual(SearchRank.score("Hermann", query: "man"), 1)       // contains
    XCTAssertNil(SearchRank.score("Anna", query: "xyz"))
  }
  func test_diacriticAndCaseInsensitive() {
    XCTAssertNotNil(SearchRank.score("Zürcher", query: "zur"))
    XCTAssertEqual(SearchRank.score("ÉCOLE", query: "ecole"), 3)
  }
  func test_emptyQueryNoMatch() { XCTAssertNil(SearchRank.score("Anna", query: "  ")) }
  func test_bestAcrossFields() {
    XCTAssertEqual(SearchRank.best(["Bob", "anna@x.ch", nil], query: "anna"), 3)
    XCTAssertNil(SearchRank.best(["Bob", "x@y.ch"], query: "zzz"))
  }
}
