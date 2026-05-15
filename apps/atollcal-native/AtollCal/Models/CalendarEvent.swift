import Foundation
import EventKit
import SwiftUI
import AtollCore
import AtollDesign

/// Unifizierte Repräsentation für Calendar-Events aus System (EventKit) + ATOLL.
/// Wird von Calendar-Views konsumiert ohne Wissen über die Quelle.
///
/// v1: ATOLL-Events sind immer all-day. Time-Slots aus course_dates kommen
/// in v2 (Phase 2 — eigenes Spec).
enum CalendarEvent: Identifiable, Hashable {
  case system(EKEvent)
  /// Ein ATOLL-Event = ein konkretes Kurs-Datum eines Assignments. Wenn ein
  /// Course mehrere Daten hat, entstehen mehrere CalendarEvent.atoll-Instanzen.
  case atoll(assignment: Assignment, dayDate: Date)

  var id: String {
    switch self {
    case .system(let e):
      return "ek-\(e.eventIdentifier ?? "ts-\(e.startDate.timeIntervalSince1970)")"
    case .atoll(let a, let d):
      return "atoll-\(a.id)-\(Int(d.timeIntervalSince1970))"
    }
  }

  var title: String {
    switch self {
    case .system(let e): return e.title ?? ""
    case .atoll(let a, _):
      let courseTitle = a.course?.title ?? "Kurs"
      return "\(courseTitle) (\(a.role.rawValue))"
    }
  }

  /// Start-Date — bei ATOLL all-day = Mitternacht des dayDate.
  var startDate: Date {
    switch self {
    case .system(let e): return e.startDate
    case .atoll(_, let d): return Calendar.current.startOfDay(for: d)
    }
  }

  /// End-Date — bei ATOLL all-day = Mitternacht des Folgetags.
  var endDate: Date {
    switch self {
    case .system(let e): return e.endDate
    case .atoll(_, let d):
      let dayStart = Calendar.current.startOfDay(for: d)
      return Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
    }
  }

  var isAllDay: Bool {
    switch self {
    case .system(let e): return e.isAllDay
    case .atoll: return true  // v1: ATOLL immer all-day
    }
  }

  var location: String? {
    switch self {
    case .system(let e): return e.location
    case .atoll(let a, _): return a.course?.location
    }
  }

  /// Color für Event-Bar. Brand-Color für ATOLL, Calendar-Color für System.
  var color: Color {
    switch self {
    case .system(let e):
      if let cgColor = e.calendar?.cgColor {
        return Color(cgColor: cgColor)
      }
      return .gray
    case .atoll:
      return .brandBlue
    }
  }

  var isATOLL: Bool {
    if case .atoll = self { return true }
    return false
  }

  // MARK: - Hashable
  func hash(into hasher: inout Hasher) { hasher.combine(id) }
  static func == (lhs: CalendarEvent, rhs: CalendarEvent) -> Bool { lhs.id == rhs.id }
}
