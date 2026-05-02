import Foundation

struct Skill: Codable, Identifiable, Hashable {
    let id: UUID
    let code: String
    let label: String
    let category: String?
}

/// Wrapper für PostgREST nested-select `instructor_skills(skills(...))`.
struct InstructorSkillRow: Codable, Hashable {
    let skills: Skill?
}
