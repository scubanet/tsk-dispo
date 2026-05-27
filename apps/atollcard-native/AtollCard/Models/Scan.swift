import Foundation

/// A single scan event — when someone resolves a card URL via QR / NFC / direct.
///
/// Maps to `card_scans`. The web page logs one row per visit and falls back
/// to `Scan.source = .direct` if no UTM tag is present.
public struct Scan: Identifiable, Hashable, Sendable, Codable {
  public let id: UUID
  public let cardId: UUID
  public var scannedAt: Date
  public var source: Source
  public var ipCountry: String?
  public var userAgent: String?
  public var convertedToLead: Bool
  /// Which CTA the visitor tapped on the public page (email / phone / whatsapp
  /// / message-form). Empty if they only viewed.
  public var fieldTapped: TappedField?

  public init(
    id: UUID,
    cardId: UUID,
    scannedAt: Date,
    source: Source,
    ipCountry: String? = nil,
    userAgent: String? = nil,
    convertedToLead: Bool = false,
    fieldTapped: TappedField? = nil
  ) {
    self.id = id
    self.cardId = cardId
    self.scannedAt = scannedAt
    self.source = source
    self.ipCountry = ipCountry
    self.userAgent = userAgent
    self.convertedToLead = convertedToLead
    self.fieldTapped = fieldTapped
  }

  public enum Source: String, Codable, Sendable {
    case qr
    case nfc
    case airdrop
    case imessage
    case wallet
    case direct
  }

  public enum TappedField: String, Codable, Sendable, CaseIterable {
    case email, phone, whatsapp, instagram, linkedin, website, leadForm
  }

  enum CodingKeys: String, CodingKey {
    case id
    case cardId = "card_id"
    case scannedAt = "scanned_at"
    case source
    case ipCountry = "ip_country"
    case userAgent = "user_agent"
    case convertedToLead = "converted_to_lead"
    case fieldTapped = "field_tapped"
  }
}
