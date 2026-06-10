import Testing
import Foundation
import SwiftData
import AtollSpeech
@testable import AtollTalk

@MainActor @Suite(.serialized) struct ConsentGateTests {
  @Test func noConsentBlocksCloudCallAndAddsNoTurn() async throws {
    // Responder would yield a valid transcript — proving the gate prevents the
    // cloud STT call (no turn is ever produced).
    MockURLProtocol.responder = { _ in (Data(#"{"text":"Доброго дня","language_code":"ukr"}"#.utf8), 200) }
    let client = ElevenLabsClient(apiKey: "x", session: MockURLProtocol.session())
    let container = try ModelContainer(for: Turn.self,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let store = ConversationStore(context: container.mainContext)
    let vm = AppViewModel(
      recorder: AudioRecorder(),
      speech: SpeechService(client: client),
      translator: TranslationService(provider: StubLLM(chunks: [.text("Guten Tag"), .done])),
      synthesis: SynthesisService(backend: nil, voices: [:]),
      store: store,
      context: "", glossaryLines: { "" },
      pair: { LanguagePair(a: .de, b: .uk) },
      consent: { false })          // ← no consent
    await vm.process(wav: Data([1, 2, 3]))
    #expect(try store.allNewestFirst().isEmpty)
    if case .error = vm.phase { } else { Issue.record("expected .error phase") }
  }
}
