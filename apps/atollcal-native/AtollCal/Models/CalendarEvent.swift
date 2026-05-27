import Foundation
import EventKit
import SwiftUI
import AtollCore
import AtollDesign

/// Unifizierte Repräsentation für Calendar-Events aus System (EventKit) + ATOLL.
/// Wird von Calendar-Views konsumiert ohne Wissen über die Quelle.
///
/// **ATOLL Module-Zeiten:** Seit Migration 0095 hat eine `course_dates`-Row
/// pro Modul (Theorie/Pool/See) eigene Zeiten. `CalendarEvent.atoll(...)`
/// trägt ein optionales `CourseModule`. Ist es gesetzt, ist das Event **timed**
/// (mit start/end Wall-Clock). Ist es `nil`, fällt es auf **all-day**
/// zurück — entweder weil der Kurs noch im Legacy-Modus läuft, oder weil
/// ein Modul aktiviert wurde ohne Zeit-Eintrag.
enum CalendarEvent: Identifiable, Hashable {
  case system(EKEvent)
  /// Ein ATOLL-Event = ein konkretes Kurs-Datum eines Assignments, optional
  /// auf ein einzelnes Modul eingeschränkt. Ein Kurstag mit Theorie + Pool
  /// erzeugt zwei `.atoll`-Instanzen mit unterschiedlichen Modulen.
  case atoll(assignment: Assignment, dayDate: Date, module: CourseModule?)
  /// Ein synthetisches Jahrestag-Event aus dem Contacts-Framework. EventKit
  /// spiegelt nur Geburtstage in seinen Birthday-Calendar; Jahrestage holt
  /// Apple's Calendar.app aus `CNContact.dates` (label = `CNLabelDateAnniversary`).
  /// Wir machen es genauso — `ContactsAnniversaryStore` lädt die Kontakte,
  /// und die Calendar-Views synthesisieren pro Jahr ein all-day Event.
  ///
  /// `ageYears` ist gesetzt, wenn der User beim Anlegen das Jahr eingetragen
  /// hat — wir können dann den passenden "12. Jahrestag"-Suffix bilden.
  case anniversary(contactName: String, dayDate: Date, ageYears: Int?, contactID: String)

  var id: String {
    switch self {
    case .system(let e):
      return "ek-\(e.eventIdentifier ?? "ts-\(e.startDate.timeIntervalSince1970)")"
    case .atoll(let a, let d, let m):
      let dayStamp = Int(Calendar.current.startOfDay(for: d).timeIntervalSince1970)
      if let m {
        return "atoll-\(a.id)-\(dayStamp)-\(m.type.rawValue)-\(Int(m.start.timeIntervalSince1970))"
      }
      return "atoll-\(a.id)-\(dayStamp)"
    case .anniversary(_, let d, _, let cid):
      let dayStamp = Int(Calendar.current.startOfDay(for: d).timeIntervalSince1970)
      return "ann-\(cid)-\(dayStamp)"
    }
  }

  var title: String {
    switch self {
    case .system(let e):
      return e.title ?? ""
    case .atoll(let a, _, let m):
      let courseTitle = a.course?.title ?? "Kurs"
      if let m {
        return "\(courseTitle) — \(m.type.label)"
      }
      return "\(courseTitle) (\(a.role.rawValue))"
    case .anniversary(let name, _, let age, _):
      if let age, age > 0 {
        return "\(name)s \(age). Jahrestag"
      }
      return "\(name)s Jahrestag"
    }
  }

  /// Start-Date — bei ATOLL mit Modul: `module.start` (Wall-Clock).
  /// Ohne Modul: Mitternacht des Kurstags (all-day Fallback).
  var startDate: Date {
    switch self {
    case .system(let e):
      return e.startDate
    case .atoll(_, let d, let m):
      if let m { return m.start }
      return Calendar.current.startOfDay(for: d)
    case .anniversary(_, let d, _, _):
      return Calendar.current.startOfDay(for: d)
    }
  }

