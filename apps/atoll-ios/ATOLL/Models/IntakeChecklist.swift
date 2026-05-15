import Foundation

/// Pre-Dive-Intake-Datensatz pro course_participant. Nur die 3 Felder die
/// Instructors auf iOS setzen — die volle CD-IDC-Checkliste (Medical/EFR/
/// Logbook/…) bleibt Web-only.
struct IntakeChecklist: Codable, Identifiable, Hashable {
  let id: UUID?
  let courseParticipantId: UUID?
  let medicalSigned: Bool
  let liabilitySigned: Bool
  let safeDivingSigned: Bool
  let notes: String?
  let checkedOn: String?        // ISO date "yyyy-MM-dd"
  let checkedById: UUID?        // legacy instructors.id (siehe legacyInstructorId)

  /// Convenience: ist die Pre-Dive-Check komplett?
  var isComplete: Bool {
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
struct IntakeUpsert: Encodable {
  let courseParticipantId: UUID
  let medicalSigned: Bool
  let liabilitySigned: Bool
  let safeDivingSigned: Bool
  let notes: String?
  let checkedOn: String          // ISO yyyy-MM-dd
  let checkedById: UUID?

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
