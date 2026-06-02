import Foundation
@testable import AtollHub

/// Liefert eine feste Event-Liste.
final class FakeCalendar: CalendarProvider {
  let events: [UnifiedEvent]
  init(_ events: [UnifiedEvent]) { self.events = events }
  func events(in interval: DateInterval) async throws -> [UnifiedEvent] {
    events.filter { $0.start >= interval.start && $0.start <= interval.end }
  }
}

/// Wirft immer — für Fehlertoleranz-Tests.
struct FailingCalendar: CalendarProvider {
  struct Boom: Error {}
  func events(in interval: DateInterval) async throws -> [UnifiedEvent] {
    throw Boom()
  }
}

/// Liefert feste Tasks.
final class FakeTodo: TodoProvider {
  let items: [UnifiedTask]
  init(_ items: [UnifiedTask]) { self.items = items }
  func tasks() async throws -> [UnifiedTask] { items }
}

/// Liefert feste Kontakte.
final class FakeContacts: ContactsProvider {
  let items: [UnifiedContact]
  init(_ items: [UnifiedContact]) { self.items = items }
  func contacts() async throws -> [UnifiedContact] { items }
}

/// Test-Helfer zum Bauen eines Events.
func makeEvent(_ id: String, type: AccountType, start: TimeInterval) -> UnifiedEvent {
  UnifiedEvent(id: id, source: AccountRef(accountId: type.rawValue, type: type),
               title: id, start: Date(timeIntervalSince1970: start),
               end: Date(timeIntervalSince1970: start + 3600),
               isAllDay: false, location: nil)
}
