import Foundation
import AtollCore
import Supabase
import Observation

@MainActor
@Observable
public final class AtollEventLoader {
  public private(set) var assignments: [Assignment] = []
  public private(set) var lastError: Error?
  public private(set) var loading: Bool = false

  private let supabase = SupabaseClient.shared

  public init() {}

  /// Lädt alle course_assignments für den Instructor mit Courses im Date-Range.
  /// PostgREST-Embed liefert Course via Assignment.course (Codable-Mapping in AtollCore).
  public func reload(for instructorId: UUID, range: DateInterval) async {
    loading = true
    lastError = nil

    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    dateFormatter.timeZone = TimeZone(identifier: "Europe/Zurich")
    let startStr = dateFormatter.string(from: range.start)
    let endStr   = dateFormatter.string(from: range.end)

    do {
      let resp: [Assignment] = try await supabase
        .from("course_assignments")
        .select("""
          id, role, confirmed,
          courses!inner(id, title, status, info, notes, location, start_date, additional_dates, course_types(id, code, label))
        """)
        .eq("instructor_id", value: instructorId)
        .gte("courses.start_date", value: startStr)
        .lte("courses.start_date", value: endStr)
        .neq("courses.status", value: "cancelled")
        .execute()
        .value
      assignments = resp
    } catch {
      lastError = error
      print("[AtollEventLoader] reload failed: \(error)")
    }
    loading = false
  }
}
