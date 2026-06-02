import Foundation

// Capability-Protokolle. Ein Adapter (Apple/Atoll/…) erfüllt jene, die sein
// Konto laut `Account.capabilities` anbietet. Alle sind `Sendable`, weil der
// Hub sie über Konkurrenz-Grenzen hinweg hält.

/// Liefert Kalendertermine in einem Zeitfenster.
public protocol CalendarProvider: Sendable {
  func events(in interval: DateInterval) async throws -> [UnifiedEvent]
}

/// Liefert E-Mails (jüngste zuerst), begrenzt auf `limit`.
public protocol MailProvider: Sendable {
  func messages(limit: Int) async throws -> [UnifiedMessage]
}

/// Liefert offene/erledigte Aufgaben.
public protocol TodoProvider: Sendable {
  func tasks() async throws -> [UnifiedTask]
}

/// Liefert Kontakte.
public protocol ContactsProvider: Sendable {
  func contacts() async throws -> [UnifiedContact]
}

// — Atoll-spezifische Capabilities —

/// Kombox-Nachrichten (WhatsApp + Mail) für einen Kontakt.
public protocol CommsProvider: Sendable {
  func thread(contactId: String) async throws -> [UnifiedMessage]
}

/// Atoll-Events (Kurse/Termine aus dem CRM).
public protocol EventsProvider: Sendable {
  func atollEvents(in interval: DateInterval) async throws -> [UnifiedEvent]
}

/// Neue Leads aus AtollCard (`card_leads`).
public protocol CardInboxProvider: Sendable {
  func newLeads(limit: Int) async throws -> [Lead]
}
