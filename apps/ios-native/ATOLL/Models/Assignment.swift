import Foundation

struct Assignment: Codable, Identifiable, Hashable {
    let id: UUID
    let role: AssignmentRole
    let confirmed: Bool
    let course: Course?

    enum CodingKeys: String, CodingKey {
        case id, role, confirmed
        case course = "courses"
    }
}

enum AssignmentRole: String, Codable, Hashable {
    case haupt, assist, opfer
    case dmt  // Legacy — bleibt für Decoding alter Daten, wird nicht mehr neu vergeben
}
