import Foundation

enum CalendarViewKind: String, CaseIterable, Identifiable {
  case day, week, month, quarter, year

  var id: String { rawValue }

  var label: String {
    switch self {
    case .day:     "Tag"
    case .week:    "Woche"
    case .month:   "Monat"
    case .quarter: "Quartal"
    case .year:    "Jahr"
    }
  }

  var systemImage: String {
    switch self {
    case .day:     "calendar.day.timeline.left"
    case .week:    "calendar"
    case .month:   "square.grid.3x3"
    case .quarter: "rectangle.split.3x1"
    case .year:    "square.grid.4x3.fill"
    }
  }
}
