import Testing
import Foundation
import AtollSpeech
@testable import AtollTalk

@Suite struct SpeechServiceTests {
  @Test func transcribeMapsTextAndLanguage() async throws {
    MockURLProtocol.responder = { _ in
      let body = #"{"text":"Доброго дня","language_code":"ukr","language_probability":0.98}"#
      return (Data(body.utf8), 200)
    }
    let client = ElevenLabsClient(apiKey: "x", session: MockURLProtocol.session())
    let service = SpeechService(client: client)
    let result = try await service.transcribe(wav: Data([0, 1, 2, 3]))
    #expect(result.text == "Доброго дня")
    #expect(result.language == .uk)
  }
}
