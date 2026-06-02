import Foundation
import AtollCore
import AtollHub
import Supabase

/// Erfuellt `CalendarProvider` ueber die Atoll-`course_assignments`. Der
/// Instructor (canonical/legacy id) wird beim Verdrahten injiziert. Select-
/// Spaltenliste gespiegelt von `AtollEventLoader` (AtollCal).
struct AtollEventsAdapter: CalendarProvider {
  let accountId: String
  let instructorId: UUID

  init(accountId: String = "atoll", instructorId: UUID) {
    self.accountId = accountId
    self.instructorId = instructorId
  }

  func events(in interval: DateInterval) async throws -> [UnifiedEvent] {
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd"
    df.timeZone = TimeZone(identifier: "Europe/Zurich")
    let startStr = df.string(from: interval.start)
    let endStr = df.string(from: interval.end)

    let assignments: [Assignment] = try await SupabaseClient.shared
      .from("course_assignments")
      .select("""
        id, role, confirmed,
        courses!inner(
          id, title, status, info, notes, location, start_date, additional_dates,
          course_types(id, code, label),
          course_dates(
            id, date,
            has_theory, has_pool, has_lake,
            theory_from, theory_to,
            pool_from, pool_to,
            lake_from, lake_to,
            pool_location, pool_reserved, note
          )
        )
      """)
      .eq("instructor_id", value: instructorId)
      .gte("courses.start_date", value: startStr)
      .lte("courses.start_date", value: endStr)
      .neq("courses.status", value: "cancelled")
      .execute()
      .value

    return AtollEventMapper.events(from: assignments, accountId: accountId)
  }
}
