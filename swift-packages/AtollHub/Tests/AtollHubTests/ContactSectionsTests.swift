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

  private func person(_ id: String, first: String, last: String) -> MergedContact {
    MergedContact(group: [UnifiedContact(
      id: id, source: AccountRef(accountId: "x", type: .atoll),
      firstName: first, lastName: last, emails: [], phones: [])])
  }

  func test_sortsByLastNameThenFirstName() {
    let anna = person("1", first: "Anna", last: "Zueable")
    let bob  = person("2", first: "Bob",  last: "Aebi")
    let zora = person("3", first: "Zora", last: "Aebi")
    let sections = ContactSections.byLetter([anna, bob, zora])
    let flat = sections.flatMap { $0.contacts }
    XCTAssertEqual(flat.map(\.id), ["2", "3", "1"]) // Aebi Bob, Aebi Zora, Zueable Anna
    XCTAssertEqual(sections.first?.letter, "A")      // section by lastName
  }
}
