import Foundation
import Observation
import AtollCore
import Supabase
import OSLog

/// Eine AtollCard-Lead-Zeile (read-only). Quelle: v_card_leads_inbox / card_leads.
struct CardLead: Identifiable, Decodable, Sendable {
  let id: String
  let firstName: String?
  let lastName: String?
  let email: String?
  let phone: String?
  let message: String?
  let topic: String?
  let status: String?
  let capturedAt: String?
  let importedContactId: String?
  let cardTitle: String?
  enum CodingKeys: String, CodingKey {
    case id
    case firstName = "first_name"
    case lastName = "last_name"
    case email, phone, message, topic, status
    case capturedAt = "captured_at"
    case importedContactId = "imported_contact_id"
    case cardTitle = "card_title"
  }
  var displayName: String {
    let n = "\(firstName ?? "") \(lastName ?? "")".trimmingCharacters(in: .whitespaces)
    return n.isEmpty ? (email ?? phone ?? "Lead") : n
  }
  var isImported: Bool { importedContactId != nil }

  /// `captured_at` (ISO 8601) als "dd.MM.yyyy" — leer, wenn nicht parsebar.
  var capturedDateText: String {
    guard let raw = capturedAt else { return "" }
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let date = iso.date(from: raw) ?? {
      let iso2 = ISO8601DateFormatter()
      iso2.formatOptions = [.withInternetDateTime]
      return iso2.date(from: raw)
    }()
    guard let date else { return "" }
    let out = DateFormatter()
    out.dateFormat = "dd.MM.yyyy"
    out.locale = Locale(identifier: "de_CH")
    out.timeZone = TimeZone(identifier: "Europe/Zurich")
    return out.string(from: date)
  }
}

@MainActor
@Observable
final class CardInboxStore {
  private(set) var leads: [CardLead] = []
  private(set) var loading = false
  private let supabase = SupabaseClient.shared
  private let logger = Logger(subsystem: "swiss.atoll.hub", category: "cardinbox")

  /// Anzahl noch nicht importierter Leads (fuers Heute-Widget / Badge).
  var newCount: Int { leads.filter { !$0.isImported }.count }

  func reload() async {
    loading = true
    do {
      leads = try await supabase
        .from("v_card_leads_inbox")
        .select("id, first_name, last_name, email, phone, message, topic, status, captured_at, imported_contact_id, card_title")
        .order("captured_at", ascending: false)
        .limit(200)
        .execute()
        .value
    } catch {
      logger.error("cardinbox reload failed: \(error.localizedDescription, privacy: .public)")
    }
    loading = false
  }
}
