import Foundation

/// Atoll OS `persons` row — minimal mirror.
///
/// Lives in the `persons` Supabase table (managed by Atoll OS web), AtollCard
/// only reads. Columns we use: `id`, `first_name`, `last_name`, `email_primary`,
/// `phone_primary`, `languages`, `padi_member_number`. Anything else is
/// fetched on demand by the cards that need it.
public struct Person: Identifiable, Hashable, Sendable, Codable {
  public let id: UUID
  public var firstName: String
  public var lastName: String
  public var emailPrimary: String?
  public var phonePrimary: String?
  public var languages: [String]
  public var padiMemberNumber: String?
  public var avatarColorHex: String?

  public init(
    id: UUID,
    firstName: String,
    lastName: String,
    emailPrimary: String? = nil,
    phonePrimary: String? = nil,
    languages: [String] = [],
    padiMemberNumber: String? = nil,
    avatarColorHex: String? = nil
  ) {
    self.id = id
    self.firstName = firstName
    self.lastName = lastName
    self.emailPrimary = emailPrimary
    self.phonePrimary = phonePrimary
    self.languages = languages
    self.padiMemberNumber = padiMemberNumber
    self.avatarColorHex = avatarColorHex
  }

  public var fullName: String { "\(firstName) \(lastName)" }

  public var initials: String {
    let f = firstName.first.map(String.init) ?? ""
    let l = lastName.first.map(String.init) ?? ""
    return (f + l).uppercased()
  }

  enum CodingKeys: String, CodingKey {
    case id
    case firstName = "first_name"
    case lastName  = "last_name"
    case emailPrimary = "email_primary"
    case phonePrimary = "phone_primary"
    case languages
    case padiMemberNumber = "padi_member_number"
    case avatarColorHex   = "avatar_color"
  }
}
