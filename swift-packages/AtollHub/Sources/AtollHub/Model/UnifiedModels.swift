import Foundation

/// Verweis auf die Quelle (Konto) eines Datensatzes — der „source"-Tag.
public struct AccountRef: Sendable, Equatable, Hashable {
  public let accountId: String
  public let type: AccountType
  public init(accountId: String, type: AccountType) {
    self.accountId = accountId
    self.type = type
  }
}

/// Kanal einer Nachricht in der Kombox.
public enum MessageChannel: String, Sendable, CaseIterable {
  case mail
  case whatsapp
}

/// Richtung einer Nachricht.
public enum MessageDirection: String, Sendable {
  case inbound
  case outbound
}

/// Quellneutraler Kalendertermin (Apple, Atoll, später Google/MS).
public struct UnifiedEvent: Sendable, Identifiable, Equatable, Hashable {
  public let id: String
  public let source: AccountRef
  public let title: String
  public let start: Date
  public let end: Date
  public let isAllDay: Bool
  public let location: String?
  public let calendarId: String?
  public let colorHex: String?

  public init(id: String, source: AccountRef, title: String, start: Date,
              end: Date, isAllDay: Bool, location: String?,
              calendarId: String? = nil, colorHex: String? = nil) {
    self.id = id; self.source = source; self.title = title
    self.start = start; self.end = end; self.isAllDay = isAllDay
    self.location = location; self.calendarId = calendarId; self.colorHex = colorHex
  }
}

/// Quellneutrale Nachricht (Mail/WhatsApp) für die Kombox.
public struct UnifiedMessage: Sendable, Identifiable, Equatable, Hashable {
  public let id: String
  public let source: AccountRef
  public let channel: MessageChannel
  public let direction: MessageDirection
  public let contactName: String?
  public let preview: String
  public let timestamp: Date
  public let isUnread: Bool
  public init(id: String, source: AccountRef, channel: MessageChannel,
              direction: MessageDirection, contactName: String?, preview: String,
              timestamp: Date, isUnread: Bool) {
    self.id = id; self.source = source; self.channel = channel
    self.direction = direction; self.contactName = contactName
    self.preview = preview; self.timestamp = timestamp; self.isUnread = isUnread
  }
}

/// Quellneutrale Aufgabe (Apple Erinnerungen / Atoll-Tasks).
public struct UnifiedTask: Sendable, Identifiable, Equatable, Hashable {
  public let id: String
  public let source: AccountRef
  public let title: String
  public let due: Date?
  public let isDone: Bool
  public let listName: String?
  public let listColorHex: String?
  public let isFlagged: Bool
  public let priority: Int        // 0 = keine
  public let notes: String?

  public init(id: String, source: AccountRef, title: String, due: Date?, isDone: Bool,
              listName: String? = nil, listColorHex: String? = nil,
              isFlagged: Bool = false, priority: Int = 0, notes: String? = nil) {
    self.id = id; self.source = source; self.title = title
    self.due = due; self.isDone = isDone
    self.listName = listName; self.listColorHex = listColorHex
    self.isFlagged = isFlagged; self.priority = priority; self.notes = notes
  }
}

public extension UnifiedTask {
  /// Kopie mit geaendertem Erledigt-Status (fuer optimistische Updates).
  func withDone(_ done: Bool) -> UnifiedTask {
    UnifiedTask(id: id, source: source, title: title, due: due, isDone: done,
                listName: listName, listColorHex: listColorHex, isFlagged: isFlagged,
                priority: priority, notes: notes)
  }
}

/// Art eines Kontakts: natuerliche Person oder Organisation.
public enum ContactKind: String, Sendable, Codable, Equatable { case person, organization }

/// Quellneutrale Postanschrift.
public struct PostalAddress: Sendable, Equatable, Hashable, Codable {
  public var street: String?
  public var postalCode: String?
  public var city: String?
  public var region: String?
  public var country: String?
  public var label: String?
  public init(street: String? = nil, postalCode: String? = nil, city: String? = nil,
              region: String? = nil, country: String? = nil, label: String? = nil) {
    self.street = street; self.postalCode = postalCode; self.city = city
    self.region = region; self.country = country; self.label = label
  }
  public var oneLine: String {
    [street, [postalCode, city].compactMap { $0 }.joined(separator: " "), country]
      .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
  }
}

/// Quellneutraler Kontakt (Atoll-CRM / Apple-Kontakte).
public struct UnifiedContact: Sendable, Identifiable, Equatable, Hashable {
  public let id: String
  public let source: AccountRef
  public let firstName: String
  public let lastName: String
  public let emails: [String]
  public let phones: [String]
  public var kind: ContactKind
  public var organizationName: String?
  public var addresses: [PostalAddress]
  public var birthday: Date?
  public var languages: [String]
  public var roles: [String]
  public var tags: [String]
  public var notes: String?
  public init(id: String, source: AccountRef, firstName: String, lastName: String,
              emails: [String], phones: [String],
              kind: ContactKind = .person, organizationName: String? = nil,
              addresses: [PostalAddress] = [], birthday: Date? = nil,
              languages: [String] = [], roles: [String] = [],
              tags: [String] = [], notes: String? = nil) {
    self.id = id; self.source = source; self.firstName = firstName
    self.lastName = lastName; self.emails = emails; self.phones = phones
    self.kind = kind; self.organizationName = organizationName
    self.addresses = addresses; self.birthday = birthday
    self.languages = languages; self.roles = roles
    self.tags = tags; self.notes = notes
  }
}

/// Neuer Lead aus AtollCard (`card_leads`) für die CardInbox.
public struct Lead: Sendable, Identifiable, Equatable, Hashable {
  public let id: String
  public let name: String
  public let createdAt: Date
  public let email: String?
  public let phone: String?
  public init(id: String, name: String, createdAt: Date, email: String?, phone: String?) {
    self.id = id; self.name = name; self.createdAt = createdAt
    self.email = email; self.phone = phone
  }
}
