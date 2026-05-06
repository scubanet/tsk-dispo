import Foundation

struct CurrentUser: Codable, Identifiable, Equatable {
  enum Role: String, Codable {
    case instructor
    case dispatcher
    case owner
    case cd

    /// Lesbares Label für UI-Anzeige (z.B. "Course Director" statt "Cd").
    var displayName: String {
      switch self {
      case .instructor: return "Instructor"
      case .dispatcher: return "Dispatcher"
      case .owner:      return "Owner"
      case .cd:         return "Course Director"
      }
    }
  }

  let id: UUID                  // instructors.id
  let name: String
  let email: String?
  let padiLevel: String
  let role: Role
  let authUserId: UUID?
  let color: String?
  let initials: String?

  enum CodingKeys: String, CodingKey {
    case id, name, email, role, color, initials
    case padiLevel = "padi_level"
    case authUserId = "auth_user_id"
  }

  /// Fallback wenn ein auth.users-Account nicht zu einem `instructors`-Eintrag verknüpft ist.
  static func unlinked(authUserId: UUID) -> CurrentUser {
    CurrentUser(
      id: UUID(),
      name: "—",
      email: nil,
      padiLevel: "—",
      role: .instructor,
      authUserId: authUserId,
      color: nil,
      initials: nil
    )
  }

  var firstName: String { name.split(separator: " ").first.map(String.init) ?? name }
}
