import Foundation

/// Sichtbare Stundenrange eines Tages-/Wochen-Gitters.
public enum DayWindow {
  public struct Range: Sendable, Equatable {
    public let startHour: Int
    public let endHour: Int
  }

  /// Default 7–19; erweitert sich an die timed Events (mit 1h Puffer),
  /// geklammert auf [6, 23].
  public static func hours(for events: [UnifiedEvent], calendar: Calendar) -> Range {
    let timed = events.filter { !$0.isAllDay }
    guard !timed.isEmpty else { return Range(startHour: 7, endHour: 19) }

    let starts = timed.map { calendar.component(.hour, from: $0.start) }
    let ends = timed.map { ev -> Int in
      let h = calendar.component(.hour, from: ev.end)
      let m = calendar.component(.minute, from: ev.end)
      return m > 0 ? h + 1 : h
    }
    let minStart = max(6, min((starts.min() ?? 7) - 1, 7))
    let maxEnd = min(23, max((ends.max() ?? 19) + 1, 19))
    return Range(startHour: minStart, endHour: maxEnd)
  }
}
