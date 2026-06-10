import Foundation

/// Picks the translation backend by tier. Basic → on-device Apple MT (no Claude
/// cost, no keys), wrapped in `GlossaryRefiner` for optional on-device glossary
/// post-processing; Pro → ProxyTranslator (Claude via Supabase Edge Function, key
/// stays server-side, glossary applied there). STT (Scribe) and synthesis are
/// wired separately.
enum ServiceFactory {
  static func translator(
    isPro: Bool,
    model: String,
    jws: @escaping @Sendable () async -> String?
  ) -> any Translator {
    isPro ? ProxyTranslator(model: model, jws: jws)
          : GlossaryRefiner(base: AppleTranslator())
  }
}