  /// End-Date — bei ATOLL mit Modul: `module.end`. Ohne Modul: Mitternacht
  /// des Folgetags (all-day Fallback).
  var endDate: Date {
    switch self {
    case .system(let e):
      return e.endDate
    case .atoll(_, let d, let m):
      if let m { return m.end }
      let dayStart = Calendar.current.startOfDay(for: d)
      return Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
    case .anniversary(_, let d, _, _):
      let dayStart = Calendar.current.startOfDay(for: d)
      return Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
    }
  }

  var isAllDay: Bool {
    switch self {
    case .system(let e): return e.isAllDay
    case .atoll(_, _, let m): return m == nil
    case .anniversary: return true
    }
  }

  var location: String? {
    switch self {
    case .system(let e):
      return e.location
    case .atoll(let a, _, let m):
      // Pool-Module tragen eine eigene Location (pool_location); fallback auf
      // Kurs-Location (z. B. "Zürich") wenn nicht gesetzt.
      if let m, let loc = m.location, !loc.isEmpty { return loc }
      return a.course?.location
    case .anniversary:
      return nil
    }
  }

  /// Color für Event-Bar. Brand-Role-Color für ATOLL, Calendar-Color für System.
  var color: Color {
    switch self {
    case .system(let e):
      if let cgColor = e.calendar?.cgColor {
        return Color(cgColor: cgColor)
      }
      return .gray
    case .atoll(let a, _, _):
      return .atollRole(a.role)
    case .anniversary:
      // Apple's Calendar.app tints anniversary entries with the same warm
      // pink as the Birthdays calendar — keep that visual association.
      return .pink
    }
  }

  var isATOLL: Bool {
    if case .atoll = self { return true }
    return false
  }

  /// GL-006 Phase 1.5f — SF Symbol name for "special day" markers that
  /// should appear in the mini-month dot row alongside (or instead of) a
  /// colour dot. Returns `nil` for ordinary events.
  ///
  /// Detection (title first so anniversaries in the Birthdays calendar get
  /// the heart icon instead of the generic cake):
  /// - Title contains "Jahrestag" / "Anniversary" → heart icon
  /// - Title contains "Geburtstag" / "Birthday" → cake icon
  /// - Otherwise, if it lives in the Apple Birthdays calendar
  ///   (`EKCalendar.type == .birthday`) → cake icon (fallback for events
  ///   that carry just the contact's name)
  ///
  /// Title-based detection is locale-aware: DE + EN keywords for now;
  /// extend the list as needed for other locales.
  var specialIconName: String? {
    switch self {
    case .anniversary:
      return "heart.fill"
    case .atoll:
      return nil
    case .system(let ek):
      let title = (ek.title ?? "").lowercased()
      if title.contains("jahrestag") || title.contains("anniversary") {
        return "heart.fill"
      }
      if title.contains("geburtstag") || title.contains("birthday") {
        return "birthday.cake.fill"
      }
      if ek.calendar?.type == .birthday {
        return "birthday.cake.fill"
      }
      return nil
    }
  }

  /// `AssignmentRole` if this is an ATOLL event — used by EventDetailSheet to
  /// label the role and by tests to verify role/colour mapping.
  var atollRole: AssignmentRole? {
    if case .atoll(let a, _, _) = self { return a.role }
    return nil
  }

  /// `CourseModule` if this is an ATOLL event with concrete module times.
  /// Nil for all-day ATOLL events (legacy or has_*-without-time).
  var atollModule: CourseModule? {
    if case .atoll(_, _, let m) = self { return m }
    return nil
  }

  // MARK: - Hashable
  // Note: startDate / endDate are included so SwiftUI `@State<[CalendarEvent]>`
  // detects a rescheduled event as "changed" and re-renders the grid. With
  // id-only equality, drag-to-reschedule wouldn't refresh the visual position
  // because the new and old EKEvent reference share the same identifier.
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
    hasher.combine(startDate)
    hasher.combine(endDate)
  }
  static func == (lhs: CalendarEvent, rhs: CalendarEvent) -> Bool {
    lhs.id == rhs.id && lhs.startDate == rhs.startDate && lhs.endDate == rhs.endDate
  }
}
