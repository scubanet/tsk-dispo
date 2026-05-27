import Foundation

/// A physical NFC tag that's been programmed with a card URL.
///
/// Maps to `nfc_tags`. The app writes one row per successful Core NFC write
/// so the user can later see "Tag #3" was written for the CD card and is
/// stuck on the desk in Dauin.
public struct NFCTag: Identifiable, Hashable, Sendable, Codable {
  public let id: UUID
  public let cardId: UUID
  public var tagUID: String            // hex string of the tag's UID
  public var label: String?            // user-supplied: "Schreibtisch Dauin"
  public var writtenAt: Date
  public var lastSeenAt: Date?         // if we ever read it back later

  public init(
    id: UUID,
    cardId: UUID,
    tagUID: String,
    label: String? = nil,
    writtenAt: Date = .now,
    lastSeenAt: Date? = nil
  ) {
    self.id = id
    self.cardId = cardId
    self.tagUID = tagUID
    self.label = label
    self.writtenAt = writtenAt
    self.lastSeenAt = lastSeenAt
  }

  enum CodingKeys: String, CodingKey {
    case id
    case cardId = "card_id"
    case tagUID = "tag_uid"
    case label
    case writtenAt = "written_at"
    case lastSeenAt = "last_seen_at"
  }
}
