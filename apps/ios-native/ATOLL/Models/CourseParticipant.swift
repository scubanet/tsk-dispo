import Foundation

/// Read-Modell für PostgREST `course_participants` join nested `student:contacts(...)`.
struct CourseParticipant: Codable, Identifiable, Hashable {
  let id: UUID
  let courseId: UUID
  let studentId: UUID
  let status: Status
  let certificateNr: String?
  let notes: String?
  let student: Student?

  enum Status: String, Codable, Hashable {
    case enrolled, certified, dropped

    var label: String {
      switch self {
      case .enrolled:  "Eingeschrieben"
      case .certified: "Zertifiziert"
      case .dropped:   "Abgebrochen"
      }
    }

    func label(for locale: Locale) -> String {
      let isEn = locale.language.languageCode?.identifier == "en"
      switch self {
      case .enrolled:  return isEn ? "Enrolled"   : "Eingeschrieben"
      case .certified: return isEn ? "Certified"  : "Zertifiziert"
      case .dropped:   return isEn ? "Dropped"    : "Abgebrochen"
      }
    }

    /// Defensiv gegen zukünftige DB-Werte: unbekannte Status werden als
    /// `enrolled` interpretiert, statt die ganze Liste zu sprengen.
    init(from decoder: Decoder) throws {
      let raw = try decoder.singleValueContainer().decode(String.self)
      self = Status(rawValue: raw) ?? .enrolled
    }
  }

  enum CodingKeys: String, CodingKey {
    case id, status, notes, student
    case courseId      = "course_id"
    case studentId     = "student_id"
    case certificateNr = "certificate_nr"
  }
}
