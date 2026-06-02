import Foundation
import AVFoundation
import AtollSpeech

@MainActor
final class SynthesisService {
  private let composite: CompositeSynthesizer
  private let elevenVoiceByLang: [AppLanguage: String]

  /// - elevenLabsKey: ElevenLabs API key; empty/nil → Apple-only fallback.
  /// - voices: ElevenLabs voice id per language (from Settings).
  init(elevenLabsKey: String?, voices: [AppLanguage: String], session: URLSession = .shared) {
    self.elevenVoiceByLang = voices
    let apple = AppleSynthesizer()
    if let key = elevenLabsKey, !key.isEmpty {
      let client = ElevenLabsClient(apiKey: key, session: session)
      let seed = voices[.uk] ?? voices[.de] ?? ""
      let eleven = ElevenLabsSynthesizer(client: client, defaultVoiceID: seed)
      composite = CompositeSynthesizer(
        apple: apple, elevenLabs: eleven,
        provider: seed.isEmpty ? .apple : .elevenLabs)
    } else {
      composite = CompositeSynthesizer(apple: apple, elevenLabs: nil, provider: .apple)
    }
  }

  func speak(_ text: String, in lang: AppLanguage) {
    switch composite.currentProvider {
    case .elevenLabs:
      if let v = elevenVoiceByLang[lang], !v.isEmpty {
        composite.setVoice(identifier: v)
      }
    case .apple:
      if let id = Self.appleVoiceIdentifier(for: lang) {
        composite.setVoice(identifier: id)
      }
    }
    composite.speak(text)
  }

  func stop() { composite.stop() }

  /// Resolve a concrete installed Apple voice for the language, if any.
  /// Returns nil when no voice for that locale is installed (e.g. no
  /// Ukrainian voice) — surfaced to the user in the final task's error handling.
  static func appleVoiceIdentifier(for lang: AppLanguage) -> String? {
    AVSpeechSynthesisVoice.speechVoices()
      .first { $0.language.hasPrefix(lang.appleLocale) }?
      .identifier
  }
}
