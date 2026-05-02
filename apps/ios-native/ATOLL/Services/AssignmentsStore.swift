import Foundation
import Supabase

@MainActor
@Observable
final class AssignmentsStore {
    enum LoadState {
        case idle, loading, loaded, error
    }

    private(set) var assignments: [Assignment] = []
    private(set) var loadState: LoadState = .idle
    private(set) var errorMessage: String?

    private let supabase = SupabaseClient.shared

    func load(instructorId: UUID) async {
        loadState = .loading
        do {
            let result: [Assignment] = try await supabase
                .from("course_assignments")
                .select("id, role, confirmed, courses(id, title, start_date, additional_dates, status, location, info, course_types(id, code, label))")
                .eq("instructor_id", value: instructorId)
                .execute()
                .value

            assignments = result.sorted {
                ($0.course?.startDateAsDate ?? .distantFuture) < ($1.course?.startDateAsDate ?? .distantFuture)
            }
            loadState = .loaded
            errorMessage = nil
        } catch {
            if !assignments.isEmpty {
                loadState = .loaded
            } else {
                loadState = .error
            }
            errorMessage = error.localizedDescription
        }
    }

    func today() -> [Assignment] {
        let cal = Calendar.current
        return assignments.filter { a in
            guard let d = a.course?.startDateAsDate else { return false }
            return cal.isDateInToday(d)
        }
    }

    func upcomingWeek() -> [Assignment] {
        let cal = Calendar.current
        let tomorrow = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: .now)!)
        let weekEnd = cal.date(byAdding: .day, value: 7, to: cal.startOfDay(for: .now))!
        return assignments.filter { a in
            guard let d = a.course?.startDateAsDate else { return false }
            return d >= tomorrow && d < weekEnd
        }
    }

    struct MonthGroup {
        let monthLabel: String
        let items: [Assignment]
    }

    func groupedByMonth() -> [MonthGroup] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_CH")
        formatter.dateFormat = "MMMM yyyy"

        let grouped = Dictionary(grouping: assignments) { a -> String in
            guard let d = a.course?.startDateAsDate else { return "Ohne Datum" }
            return formatter.string(from: d)
        }

        return grouped
            .sorted {
                ($0.value.first?.course?.startDateAsDate ?? .distantFuture)
                    < ($1.value.first?.course?.startDateAsDate ?? .distantFuture)
            }
            .map { MonthGroup(monthLabel: $0.key, items: $0.value) }
    }
}
