import Foundation

/// Picks the translation backend by tier. Basic → on-device Apple MT (no Claude
/// cost, no keys); Pro → ProxyTranslator (Claude via Supabase Edge Function, key
/// stays server-side). STT (Scribe) and synthesis are wired separately.
enum ServiceFactory {
  static func translator(
    isPro: Bool,
    model: String,
    jws: @escaping @Sendable () async -> String?
  ) -> any Translator {
    isPro ? ProxyTranslator(model: model, jws: jws) : AppleTranslator()
  }
}
