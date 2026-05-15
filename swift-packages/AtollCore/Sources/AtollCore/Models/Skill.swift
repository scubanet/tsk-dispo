import Foundation

public struct Skill: Codable, Identifiable, Hashable {
    public let id: UUID
    public let code: String
    public let label: String
    public let category: String?
}

/// Wrapper für PostgREST nested-select `instructor_skills(skills(...))`.
public struct InstructorSkillRow: Codable, Hashable {
    public let skills: Skill?
}
