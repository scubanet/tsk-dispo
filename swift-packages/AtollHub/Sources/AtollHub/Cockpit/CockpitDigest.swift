import Foundation

/// Reine Aggregations-Helfer fuers Heute-Cockpit. Keine SwiftUI-/Netzwerk-
/// Abhaengigkeit — der `CockpitStore` (App) fuettert die Roh-Listen rein.
public enum CockpitDigest {
  /// Events, deren Start auf denselben Kalendertag wie `now` faellt.
  /// Sortiert: all-day zuerst, dann timed nach Startzeit.
  public static func todayEvents(from events: [UnifiedEvent], now: Date,
                                 calendar: Calendar) -> [UnifiedEvent] {
    let today = calendar.startOfDay(for: now)
    return events
      .filter { calendar.startOfDay(for: $0.start) == today }
      .sorted { lhs, rhs in
        if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay && !rhs.isAllDay }
        return lhs.start < rhs.start
      }
  }

  /// Offene (nicht erledigte) Aufgaben, sortiert nach Faelligkeit
  /// (ohne Faelligkeit zuletzt), begrenzt auf `limit`.
  public static func openTasks(from tasks: [UnifiedTask], limit: Int) -> [UnifiedTask] {
    let open = tasks.filter { !$0.isDone }
    let sorted = open.sorted { lhs, rhs in
      switch (lhs.due, rhs.due) {
      case let (l?, r?): return l < r
      case (nil, _?):    return false
      case (_?, nil):    return true
      case (nil, nil):   return lhs.title < rhs.title
      }
    }
    return Array(sorted.prefix(limit))
  }
}
