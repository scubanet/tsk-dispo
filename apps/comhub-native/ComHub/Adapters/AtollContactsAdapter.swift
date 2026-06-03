import Foundation
import AtollCore
import AtollHub
import Supabase

/// Erfuellt `ContactsProvider` ueber die Atoll-`contacts`-Tabelle. RLS ist fuer
/// `contacts` permissiv (alle authentifizierten Nutzer lesen alle Kontakte);
/// wir filtern auf aktive, nicht zusammengefuehrte Personen/Orgs. Spaltenliste
/// gespiegelt vom Web-`contactQueries.ts` (Subset).
struct AtollContactsAdapter: ContactsProvider {
  let accountId: String
  let pageSize: Int
  private let supabase = SupabaseClient.shared

  /// Spaltenliste fuer Lese- und Schreib-Pfad (Schreiben gibt die erzeugte/
  /// aktualisierte Row reich zurueck, damit der gemappte Kontakt vollstaendig ist).
  private static let selectColumns =
    "id, kind, first_name, last_name, trading_name, legal_name, primary_email, emails, phones, birth_date, addresses, languages, roles, tags, notes"

  init(accountId: String = "atoll", pageSize: Int = 1000) {
    self.accountId = accountId
    self.pageSize = pageSize
  }

  func contacts() async throws -> [UnifiedContact] {
    let rows: [AtollContactRow] = try await supabase
      .from("contacts")
      .select(Self.selectColumns)
      .is("archived_at", value: nil as Bool?)
      .is("merged_into_id", value: nil as Bool?)
      .order("last_name", ascending: true)
      .limit(pageSize)
      .execute()
      .value

    return AtollContactMapper.contacts(from: rows, accountId: accountId)
  }

  // MARK: – Schreiben (Phase-7)

  private struct AddrJSON: Encodable {
    let label: String?; let street: String?; let postal: String?
    let city: String?; let country: String?
  }

  /// Schreib-Row fuer `contacts`. `display_name` ist GENERATED und wird nicht
  /// gesetzt; `created_by`/`owner_id` bleiben unbestimmt (nullable).
  private struct ContactWrite: Encodable {
    let kind: String
    let first_name: String?
    let last_name: String?
    let legal_name: String?
    let trading_name: String?
    let primary_email: String?
    let emails: [[String: String]]
    let phones: [[String: String]]
    let addresses: [AddrJSON]
    let languages: [String]
    let roles: [String]
    let tags: [String]
    let birth_date: String?
    let notes: String?
  }

  private static let birthFmt: DateFormatter = {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: "Europe/Zurich")
    f.dateFormat = "yyyy-MM-dd"
    return f
  }()

  private func write(from d: ContactDraft) -> ContactWrite {
    let isOrg = d.kind == .organization
    return ContactWrite(
      kind: d.kind.rawValue,
      first_name: isOrg ? nil : d.firstName,
      last_name: isOrg ? nil : d.lastName,
      legal_name: isOrg ? d.organizationName : nil,
      trading_name: nil,
      primary_email: d.emails.first,
      emails: d.emails.map { ["email": $0] },
      phones: d.phones.map { ["e164": $0] },
      addresses: d.addresses.map {
        AddrJSON(label: $0.label, street: $0.street, postal: $0.postalCode,
                 city: $0.city, country: $0.country)
      },
      languages: d.languages, roles: d.roles, tags: d.tags,
      birth_date: d.birthday.map { Self.birthFmt.string(from: $0) },
      notes: d.notes.isEmpty ? nil : d.notes)
  }

  func createContact(_ draft: ContactDraft) async throws -> UnifiedContact {
    let rows: [AtollContactRow] = try await supabase
      .from("contacts")
      .insert(write(from: draft))
      .select(Self.selectColumns)
      .execute()
      .value
    guard let row = rows.first else {
      throw ProviderWriteError.invalid("insert lieferte keine Zeile")
    }
    return AtollContactMapper.contacts(from: [row], accountId: accountId)[0]
  }

  func updateContact(id: String, with draft: ContactDraft) async throws -> UnifiedContact {
    let rowId = SourceID.raw(from: id)
    let rows: [AtollContactRow] = try await supabase
      .from("contacts")
      .update(write(from: draft))
      .eq("id", value: rowId)
      .select(Self.selectColumns)
      .execute()
      .value
    guard let row = rows.first else { throw ProviderWriteError.notFound }
    return AtollContactMapper.contacts(from: [row], accountId: accountId)[0]
  }

  /// Soft-Archiv: setzt `archived_at = now()`. `contacts()` filtert auf
  /// `archived_at IS NULL`, der Kontakt verschwindet so reversibel aus dem Adressbuch.
  func deleteContact(id: String) async throws {
    let rowId = SourceID.raw(from: id)
    struct Archive: Encodable { let archived_at: String }
    let iso = ISO8601DateFormatter(); iso.formatOptions = [.withInternetDateTime]
    _ = try await supabase.from("contacts")
      .update(Archive(archived_at: iso.string(from: Date())))
      .eq("id", value: rowId)
      .execute()
  }
}
