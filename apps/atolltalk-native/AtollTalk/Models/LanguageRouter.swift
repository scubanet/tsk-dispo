import Foundation

struct LanguagePair: Equatable, Sendable, Codable {
  var a: AppLanguage
  var b: AppLanguage

  func contains(_ lang: AppLanguage) -> Bool { lang == a || lang == b }
  func other(than lang: AppLanguage) -> AppLanguage? {
    if lang == a { return b }
    if lang == b { return a }
    return nil
  }
}

enum LanguageRouter {
  /// (source, target) for the detected language within the active pair,
  /// or nil if the detected language isn't part of the pair.
  static func route(
    detected: AppLanguage, in pair: LanguagePair
  ) -> (source: AppLanguage, target: AppLanguage)? {
    guard let target = pair.other(than: detected) else { return nil }
    return (detected, target)
  }
}
