import Foundation

enum CalendarViewKind: String, CaseIterable, Identifiable {
  case day, week, month

  var id: String { rawValue }

  var label: String {
    switch self {
    case .day:   "Tag"
    case .week:  "Woche"
    case .month: "Monat"
    }
  }

  var systemImage: String {
    switch self {
    case .day:   "calendar.day.timeline.left"
    case .week:  "calendar"
    case .month: "calendar"
    }
  }
}
