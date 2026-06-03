import Testing
import Foundation
@testable import AtollSpeech

@Suite struct ScribeDecodeTests {
  @Test func decodesTextAndLanguage() throws {
    let json = """
    { "text": "Доброго дня", "language_code": "ukr", "language_probability": 0.99 }
    """.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(ElevenLabsClient.Transcription.self, from: json)
    #expect(decoded.text == "Доброго дня")
    #expect(decoded.languageCode == "ukr")
  }
}
