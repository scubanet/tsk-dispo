import Foundation

/// A single calendar day belonging to a course, with per-module times.
///
/// Wire format mirrors `public.course_dates` (post-migration 0095). One row
/// can have up to three active modules (Theorie / Pool / See). Each module
/// may have a start and end time, or `has_*=true` with `*_from=NULL` to
/// indicate „dispatcher activated this module but hasn't set a time yet".
public struct CourseDate: Codable, Identifiable, Hashable, Sendable {
  public let id: UUID
  public let date: String                // "YYYY-MM-DD"

  public let hasTheory: Bool
  public let hasPool: Bool
  public let hasLake: Bool

  public let theoryFrom: String?         // "HH:MM:SS"
  public let theoryTo: String?
  public let poolFrom: String?
  public let poolTo: String?
  public let lakeFrom: String?
  public let lakeTo: String?

  public let poolLocation: String?
  public let poolReserved: Bool?
  public let note: String?

  enum CodingKeys: String, CodingKey {
    case id, date, note
    case hasTheory = "has_theory"
    case hasPool = "has_pool"
    case hasLake = "has_lake"
    case theoryFrom = "theory_from"
    case theoryTo = "theory_to"
    case poolFrom = "pool_from"
    case poolTo = "pool_to"
    case lakeFrom = "lake_from"
    case lakeTo = "lake_to"
    case poolLocation = "pool_location"
    case poolReserved = "pool_reserved"
  }

  // MARK: - Derived

  /// Parsed `date` as a Swift `Date`, or `nil` if the wire string is malformed.
  public var dayDate: Date? { Self.dateFormatter.date(from: date) }

  /// `true` if no module is active — the row exists for some other reason
  /// (e.g. a pool placeholder later filled in) but currently carries no event.
  public var isEmpty: Bool { !hasTheory && !hasPool && !hasLake }

  /// `true` if at least one module is activated but lacks a start time. UI may
  /// want to render an all-day fallback for these.
  public var hasActiveTypeWithoutTime: Bool {
    (hasTheory && theoryFrom == nil)
      || (hasPool && poolFrom == nil)
      || (hasLake && lakeFrom == nil)
  }

  /// Expand into 0–3 timed `CourseModule`s. A module is emitted only when its
  /// `has_*` flag is true **and** its `*_from` time is set. Missing `*_to`
  /// falls back to `*_from` so the caller still gets a (zero-duration) event.
  ///
  /// Times are interpreted in `Europe/Zurich` wall-clock, matching the web app.
  public func expandModules() -> [CourseModule] {
    guard let day = dayDate else { return [] }
    var modules: [CourseModule] = []

    if hasTheory, let from = theoryFrom,
       let s = Self.combine(day: day, time: from) {
      let e = Self.combine(day: day, time: theoryTo ?? from) ?? s
      modules.append(CourseModule(type: .theory, start: s, end: e))
    }
    if hasPool, let from = poolFrom,
       let s = Self.combine(day: day, time: from) {
      let e = Self.combine(day: day, time: poolTo ?? from) ?? s
      modules.append(CourseModule(
        type: .pool, start: s, end: e,
        location: poolLocation, reserved: poolReserved
      ))
    }
    if hasLake, let from = lakeFrom,
       let s = Self.combine(day: day, time: from) {
      let e = Self.combine(day: day, time: lakeTo ?? from) ?? s
      modules.append(CourseModule(type: .lake, start: s, end: e))
    }
    return modules
  }

  // MARK: - Parsing helpers

  /// Combine a date-only `Date` with an `"HH:MM[:SS]"` string into a wall-clock
  /// `Date` in `Europe/Zurich`. Returns `nil` if the time string is unparsable.
  static func combine(day: Date, time: String) -> Date? {
    let parts = time.split(separator: ":")
    guard parts.count >= 2,
          let hour = Int(parts[0]),
          let minute = Int(parts[1]) else { return nil }
    let second = parts.count >= 3 ? Int(parts[2]) ?? 0 : 0

    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
    var comps = cal.dateComponents([.year, .month, .day], from: day)
    comps.hour = hour
    comps.minute = minute
    comps.second = second
    return cal.date(from: comps)
  }

  /// Shared ISO-date formatter for the `date` column. Thread-safe for reads.
  nonisolated(unsafe) public static let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: "Europe/Zurich")
    return f
  }()
}
