import Testing
import Foundation
import SwiftData
import AtollSpeech
import AtollLLM
@testable import AtollTalk

private struct StubLLM: LLMProvider {
  let chunks: [LLMChunk]
  func streamChat(messages: [LLMMessage], tools: [LLMTool], model: String, systemPrompt: String?)
    -> AsyncThrowingStream<LLMChunk, Error> {
    AsyncThrowingStream { c in chunks.forEach { c.yield($0) }; c.finish() }
  }
}

@MainActor @Suite(.serialized) struct AppViewModelTests {
  private func makeVM(scribeJSON: String, llm: [LLMChunk]) throws -> (AppViewModel, ConversationStore) {
    MockURLProtocol.responder = { _ in (Data(scribeJSON.utf8), 200) }
    let client = ElevenLabsClient(apiKey: "x", session: MockURLProtocol.session())
    let container = try ModelContainer(for: Turn.self,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let store = ConversationStore(context: container.mainContext)
    let vm = AppViewModel(
      recorder: AudioRecorder(),
      speech: SpeechService(client: client),
      translator: TranslationService(provider: StubLLM(chunks: llm)),
      synthesis: SynthesisService(elevenLabsKey: nil, voices: [:]),
      store: store,
      context: "ctx",
      glossaryLines: { "" },
      pair: { LanguagePair(a: .de, b: .uk) }
    )
    return (vm, store)
  }

  @Test func ukrainianInputProducesGermanTurn() async throws {
    let (vm, store) = try makeVM(
      scribeJSON: #"{"text":"Доброго дня","language_code":"ukr"}"#,
      llm: [.text("Guten Tag"), .done])
    await vm.process(wav: Data([1,2,3]))
    let turns = try store.allNewestFirst()
    #expect(turns.count == 1)
    #expect(turns.first?.sourceLang == .uk)
    #expect(turns.first?.targetLang == .de)
    #expect(turns.first?.targetText == "Guten Tag")
    #expect(vm.phase == .idle)
  }

  @Test func emptyTranscriptSurfacesError() async throws {
    let (vm, _) = try makeVM(scribeJSON: #"{"text":"","language_code":"deu"}"#, llm: [.done])
    await vm.process(wav: Data([1]))
    if case .error = vm.phase { } else { Issue.record("expected .error phase") }
  }
}
