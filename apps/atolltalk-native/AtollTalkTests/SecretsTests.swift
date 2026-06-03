import Testing
@testable import AtollTalk

@Suite struct SecretsTests {
  @Test func setGetClear() {
    let store = InMemorySecretStore()
    #expect(store.value(for: .anthropicAPIKey) == nil)
    store.set("sk-ant-123", for: .anthropicAPIKey)
    #expect(store.value(for: .anthropicAPIKey) == "sk-ant-123")
    store.set(nil, for: .anthropicAPIKey)
    #expect(store.value(for: .anthropicAPIKey) == nil)
  }
}
