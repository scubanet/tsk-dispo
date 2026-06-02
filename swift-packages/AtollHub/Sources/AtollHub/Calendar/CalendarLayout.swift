import Foundation

/// Reine Layout-Helfer fuers Kalender-Modul. Keine SwiftUI-Abhaengigkeit —
/// die Views konsumieren diese Strukturen.
public enum CalendarLayout {
  /// Buendelt Events nach lokalem Tag (Schluessel = `startOfDay`). Innerhalb
  /// eines Tages: all-day zuerst, dann timed nach Startzeit.
  public static func eventsByDay(_ events: [UnifiedEvent],
                                 calendar: Calendar) -> [Date: [UnifiedEvent]] {
    var buckets: [Date: [UnifiedEvent]] = [:]
    for e in events {
      let day = calendar.startOfDay(for: e.start)
      buckets[day, default: []].append(e)
    }
    for day in Array(buckets.keys) {
      buckets[day] = buckets[day]!.sorted { lhs, rhs in
        if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay && !rhs.isAllDay }
        return lhs.start < rhs.start
      }
    }
    return buckets
  }

  /// Die sieben Tage (00:00) der Woche, die `date` enthaelt — Mo..So je nach
  /// `calendar.firstWeekday`.
  public static func weekDays(of date: Date, calendar: Calendar) -> [Date] {
    let start = CalendarWindow.startOfWeek(for: date, calendar: calendar)
    return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
  }

  /// Das Monatsraster als Wochen x 7 Tage (00:00), ganze Wochen Mo..So.
  public static func monthGrid(of date: Date, calendar: Calendar) -> [[Date]] {
    let window = CalendarWindow.interval(for: date, kind: .month, calendar: calendar)
    var weeks: [[Date]] = []
    var cursor = window.start
    while cursor < window.end {
      let week = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: cursor) }
      weeks.append(week)
      cursor = calendar.date(byAdding: .day, value: 7, to: cursor) ?? window.end
    }
    return weeks
  }
}
