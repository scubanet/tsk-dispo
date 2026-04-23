import Testing
import Foundation
import SwiftData
@testable import DiveLog_Pro

@Suite("PoolSession model")
struct PoolSessionTests {
    @MainActor
    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Dive.self, DiverProfile.self, DiveSite.self, Buddy.self, DiveSignature.self,
            Student.self, PoolSession.self, SkillCompletion.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: [config]))
    }

    @Test("PoolSession persists")
    @MainActor
    func persists() throws {
        let ctx = try makeContext()
        let p = PoolSession()
        p.slotCode = "CW2"
        p.courseType = "OWD"
        p.location = "Sutera Pool, KK"
        p.durationMinutes = 45
        ctx.insert(p)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<PoolSession>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.slotCode == "CW2")
    }

    @Test("PoolSession is NOT returned by Dive query")
    @MainActor
    func poolSessionExcludedFromDiveQuery() throws {
        let ctx = try makeContext()
        let d = Dive(number: 100)
        let p = PoolSession(); p.slotCode = "CW1"
        ctx.insert(d); ctx.insert(p)
        try ctx.save()

        let dives = try ctx.fetch(FetchDescriptor<Dive>())
        #expect(dives.count == 1)
        #expect(dives.first?.number == 100)
    }

    @Test("PoolSession with students many-to-many")
    @MainActor
    func manyToMany() throws {
        let ctx = try makeContext()
        let p = PoolSession(); p.slotCode = "CW3"
        let s1 = Student(); s1.firstName = "Maya"
        let s2 = Student(); s2.firstName = "Jan"
        p.students = [s1, s2]
        ctx.insert(p); ctx.insert(s1); ctx.insert(s2)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<PoolSession>()).first
        #expect(fetched?.students?.count == 2)

        let students = try ctx.fetch(FetchDescriptor<Student>())
        #expect(students.allSatisfy { ($0.poolSessions?.count ?? 0) == 1 })
    }
}
