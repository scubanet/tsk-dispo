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
  public var firstName: String?
  public var lastName: String?
  public var kind: ContactKind
  public var organizationName: String?
  public var addresses: [PostalAddress]
  public var birthday: Date?
  public var languages: [String]
  public var roles: [String]
  public var tags: [String]
  public var notes: String?

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

    // Rich-Felder aus den Mitgliedern ableiten (Atoll bevorzugt als Primaerquelle).
    let primary = group.first { $0.source.type == .atoll } ?? group.first
    self.firstName = group.compactMap { $0.firstName.isEmpty ? nil : $0.firstName }.first
    self.lastName = group.compactMap { $0.lastName.isEmpty ? nil : $0.lastName }.first
    self.kind = primary?.kind ?? .person
    self.organizationName = group.compactMap { $0.organizationName }.first
    self.addresses = group.flatMap { $0.addresses }
    self.birthday = group.compactMap { $0.birthday }.first
    self.languages = Array(Set(group.flatMap { $0.languages })).sorted()
    self.roles = Array(Set(group.flatMap { $0.roles })).sorted()
    self.tags = Array(Set(group.flatMap { $0.tags })).sorted()
    self.notes = group.compactMap { ($0.notes?.isEmpty == false) ? $0.notes : nil }.first
  }
}
