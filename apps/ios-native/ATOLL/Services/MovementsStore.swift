import Foundation
import Supabase

@MainActor
@Observable
final class MovementsStore {
    enum LoadState {
        case idle, loading, loaded, error
    }

    private(set) var movements: [Movement] = []
    private(set) var loadState: LoadState = .idle
    private(set) var errorMessage: String?

    private let supabase = SupabaseClient.shared

    /// Sichtbare Bewegungen (Saldo-Filter — nur completed Vergütungen + immer Übertrag/Korrektur).
    var visible: [Movement] {
        movements.filter(\.countsToBalance)
    }

    /// Aktueller Saldo (Summe aller sichtbaren Bewegungen).
    var balance: Double {
        visible.reduce(0) { $0 + $1.amountChf }
    }

    func load(instructorId: UUID) async {
        loadState = .loading
        do {
            let result: [Movement] = try await supabase
                .from("account_movements")
                .select("""
                    id, date, amount_chf, kind, description, breakdown_json, ref_assignment_id,
                    course_assignments(courses(status))
                """)
                .eq("instructor_id", value: instructorId)
                .order("date", ascending: false)
                .execute()
                .value
            movements = result
            loadState = .loaded
            errorMessage = nil
        } catch {
            if !movements.isEmpty {
                loadState = .loaded
            } else {
                loadState = .error
            }
            errorMessage = error.localizedDescription
        }
    }
}
