import Testing
import Foundation
import AtollSpeech
@testable import AtollTalk

/// Backend stub — synthesis tests only check the wiring, never the network.
struct StubSpeechBackend: SpeechBackend {
  func transcribe(audioData: Data, modelID: String) async throws
    -> ElevenLabsClient.Transcription {
    .init(text: "", languageCode: nil, languageProbability: nil)
  }
  func synthesize(text: String, voiceID: String, modelID: String) async throws -> Data {
    Data()
  }
}

@MainActor @Suite struct SynthesisServiceTests {
  @Test func basicTierNeverWiresElevenLabsEvenWithBackend() {
    let s = SynthesisService(backend: StubSpeechBackend(), voices: [.de: "voice-id"], tier: .basic)
    #expect(s.isElevenLabsActive == false)
  }
  @Test func proTierWithBackendWiresElevenLabs() {
    let s = SynthesisService(backend: StubSpeechBackend(), voices: [.de: "voice-id"], tier: .pro)
    #expect(s.isElevenLabsActive == true)
  }
  @Test func proTierWithoutBackendStaysApple() {
    let s = SynthesisService(backend: nil, voices: [:], tier: .pro)
    #expect(s.isElevenLabsActive == false)
  }
}
