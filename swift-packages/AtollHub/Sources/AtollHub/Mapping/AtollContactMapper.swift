import Foundation

/// Ein JSONB-E-Mail-Eintrag aus `contacts.emails`.
public struct AtollEmail: Decodable, Sendable {
  public let email: String?
}

/// Ein JSONB-Telefon-Eintrag aus `contacts.phones`.
public struct AtollPhone: Decodable, Sendable {
  public let e164: String?
}

/// Ein JSONB-Adress-Eintrag aus `contacts.addresses`. Die kanonische Form
/// (siehe `AddressJsonbEntry` im Web sowie die Sync-Trigger 0082/0083)
/// nutzt `street`/`postal`/`city`/`country`/`label`. Wir decodieren tolerant:
/// `postal` ODER `postal_code`, `region` ist optional. Alles optional, damit
/// eine fehlerhafte/leere Adresse nicht die ganze Abfrage kippt.
public struct AtollAddress: Decodable, Sendable {
  public let street: String?
  public let postal: String?
  public let postalCode: String?
  public let city: String?
  public let region: String?
  public let country: String?
  public let label: String?

  enum CodingKeys: String, CodingKey {
    case street, postal, city, region, country, label
    case postalCode = "postal_code"
  }

  /// Vereinheitlichte PLZ: `postal` bevorzugt, sonst `postal_code`.
  public var resolvedPostalCode: String? { postal ?? postalCode }
}

/// Wire-Format einer `contacts`-Row (das Subset, das ComHub liest — inkl. der
/// reichen Felder fuer das vereinheitlichte Adressbuch).
public struct AtollContactRow: Decodable, Sendable {
  public let id: String
  public let kind: String?
  public let firstName: String?
  public let lastName: String?
  public let tradingName: String?
  public let legalName: String?
  public let primaryEmail: String?
  public let emails: [AtollEmail]?
  public let phones: [AtollPhone]?
  public let addresses: [AtollAddress]?
  public let birthDate: String?
  public let languages: [String]?
  public let roles: [String]?
  public let tags: [String]?
  public let notes: String?

  enum CodingKeys: String, CodingKey {
    case id, kind, emails, phones, addresses, languages, roles, tags, notes
    case firstName = "first_name"
    case lastName = "last_name"
    case tradingName = "trading_name"
    case legalName = "legal_name"
    case primaryEmail = "primary_email"
    case birthDate = "birth_date"
  }
}

/// Uebersetzt `contacts`-Rows in quellneutrale `UnifiedContact`s.
public enum AtollContactMapper {
  /// `birth_date` aus Postgres ist ein reines Datum (`yyyy-MM-dd`). Wir parsen
  /// es in Europe/Zurich mit POSIX-Locale, damit es lokale-unabhaengig bleibt.
  private static let birthDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: "Europe/Zurich")
    f.dateFormat = "yyyy-MM-dd"
    return f
  }()

  public static func contacts(from rows: [AtollContactRow],
                              accountId: String) -> [UnifiedContact] {
    let ref = AccountRef(accountId: accountId, type: .atoll)
    return rows.map { row in
      let isOrg = (row.kind == "organization" || row.kind == "company")

      // Namens-Aufloesung: Organisationen tragen den Anzeigenamen im lastName-Slot.
      let first: String
      let last: String
      if isOrg {
        first = ""
        last = (row.tradingName ?? row.legalName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      } else {
        first = (row.firstName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        last = (row.lastName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      }

      // E-Mails: primary_email zuerst, dann Array — dedup unter Erhalt der Reihenfolge.
      var emails: [String] = []
      var seenEmail = Set<String>()
      func addEmail(_ raw: String?) {
        let v = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !v.isEmpty, !seenEmail.contains(v.lowercased()) else { return }
        seenEmail.insert(v.lowercased()); emails.append(v)
      }
      addEmail(row.primaryEmail)
      (row.emails ?? []).forEach { addEmail($0.email) }

      var phones: [String] = []
      var seenPhone = Set<String>()
      func addPhone(_ raw: String?) {
        let v = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !v.isEmpty, !seenPhone.contains(v) else { return }
        seenPhone.insert(v); phones.append(v)
      }
      (row.phones ?? []).forEach { addPhone($0.e164) }

      // Firmenname: trading_name bevorzugt, sonst legal_name; nil wenn beides leer.
      let orgNameRaw = (row.tradingName ?? row.legalName)?
        .trimmingCharacters(in: .whitespacesAndNewlines)
      let organizationName = (orgNameRaw?.isEmpty == false) ? orgNameRaw : nil

      // Adressen: tolerant gemappt; leere Eintraege bleiben erhalten (Felder optional).
      let addresses: [PostalAddress] = (row.addresses ?? []).map { a in
        PostalAddress(
          street: a.street, postalCode: a.resolvedPostalCode, city: a.city,
          region: a.region, country: a.country, label: a.label
        )
      }

      let birthday: Date? = row.birthDate
        .flatMap { $0.isEmpty ? nil : birthDateFormatter.date(from: $0) }

      return UnifiedContact(
        id: "atoll:\(row.id)", source: ref,
        firstName: first, lastName: last, emails: emails, phones: phones,
        kind: isOrg ? .organization : .person,
        organizationName: organizationName,
        addresses: addresses,
        birthday: birthday,
        languages: row.languages ?? [],
        roles: row.roles ?? [],
        tags: row.tags ?? [],
        notes: row.notes
      )
    }
  }
}
