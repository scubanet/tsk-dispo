import Foundation

/// Read-Modell für PostgREST `course_participants` join nested `student:contacts(...)`.
public struct CourseParticipant: Codable, Identifiable, Hashable {
  public let id: UUID
  public let courseId: UUID
  public let studentId: UUID
  public let status: Status
  public let certificateNr: String?
  public let notes: String?
  public let student: Student?

  public enum Status: String, Codable, Hashable {
    case enrolled, certified, dropped

    public var label: String {
      switch self {
      case .enrolled:  "Eingeschrieben"
      case .certified: "Zertifiziert"
      case .dropped:   "Abgebrochen"
      }
    }

    public func label(for locale: Locale) -> String {
      let isEn = locale.language.languageCode?.identifier == "en"
      switch self {
      case .enrolled:  return isEn ? "Enrolled"   : "Eingeschrieben"
      case .certified: return isEn ? "Certified"  : "Zertifiziert"
      case .dropped:   return isEn ? "Dropped"    : "Abgebrochen"
      }
    }

    /// Defensiv gegen zukünftige DB-Werte: unbekannte Status werden als
    /// `enrolled` interpretiert, statt die ganze Liste zu sprengen.
    public init(from decoder: Decoder) throws {
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
