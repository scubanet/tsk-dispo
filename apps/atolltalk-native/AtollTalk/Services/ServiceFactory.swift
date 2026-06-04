import Foundation

/// Picks the translation backend by tier. Basic → on-device Apple MT (no Claude
/// cost); Pro → Claude. STT (Scribe) and synthesis are wired separately.
enum ServiceFactory {
  static func translator(isPro: Bool, anthropicKey: String, model: String) -> any Translator {
    isPro ? TranslationService(apiKey: anthropicKey, model: model) : AppleTranslator()
  }
}
