import Testing
import Foundation
import SwiftData
@testable import AtollTalk

@MainActor @Suite(.serialized) struct SpeakFallbackTests {
  @Test func missingVoiceStaysSilentNotError() throws {
    let container = try ModelContainer(for: Turn.self,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let vm = AppViewModel(
      recorder: AudioRecorder(),
      speech: SpeechService(apiKey: ""),
      translator: TranslationService(provider: StubLLM(chunks: [.done])),
      synthesis: SynthesisService(elevenLabsKey: nil, voices: [:]),
      store: ConversationStore(context: container.mainContext),
      context: "", glossaryLines: { "" }, pair: { LanguagePair(a: .de, b: .ceb) })
    vm.speak(Turn(sourceText: "hi", sourceLang: .de, targetText: "uy", targetLang: .ceb))
    #expect(vm.phase == .idle)   // not .error
  }
}
