import Foundation

/// Ein JSONB-E-Mail-Eintrag aus `contacts.emails`.
public struct AtollEmail: Decodable, Sendable {
  public let email: String?
}

/// Ein JSONB-Telefon-Eintrag aus `contacts.phones`.
public struct AtollPhone: Decodable, Sendable {
  public let e164: String?
}

/// Wire-Format einer `contacts`-Row (Subset, das ComHub Phase 1 liest).
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

  enum CodingKeys: String, CodingKey {
    case id, kind, emails, phones
    case firstName = "first_name"
    case lastName = "last_name"
    case tradingName = "trading_name"
    case legalName = "legal_name"
    case primaryEmail = "primary_email"
  }
}

/// Uebersetzt `contacts`-Rows in quellneutrale `UnifiedContact`s.
public enum AtollContactMapper {
  public static func contacts(from rows: [AtollContactRow],
                              accountId: String) -> [UnifiedContact] {
    let ref = AccountRef(accountId: accountId, type: .atoll)
    return rows.map { row in
      // Namens-Aufloesung: Organisationen tragen den Anzeigenamen im lastName-Slot.
      let first: String
      let last: String
      if row.kind == "organization" {
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

      return UnifiedContact(
        id: "atoll:\(row.id)", source: ref,
        firstName: first, lastName: last, emails: emails, phones: phones
      )
    }
  }
}
