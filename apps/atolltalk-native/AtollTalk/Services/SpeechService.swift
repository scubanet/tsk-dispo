import Foundation
import AtollSpeech

struct SpeechResult: Equatable, Sendable {
  let text: String
  let language: AppLanguage?
}

struct SpeechService: Sendable {
  let client: ElevenLabsClient
  let modelID: String

  init(apiKey: String, modelID: String = Config.scribeModelID, session: URLSession = .shared) {
    self.client = ElevenLabsClient(apiKey: apiKey, session: session)
    self.modelID = modelID
  }

  /// Test seam — inject a client wired to a mocked URLSession.
  init(client: ElevenLabsClient, modelID: String = Config.scribeModelID) {
    self.client = client
    self.modelID = modelID
  }

  func transcribe(wav: Data) async throws -> SpeechResult {
    let t = try await client.transcribe(audioData: wav, modelID: modelID)
    let lang = t.languageCode.flatMap { AppLanguage(scribeCode: $0) }
    return SpeechResult(text: t.text, language: lang)
  }
}
