import Foundation
import SwiftData

@Model
final class SkillCompletion {
    // Scalar fields with inline defaults (CloudKit requirement).
    var skillCode: String = ""      // e.g. "OW2.4"
    var status: String = SkillStatus.notStarted.rawValue
    var assessedOn: Date = Date()
    var reviewNotes: String = ""

    // Context relationships — exactly one of dive/poolSession is set,
    // OR both nil for seed records (historical mastery).
    var student: Student?
    var dive: Dive?
    var poolSession: PoolSession?

    init() {}

    // MARK: - Computed

    var statusEnum: SkillStatus {
        SkillStatus(rawValue: status) ?? .notStarted
    }

    var isSeedRecord: Bool {
        dive == nil && poolSession == nil
    }
}
