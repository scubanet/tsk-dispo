import Foundation

/// Quick-toggle filter for which event sources should appear in the calendar.
///
/// `.all` is the default — both system (EventKit) and ATOLL events render.
/// `.atollOnly` hides system events; `.personalOnly` hides ATOLL events.
/// Persisted via `@AppStorage` so the choice survives app restart.
enum CalendarSourceFilter: String, CaseIterable, Identifiable {
  case all
  case atollOnly
  case personalOnly

  var id: String { rawValue }

  var label: String {
    switch self {
    case .all:          return "Alle Quellen"
    case .atollOnly:    return "Nur ATOLL"
    case .personalOnly: return "Nur Persönlich"
    }
  }

  var systemImage: String {
    switch self {
    case .all:          return "rectangle.stack.fill"
    case .atollOnly:    return "stethoscope"
    case .personalOnly: return "person.crop.circle"
    }
  }

  /// Should system EKEvents be shown under this filter?
  var includesSystem: Bool { self != .atollOnly }

  /// Should ATOLL events be shown under this filter?
  var includesATOLL: Bool { self != .personalOnly }
}
