import Foundation

public struct Assignment: Codable, Identifiable, Hashable {
    public let id: UUID
    public let role: AssignmentRole
    public let confirmed: Bool
    public let course: Course?

    enum CodingKeys: String, CodingKey {
        case id, role, confirmed
        case course = "courses"
    }
}

public enum AssignmentRole: String, Codable, Hashable {
    case haupt, assist, opfer
    case dmt  // Legacy — bleibt für Decoding alter Daten, wird nicht mehr neu vergeben
}
