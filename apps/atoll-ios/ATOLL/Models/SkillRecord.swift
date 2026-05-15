import Foundation

struct SkillRecord: Codable, Identifiable, Hashable {
  let id: UUID?
  let courseId: UUID
  let participantId: UUID
  let skillCode: String
  let completedOn: String?
  let instructorId: UUID?

  enum CodingKeys: String, CodingKey {
    case id
    case courseId      = "course_id"
    case participantId = "participant_id"
    case skillCode     = "skill_code"
    case completedOn   = "completed_on"
    case instructorId  = "instructor_id"
  }
}

struct SkillRecordInsert: Encodable {
  let courseId: UUID
  let participantId: UUID
  let skillCode: String
  let completedOn: String
  let instructorId: UUID?

  enum CodingKeys: String, CodingKey {
    case courseId      = "course_id"
    case participantId = "participant_id"
    case skillCode     = "skill_code"
    case completedOn   = "completed_on"
    case instructorId  = "instructor_id"
  }
}
