import XCTest
@testable import AtollHub

final class MergedContactTests: XCTestCase {
  private func c(_ id: String, type: AccountType, first: String, last: String,
                emails: [String] = [], phones: [String] = []) -> UnifiedContact {
    UnifiedContact(id: id, source: AccountRef(accountId: type.rawValue, type: type),
                   firstName: first, lastName: last, emails: emails, phones: phones)
  }

  func test_mergesGroupUnionsContactsAndSources() {
    let group = [
      c("atoll:1", type: .atoll, first: "Anna", last: "Muster",
        emails: ["anna@example.com"], phones: ["+41791234567"]),
      c("apple:9", type: .apple, first: "Anna", last: "Muster",
        emails: ["anna@example.com"], phones: ["+41 79 123 45 67"]),
    ]
    let merged = MergedContact(group: group)
    XCTAssertEqual(merged.displayName, "Anna Muster")
    XCTAssertEqual(merged.sources, [.apple, .atoll])
    XCTAssertEqual(merged.emails, ["anna@example.com"])
    XCTAssertEqual(merged.phones.count, 2)
    XCTAssertEqual(merged.id, "apple:9")
  }

  func test_singletonKeepsSingleSource() {
    let merged = MergedContact(group: [c("apple:1", type: .apple, first: "Ben", last: "B")])
    XCTAssertEqual(merged.sources, [.apple])
    XCTAssertEqual(merged.displayName, "Ben B")
  }

  func test_displayNameFallsBackToEmailWhenNameEmpty() {
    let merged = MergedContact(group: [c("atoll:1", type: .atoll, first: "", last: "",
                                         emails: ["info@tsz.ch"])])
    XCTAssertEqual(merged.displayName, "info@tsz.ch")
  }
}
