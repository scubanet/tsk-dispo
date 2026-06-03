import XCTest
@testable import AtollHub

@MainActor
final class HubContactRoutingTests: XCTestCase {
  final class FakeContacts: ContactsProvider, @unchecked Sendable {
    var created: [ContactDraft] = []; var updated: [(String, ContactDraft)] = []
    let stub: UnifiedContact
    init(stub: UnifiedContact) { self.stub = stub }
    func contacts() async throws -> [UnifiedContact] { [] }
    func createContact(_ d: ContactDraft) async throws -> UnifiedContact { created.append(d); return stub }
    func updateContact(id: String, with d: ContactDraft) async throws -> UnifiedContact { updated.append((id, d)); return stub }
  }
  final class FakeTodo: TodoProvider, @unchecked Sendable {
    var created: [String] = []
    func tasks() async throws -> [UnifiedTask] { [] }
    func createTask(title: String, due: Date?, listId: String?) async throws { created.append(title) }
  }
  private func acct(_ id: String, _ t: AccountType) -> Account {
    Account(id: id, type: t, displayName: id, capabilities: [.contacts, .todo])
  }
  private var stub: UnifiedContact {
    UnifiedContact(id: "atoll:new", source: AccountRef(accountId: "atoll", type: .atoll),
                   firstName: "A", lastName: "B", emails: [], phones: [])
  }

  func test_createContact_routesToChosenSource() async throws {
    let apple = FakeContacts(stub: stub), atoll = FakeContacts(stub: stub)
    let hub = Hub()
    hub.connect(AccountConnection(account: acct("apple", .apple), contacts: apple))
    hub.connect(AccountConnection(account: acct("atoll", .atoll), contacts: atoll))
    _ = try await hub.createContact(ContactDraft(firstName: "X", lastName: "Y"), source: .atoll)
    XCTAssertEqual(atoll.created.count, 1); XCTAssertTrue(apple.created.isEmpty)
  }
  func test_updateContact_routesByIdPrefix() async throws {
    let apple = FakeContacts(stub: stub)
    let hub = Hub(); hub.connect(AccountConnection(account: acct("apple", .apple), contacts: apple))
    _ = try await hub.updateContact(id: "apple:1", with: ContactDraft(firstName: "X", lastName: "Y"))
    XCTAssertEqual(apple.updated.first?.0, "apple:1")
  }
  func test_createTask_routesToApple() async throws {
    let todo = FakeTodo()
    let hub = Hub(); hub.connect(AccountConnection(account: acct("apple", .apple), todo: todo))
    try await hub.createTask(title: "T", due: nil, listId: nil)
    XCTAssertEqual(todo.created, ["T"])
  }
  func test_createTask_throwsWithoutAppleTodo() async {
    let hub = Hub()
    do { try await hub.createTask(title: "T", due: nil, listId: nil); XCTFail("should throw") }
    catch {}
  }
}
