import Foundation
import AtollCore

extension CalendarEvent {
  /// Expand a single ATOLL `Assignment` into the calendar events that fall
  /// inside `range`. Encapsulates the priority logic between the new
  /// `course_dates` per-module times and the legacy `course.allDates`
  /// single-day approach.
  ///
  /// Priority:
  /// 1. **Per-module times** — if the course has any `course_dates` rows,
  ///    each row expands into 0–3 timed events (one per active module
  ///    with a `*_from` time set).
  /// 2. **Has-flag without time** — if a row has `has_*=true` but no
  ///    `*_from`, an all-day fallback event is emitted (so the dispatcher
  ///    still sees the day blocked).
  /// 3. **Legacy fallback** — if no `course_dates` rows exist at all,
  ///    `course.allDates` is used as a pure all-day list (pre-0095 data).
  ///
  /// Empty rows (all `has_*=false`) are skipped entirely.
  static func expandATOLL(
    _ assignment: Assignment,
    in range: DateInterval
  ) -> [CalendarEvent] {
    guard let course = assignment.course else { return [] }
    let cal = Calendar.current
    var result: [CalendarEvent] = []

    if let courseDates = course.courseDates, !courseDates.isEmpty {
      for cd in courseDates {
        guard let day = cd.dayDate else { continue }
        let dayStart = cal.startOfDay(for: day)
        guard dayStart >= range.start && dayStart < range.end else { continue }
        if cd.isEmpty { continue }

        let modules = cd.expandModules()
        if !modules.isEmpty {
          for m in modules {
            result.append(.atoll(assignment: assignment, dayDate: day, module: m))
          }
          // Edge case: a row could have e.g. has_theory=true with a time *and*
          // has_pool=true without a time. expandModules() returns the theory
          // module only; the pool side is silently dropped. That matches the
          // web app's "render whatever you have" behaviour.
        } else if cd.hasActiveTypeWithoutTime {
          // Type(s) activated but no times set → render an all-day placeholder
          // so the dispatcher still sees the day blocked on the timeline.
          result.append(.atoll(assignment: assignment, dayDate: day, module: nil))
        }
      }
    } else {
      // Legacy: fall back to the single-date list. All events are all-day.
      for d in course.allDates {
        let dayStart = cal.startOfDay(for: d)
        guard dayStart >= range.start && dayStart < range.end else { continue }
        result.append(.atoll(assignment: assignment, dayDate: d, module: nil))
      }
    }
    return result
  }
}
