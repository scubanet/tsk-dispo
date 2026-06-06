import Foundation

/// Shared interface for both tiers: Pro (`TranslationService`, Claude) and
/// Basic (`AppleTranslator`, on-device MT). The composition root injects the
/// right one based on `SubscriptionStore.isPro`.
protocol Translator: Sendable {
  /// `source` is the detected source language (from routing). Pro (Claude) can
  /// ignore it; Basic (Apple on-device) needs it to build a `TranslationSession`.
  func translate(_ text: String, from source: AppLanguage, to target: AppLanguage,
                 context: String, glossary: String) async throws -> String
}
