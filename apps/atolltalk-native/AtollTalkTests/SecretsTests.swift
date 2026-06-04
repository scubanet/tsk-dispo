import Testing
@testable import AtollTalk

@Suite struct SecretsTests {
  @Test func setGetClear() {
    let store = InMemorySecretStore()
    #expect(store.value(for: .elevenLabsAPIKey) == nil)
    store.set("el-123", for: .elevenLabsAPIKey)
    #expect(store.value(for: .elevenLabsAPIKey) == "el-123")
    store.set(nil, for: .elevenLabsAPIKey)
    #expect(store.value(for: .elevenLabsAPIKey) == nil)
  }
}
