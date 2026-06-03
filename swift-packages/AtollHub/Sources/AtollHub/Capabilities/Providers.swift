import Foundation

// Capability-Protokolle. Ein Adapter (Apple/Atoll/…) erfüllt jene, die sein
// Konto laut `Account.capabilities` anbietet. Alle sind `Sendable`, weil der
// Hub sie über Konkurrenz-Grenzen hinweg hält.

/// Liefert Kalendertermine in einem Zeitfenster.
public protocol CalendarProvider: Sendable {
  func events(in interval: DateInterval) async throws -> [UnifiedEvent]
  // Schreib-Anforderungen (Default in Extension) — als Requirement deklariert,
  // damit der Hub ueber das Existential dynamisch auf die echte Impl dispatcht.
  func createEvent(_ draft: EventDraft) async throws -> UnifiedEvent
  func updateEvent(id: String, with draft: EventDraft) async throws -> UnifiedEvent
  func deleteEvent(id: String) async throws
}

/// Liefert E-Mails (jüngste zuerst), begrenzt auf `limit`.
public protocol MailProvider: Sendable {
  func messages(limit: Int) async throws -> [UnifiedMessage]
}

/// Liefert offene/erledigte Aufgaben.
public protocol TodoProvider: Sendable {
  func tasks() async throws -> [UnifiedTask]
  // Schreib-Anforderungen (Default in Extension) — als Requirement deklariert,
  // damit der Hub ueber das Existential dynamisch auf die echte Impl dispatcht.
  func setDone(taskId: String, isDone: Bool) async throws
  func createTask(title: String, due: Date?, listId: String?) async throws
  func updateTask(id: String, title: String, due: Date?, listId: String?) async throws
}

/// Liefert Kontakte.
public protocol ContactsProvider: Sendable {
  func contacts() async throws -> [UnifiedContact]
  // Schreib-Anforderungen (Default in Extension) — als Requirement deklariert,
  // damit der Hub ueber das Existential dynamisch auf die echte Impl dispatcht.
  func createContact(_ draft: ContactDraft) async throws -> UnifiedContact
  func updateContact(id: String, with draft: ContactDraft) async throws -> UnifiedContact
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

// — Schreib-Oberflaeche (Phase-5a) —

/// Fehler, wenn ein Provider eine Schreib-Operation nicht unterstuetzt.
public enum ProviderWriteError: Error, Sendable, Equatable {
  case unsupported            // dieser Provider kann das nicht (Default)
  case notFound               // Ziel-Objekt (Task/Event) nicht gefunden
  case invalid(String)        // ungueltige Eingabe
}

public extension TodoProvider {
  /// Schaltet den Erledigt-Status einer Aufgabe um. Default: nicht unterstuetzt.
  func setDone(taskId: String, isDone: Bool) async throws {
    throw ProviderWriteError.unsupported
  }
  /// Legt eine neue Aufgabe an (Liste optional). Default: nicht unterstuetzt.
  func createTask(title: String, due: Date?, listId: String?) async throws {
    throw ProviderWriteError.unsupported
  }
  /// Aendert Titel/Faelligkeit/Liste einer Aufgabe. Default: nicht unterstuetzt.
  func updateTask(id: String, title: String, due: Date?, listId: String?) async throws {
    throw ProviderWriteError.unsupported
  }
}

public extension ContactsProvider {
  /// Erstellt einen Kontakt und liefert ihn quellneutral zurueck. Default: nicht unterstuetzt.
  func createContact(_ draft: ContactDraft) async throws -> UnifiedContact {
    throw ProviderWriteError.unsupported
  }
  /// Aktualisiert einen Kontakt (per UnifiedContact.id). Default: nicht unterstuetzt.
  func updateContact(id: String, with draft: ContactDraft) async throws -> UnifiedContact {
    throw ProviderWriteError.unsupported
  }
}

public extension CalendarProvider {
  /// Erstellt einen Termin und liefert ihn quellneutral zurueck. Default: nicht unterstuetzt.
  func createEvent(_ draft: EventDraft) async throws -> UnifiedEvent {
    throw ProviderWriteError.unsupported
  }
  /// Aktualisiert einen Termin (per UnifiedEvent.id). Default: nicht unterstuetzt.
  func updateEvent(id: String, with draft: EventDraft) async throws -> UnifiedEvent {
    throw ProviderWriteError.unsupported
  }
  /// Loescht einen Termin (per UnifiedEvent.id). Default: nicht unterstuetzt.
  func deleteEvent(id: String) async throws {
    throw ProviderWriteError.unsupported
  }
}
