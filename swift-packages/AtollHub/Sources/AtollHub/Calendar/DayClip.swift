import Foundation

/// Schneidet Events auf Tagesfenster zu — fuer Termine, die ueber Mitternacht
/// reichen oder mehrere Tage umspannen (z.B. Ferien). Reine Logik, keine View.
public enum DayClip {
  /// Der Anteil von `event`, der in den Tag `day` (lokal) faellt, oder `nil`
  /// wenn das Event diesen Tag nicht beruehrt. Tagesgrenzen klammern Start/Ende:
  /// ein Event 22:00→01:00 ergibt an Tag X (22:00, 24:00) und an Tag X+1
  /// (00:00, 01:00). Ein Event, das exakt um Mitternacht endet, beruehrt den
  /// Folgetag nicht.
  public static func segment(event: UnifiedEvent, on day: Date,
                             calendar: Calendar) -> (start: Date, end: Date)? {
    let dayStart = calendar.startOfDay(for: day)
    guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return nil }
    let segStart = max(event.start, dayStart)
    let segEnd = min(event.end, dayEnd)
    guard segStart < segEnd else { return nil }
    return (segStart, segEnd)
  }

  /// Alle lokalen Tage (00:00), die `event` beruehrt — fuer mehrtaegige und
  /// uebernaechtige Events. Ein Event mit Ende exakt um Mitternacht zaehlt den
  /// Endtag nicht mit (Ende exklusiv).
  public static func overlappedDays(event: UnifiedEvent, calendar: Calendar) -> [Date] {
    var days: [Date] = []
    var cursor = calendar.startOfDay(for: event.start)
    while cursor < event.end {
      days.append(cursor)
      guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
      cursor = next
    }
    return days
  }
}

public extension UnifiedEvent {
  /// Kopie mit ersetzten Zeiten — fuer den auf einen Tag geclippten Anteil.
  func withTimes(start: Date, end: Date) -> UnifiedEvent {
    UnifiedEvent(id: id, source: source, title: title, start: start, end: end,
                 isAllDay: isAllDay, location: location)
  }
}
