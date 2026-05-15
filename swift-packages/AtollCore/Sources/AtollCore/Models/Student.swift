import Foundation

/// Read-Modell für PostgREST `contacts` join `contact_student` (1:1 sidecar).
/// Wird in `CourseParticipant.student` eingebettet.
public struct Student: Codable, Identifiable, Hashable {
  public let id: UUID                       // = contacts.id
  public let firstName: String
  public let lastName: String
  public let primaryEmail: String?
  public let contactStudent: ContactStudentInfo?

  /// Convenience für UI — die zwei häufigsten Sidecar-Felder.
  public var level: String? { contactStudent?.level }
  public var photoUrl: String? { contactStudent?.photoUrl }

  public var displayName: String {
    let trimmed = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    return trimmed.isEmpty ? "—" : trimmed
  }

  public var initials: String {
    let f = firstName.first.map(String.init) ?? ""
    let l = lastName.first.map(String.init) ?? ""
    let combined = (f + l).uppercased()
    return combined.isEmpty ? "—" : combined
  }

  enum CodingKeys: String, CodingKey {
    case id
    case firstName = "first_name"
    case lastName = "last_name"
    case primaryEmail = "primary_email"
    case contactStudent = "contact_student"
  }

  public struct ContactStudentInfo: Codable, Hashable {
    public let level: String?
    public let photoUrl: String?

    enum CodingKeys: String, CodingKey {
      case level
      case photoUrl = "photo_url"
    }
  }
}
