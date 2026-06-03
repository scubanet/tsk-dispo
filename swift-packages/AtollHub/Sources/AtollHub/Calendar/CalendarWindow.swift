import Foundation

/// Reine Logik: das `DateInterval`, das der Hub fuer eine Ansicht laden muss.
/// Monat = ganze Wochen (Mo-So), damit das Monatsraster lueckenlos ist.
public enum CalendarWindow {
  public static func interval(for anchor: Date, kind: CalendarKind,
                              calendar: Calendar) -> DateInterval {
    let start = calendar.startOfDay(for: anchor)
    switch kind {
    case .day:
      let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
      return DateInterval(start: start, end: end)

    case .week:
      let weekStart = startOfWeek(for: anchor, calendar: calendar)
      let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
      return DateInterval(start: weekStart, end: weekEnd)

    case .month:
      let comps = calendar.dateComponents([.year, .month], from: anchor)
      let firstOfMonth = calendar.date(from: comps) ?? start
      let nextMonth = calendar.date(byAdding: .month, value: 1, to: firstOfMonth) ?? firstOfMonth
      let lastOfMonth = calendar.date(byAdding: .day, value: -1, to: nextMonth) ?? firstOfMonth
      let gridStart = startOfWeek(for: firstOfMonth, calendar: calendar)
      let weekStartOfLast = startOfWeek(for: lastOfMonth, calendar: calendar)
      let gridEnd = calendar.date(byAdding: .day, value: 7, to: weekStartOfLast) ?? weekStartOfLast
      return DateInterval(start: gridStart, end: gridEnd)
    }
  }

  /// Start der Woche (00:00 des Wochenstart-Tages), respektiert `calendar.firstWeekday`.
  public static func startOfWeek(for date: Date, calendar: Calendar) -> Date {
    let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
    let weekStart = calendar.date(from: comps) ?? calendar.startOfDay(for: date)
    return calendar.startOfDay(for: weekStart)
  }
}
