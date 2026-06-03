import XCTest
@testable import AtollHub

final class ContactMatcherTests: XCTestCase {
  private func contact(_ id: String, type: AccountType, emails: [String] = [],
                       phones: [String] = []) -> UnifiedContact {
    UnifiedContact(id: id, source: AccountRef(accountId: type.rawValue, type: type),
                   firstName: id, lastName: "Test", emails: emails, phones: phones)
  }

  func test_group_linksBySharedEmailAcrossSources() {
    let atoll = contact("atoll1", type: .atoll, emails: ["Anna@Example.com"])
    let apple = contact("apple1", type: .apple, emails: ["anna@example.com"])
    let other = contact("apple2", type: .apple, emails: ["ben@example.com"])

    let groups = ContactMatcher.group([atoll, apple, other])

    let linked = groups.first { $0.count == 2 }
    XCTAssertNotNil(linked)
    XCTAssertEqual(Set(linked!.map(\.id)), ["atoll1", "apple1"])
    XCTAssertEqual(groups.count, 2) // {atoll1,apple1} + {apple2}
  }

  func test_group_linksByPhoneWhenEmailDiffers() {
    let a = contact("a", type: .atoll, phones: ["+41 79 123 45 67"])
    let b = contact("b", type: .apple, phones: ["079 123 45 67"]) // ergibt anderen Key (kein +)
    let c = contact("c", type: .apple, phones: ["+41791234567"])  // gleich wie a

    let groups = ContactMatcher.group([a, b, c])

    let linked = groups.first { Set($0.map(\.id)) == ["a", "c"] }
    XCTAssertNotNil(linked)
  }

  func test_group_singletonWhenNoKeys() {
    let lonely = contact("x", type: .apple)
    let groups = ContactMatcher.group([lonely])
    XCTAssertEqual(groups.map { $0.map(\.id) }, [["x"]])
  }
}
