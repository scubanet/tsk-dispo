import Testing
import Foundation
import SwiftData
@testable import DiveLog_Pro

@Suite("SkillCompletion model")
struct SkillCompletionTests {
    @MainActor
    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Dive.self, DiverProfile.self, DiveSite.self, Buddy.self, DiveSignature.self,
            Student.self, PoolSession.self, SkillCompletion.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: [config]))
    }

    @Test("SkillCompletion persists with student + dive context")
    @MainActor
    func persistsWithDive() throws {
        let ctx = try makeContext()
        let s = Student(); s.firstName = "Maya"
        let d = Dive(number: 1)
        d.courseType = "OWD"
        d.courseSlot = "OW2"
        ctx.insert(s); ctx.insert(d)

        let c = SkillCompletion()
        c.skillCode = "OW2.4"
        c.status = SkillStatus.mastered.rawValue
        c.student = s
        c.dive = d
        ctx.insert(c)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<SkillCompletion>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.skillCode == "OW2.4")
        #expect(fetched.first?.student?.firstName == "Maya")
        #expect(fetched.first?.dive?.courseSlot == "OW2")
        #expect(fetched.first?.poolSession == nil)
    }

    @Test("SkillCompletion persists with poolSession context")
    @MainActor
    func persistsWithPoolSession() throws {
        let ctx = try makeContext()
        let s = Student(); s.firstName = "Jan"
        let p = PoolSession(); p.slotCode = "CW2"
        ctx.insert(s); ctx.insert(p)

        let c = SkillCompletion()
        c.skillCode = "CW2.3"
        c.status = SkillStatus.practiced.rawValue
        c.student = s
        c.poolSession = p
        ctx.insert(c)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<SkillCompletion>())
        #expect(fetched.first?.poolSession?.slotCode == "CW2")
        #expect(fetched.first?.dive == nil)
    }

    @Test("Seed completion has nil dive and nil poolSession")
    @MainActor
    func seedCompletion() throws {
        let ctx = try makeContext()
        let s = Student(); s.firstName = "Sven"
        ctx.insert(s)
        let c = SkillCompletion()
        c.skillCode = "CW1.1"
        c.status = SkillStatus.mastered.rawValue
        c.student = s
        c.reviewNotes = "Seeded at enrollment"
        ctx.insert(c)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<SkillCompletion>())
        #expect(fetched.first?.dive == nil)
        #expect(fetched.first?.poolSession == nil)
        #expect(fetched.first?.reviewNotes == "Seeded at enrollment")
    }

    @Test("statusEnum returns SkillStatus from rawValue")
    @MainActor
    func statusEnum() {
        let c = SkillCompletion()
        c.status = "mastered"
        #expect(c.statusEnum == .mastered)
    }
}
