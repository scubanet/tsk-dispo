import Foundation

/// Quellneutrale Eingabe zum Erstellen/Bearbeiten eines Kontakts.
public struct ContactDraft: Sendable, Equatable {
  public var kind: ContactKind
  public var firstName: String
  public var lastName: String
  public var organizationName: String
  public var emails: [String]
  public var phones: [String]
  public var addresses: [PostalAddress]
  public var birthday: Date?
  public var languages: [String]
  public var roles: [String]
  public var tags: [String]
  public var notes: String

  public init(kind: ContactKind = .person, firstName: String = "", lastName: String = "",
              organizationName: String = "", emails: [String] = [], phones: [String] = [],
              addresses: [PostalAddress] = [], birthday: Date? = nil, languages: [String] = [],
              roles: [String] = [], tags: [String] = [], notes: String = "") {
    self.kind = kind; self.firstName = firstName; self.lastName = lastName
    self.organizationName = organizationName; self.emails = emails; self.phones = phones
    self.addresses = addresses; self.birthday = birthday; self.languages = languages
    self.roles = roles; self.tags = tags; self.notes = notes
  }

  public var isValid: Bool {
    switch kind {
    case .person:
      return !firstName.trimmingCharacters(in: .whitespaces).isEmpty
          && !lastName.trimmingCharacters(in: .whitespaces).isEmpty
    case .organization:
      return !organizationName.trimmingCharacters(in: .whitespaces).isEmpty
    }
  }
}
