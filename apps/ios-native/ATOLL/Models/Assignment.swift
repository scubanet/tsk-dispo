import Foundation

struct Assignment: Codable, Identifiable, Hashable {
    let id: UUID
    let role: AssignmentRole
    let confirmed: Bool
    let course: Course?

    enum CodingKeys: String, CodingKey {
        case id, role, confirmed
        case course = "courses"
    }
}

enum AssignmentRole: String, Codable, Hashable {
    case haupt, assist, dmt
}

struct Course: Codable, Hashable {
    let id: UUID
    let title: String
    let startDate: String
    let additionalDates: [String]
    let status: CourseStatus?
    let location: String?
    let info: String?
    let courseType: CourseType?

    enum CodingKeys: String, CodingKey {
        case id, title, status, location, info
        case startDate = "start_date"
        case additionalDates = "additional_dates"
        case courseType = "course_types"
    }

    var startDateAsDate: Date? {
        Self.dateFormatter.date(from: startDate)
    }

    var allDates: [Date] {
        let all = [startDate] + additionalDates
        return all.compactMap { Self.dateFormatter.date(from: $0) }.sorted()
    }

    func nextDateOnOrAfter(_ date: Date) -> Date? {
        let startOfDay = Calendar.current.startOfDay(for: date)
        return allDates.first { $0 >= startOfDay } ?? allDates.last
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}

enum CourseStatus: String, Codable, Hashable {
    case confirmed, tentative, cancelled, completed
}

struct CourseType: Codable, Hashable {
    let id: UUID
    let code: String
    let label: String
}
