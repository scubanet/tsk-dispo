import Foundation

public struct CurrentUser: Identifiable, Equatable {
  public enum Role: String, Codable {
    case instructor
    case dispatcher
    case owner
    case cd

    /// Lesbares Label für UI-Anzeige (z.B. "Course Director" statt "Cd").
    public var displayName: String {
      switch self {
      case .instructor: return "Instructor"
      case .dispatcher: return "Dispatcher"
      case .owner:      return "Owner"
      case .cd:         return "Course Director"
      }
    }
  }

  public init(
    id: UUID,
    instructorId: UUID?,
    firstName: String,
    lastName: String,
    email: String?,
    padiLevel: String,
    role: Role,
    authUserId: UUID?,
    preferredLanguage: String?,
    initials: String?,
    color: String?
  ) {
    self.id = id
    self.instructorId = instructorId
    self.firstName = firstName
    self.lastName = lastName
    self.email = email
    self.padiLevel = padiLevel
    self.role = role
    self.authUserId = authUserId
    self.preferredLanguage = preferredLanguage
    self.initials = initials
    self.color = color
  }

  /// Canonical Identifier ab Phase J — entspricht `contacts.id`.
  public let id: UUID

  /// Legacy `instructors.id` — bleibt als Alias bis Stores (Assignments, Movements,
  /// instructor_skills) in späteren Etappen auf `contacts.id` migriert sind.
  /// Nil, wenn der User noch keinen Legacy-Eintrag hat.
  public let instructorId: UUID?

  public let firstName: String
  public let lastName: String
  public let email: String?
  public let padiLevel: String
  public let role: Role
  public let authUserId: UUID?
  public let preferredLanguage: String?
  public let initials: String?
  /// Legacy-Avatar-Farbe aus `instructors.color`. Geht verloren wenn die
  /// Tabelle gedroppt wird — UI muss dann auf ID-Hash-Farbe ausweichen.
  public let color: String?

  /// Zusammengesetzter Anzeige-Name für Begrüssungen.
  public var name: String {
    let trimmed = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    return trimmed.isEmpty ? "—" : trimmed
  }

  /// Convenience für Stores die noch mit Legacy `instructors.id` arbeiten.
  /// Fällt auf `id` (= contacts.id) zurück wenn kein Legacy-Eintrag existiert —
  /// dann liefern die Stores einfach eine leere Liste.
  public var legacyInstructorId: UUID { instructorId ?? id }

  /// Fallback wenn ein auth.users-Account weder einem `contact_instructor` noch
  /// einem `instructors`-Eintrag verknüpft ist.
  public static func unlinked(authUserId: UUID) -> CurrentUser {
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
