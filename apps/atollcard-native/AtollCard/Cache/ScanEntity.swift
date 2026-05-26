import Foundation
import SwiftData

/// SwiftData mirror of `Scan`. `source` and `fieldTapped` are stored as raw
/// string values of their respective enums to survive enum-case renames.
///
/// See `CacheConverters.swift` for `Scan` ↔ `ScanEntity` bridging.
@Model
final class ScanEntity {
  @Attribute(.unique) var id: UUID
  var cardId:                 UUID
  var scannedAt:              Date
  var source:                 String        // Scan.Source.rawValue: 'qr' / 'nfc' / 'airdrop' / 'imessage' / 'wallet' / 'direct'
  var ipCountry:              String?
  var userAgent:              String?
  var convertedToLead:        Bool
  var fieldTapped:            String?       // Scan.TappedField.rawValue
  var lastFetched:            Date

  init(id: UUID, cardId: UUID, scannedAt: Date, source: String, ipCountry: String?,
       userAgent: String?, convertedToLead: Bool, fieldTapped: String?, lastFetched: Date) {
    self.id = id; self.cardId = cardId
    self.scannedAt = scannedAt; self.source = source
    self.ipCountry = ipCountry; self.userAgent = userAgent
    self.convertedToLead = convertedToLead
    self.fieldTapped = fieldTapped
    self.lastFetched = lastFetched
  }
}
