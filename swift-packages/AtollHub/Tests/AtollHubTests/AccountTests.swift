import XCTest
@testable import AtollHub

final class AccountTests: XCTestCase {
  func test_account_reportsSupportedCapabilities() {
    let atoll = Account(id: "atoll", type: .atoll, displayName: "Atoll",
                        capabilities: [.calendar, .comms, .contacts, .cardInbox, .todo])
    XCTAssertTrue(atoll.supports(.comms))
    XCTAssertTrue(atoll.supports(.calendar))
    XCTAssertFalse(atoll.supports(.mail))
  }

  func test_accountRef_derivesFromAccount() {
    let apple = Account(id: "icloud", type: .apple, displayName: "iCloud",
                        capabilities: [.calendar, .contacts, .todo])
    XCTAssertEqual(apple.ref, AccountRef(accountId: "icloud", type: .apple))
  }
}
