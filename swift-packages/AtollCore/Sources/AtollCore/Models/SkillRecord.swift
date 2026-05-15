import Foundation

public struct SkillRecord: Codable, Identifiable, Hashable {
  public let id: UUID?
  public let courseId: UUID
  public let participantId: UUID
  public let skillCode: String
  public let completedOn: String?
  public let instructorId: UUID?

  public init(
    id: UUID?,
    courseId: UUID,
    participantId: UUID,
    skillCode: String,
    completedOn: String?,
    instructorId: UUID?
  ) {
    self.id = id
    self.courseId = courseId
    self.participantId = participantId
    self.skillCode = skillCode
    self.completedOn = completedOn
    self.instructorId = instructorId
  }

  enum CodingKeys: String, CodingKey {
    case id
    case courseId      = "course_id"
    case participantId = "participant_id"
    case skillCode     = "skill_code"
    case completedOn   = "completed_on"
    case instructorId  = "instructor_id"
  }
}

public struct SkillRecordInsert: Encodable {
  public init(
    courseId: UUID,
    participantId: UUID,
    skillCode: String,
    completedOn: String,
    instructorId: UUID?
  ) {
    self.courseId = courseId
    self.participantId = participantId
    self.skillCode = skillCode
    self.completedOn = completedOn
    self.instructorId = instructorId
  }

  public let courseId: UUID
  public let participantId: UUID
  public let skillCode: String
  public let completedOn: String
  public let instructorId: UUID?

  enum CodingKeys: String, CodingKey {
    case courseId      = "course_id"
    case participantId = "participant_id"
    case skillCode     = "skill_code"
    case completedOn   = "completed_on"
    case instructorId  = "instructor_id"
  }
}
