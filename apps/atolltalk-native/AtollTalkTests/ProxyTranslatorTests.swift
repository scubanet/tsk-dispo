import Testing
import Foundation
@testable import AtollTalk

@Suite(.serialized) struct ProxyTranslatorTests {
  @Test func returnsTranslatedText() async throws {
    MockURLProtocol.responder = { _ in (Data(#"{"text":"Привіт"}"#.utf8), 200) }
    let t = ProxyTranslator(
      endpoint: URL(string: "https://example.com/translate")!,
      model: "m", jws: { "fake-jws" }, session: MockURLProtocol.session())
    let out = try await t.translate("Hallo", from: .de, to: .uk, context: "", glossary: "")
    #expect(out == "Привіт")
  }

  @Test func throwsWhenNotEntitled() async {
    let t = ProxyTranslator(
      endpoint: URL(string: "https://example.com/translate")!,
      model: "m", jws: { nil }, session: MockURLProtocol.session())
    await #expect(throws: ProxyTranslator.ProxyError.self) {
      try await t.translate("Hallo", from: .de, to: .uk, context: "", glossary: "")
    }
  }

  @Test func throwsOnNon200() async {
    MockURLProtocol.responder = { _ in (Data(#"{"error":"not_entitled"}"#.utf8), 403) }
    let t = ProxyTranslator(
      endpoint: URL(string: "https://example.com/translate")!,
      model: "m", jws: { "fake-jws" }, session: MockURLProtocol.session())
    await #expect(throws: ProxyTranslator.ProxyError.self) {
      try await t.translate("Hallo", from: .de, to: .uk, context: "", glossary: "")
    }
  }
}
