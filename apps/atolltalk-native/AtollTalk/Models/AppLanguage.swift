import Foundation

enum AppLanguage: String, CaseIterable, Sendable, Codable, Identifiable {
  case de
  case uk

  var id: String { rawValue }
  var displayName: String { self == .de ? "Deutsch" : "Українська" }
  var flag: String { self == .de ? "🇩🇪" : "🇺🇦" }

  /// BCP-47 locale used to pick an Apple fallback voice.
  var appleLocale: String { self == .de ? "de-DE" : "uk-UA" }

  /// Map a Scribe language code (ISO 639-1 "de"/"uk" or 639-3 "deu"/"ukr").
  init?(scribeCode raw: String) {
    let c = raw.lowercased()
    if c.hasPrefix("de") || c.hasPrefix("ger") { self = .de }
    else if c.hasPrefix("uk") || c.hasPrefix("ukr") { self = .uk }
    else { return nil }
  }
}
