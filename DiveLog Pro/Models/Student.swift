import Foundation
import SwiftData

@Model
final class Student {
    // All scalars have inline defaults — required for CloudKit integration.
    var firstName: String = ""
    var lastName: String = ""
    var email: String = ""
    var padiELearningID: String = ""
    var enrolledOn: Date = Date()
    var notes: String = ""

    // All relationships optional with array defaults.
    @Relationship(deleteRule: .nullify, inverse: \Dive.students)
    var dives: [Dive]? = []

    @Relationship(deleteRule: .nullify, inverse: \PoolSession.students)
    var poolSessions: [PoolSession]? = []

    @Relationship(deleteRule: .cascade, inverse: \SkillCompletion.student)
    var skillCompletions: [SkillCompletion]? = []

    init() {}

    // MARK: - Computed

    var fullName: String {
        [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
    }

    var initials: String {
        let first = firstName.first.map(String.init) ?? ""
        let last = lastName.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }

    /// Most recent activity (dive or pool) for sorting/recency filters.
    var lastActivityDate: Date? {
        let diveDate = (dives ?? []).map(\.date).max()
        let poolDate = (poolSessions ?? []).map(\.date).max()
        return [diveDate, poolDate].compactMap { $0 }.max()
    }
}
