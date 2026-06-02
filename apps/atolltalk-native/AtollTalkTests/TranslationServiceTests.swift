import Testing
import Foundation
import AtollLLM
@testable import AtollTalk

private struct MockLLMProvider: LLMProvider {
  let chunks: [LLMChunk]
  func streamChat(messages: [LLMMessage], tools: [LLMTool], model: String, systemPrompt: String?)
    -> AsyncThrowingStream<LLMChunk, Error> {
    AsyncThrowingStream { cont in
      for c in chunks { cont.yield(c) }
      cont.finish()
    }
  }
}

@Suite struct TranslationServiceTests {
  @Test func systemPromptCarriesTargetAndGlossary() {
    let p = TranslationService.systemPrompt(
      context: "KÜCHENKONTEXT", glossary: "Maria ↔ Марія", target: .uk)
    #expect(p.contains("KÜCHENKONTEXT"))
    #expect(p.contains("Українська"))
    #expect(p.contains("Maria ↔ Марія"))
  }

  @Test func translateAccumulatesTextChunks() async throws {
    let provider = MockLLMProvider(chunks: [.text("При"), .text("віт"), .done])
    let service = TranslationService(provider: provider)
    let out = try await service.translate("Hallo", to: .uk, context: "x", glossary: "")
    #expect(out == "Привіт")
  }
}
