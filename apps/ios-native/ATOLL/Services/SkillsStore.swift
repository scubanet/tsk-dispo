import Foundation
import Supabase

@MainActor
@Observable
final class SkillsStore {
    private(set) var skills: [Skill] = []
    private(set) var loaded = false

    private let supabase = SupabaseClient.shared

    func load(instructorId: UUID) async {
        do {
            let result: [InstructorSkillRow] = try await supabase
                .from("instructor_skills")
                .select("skills(id, code, label, category)")
                .eq("instructor_id", value: instructorId)
                .execute()
                .value
            // Skills nach Kategorie + Label sortieren
            skills = result.compactMap(\.skills).sorted { lhs, rhs in
                let lc = lhs.category ?? ""
                let rc = rhs.category ?? ""
                if lc != rc { return lc < rc }
                return lhs.label < rhs.label
            }
            loaded = true
        } catch {
            // Fail silent — Skills sind nice-to-have, nicht kritisch
            loaded = true
        }
    }

    /// Skills gruppiert nach Kategorie für Sectioned-Display.
    var grouped: [(category: String, items: [Skill])] {
        Dictionary(grouping: skills, by: { $0.category ?? "Allgemein" })
            .map { (category: $0.key, items: $0.value) }
            .sorted { $0.category < $1.category }
    }
}
