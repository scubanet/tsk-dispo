import Foundation

enum AppDate {
    /// Parser für PostgREST DATE-Strings ("yyyy-MM-dd").
    static func parseISODate(_ s: String) -> Date? {
        isoDateFormatter.date(from: s)
    }

    private static let isoDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "de_CH")
        f.unitsStyle = .short
        return f
    }()

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_CH")
        f.dateFormat = "EEEE"
        return f
    }()

    private static let shortFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_CH")
        f.dateFormat = "d. MMM"
        return f
    }()

    static func relativeLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Heute" }
        if cal.isDateInTomorrow(date) { return "Morgen" }

        let days = cal.dateComponents([.day], from: cal.startOfDay(for: .now), to: cal.startOfDay(for: date)).day ?? 0
        if days > 0 && days < 7 {
            return weekdayFormatter.string(from: date)
        }
        return shortFormatter.string(from: date)
    }
}
