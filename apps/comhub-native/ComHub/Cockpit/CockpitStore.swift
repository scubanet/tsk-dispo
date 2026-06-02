import Foundation
import Observation
import AtollHub

/// Aggregiert die Heute-Cockpit-Daten ueber den `Hub`: heutige Termine (live)
/// und offene Aufgaben (ueber `Hub.allTasks()`, leer bis Phase 4 einen
/// TodoProvider verdrahtet). Nachrichten/Leads kommen in Phase 3/4 dazu.
@MainActor
@Observable
final class CockpitStore {
  private(set) var todayEvents: [UnifiedEvent] = []
  private(set) var openTasks: [UnifiedTask] = []
  private(set) var loading = false
  private(set) var errors: [String] = []

  /// Zuerich-Kalender, konsistent mit den uebrigen ComHub-Datumshelfern.
  private var calendar: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
    c.firstWeekday = 2
    return c
  }

  func reload(using hub: Hub) async {
    loading = true
    let now = Date()
    let start = calendar.startOfDay(for: now)
    let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
    let interval = DateInterval(start: start, end: end)

    let events = await hub.allEvents(in: interval)
    let tasks = await hub.allTasks()

    todayEvents = CockpitDigest.todayEvents(from: events, now: now, calendar: calendar)
    openTasks = CockpitDigest.openTasks(from: tasks, limit: 8)
    errors = hub.lastErrors
    loading = false
  }
}
