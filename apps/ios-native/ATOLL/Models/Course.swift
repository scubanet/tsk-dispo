import Foundation

enum CourseStatus: String, Codable, CaseIterable, Hashable {
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
    let id: UUID?
    let code: String
    let label: String
}

struct Course: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let startDate: String
    let status: CourseStatus?
    let info: String?
    let notes: String?
    let location: String?
    let additionalDates: [String]?
    let courseType: CourseType?

    enum CodingKeys: String, CodingKey {
        case id, title, status, info, notes, location
        case startDate = "start_date"
        case additionalDates = "additional_dates"
        case courseType = "course_types"
    }

    var allDates: [Date] {
        let formatter = Self.dateFormatter
        let extras = (additionalDates ?? []).compactMap(formatter.date(from:))
        let start = formatter.date(from: startDate)
        return ([start].compactMap { $0 } + extras).sorted()
    }

    var startDateAsDate: Date? {
        Self.dateFormatter.date(from: startDate)
    }

    func nextDateOnOrAfter(_ reference: Date) -> Date? {
        let cal = Calendar.current
        let refDay = cal.startOfDay(for: reference)
        return allDates.first { cal.startOfDay(for: $0) >= refDay }
    }

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
