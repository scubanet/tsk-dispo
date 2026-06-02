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
          let dayStamp = Int(startOfDay(dayDate).timeIntervalSince1970)
          out.append(UnifiedEvent(
            id: "atoll:\(a.id.uuidString):\(dayStamp)",
            source: ref,
            title: "\(course.title) (\(a.role.rawValue))",
            start: startOfDay(dayDate),
            end: nextDay(dayDate),
            isAllDay: true,
            location: course.location
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
              location: (m.location?.isEmpty == false) ? m.location : course.location
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
