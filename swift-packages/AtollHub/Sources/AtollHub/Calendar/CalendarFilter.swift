import Foundation

/// Filtert Events nach aktiven Kalender-Ids. `enabledIds == nil` → kein Filter.
/// Events ohne `calendarId` werden immer behalten.
public enum CalendarFilter {
  public static func apply(_ events: [UnifiedEvent], enabledIds: Set<String>?) -> [UnifiedEvent] {
    guard let enabledIds else { return events }
    return events.filter { ev in
      guard let id = ev.calendarId else { return true }
      return enabledIds.contains(id)
    }
  }

  /// Variante über deaktivierte Ids (leeres Set → kein Filter). Events ohne
  /// `calendarId` werden immer behalten. Genutzt für den appweiten Hub-Filter.
  public static func apply(_ events: [UnifiedEvent], disabledIds: Set<String>) -> [UnifiedEvent] {
    guard !disabledIds.isEmpty else { return events }
    return events.filter { ev in
      guard let id = ev.calendarId else { return true }
      return !disabledIds.contains(id)
    }
  }
}
