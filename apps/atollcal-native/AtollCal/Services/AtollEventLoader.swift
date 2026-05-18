import Foundation
import AtollCore
import Supabase
import Observation
import OSLog

/// Loads ATOLL course assignments from Supabase and exposes them as observable
/// state. Designed to coexist with multiple Views calling `reload(...)` in
/// parallel (DayView + WeekView + MonthView trigger on date changes):
///
/// - **Debouncing**: if the requested range is already covered by the last load
///   and that load is < 30s old for the same instructor, the call is skipped.
///   Bypass with `force: true` after a CRUD or explicit retry.
/// - **Cancellation**: each `reload` honours `Task.isCancelled` before and after
///   the network request, so SwiftUI's `task(id:)` cancellation kills stale
///   in-flight loads when the user scrolls quickly.
/// - **Logging**: all output goes through `os.Logger` under the
///   `swiss.atoll.cal` subsystem so it shows up in Console.app, not via `print`.
@MainActor
@Observable
public final class AtollEventLoader {
  public private(set) var assignments: [Assignment] = []
  public private(set) var lastError: Error?
  public private(set) var loading: Bool = false

  private let supabase = SupabaseClient.shared
  private let logger = Logger(subsystem: "swiss.atoll.cal", category: "events")

  // Debounce cache — read on next reload to decide if work is needed.
  private var lastLoadedRange: DateInterval?
  private var lastLoadedAt: Date?
  private var lastLoadedInstructor: UUID?

  /// 30 s window during which an already-covered range will skip re-fetch.
  private let debounceWindow: TimeInterval = 30

  public init() {}

  /// Loads `course_assignments` for the given instructor in the date range.
  ///
  /// - Parameter force: skip the debounce check (e.g. after a CRUD, an
  ///   explicit "Erneut versuchen" tap, or a manual pull-to-refresh).
  public func reload(for instructorId: UUID,
                     range: DateInterval,
                     force: Bool = false) async {
    guard !Task.isCancelled else { return }

    // Debounce: same instructor, requested range already covered, recent load.
    if !force,
       let last = lastLoadedRange,
       let lastAt = lastLoadedAt,
       lastLoadedInstructor == instructorId,
       last.start <= range.start,
       last.end >= range.end,
       Date().timeIntervalSince(lastAt) < debounceWindow {
      logger.debug("reload skipped (debounce hit — range covered, last load \(Int(Date().timeIntervalSince(lastAt)))s ago)")
      return
    }

    loading = true
    lastError = nil

    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    dateFormatter.timeZone = TimeZone(identifier: "Europe/Zurich")
    let startStr = dateFormatter.string(from: range.start)
    let endStr   = dateFormatter.string(from: range.end)

    do {
      try Task.checkCancellation()
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
      try Task.checkCancellation()
      assignments = resp
      lastLoadedRange = range
      lastLoadedAt = Date()
      lastLoadedInstructor = instructorId
      logger.info("Loaded \(resp.count) assignments for \(startStr, privacy: .public)..\(endStr, privacy: .public)")
    } catch is CancellationError {
      logger.debug("reload cancelled")
    } catch {
      lastError = error
      logger.error("reload failed: \(error.localizedDescription, privacy: .public)")
    }

    loading = false
  }

  /// Manually invalidate the debounce cache — call this after a CRUD on a
  /// course that might have shifted dates outside the current window.
  public func invalidateCache() {
    lastLoadedRange = nil
    lastLoadedAt = nil
    lastLoadedInstructor = nil
  }
}
