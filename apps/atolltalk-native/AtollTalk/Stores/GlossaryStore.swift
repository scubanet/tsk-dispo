import Foundation
import Observation

@MainActor @Observable
final class GlossaryStore {
  private let defaults: UserDefaults
  private let key = "swiss.atoll.talk.glossary"
  private(set) var entries: [GlossaryEntry]

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    if let data = defaults.data(forKey: key),
       let decoded = try? JSONDecoder().decode([GlossaryEntry].self, from: data) {
      entries = decoded
    } else {
      entries = []
    }
  }

  func add(de: String, uk: String) {
    entries.append(GlossaryEntry(de: de, uk: uk)); persist()
  }

  func remove(_ entry: GlossaryEntry) {
    entries.removeAll { $0.id == entry.id }; persist()
  }

  /// Glossary rendered for the translation system prompt.
  func promptLines() -> String {
    entries.map { "\($0.de) ↔ \($0.uk)" }.joined(separator: "\n")
  }

  private func persist() {
    if let data = try? JSONEncoder().encode(entries) {
      defaults.set(data, forKey: key)
    }
  }
}
