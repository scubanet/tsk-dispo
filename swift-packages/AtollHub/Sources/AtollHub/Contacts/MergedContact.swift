import Foundation

/// Eine zusammengefuehrte Kontakt-Gruppe fuers kombinierte Adressbuch.
/// Aus `ContactMatcher.group(_:)`-Ausgabe gebaut: vereinigt Namen, E-Mails,
/// Telefone der Mitglieder und haelt die beteiligten Quell-Typen fuer Tags.
public struct MergedContact: Identifiable, Equatable, Hashable, Sendable {
  /// Stabile id = lexikographisch kleinste Mitglieds-id (deterministisch).
  public let id: String
  public let displayName: String
  public let emails: [String]
  public let phones: [String]
  public let sources: [AccountType]
  /// Die Roh-Mitglieder (fuer die Detailansicht — pro Quelle aufschluesselbar).
  public let members: [UnifiedContact]

  public init(group: [UnifiedContact]) {
    precondition(!group.isEmpty, "MergedContact braucht mindestens ein Mitglied")
    self.members = group
    self.id = group.map(\.id).min() ?? group[0].id

    // Anzeigename: erster nicht-leerer "First Last", sonst erste E-Mail, sonst id.
    let named = group.first { !($0.firstName + $0.lastName).trimmingCharacters(in: .whitespaces).isEmpty }
    if let n = named {
      self.displayName = "\(n.firstName) \(n.lastName)".trimmingCharacters(in: .whitespaces)
    } else if let mail = group.compactMap({ $0.emails.first }).first {
      self.displayName = mail
    } else {
      self.displayName = self.id
    }

    // E-Mails dedup (case-insensitiv), Reihenfolge erhalten.
    var emails: [String] = []; var seenE = Set<String>()
    for c in group { for e in c.emails where !seenE.contains(e.lowercased()) {
      seenE.insert(e.lowercased()); emails.append(e)
    } }
    self.emails = emails

    // Telefone dedup (exakt), Reihenfolge erhalten.
    var phones: [String] = []; var seenP = Set<String>()
    for c in group { for p in c.phones where !seenP.contains(p) {
      seenP.insert(p); phones.append(p)
    } }
    self.phones = phones

    self.sources = Array(Set(group.map { $0.source.type }))
      .sorted { $0.rawValue < $1.rawValue }
  }
}
