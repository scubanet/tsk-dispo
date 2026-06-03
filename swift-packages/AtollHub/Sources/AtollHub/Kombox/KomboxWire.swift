import Foundation

public struct KomboxPayload: Decodable, Sendable {
  public let direction: String?
  public let subject: String?
}

public struct KomboxContactRef: Decodable, Sendable {
  public let id: String
  public let kind: String?
  public let firstName: String?
  public let lastName: String?
  public let tradingName: String?
  public let legalName: String?
  enum CodingKeys: String, CodingKey {
    case id, kind
    case firstName = "first_name"
    case lastName = "last_name"
    case tradingName = "trading_name"
    case legalName = "legal_name"
  }
}

public struct KomboxEventRow: Decodable, Sendable {
  public let id: String
  public let contactId: String
  public let eventType: String
  public let occurredAt: String
  public let summary: String
  public let body: String?
  public let payload: KomboxPayload?
  public let status: String
  public let contacts: KomboxContactRef?
  enum CodingKeys: String, CodingKey {
    case id, summary, body, payload, status, contacts
    case contactId = "contact_id"
    case eventType = "event_type"
    case occurredAt = "occurred_at"
  }
}
