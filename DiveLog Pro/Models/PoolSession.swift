import Foundation
import SwiftData

@Model
final class PoolSession {
    var slotCode: String = "CW1"       // CW1-CW5
    var courseType: String = "OWD"      // OWD, AOWD (AOWD typically doesn't use pool, but allow it)
    var date: Date = Date()
    var durationMinutes: Int = 45
    var location: String = ""
    var notes: String = ""

    @Relationship(deleteRule: .nullify, inverse: \Student.poolSessions)
    var students: [Student]? = []

    @Relationship(deleteRule: .cascade, inverse: \SkillCompletion.poolSession)
    var skillAssessments: [SkillCompletion]? = []

    init() {}

    // MARK: - Computed

    var formattedDate: String {
        date.formatted(.dateTime.day().month(.abbreviated).year())
    }

    var formattedTime: String {
        date.formatted(.dateTime.hour().minute())
    }
}
