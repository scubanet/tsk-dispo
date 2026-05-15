import Foundation

/// Pre-Dive-Intake-Datensatz pro course_participant. Nur die 3 Felder die
/// Instructors auf iOS setzen — die volle CD-IDC-Checkliste (Medical/EFR/
/// Logbook/…) bleibt Web-only.
public struct IntakeChecklist: Codable, Identifiable, Hashable {
  public let id: UUID?
  public let courseParticipantId: UUID?
  public let medicalSigned: Bool
  public let liabilitySigned: Bool
  public let safeDivingSigned: Bool
  public let notes: String?
  public let checkedOn: String?        // ISO date "yyyy-MM-dd"
  public let checkedById: UUID?        // legacy instructors.id (siehe legacyInstructorId)

  /// Convenience: ist die Pre-Dive-Check komplett?
  public var isComplete: Bool {
    medicalSigned && liabilitySigned && safeDivingSigned
  }

  enum CodingKeys: String, CodingKey {
    case id, notes
    case courseParticipantId = "course_participant_id"
    case medicalSigned       = "medical_signed"
    case liabilitySigned     = "liability_signed"
    case safeDivingSigned    = "safe_diving_signed"
    case checkedOn           = "checked_on"
    case checkedById         = "checked_by_id"
  }
}

/// Insert/Update-Payload — nur die 3 Felder + Bookkeeping.
/// Volle `intake_checklists`-Row hat 20+ Felder (CD-Checkliste), die wir
/// hier bewusst NULL lassen.
public struct IntakeUpsert: Encodable {
  public init(
    courseParticipantId: UUID,
    medicalSigned: Bool,
    liabilitySigned: Bool,
    safeDivingSigned: Bool,
    notes: String?,
    checkedOn: String,
    checkedById: UUID?
  ) {
    self.courseParticipantId = courseParticipantId
    self.medicalSigned = medicalSigned
    self.liabilitySigned = liabilitySigned
    self.safeDivingSigned = safeDivingSigned
    self.notes = notes
    self.checkedOn = checkedOn
    self.checkedById = checkedById
  }

  public let courseParticipantId: UUID
  public let medicalSigned: Bool
  public let liabilitySigned: Bool
  public let safeDivingSigned: Bool
  public let notes: String?
  public let checkedOn: String          // ISO yyyy-MM-dd
  public let checkedById: UUID?

  enum CodingKeys: String, CodingKey {
    case courseParticipantId = "course_participant_id"
    case medicalSigned       = "medical_signed"
    case liabilitySigned     = "liability_signed"
    case safeDivingSigned    = "safe_diving_signed"
    case notes
    case checkedOn           = "checked_on"
    case checkedById         = "checked_by_id"
  }
}
