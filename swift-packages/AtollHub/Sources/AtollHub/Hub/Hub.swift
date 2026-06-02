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
    return out.sorted { $0.start < $1.start }
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
}
