import Foundation
import Translation

/// On-device machine translation for the Basic tier. Pure MT — `context` and
/// `glossary` are ignored (Apple's Translation framework takes neither).
///
/// Uses the iOS 26 programmatic `TranslationSession(installedSource:target:)`.
/// The language pack must already be installed; if it isn't, `translate` throws
/// and the caller surfaces an error. Pack download is handled separately.
struct AppleTranslator: Translator {
  enum MTError: Error { case packNotInstalled, unsupported }

  func translate(_ text: String, from source: AppLanguage, to target: AppLanguage,
                 context: String, glossary: String) async throws -> String {
    let status = await LanguageAvailability().status(from: locale(source), to: locale(target))
    switch status {
    case .installed: break
    case .supported: throw MTError.packNotInstalled   // ConversationView prepares it
    default:         throw MTError.unsupported
    }
    let session = TranslationSession(installedSource: locale(source), target: locale(target))
    return try await session.translate(text).targetText
  }

  /// AppLanguage → BCP-47 language (de, uk, en, it, es, fr).
  private func locale(_ l: AppLanguage) -> Locale.Language {
    Locale.Language(identifier: String(l.appleLocale.prefix(2)))
  }
}
