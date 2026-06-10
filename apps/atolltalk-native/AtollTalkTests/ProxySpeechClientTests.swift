import Testing
import Foundation
import AtollSpeech
@testable import AtollTalk

@Suite(.serialized) struct ProxySpeechClientTests {
  private let base = URL(string: "https://x.test/functions/v1/speech")!
  private let device = "11111111-2222-3333-4444-555555555555"

  @Test func sttSendsDeviceHeaderAndDecodesTranscription() async throws {
    MockURLProtocol.responder = { req in
      #expect(req.url?.path.hasSuffix("/speech/stt") == true)
      #expect(req.value(forHTTPHeaderField: "x-atoll-device") == "11111111-2222-3333-4444-555555555555")
      #expect(req.value(forHTTPHeaderField: "x-atoll-jws") == nil)
      return (Data(#"{"text":"hallo","language_code":"deu","language_probability":0.97}"#.utf8), 200)
    }
    let c = ProxySpeechClient(baseURL: base, deviceID: device,
                              session: MockURLProtocol.session())
    let t = try await c.transcribe(audioData: Data([1, 2, 3]), modelID: "scribe_v1")
    #expect(t.text == "hallo")
    #expect(t.languageCode == "deu")
  }

  @Test func sttAttachesJWSWhenAvailable() async throws {
    MockURLProtocol.responder = { req in
      #expect(req.value(forHTTPHeaderField: "x-atoll-jws") == "jws-token")
      return (Data(#"{"text":"ok"}"#.utf8), 200)
    }
    let c = ProxySpeechClient(baseURL: base, deviceID: device,
                              jws: { "jws-token" },
                              session: MockURLProtocol.session())
    _ = try await c.transcribe(audioData: Data([1]), modelID: "scribe_v1")
  }

  @Test func ttsWithoutJWSFailsBeforeNetwork() async {
    MockURLProtocol.responder = { _ in
      Issue.record("network must not be hit without a JWS")
      return (Data(), 500)
    }
    let c = ProxySpeechClient(baseURL: base, deviceID: device,
                              jws: { nil },
                              session: MockURLProtocol.session())
    await #expect(throws: ElevenLabsClient.Error.unauthorized) {
      _ = try await c.synthesize(text: "hi", voiceID: "abcdefgh1", modelID: "m")
    }
  }

  @Test func ttsPostsToVoicePathAndReturnsAudio() async throws {
    MockURLProtocol.responder = { req in
      #expect(req.url?.path.hasSuffix("/speech/tts/voice1234") == true)
      #expect(req.value(forHTTPHeaderField: "x-atoll-jws") == "jws-token")
      return (Data([0xFF, 0xF3]), 200)  // fake MP3 bytes
    }
    let c = ProxySpeechClient(baseURL: base, deviceID: device,
                              jws: { "jws-token" },
                              session: MockURLProtocol.session())
    let data = try await c.synthesize(text: "Guten Tag", voiceID: "voice1234", modelID: "m")
    #expect(data == Data([0xFF, 0xF3]))
  }

  @Test func rateLimitMapsToRateLimitError() async {
    MockURLProtocol.responder = { _ in (Data(#"{"error":"rate_limited"}"#.utf8), 429) }
    let c = ProxySpeechClient(baseURL: base, deviceID: device,
                              session: MockURLProtocol.session())
    await #expect(throws: ElevenLabsClient.Error.rateLimit) {
      _ = try await c.transcribe(audioData: Data([1]), modelID: "scribe_v1")
    }
  }
}
