import Foundation
import Observation

/// Bündelt ein Konto mit seinen konkreten Provider-Instanzen. Nicht jede
/// Capability muss belegt sein — `nil` heißt „dieses Konto liefert das nicht".
public struct AccountConnection: Sendable {
  public let account: Account
  public let calendar: CalendarProvider?
  public let mail: MailProvider?
  public let todo: TodoProvider?
  public let contacts: ContactsProvider?

  public init(account: Account,
              calendar: CalendarProvider? = nil,
              mail: MailProvider? = nil,
              todo: TodoProvider? = nil,
              contacts: ContactsProvider? = nil) {
    self.account = account
    self.calendar = calendar
    self.mail = mail
    self.todo = todo
    self.contacts = contacts
  }
}

/// Der Hub-Kern: hält alle Konto-Verbindungen und aggregiert quellneutral
/// über sie. Fehlerhafte Provider werden übersprungen (gesammelt in
/// `lastErrors`), damit ein kaputtes Konto die übrigen nicht blockiert.
@MainActor
@Observable
public final class Hub {
  public private(set) var connections: [AccountConnection] = []
  public private(set) var lastErrors: [String] = []

  /// Appweit deaktivierte Kalender-Ids (vom Kalender-Filter gesetzt, persistiert).
  /// Wirkt auf JEDE Event-Aggregation (Heute-Cockpit, Kalender, …). Leer = kein Filter.
  public var disabledCalendarIds: Set<String> = []

  public init() {}

  public func connect(_ connection: AccountConnection) {
    connections.append(connection)
  }

  public func reset() {
    connections.removeAll()
    lastErrors.removeAll()
  }

  // MARK: – Aggregation

  public func allEvents(in interval: DateInterval) async -> [UnifiedEvent] {
    lastErrors.removeAll()
    var out: [UnifiedEvent] = []
    for connection in connections {
      guard let provider = connection.calendar else { continue }
      do {
        out += try await provider.events(in: interval)
      } catch {
        lastErrors.append("calendar[\(connection.account.id)]: \(error)")
      }
    }
    let filtered = CalendarFilter.apply(out, disabledIds: disabledCalendarIds)
    return filtered.sorted { $0.start < $1.start }
  }

  public func allTasks() async -> [UnifiedTask] {
    lastErrors.removeAll()
    var out: [UnifiedTask] = []
    for connection in connections {
      guard let provider = connection.todo else { continue }
      do {
        out += try await provider.tasks()
      } catch {
        lastErrors.append("todo[\(connection.account.id)]: \(error)")
      }
    }
    return out
  }

  public func allContacts() async -> [UnifiedContact] {
    lastErrors.removeAll()
    var out: [UnifiedContact] = []
    for connection in connections {
      guard let provider = connection.contacts else { continue }
      do {
        out += try await provider.contacts()
      } catch {
        lastErrors.append("contacts[\(connection.account.id)]: \(error)")
      }
    }
    return out
  }

  // MARK: - Schreiben (Routing an die passende Verbindung)

  /// Schaltet den Erledigt-Status eines Tasks um — am Konto, das zur Quelle passt.
  public func setTaskDone(_ task: UnifiedTask, done: Bool) async throws {
    guard let conn = connections.first(where: {
      $0.account.type == task.source.type && $0.todo != nil
    }), let todo = conn.todo else {
      throw ProviderWriteError.notFound
    }
    try await todo.setDone(taskId: task.id, isDone: done)
  }

  /// Erstellt einen Termin im ersten schreibfaehigen Apple-Kalender-Konto.
  @discardableResult
  public func createEvent(_ draft: EventDraft) async throws -> UnifiedEvent {
    guard let cal = appleCalendar else { throw ProviderWriteError.notFound }
    return try await cal.createEvent(draft)
  }

  @discardableResult
  public func updateEvent(id: String, with draft: EventDraft) async throws -> UnifiedEvent {
    guard let cal = appleCalendar else { throw ProviderWriteError.notFound }
    return try await cal.updateEvent(id: id, with: draft)
  }

  public func deleteEvent(id: String) async throws {
    guard let cal = appleCalendar else { throw ProviderWriteError.notFound }
    try await cal.deleteEvent(id: id)
  }

  /// Der Apple-Kalender-Provider (Schreiben geht nur nach Apple; Atoll-Events sind read-only).
  private var appleCalendar: CalendarProvider? {
    connections.first(where: { $0.account.type == .apple && $0.calendar != nil })?.calendar
  }

  /// Erstellt einen Kontakt im gewählten Konto (Apple oder Atoll).
  @discardableResult
  public func createContact(_ draft: ContactDraft, source: AccountType) async throws -> UnifiedContact {
    guard let prov = connections.first(where: { $0.account.type == source && $0.contacts != nil })?.contacts else {
      throw ProviderWriteError.notFound
    }
    return try await prov.createContact(draft)
  }
  /// Aktualisiert einen Kontakt (per id-Präfix apple:/atoll:).
  @discardableResult
  public func updateContact(id: String, with draft: ContactDraft) async throws -> UnifiedContact {
    let type: AccountType = id.hasPrefix("apple:") ? .apple : .atoll
    guard let prov = connections.first(where: { $0.account.type == type && $0.contacts != nil })?.contacts else {
      throw ProviderWriteError.notFound
    }
    return try await prov.updateContact(id: id, with: draft)
  }
  /// Loescht/archiviert einen Kontakt (Routing per id-Praefix apple:/atoll:).
  public func deleteContact(id: String) async throws {
    let type: AccountType = id.hasPrefix("apple:") ? .apple : .atoll
    guard let prov = connections.first(where: { $0.account.type == type && $0.contacts != nil })?.contacts else {
      throw ProviderWriteError.notFound
    }
    try await prov.deleteContact(id: id)
  }
  /// Erstellt eine Aufgabe im ersten schreibfähigen Apple-Todo-Konto.
  public func createTask(title: String, due: Date?, listId: String?) async throws {
    guard let todo = connections.first(where: { $0.account.type == .apple && $0.todo != nil })?.todo else {
      throw ProviderWriteError.notFound
    }
    try await todo.createTask(title: title, due: due, listId: listId)
  }

  /// Aendert eine Aufgabe — am Konto, das zum Id-Praefix (apple:/atoll:) passt.
  public func updateTask(id: String, title: String, due: Date?, listId: String?) async throws {
    let type: AccountType = id.hasPrefix("apple:") ? .apple : .atoll
    guard let todo = connections.first(where: { $0.account.type == type && $0.todo != nil })?.todo else {
      throw ProviderWriteError.notFound
    }
    try await todo.updateTask(id: id, title: title, due: due, listId: listId)
  }
}
