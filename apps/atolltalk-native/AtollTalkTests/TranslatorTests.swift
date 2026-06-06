import Testing
@testable import AtollTalk

private struct EchoTranslator: Translator {
  func translate(_ text: String, from: AppLanguage, to: AppLanguage, context: String, glossary: String) async throws -> String { "echo:\(text)" }
}

@Suite struct TranslatorTests {
  @Test func protocolIsSatisfiedByService() {
    let _: any Translator = EchoTranslator()                 // compiles
    let _: any Translator = TranslationService(apiKey: "")   // TranslationService conforms
    #expect(Bool(true))
  }
  @Test func echoTranslatorReturnsExpected() async throws {
    let out = try await EchoTranslator().translate("hi", from: .de, to: .uk, context: "", glossary: "")
    #expect(out == "echo:hi")
  }
}
