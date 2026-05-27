import Foundation

/// A lead captured via the public card page on Atoll OS web.
///
/// When someone scans a QR code, the public page lets them leave their
/// contact details + an optional message ("IDC 2026 Anfrage", "Trial Dive
/// Anfrage"). Those rows land in `card_leads` and push-notify the card owner.
///
/// `importedToAddressBook` flips to true once Atoll OS reconciles the lead
/// into a `persons` row.
public struct Lead: Identifiable, Hashable, Sendable, Codable {
  public let id: UUID
  public let cardId: UUID
  public var firstName: String
  public var lastName: String?
  public var email: String?
  public var phone: String?
  public var message: String?
  /// "IDC 2026 Anfrage" / "Trial Dive" / "Divemaster Q&A" — short scenario tag
  /// the user chooses on the public form.
  public var topic: String?
  /// Free-form custom answers from optional form fields (jsonb on DB).
  public var customAnswers: [String: String]
  public var capturedAt: Date
  public var ipCountry: String?
  public var importedToAddressBook: Bool
  public var status: LeadStatus
  public var avatarColorHex: String?

  public init(
    id: UUID,
    cardId: UUID,
    firstName: String,
    lastName: String? = nil,
    email: String? = nil,
    phone: String? = nil,
    message: String? = nil,
    topic: String? = nil,
    customAnswers: [String: String] = [:],
    capturedAt: Date = .now,
    ipCountry: String? = nil,
    importedToAddressBook: Bool = false,
    status: LeadStatus = .new,
    avatarColorHex: String? = nil
  ) {
    self.id = id
    self.cardId = cardId
    self.firstName = firstName
    self.lastName = lastName
    self.email = email
    self.phone = phone
    self.message = message
    self.topic = topic
    self.customAnswers = customAnswers
    self.capturedAt = capturedAt
    self.ipCountry = ipCountry
    self.importedToAddressBook = importedToAddressBook
    self.status = status
    self.avatarColorHex = avatarColorHex
  }

  public var fullName: String {
    [firstName, lastName].compactMap { $0?.isEmpty == true ? nil : $0 }.joined(separator: " ")
  }

  public var initials: String {
    let f = firstName.first.map(String.init) ?? ""
    let l = lastName?.first.map(String.init) ?? ""
    return (f + l).uppercased()
  }

  enum CodingKeys: String, CodingKey {
    case id
    case cardId = "card_id"
    case firstName = "first_name"
    case lastName  = "last_name"
    case email, phone, message, topic
    case customAnswers = "custom_answers"
    case capturedAt    = "captured_at"
    case ipCountry     = "ip_country"
    case importedToAddressBook = "imported_to_address_book"
    case status
    case avatarColorHex = "avatar_color"
  }
}

public enum LeadStatus: String, Codable, Sendable, CaseIterable {
  case new        // never opened
  case opened
  case contacted
  case imported   // → persons row created
  case archived
  case spam
}
