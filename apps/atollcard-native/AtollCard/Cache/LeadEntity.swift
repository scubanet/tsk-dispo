import Foundation
import SwiftData

/// SwiftData mirror of `Lead`. `status` is stored as the `LeadStatus.rawValue`
/// string so the column survives enum-case renames; `customAnswersJSON`
/// captures the free-form jsonb column from `card_leads`.
///
/// See `CacheConverters.swift` for `Lead` ↔ `LeadEntity` bridging.
@Model
final class LeadEntity {
  @Attribute(.unique) var id: UUID
  var cardId:                 UUID
  var firstName:              String
  var lastName:               String?
  var email:                  String?
  var phone:                  String?
  var message:                String?
  var topic:                  String?
  var customAnswersJSON:      String        // Codable round-tripped [String:String]
  var capturedAt:             Date
  var ipCountry:              String?
  var status:                 String        // LeadStatus.rawValue
  var avatarColorHex:         String?
  var importedToAddressBook:  Bool
  var lastFetched:            Date

  init(id: UUID, cardId: UUID, firstName: String, lastName: String?, email: String?,
       phone: String?, message: String?, topic: String?, customAnswersJSON: String,
       capturedAt: Date, ipCountry: String?, status: String, avatarColorHex: String?,
       importedToAddressBook: Bool, lastFetched: Date) {
    self.id = id; self.cardId = cardId
    self.firstName = firstName; self.lastName = lastName
    self.email = email; self.phone = phone
    self.message = message; self.topic = topic
    self.customAnswersJSON = customAnswersJSON
    self.capturedAt = capturedAt; self.ipCountry = ipCountry
    self.status = status
    self.avatarColorHex = avatarColorHex
    self.importedToAddressBook = importedToAddressBook
    self.lastFetched = lastFetched
  }
}
