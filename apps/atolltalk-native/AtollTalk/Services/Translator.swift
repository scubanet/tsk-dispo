import Foundation

/// Shared interface for both tiers: Pro (`TranslationService`, Claude) and
/// Basic (`AppleTranslator`, on-device MT). The composition root injects the
/// right one based on `SubscriptionStore.isPro`.
protocol Translator: Sendable {
  func translate(_ text: String, to target: AppLanguage, context: String, glossary: String) async throws -> String
}
