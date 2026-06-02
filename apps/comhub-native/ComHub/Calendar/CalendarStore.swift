import Foundation
import Observation
import AtollHub

/// Steuert das Kalender-Modul: aktuelle Ansicht (`kind`), Anker-Datum und die
/// geladenen, quellneutralen Events. Laedt ueber den `Hub` (Apple + Atoll).
@MainActor
@Observable
final class CalendarStore {
  var kind: CalendarKind = .week
  var anchor: Date = Date()
  private(set) var events: [UnifiedEvent] = []
  private(set) var eventsByDay: [Date: [UnifiedEvent]] = [:]
  private(set) var loading = false
  private(set) var errors: [String] = []

  /// Aktive Kalender-Ids (vom CalendarSourcesStore gesetzt). nil = alle.
  var enabledCalendarIds: Set<String>?

  /// Zuerich-Kalender mit Montag als Wochenstart — konsistent mit den
  /// `AtollHub`-Datumshelfern.
  var calendar: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
    c.firstWeekday = 2
    return c
  }

  func reload(using hub: Hub) async {
    loading = true
    let window = CalendarWindow.interval(for: anchor, kind: kind, calendar: calendar)
    let merged = await hub.allEvents(in: window)
    let filtered = CalendarFilter.apply(merged, enabledIds: enabledCalendarIds)
    events = filtered
    eventsByDay = CalendarLayout.eventsByDay(filtered, calendar: calendar)
    errors = hub.lastErrors
    loading = false
  }

  // MARK: - Navigation

  func goToToday() { anchor = Date() }

  func step(_ direction: Int) {
    let component: Calendar.Component
    switch kind {
    case .day:   component = .day
    case .week:  component = .weekOfYear
    case .month: component = .month
    }
    anchor = calendar.date(byAdding: component, value: direction, to: anchor) ?? anchor
  }
}
