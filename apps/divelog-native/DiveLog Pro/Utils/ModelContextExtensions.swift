import Foundation
import SwiftData
import UIKit

enum SkillAssessmentContext {
    case dive(Dive)
    case pool(PoolSession)
    case none   // seed / historical
}

extension ModelContext {
    /// Appends a new `SkillCompletion` record whose status is the cycleNext of the
    /// student's current status for this skill. Append-only — never mutates prior records.
    func cycleSkill(student: Student, skillCode: String, context: SkillAssessmentContext) {
        let current = student.currentStatus(for: skillCode)
        let next = current.cycleNext

        let completion = SkillCompletion()
        completion.skillCode = skillCode
        completion.status = next.rawValue
        completion.student = student
        completion.assessedOn = Date()
        switch context {
        case .dive(let d):  completion.dive = d
        case .pool(let p):  completion.poolSession = p
        case .none:         break
        }
        self.insert(completion)
        try? self.save()

        // Haptic: extra success on reaching mastered
        if next == .mastered {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    /// Directly sets a skill's status (used by long-press sheet where user picks any state).
    func setSkillStatus(_ status: SkillStatus, student: Student, skillCode: String,
                       context: SkillAssessmentContext, notes: String = "") {
        let completion = SkillCompletion()
        completion.skillCode = skillCode
        completion.status = status.rawValue
        completion.student = student
        completion.assessedOn = Date()
        completion.reviewNotes = notes
        switch context {
        case .dive(let d):  completion.dive = d
        case .pool(let p):  completion.poolSession = p
        case .none:         break
        }
        self.insert(completion)
        try? self.save()
    }

    /// Batch-create "mastered" completions for a student's prior slots (drop-in CD use case).
    /// Records have `dive == nil && poolSession == nil` and `reviewNotes = "Seeded at enrollment"`.
    func seedStudent(_ student: Student, priorMastery: Set<String>) {
        for skillCode in priorMastery {
            let c = SkillCompletion()
            c.skillCode = skillCode
            c.status = SkillStatus.mastered.rawValue
            c.student = student
            c.assessedOn = Date()
            c.reviewNotes = "Seeded at enrollment"
            self.insert(c)
        }
        try? self.save()
    }
}

extension Student {
    /// Current status for a skill = latest `SkillCompletion` by `assessedOn`.
    func currentStatus(for skillCode: String) -> SkillStatus {
        let latest = (skillCompletions ?? [])
            .filter { $0.skillCode == skillCode }
            .max(by: { $0.assessedOn < $1.assessedOn })
        return latest?.statusEnum ?? .notStarted
    }

    /// All history for a skill, newest first.
    func history(for skillCode: String) -> [SkillCompletion] {
        (skillCompletions ?? [])
            .filter { $0.skillCode == skillCode }
            .sorted(by: { $0.assessedOn > $1.assessedOn })
    }

    /// (mastered, total) for a given course type. Uses PADIStandards for total.
    func masteryProgress(courseType: String) -> (mastered: Int, total: Int) {
        let allSkills = PADIStandards.shared.allSkills(for: courseType)
        let masteredCodes = Set(
            Dictionary(grouping: skillCompletions ?? [], by: \.skillCode)
                .compactMapValues { $0.max(by: { $0.assessedOn < $1.assessedOn }) }
                .filter { $0.value.statusEnum == .mastered }
                .keys
        )
        let mastered = allSkills.filter { masteredCodes.contains($0.code) }.count
        return (mastered, allSkills.count)
    }
}

// MARK: - Numbering

extension ModelContext {

    /// Re-numbers every Dive in the store chronologically by `date`,
    /// starting at `profile.startingDiveNumber`. Idempotent — calling
    /// twice in a row leaves dives in the same state.
    ///
    /// PoolSessions have no `.number` property and are excluded.
    ///
    /// Performance: O(n) per call. Bulk imports should batch and call
    /// once at the end, not per insert.
    ///
    /// CloudKit-safety: because the result is a deterministic function
    /// of the dive set + starting number, two devices that both call
    /// this after a sync converge on the same numbering without a
    /// merge-conflict mechanism.
    func renumberDives(from profile: DiverProfile) {
        let descriptor = FetchDescriptor<Dive>(
            sortBy: [SortDescriptor(\Dive.date, order: .forward)]
        )
        guard let dives = try? fetch(descriptor) else { return }

        let start = profile.startingDiveNumber
        for (index, dive) in dives.enumerated() {
            let target = start + index
            if dive.number != target {
                dive.number = target
            }
        }
    }
}
