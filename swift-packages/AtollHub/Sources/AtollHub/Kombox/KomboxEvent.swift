import Foundation

/// Sichtbarer Typ einer Kombox-Zeile (steuert die Darstellung).
public enum KomboxKind: String, Sendable, Equatable, Hashable {
  case whatsapp
  case email
  case system
}

/// Quellneutrales Kombox-Event (eine `contact_events`-Zeile, UI-fertig).
public struct KomboxEvent: Sendable, Identifiable, Equatable, Hashable {
  public let id: String
  public let contactId: String
  public let contactName: String
  public let kind: KomboxKind
  public let direction: MessageDirection?
  public let summary: String
  public let body: String?
  public let subject: String?
  public let timestamp: Date
  public let status: String

  public init(id: String, contactId: String, contactName: String, kind: KomboxKind,
              direction: MessageDirection?, summary: String, body: String?,
              subject: String?, timestamp: Date, status: String) {
    self.id = id; self.contactId = contactId; self.contactName = contactName
    self.kind = kind; self.direction = direction; self.summary = summary
    self.body = body; self.subject = subject; self.timestamp = timestamp; self.status = status
  }
}

/// Eine Konversation = neuestes Event je Kontakt (fuer die Kontaktliste).
public struct KomboxConversation: Sendable, Identifiable, Equatable, Hashable {
  public let id: String
  public let contactName: String
  public let lastEvent: KomboxEvent
  public init(id: String, contactName: String, lastEvent: KomboxEvent) {
    self.id = id; self.contactName = contactName; self.lastEvent = lastEvent
  }
}

/// Eine Tages-Sektion im Verlauf (fuer Tages-Trenner).
public struct KomboxDaySection: Sendable, Identifiable, Equatable {
  public let id: Date
  public let day: Date
  public let events: [KomboxEvent]
  public init(day: Date, events: [KomboxEvent]) {
    self.id = day; self.day = day; self.events = events
  }
}
