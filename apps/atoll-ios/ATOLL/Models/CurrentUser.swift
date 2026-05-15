import Foundation

struct CurrentUser: Identifiable, Equatable {
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

  /// Canonical Identifier ab Phase J — entspricht `contacts.id`.
  let id: UUID

  /// Legacy `instructors.id` — bleibt als Alias bis Stores (Assignments, Movements,
  /// instructor_skills) in späteren Etappen auf `contacts.id` migriert sind.
  /// Nil, wenn der User noch keinen Legacy-Eintrag hat.
  let instructorId: UUID?

  let firstName: String
  let lastName: String
  let email: String?
  let padiLevel: String
  let role: Role
  let authUserId: UUID?
  let preferredLanguage: String?
  let initials: String?
  /// Legacy-Avatar-Farbe aus `instructors.color`. Geht verloren wenn die
  /// Tabelle gedroppt wird — UI muss dann auf ID-Hash-Farbe ausweichen.
  let color: String?

  /// Zusammengesetzter Anzeige-Name für Begrüssungen.
  var name: String {
    let trimmed = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    return trimmed.isEmpty ? "—" : trimmed
  }

  /// Convenience für Stores die noch mit Legacy `instructors.id` arbeiten.
  /// Fällt auf `id` (= contacts.id) zurück wenn kein Legacy-Eintrag existiert —
  /// dann liefern die Stores einfach eine leere Liste.
  var legacyInstructorId: UUID { instructorId ?? id }

  /// Fallback wenn ein auth.users-Account weder einem `contact_instructor` noch
  /// einem `instructors`-Eintrag verknüpft ist.
  static func unlinked(authUserId: UUID) -> CurrentUser {
    CurrentUser(
      id: authUserId,   // stable for the session; contacts.id is not available
      instructorId: nil,
      firstName: "—",
      lastName: "",
      email: nil,
      padiLevel: "—",
      role: .instructor,
      authUserId: authUserId,
      preferredLanguage: nil,
      initials: nil,
      color: nil
    )
  }
}
