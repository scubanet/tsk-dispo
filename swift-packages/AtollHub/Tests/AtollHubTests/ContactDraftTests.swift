import XCTest
@testable import AtollHub

final class ContactDraftTests: XCTestCase {
  func test_person_requiresFirstAndLast() {
    XCTAssertFalse(ContactDraft(kind: .person, firstName: "A", lastName: " ").isValid)
    XCTAssertTrue(ContactDraft(kind: .person, firstName: "A", lastName: "B").isValid)
  }
  func test_org_requiresName() {
    XCTAssertFalse(ContactDraft(kind: .organization, organizationName: "").isValid)
    XCTAssertTrue(ContactDraft(kind: .organization, organizationName: "TSK").isValid)
  }
}
