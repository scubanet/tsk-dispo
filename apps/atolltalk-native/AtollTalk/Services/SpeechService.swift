import Foundation
import AtollSpeech

struct SpeechResult: Equatable, Sendable {
  let text: String
  let language: AppLanguage?
}

struct SpeechService: Sendable {
  let client: any SpeechBackend
  let modelID: String

  /// Production wiring passes a `ProxySpeechClient`; tests inject an
  /// `ElevenLabsClient` on a mocked URLSession (both are `SpeechBackend`).
  init(client: any SpeechBackend, modelID: String = Config.scribeModelID) {
    self.client = client
    self.modelID = modelID
  }

  func transcribe(wav: Data) async throws -> SpeechResult {
    let t = try await client.transcribe(audioData: wav, modelID: modelID)
    let lang = t.languageCode.flatMap { AppLanguage(scribeCode: $0) }
    return SpeechResult(text: t.text, language: lang)
  }
}
