import Foundation
import AtollCore

/// Uebersetzt geladene Atoll-`Assignment`s (course_assignments → courses →
/// course_dates) in quellneutrale `UnifiedEvent`s. Reine Funktion — die
/// Netzwerk-/Decoding-Arbeit erledigt der App-Adapter (`AtollEventsAdapter`).
public enum AtollEventMapper {
  public static func events(from assignments: [Assignment],
                            accountId: String) -> [UnifiedEvent] {
    let ref = AccountRef(accountId: accountId, type: .atoll)
    var out: [UnifiedEvent] = []

    for a in assignments {
      guard let course = a.course, course.status != .cancelled else { continue }

      for day in course.courseDates ?? [] {
        guard let dayDate = day.dayDate else { continue }
        let modules = day.expandModules()

        if modules.isEmpty {
          // All-day Fallback: leerer Kurstag oder has_*-ohne-Zeit.
          // course_date-UUID statt Tagesstempel als Suffix — kollisionsfrei,
          // konsistent mit dem timed-Zweig (zwei Rows am selben Tag wuerden
          // sonst dieselbe id liefern und in einer SwiftUI-List eine Zeile schlucken).
          out.append(UnifiedEvent(
            id: "atoll:\(a.id.uuidString):\(day.id.uuidString)",
            source: ref,
            title: "\(course.title) (\(a.role.rawValue))",
            start: startOfDay(dayDate),
            end: nextDay(dayDate),
            isAllDay: true,
            location: course.location,
            calendarId: "atoll", colorHex: "#0A84FF"
          ))
        } else {
          for m in modules {
            out.append(UnifiedEvent(
              id: "atoll:\(a.id.uuidString):\(day.id.uuidString):\(m.type.rawValue)",
              source: ref,
              title: "\(course.title) \u{2014} \(m.type.label)",
              start: m.start,
              end: m.end,
              isAllDay: false,
              location: (m.location?.isEmpty == false) ? m.location : course.location,
              calendarId: "atoll", colorHex: "#0A84FF"
            ))
          }
        }
      }
    }

    return out.sorted { $0.start < $1.start }
  }

  // Zuerich-Wall-Clock-Tagesgrenzen (wie der Rest der Atoll-Datumslogik).
  private static var zurichCalendar: Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
    return cal
  }
  private static func startOfDay(_ d: Date) -> Date { zurichCalendar.startOfDay(for: d) }
  private static func nextDay(_ d: Date) -> Date {
    let s = startOfDay(d)
    return zurichCalendar.date(byAdding: .day, value: 1, to: s) ?? s
  }
}
