import Foundation

public enum CourseStatus: String, Codable, CaseIterable, Hashable {
    case confirmed
    case tentative
    case cancelled
    case completed

    public var label: String {
        switch self {
        case .confirmed: "Bestätigt"
        case .tentative: "Geplant"
        case .cancelled: "Abgesagt"
        case .completed: "Abgeschlossen"
        }
    }
}

public struct CourseType: Codable, Hashable {
    public let id: UUID?
    public let code: String
    public let label: String
}

public struct Course: Codable, Identifiable, Hashable {
    public let id: UUID
    public let title: String
    public let startDate: String
    public let status: CourseStatus?
    public let info: String?
    public let notes: String?
    public let location: String?
    public let additionalDates: [String]?
    public let courseType: CourseType?

    enum CodingKeys: String, CodingKey {
        case id, title, status, info, notes, location
        case startDate = "start_date"
        case additionalDates = "additional_dates"
        case courseType = "course_types"
    }

    public var allDates: [Date] {
        let formatter = Self.dateFormatter
        let extras = (additionalDates ?? []).compactMap(formatter.date(from:))
        let start = formatter.date(from: startDate)
        return ([start].compactMap { $0 } + extras).sorted()
    }

    public var startDateAsDate: Date? {
        Self.dateFormatter.date(from: startDate)
    }

    public func nextDateOnOrAfter(_ reference: Date) -> Date? {
        let cal = Calendar.current
        let refDay = cal.startOfDay(for: reference)
        return allDates.first { cal.startOfDay(for: $0) >= refDay }
    }

    public func dateMatching(_ day: Date) -> Date? {
        let cal = Calendar.current
        return allDates.first { cal.isDate($0, inSameDayAs: day) }
    }

    public static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Zurich")
        return f
    }()
}
