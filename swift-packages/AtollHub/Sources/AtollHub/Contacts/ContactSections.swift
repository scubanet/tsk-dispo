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

/// Gruppiert `MergedContact`s nach dem ersten Buchstaben des Nachnamens
/// (Fallback Anzeigename; Nicht-Buchstabe → „#"), Sektionen alphabetisch,
/// Mitglieder nach Nachname, dann Vorname.
public enum ContactSections {
  /// Sortierschluessel: „Nachname Vorname" (Nachname-Fallback Anzeigename).
  private static func sortKey(_ c: MergedContact) -> String {
    let last = (c.lastName?.isEmpty == false) ? c.lastName! : c.displayName
    let first = c.firstName ?? ""
    return "\(last) \(first)".localizedLowercase
  }

  /// Sektionsbuchstabe aus dem Nachnamen (Fallback Anzeigename).
  private static func sectionLetter(_ c: MergedContact) -> String {
    let base = (c.lastName?.isEmpty == false) ? c.lastName! : c.displayName
    guard let ch = base.trimmingCharacters(in: .whitespaces).first else { return "#" }
    return ch.isLetter ? String(ch).uppercased() : "#"
  }

  public static func byLetter(_ contacts: [MergedContact]) -> [ContactLetterSection] {
    var buckets: [String: [MergedContact]] = [:]
    for c in contacts {
      buckets[sectionLetter(c), default: []].append(c)
    }
    return buckets.keys.sorted { $0.localizedCompare($1) == .orderedAscending }.map { letter in
      let sorted = buckets[letter]!.sorted {
        sortKey($0).localizedCompare(sortKey($1)) == .orderedAscending
      }
      return ContactLetterSection(letter: letter, contacts: sorted)
    }
  }
}
