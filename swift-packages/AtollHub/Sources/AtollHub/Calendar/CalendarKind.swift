/// Die drei Kalender-Ansichten von ComHub Phase 1.
public enum CalendarKind: String, Sendable, CaseIterable, Identifiable {
  case day, week, month
  public var id: String { rawValue }

  public var title: String {
    switch self {
    case .day:   return "Tag"
    case .week:  return "Woche"
    case .month: return "Monat"
    }
  }
}
