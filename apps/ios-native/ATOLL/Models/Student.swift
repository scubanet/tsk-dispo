import Foundation

/// Read-Modell für PostgREST `contacts` join `contact_student` (1:1 sidecar).
/// Wird in `CourseParticipant.student` eingebettet.
struct Student: Codable, Identifiable, Hashable {
  let id: UUID                       // = contacts.id
  let firstName: String
  let lastName: String
  let primaryEmail: String?
  let contactStudent: ContactStudentInfo?

  /// Convenience für UI — die zwei häufigsten Sidecar-Felder.
  var level: String? { contactStudent?.level }
  var photoUrl: String? { contactStudent?.photoUrl }

  var displayName: String {
    let trimmed = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    return trimmed.isEmpty ? "—" : trimmed
  }

  var initials: String {
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

  struct ContactStudentInfo: Codable, Hashable {
    let level: String?
    let photoUrl: String?

    enum CodingKeys: String, CodingKey {
      case level
      case photoUrl = "photo_url"
    }
  }
}
