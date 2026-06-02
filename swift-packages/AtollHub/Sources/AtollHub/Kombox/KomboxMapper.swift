import Foundation

/// Uebersetzt `contact_events`-Wire-Zeilen in quellneutrale `KomboxEvent`s.
public enum KomboxMapper {
  public static func events(from rows: [KomboxEventRow]) -> [KomboxEvent] {
    rows.compactMap { row in
      guard let ts = parseTimestamp(row.occurredAt) else { return nil }
      let kind: KomboxKind
      switch row.eventType {
      case "whatsapp_log":   kind = .whatsapp
      case "email_external": kind = .email
      default:               kind = .system
      }
      let direction: MessageDirection?
      switch row.payload?.direction {
      case "inbound":  direction = .inbound
      case "outbound": direction = .outbound
      default:         direction = nil
      }
      return KomboxEvent(
        id: row.id, contactId: row.contactId,
        contactName: contactName(row.contacts, fallback: row.contactId),
        kind: kind, direction: direction,
        summary: row.summary, body: row.body, subject: row.payload?.subject,
        timestamp: ts, status: row.status
      )
    }
  }

  static func contactName(_ c: KomboxContactRef?, fallback: String) -> String {
    guard let c else { return fallback }
    if c.kind == "organization" {
      let n = (c.tradingName ?? c.legalName ?? "").trimmingCharacters(in: .whitespaces)
      return n.isEmpty ? fallback : n
    }
    let n = "\(c.firstName ?? "") \(c.lastName ?? "")".trimmingCharacters(in: .whitespaces)
    return n.isEmpty ? fallback : n
  }

  static func parseTimestamp(_ s: String) -> Date? {
    let withFraction = ISO8601DateFormatter()
    withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = withFraction.date(from: s) { return d }
    let plain = ISO8601DateFormatter()
    plain.formatOptions = [.withInternetDateTime]
    return plain.date(from: s)
  }
}
