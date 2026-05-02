import Foundation

enum CourseStatus: String, Codable, CaseIterable {
  case confirmed
  case tentative
  case cancelled
  case completed

  var label: String {
    switch self {
    case .confirmed: "Bestätigt"
    case .tentative: "Geplant"
    case .cancelled: "Abgesagt"
    case .completed: "Abgeschlossen"
    }
  }
}

struct CourseType: Codable, Hashable {
  let code: String
  let label: String
}

struct Course: Codable, Identifiable, Hashable {
  let id: UUID
  let title: String
  let startDate: String        // YYYY-MM-DD von PostgREST
  let status: CourseStatus
  let info: String?
  let notes: String?
  let additionalDates: [String]?
  let courseType: CourseType?

  enum CodingKeys: String, CodingKey {
    case id, title, status, info, notes
    case startDate = "start_date"
    case additionalDates = "additional_dates"
    case courseType = "course_type"
  }

  /// Alle Daten des Kurses (Start + Zusatztermine), als Date-Werte. Sortiert.
  var allDates: [Date] {
    let formatter = Self.dateFormatter
    let extras = (additionalDates ?? []).compactMap(formatter.date(from:))
    let start = formatter.date(from: startDate)
    return ([start].compactMap { $0 } + extras).sorted()
  }

  var startDateAsDate: Date? {
    Self.dateFormatter.date(from: startDate)
  }

  /// Gibt das nächste Datum >= heute zurück (für Today-Sortierung).
  func nextDateOnOrAfter(_ reference: Date) -> Date? {
    let cal = Calendar.current
    let refDay = cal.startOfDay(for: reference)
    return allDates.first { cal.startOfDay(for: $0) >= refDay }
  }

  /// Findet das Datum (falls vorhanden) das auf den gegebenen Tag fällt.
  func dateMatching(_ day: Date) -> Date? {
    let cal = Calendar.current
    return allDates.first { cal.isDate($0, inSameDayAs: day) }
  }

  static let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: "Europe/Zurich")
    return f
  }()
}
