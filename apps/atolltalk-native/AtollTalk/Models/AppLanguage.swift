import Foundation

enum AppLanguage: String, CaseIterable, Sendable, Codable, Identifiable {
  case de
  case uk
  case en
  case it
  case es
  case fr
  case tl   // Tagalog
  case ceb  // Bisaya / Cebuano

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .de:  "Deutsch"
    case .uk:  "Українська"
    case .en:  "English (US)"
    case .it:  "Italiano"
    case .es:  "Español"
    case .fr:  "Français"
    case .tl:  "Tagalog"
    case .ceb: "Bisaya"
    }
  }

  var flag: String {
    switch self {
    case .de:  "🇨🇭"
    case .uk:  "🇺🇦"
    case .en:  "🇺🇸"
    case .it:  "🇮🇹"
    case .es:  "🇪🇸"
    case .fr:  "🇫🇷"
    case .tl:  "🇵🇭"
    case .ceb: "🇵🇭"
    }
  }

  /// BCP-47 locale prefix used to pick an Apple fallback voice.
  /// `ceb` has no Apple voice — synthesis falls back / surfaces an error.
  var appleLocale: String {
    switch self {
    case .de:  "de-DE"
    case .uk:  "uk-UA"
    case .en:  "en-US"
    case .it:  "it-IT"
    case .es:  "es-ES"
    case .fr:  "fr-FR"
    case .tl:  "fil-PH"   // Apple ships Filipino (fil) for Tagalog
    case .ceb: "ceb"      // no installed voice → handled by caller
    }
  }

  /// Map a Scribe language code (ISO 639-1/-3, sometimes a name) to a language.
  init?(scribeCode raw: String) {
    let c = raw.lowercased()
    // Swiss German (gsw) / Alemannic (als) is treated as the German side —
    // it's a spoken input dialect, not a separate target language.
    if c.hasPrefix("de") || c.hasPrefix("ger")
        || c.hasPrefix("gsw") || c.hasPrefix("als") || c.contains("swiss") { self = .de }
    else if c.hasPrefix("uk") || c.hasPrefix("ukr") { self = .uk }
    else if c.hasPrefix("en") || c.hasPrefix("eng") { self = .en }
    else if c.hasPrefix("it") || c.hasPrefix("ita") { self = .it }
    else if c.hasPrefix("es") || c.hasPrefix("spa") { self = .es }
    else if c.hasPrefix("fr") || c.hasPrefix("fra") || c.hasPrefix("fre") { self = .fr }
    else if c.hasPrefix("tl") || c.hasPrefix("tgl") || c.hasPrefix("fil")
        || c.hasPrefix("tag") { self = .tl }
    else if c.hasPrefix("ceb") || c.contains("bisaya") || c.contains("cebuano") { self = .ceb }
    else { return nil }
  }
}
