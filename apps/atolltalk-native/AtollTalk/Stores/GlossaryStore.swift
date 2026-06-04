import Foundation
import Observation

/// Per-pair glossary: each unordered language pair has its own list of term
/// mappings. Storage is order-independent — the pair {a,b} and {b,a} share one
/// glossary.
@MainActor @Observable
final class GlossaryStore {
  private let defaults: UserDefaults
  private let key = "swiss.atoll.talk.glossary.byPair"
  private(set) var byPair: [String: [GlossaryEntry]]

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    if let data = defaults.data(forKey: key),
       let decoded = try? JSONDecoder().decode([String: [GlossaryEntry]].self, from: data) {
      byPair = decoded
    } else {
      byPair = [:]
      migrateLegacy()
    }
  }

  /// The pair's two languages in stable (sorted) order, matching `GlossaryEntry.a/.b`.
  static func sortedLangs(_ pair: LanguagePair) -> (AppLanguage, AppLanguage) {
    let s = [pair.a, pair.b].sorted { $0.rawValue < $1.rawValue }
    return (s[0], s[1])
  }

  private static func pairKey(_ pair: LanguagePair) -> String {
    [pair.a.rawValue, pair.b.rawValue].sorted().joined(separator: "|")
  }

  func entries(for pair: LanguagePair) -> [GlossaryEntry] { byPair[Self.pairKey(pair)] ?? [] }

  /// Add a mapping. `term(for:)` supplies the term for each of the pair's languages.
  func add(for pair: LanguagePair, term: (AppLanguage) -> String) {
    let (la, lb) = Self.sortedLangs(pair)
    let entry = GlossaryEntry(a: term(la), b: term(lb))
    byPair[Self.pairKey(pair), default: []].append(entry)
    persist()
  }

  func remove(_ entry: GlossaryEntry, for pair: LanguagePair) {
    byPair[Self.pairKey(pair)]?.removeAll { $0.id == entry.id }
    persist()
  }

  /// Glossary rendered for the translation system prompt, for the active pair.
  func promptLines(for pair: LanguagePair) -> String {
    let entries = byPair[Self.pairKey(pair)] ?? []
    guard !entries.isEmpty else { return "" }
    return entries.map { "\($0.a) ↔ \($0.b)" }.joined(separator: "\n")
  }

  private func persist() {
    if let data = try? JSONEncoder().encode(byPair) {
      defaults.set(data, forKey: key)
    }
  }

  /// Import older glossary formats once: the per-foreign-language store and the
  /// original single DE↔UK list. Both map into the DE/foreign pair.
  private func migrateLegacy() {
    // Per-language store: [foreignRaw: [{de, foreign}]]
    if let data = defaults.data(forKey: "swiss.atoll.talk.glossary.byLang") {
      struct OldEntry: Codable { var id: UUID; var de: String; var foreign: String }
      if let decoded = try? JSONDecoder().decode([String: [OldEntry]].self, from: data) {
        for (rawLang, entries) in decoded {
          guard let lang = AppLanguage(rawValue: rawLang) else { continue }
          let pair = LanguagePair(a: .de, b: lang)
          for e in entries { add(for: pair) { $0 == .de ? e.de : e.foreign } }
        }
      }
      defaults.removeObject(forKey: "swiss.atoll.talk.glossary.byLang")
    }
    // Original single DE↔UK list.
    if let data = defaults.data(forKey: "swiss.atoll.talk.glossary") {
      struct LegacyEntry: Codable { var id: UUID; var de: String; var uk: String }
      if let legacy = try? JSONDecoder().decode([LegacyEntry].self, from: data) {
        let pair = LanguagePair(a: .de, b: .uk)
        for e in legacy { add(for: pair) { $0 == .de ? e.de : e.uk } }
      }
      defaults.removeObject(forKey: "swiss.atoll.talk.glossary")
    }
  }
}
