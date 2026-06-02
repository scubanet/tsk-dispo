import XCTest
@testable import AtollHub

final class ContactSectionsTests: XCTestCase {
  private func c(_ id: String, _ name: String) -> MergedContact {
    MergedContact(group: [UnifiedContact(
      id: id, source: AccountRef(accountId: "x", type: .apple),
      firstName: "", lastName: name, emails: [], phones: [])])
  }

  func test_groupsByFirstLetterSortedWithMembersSorted() {
    let input = [c("1","Muster"), c("2","Anna"), c("3","Albert"), c("4","Zorro")]
    let sections = ContactSections.byLetter(input)
    XCTAssertEqual(sections.map(\.letter), ["A", "M", "Z"])
    XCTAssertEqual(sections[0].contacts.map(\.displayName), ["Albert", "Anna"])
    XCTAssertEqual(sections[1].contacts.map(\.displayName), ["Muster"])
  }

  func test_nonLetterStartGroupsUnderHash() {
    let sections = ContactSections.byLetter([c("1","+41 79"), c("2","Ben")])
    XCTAssertEqual(Set(sections.map(\.letter)), ["#", "B"])
  }

  func test_emptyInputEmptyOutput() {
    XCTAssertTrue(ContactSections.byLetter([]).isEmpty)
  }
}
