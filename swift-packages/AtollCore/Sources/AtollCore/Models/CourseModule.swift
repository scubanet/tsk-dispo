import Foundation

/// One of the three teachable course modules. Each has its own start/end time
/// in `course_dates` (`theory_*`, `pool_*`, `lake_*`).
public enum CourseModuleType: String, Codable, CaseIterable, Hashable, Sendable {
  case theory, pool, lake

  /// Human-readable label (German, matches the web app).
  public var label: String {
    switch self {
    case .theory: return "Theorie"
    case .pool:   return "Pool"
    case .lake:   return "See"
    }
  }

  /// Single-letter abbreviation for badges on tight UI surfaces.
  public var abbreviation: String {
    switch self {
    case .theory: return "T"
    case .pool:   return "P"
    case .lake:   return "S"
    }
  }

  /// SF Symbol that visually evokes the module — used in chips/rows.
  public var systemImage: String {
    switch self {
    case .theory: return "book.fill"
    case .pool:   return "figure.pool.swim"
    case .lake:   return "water.waves"
    }
  }
}

/// One concrete time-bounded module on a course date.
///
/// Constructed by `CourseDate.expandModules()` from the wire data. Times are
/// always wall-clock in `Europe/Zurich`.
public struct CourseModule: Hashable, Sendable {
  public let type: CourseModuleType
  public let start: Date
  public let end: Date
  /// Pool location code (e.g. `"mooesli"`, `"langnau"`, `"kloten"`). Only set
  /// for `.pool` modules.
  public let location: String?
  /// Whether the pool slot is confirmed. Only meaningful for `.pool`.
  public let reserved: Bool?

  public init(type: CourseModuleType,
              start: Date,
              end: Date,
              location: String? = nil,
              reserved: Bool? = nil) {
    self.type = type
    self.start = start
    self.end = end
    self.location = location
    self.reserved = reserved
  }
}
