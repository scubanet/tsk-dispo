import Foundation

/// Eine A-Z-Sektion der Kontaktliste.
public struct ContactLetterSection: Sendable, Identifiable, Equatable {
  public let id: String
  public let letter: String
  public let contacts: [MergedContact]
  public init(letter: String, contacts: [MergedContact]) {
    self.id = letter; self.letter = letter; self.contacts = contacts
  }
}

/// Gruppiert `MergedContact`s nach dem ersten Buchstaben des Anzeigenamens
/// (Nicht-Buchstabe → „#"), Sektionen alphabetisch, Mitglieder nach Name.
public enum ContactSections {
  public static func byLetter(_ contacts: [MergedContact]) -> [ContactLetterSection] {
    var buckets: [String: [MergedContact]] = [:]
    for c in contacts {
      let first = c.displayName.trimmingCharacters(in: .whitespaces).first
      let key: String
      if let f = first, f.isLetter { key = String(f).uppercased() } else { key = "#" }
      buckets[key, default: []].append(c)
    }
    return buckets.keys.sorted { $0.localizedCompare($1) == .orderedAscending }.map { letter in
      let sorted = buckets[letter]!.sorted {
        $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
      }
      return ContactLetterSection(letter: letter, contacts: sorted)
    }
  }
}
