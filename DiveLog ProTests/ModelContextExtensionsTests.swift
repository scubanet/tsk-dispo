import Testing
import Foundation
import SwiftData
@testable import DiveLog_Pro

@Suite("ModelContext extensions")
struct ModelContextExtensionsTests {
    @MainActor
    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Dive.self, DiverProfile.self, DiveSite.self, Buddy.self, DiveSignature.self,
            Student.self, PoolSession.self, SkillCompletion.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: [config]))
    }

    @Test("cycleSkill creates a new completion record each call")
    @MainActor
    func cycleSkillAppends() throws {
        let ctx = try makeContext()
        let s = Student(); s.firstName = "Maya"
        let d = Dive(number: 1); d.courseType = "OWD"; d.courseSlot = "OW2"
        ctx.insert(s); ctx.insert(d)

        ctx.cycleSkill(student: s, skillCode: "OW2.1", context: .dive(d))
        ctx.cycleSkill(student: s, skillCode: "OW2.1", context: .dive(d))
        ctx.cycleSkill(student: s, skillCode: "OW2.1", context: .dive(d))

        let completions = try ctx.fetch(FetchDescriptor<SkillCompletion>())
        #expect(completions.count == 3)
        // First call: notStarted → introduced
        // Second: introduced → practiced
        // Third: practiced → mastered
        let statuses = completions.sorted(by: { $0.assessedOn < $1.assessedOn }).map(\.status)
        #expect(statuses == ["introduced", "practiced", "mastered"])
    }

    @Test("currentStatus returns latest completion")
    @MainActor
    func currentStatusLatest() throws {
        let ctx = try makeContext()
        let s = Student(); s.firstName = "Jan"
        ctx.insert(s)
        ctx.cycleSkill(student: s, skillCode: "CW1.1", context: .none)
        ctx.cycleSkill(student: s, skillCode: "CW1.1", context: .none)
        #expect(s.currentStatus(for: "CW1.1") == .practiced)
    }

    @Test("seedStudent inserts mastered records with nil context")
    @MainActor
    func seedStudentCreatesSeedRecords() throws {
        let ctx = try makeContext()
        let s = Student(); s.firstName = "Sven"
        ctx.insert(s)
        ctx.seedStudent(s, priorMastery: ["CW1.1", "CW1.2", "CW2.3"])

        let completions = try ctx.fetch(FetchDescriptor<SkillCompletion>())
        #expect(completions.count == 3)
        #expect(completions.allSatisfy { $0.status == "mastered" })
        #expect(completions.allSatisfy(\.isSeedRecord))
        #expect(completions.allSatisfy { $0.reviewNotes == "Seeded at enrollment" })
    }
}
