import Foundation

enum Tier: String, Sendable, Codable { case basic, pro }

extension AppLanguage {
  /// Pro languages are the ones Apple can't translate on-device (→ require Claude).
  var tier: Tier {
    switch self {
    case .tl, .ceb: .pro
    default:        .basic
    }
  }
  /// True when Apple's on-device Translation framework can translate this language.
  /// (Confirm at runtime via `LanguageAvailability`; this is the static expectation.)
  var appleTranslationSupported: Bool { tier == .basic }
}
