import Testing
@testable import AtollTalk

@Suite struct SecretsTests {
  @Test func elevenLabsKeyIsConfigured() {
    #expect(!Config.elevenLabsAPIKey.isEmpty)
  }
}
