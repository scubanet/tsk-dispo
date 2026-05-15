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

    /// Heutige Einsätze — checkt ALLE Tage des Kurses (start_date + additional_dates),
    /// damit Mehr-Tages-Kurse wie AOWD an jedem ihrer Termine auftauchen.
    func today() -> [Assignment] {
        let cal = Calendar.current
        return assignments.filter { a in
            (a.course?.allDates ?? []).contains { cal.isDateInToday($0) }
        }
    }

    /// Einsätze in den nächsten 7 Tagen exkl. heute — basierend auf `allDates`,
    /// sortiert nach nächstem anstehendem Termin.
    func upcomingWeek() -> [Assignment] {
        let cal = Calendar.current
        let tomorrow = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: .now)!)
        let weekEnd = cal.date(byAdding: .day, value: 7, to: cal.startOfDay(for: .now))!
        return assignments
            .filter { a in
                (a.course?.allDates ?? []).contains { d in
                    let day = cal.startOfDay(for: d)
                    return day >= tomorrow && day < weekEnd
                }
            }
            .sorted { a, b in
                let nextA = a.course?.nextDateOnOrAfter(.now) ?? .distantFuture
                let nextB = b.course?.nextDateOnOrAfter(.now) ?? .distantFuture
                return nextA < nextB
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

        // Neueste Monate zuerst — innerhalb des Monats neueste Tage zuerst.
        return grouped
            .sorted {
                ($0.value.first?.course?.startDateAsDate ?? .distantPast)
                    > ($1.value.first?.course?.startDateAsDate ?? .distantPast)
            }
            .map { (key, items) in
                MonthGroup(
                    monthLabel: key,
                    items: items.sorted {
                        ($0.course?.startDateAsDate ?? .distantPast)
                            > ($1.course?.startDateAsDate ?? .distantPast)
                    }
                )
            }
    }
}
