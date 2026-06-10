import Foundation
import AVFoundation
import AtollSpeech

@MainActor
final class SynthesisService {
  private let composite: CompositeSynthesizer
  private let elevenVoiceByLang: [AppLanguage: String]
  /// Whether an ElevenLabs synthesizer is wired (Pro tier + non-empty API key).
  private let hasElevenLabs: Bool
  /// True when ElevenLabs voices are active (Pro). Basic is always false.
  var isElevenLabsActive: Bool { hasElevenLabs }

  /// - backend: speech backend for ElevenLabs voices (production: the proxy);
  ///   nil → Apple-only fallback.
  /// - voices: ElevenLabs voice id per language (from Settings).
  /// - tier: `.basic` never wires ElevenLabs (Pro-only feature) — Apple voices only.
  init(backend: (any SpeechBackend)?, voices: [AppLanguage: String], tier: Tier = .pro) {
    self.elevenVoiceByLang = voices
    let apple = AppleSynthesizer()
    if tier == .pro, let backend {
      // Seed with any configured voice; the actual voice is set per utterance.
      let seed = voices.values.first { !$0.isEmpty } ?? ""
      let eleven = ElevenLabsSynthesizer(client: backend, defaultVoiceID: seed)
      composite = CompositeSynthesizer(apple: apple, elevenLabs: eleven, provider: .apple)
      hasElevenLabs = true
    } else {
      composite = CompositeSynthesizer(apple: apple, elevenLabs: nil, provider: .apple)
      hasElevenLabs = false
    }
  }

  /// Speak `text` in `lang`. Uses the ElevenLabs voice configured for that
  /// language when available; otherwise falls back to an installed Apple voice
  /// for that locale — chosen per utterance so each language reads in its own
  /// voice (and a language without an ElevenLabs voice still speaks via Apple).
  /// Returns `false` when no voice exists for `lang` (no ElevenLabs voice
  /// configured *and* no installed Apple voice for the locale), so the caller
  /// can tell the user instead of silently doing nothing / reading in the
  /// wrong voice.
  @discardableResult
  func speak(_ text: String, in lang: AppLanguage) -> Bool {
    if hasElevenLabs, let v = elevenVoiceByLang[lang], !v.isEmpty {
      composite.setProvider(.elevenLabs)
      composite.setVoice(identifier: v)
    } else if let id = Self.appleVoiceIdentifier(for: lang) {
      composite.setProvider(.apple)
      composite.setVoice(identifier: id)
    } else {
      return false
    }
    composite.speak(text)
    return true
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
