import Testing
import Foundation
import SwiftData
@testable import DiveLog_Pro

@Suite("Dive Numbering")
struct NumberingTests {

    @MainActor
    private func makeContext(startingNumber: Int = 1000) throws -> (ModelContext, DiverProfile) {
        let schema = Schema([
            Dive.self, DivePhoto.self, DiverProfile.self, DiveSite.self, Buddy.self,
            DiveSignature.self, Student.self, PoolSession.self, SkillCompletion.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        let profile = DiverProfile(startingDiveNumber: startingNumber)
        context.insert(profile)
        try context.save()
        return (context, profile)
    }

    // MARK: - Empty + first dive

    @Test("first dive in an empty logbook starts at profile.startingDiveNumber")
    @MainActor
    func emptyLogbookFirstDive() throws {
        let (ctx, profile) = try makeContext(startingNumber: 1000)

        let dive = Dive(date: .now)
        ctx.insert(dive)
        ctx.renumberDives(from: profile)
        try ctx.save()

        #expect(dive.number == 1000)
    }

    // MARK: - Backdated insert

    @Test("dive added in the past renumbers existing dives upward")
    @MainActor
    func diveInPastRenumbers() throws {
        let (ctx, profile) = try makeContext(startingNumber: 100)

        let now = Date()
        let yesterday = now.addingTimeInterval(-86400)
        let lastWeek = now.addingTimeInterval(-7 * 86400)

        let d1 = Dive(date: yesterday)
        let d2 = Dive(date: now)
        ctx.insert(d1)
        ctx.insert(d2)
        ctx.renumberDives(from: profile)
        try ctx.save()

        #expect(d1.number == 100)
        #expect(d2.number == 101)

        // Insert a dive dated last week — should renumber d1 and d2 upward.
        let d0 = Dive(date: lastWeek)
        ctx.insert(d0)
        ctx.renumberDives(from: profile)
        try ctx.save()

        #expect(d0.number == 100)
        #expect(d1.number == 101)
        #expect(d2.number == 102)
    }

    // MARK: - Delete

    @Test("deleted dive causes remaining dives to renumber down")
    @MainActor
    func deletedDiveRenumbers() throws {
        let (ctx, profile) = try makeContext(startingNumber: 500)

        let now = Date()
        let dives = (0..<3).map { i in
            Dive(date: now.addingTimeInterval(Double(i) * 3600))
        }
        dives.forEach { ctx.insert($0) }
        ctx.renumberDives(from: profile)
        try ctx.save()

        #expect(dives.map(\.number) == [500, 501, 502])

        ctx.delete(dives[1])
        ctx.renumberDives(from: profile)
        try ctx.save()

        #expect(dives[0].number == 500)
        #expect(dives[2].number == 501)
    }

    // MARK: - Starting-number shift

    @Test("changing startingDiveNumber renumbers all existing dives")
    @MainActor
    func changingStartShiftsAll() throws {
        let (ctx, profile) = try makeContext(startingNumber: 1)

        let now = Date()
        let dives = (0..<3).map { i in
            Dive(date: now.addingTimeInterval(Double(i) * 3600))
        }
        dives.forEach { ctx.insert($0) }
        ctx.renumberDives(from: profile)
        try ctx.save()

        #expect(dives.map(\.number) == [1, 2, 3])

        profile.startingDiveNumber = 9000
        ctx.renumberDives(from: profile)
        try ctx.save()

        #expect(dives.map(\.number) == [9000, 9001, 9002])
    }

    // MARK: - Idempotency

    @Test("renumber is idempotent — running twice produces the same numbers")
    @MainActor
    func idempotent() throws {
        let (ctx, profile) = try makeContext(startingNumber: 42)

        let now = Date()
        let dives = (0..<5).map { i in
            Dive(date: now.addingTimeInterval(Double(i) * 3600))
        }
        dives.forEach { ctx.insert($0) }

        ctx.renumberDives(from: profile)
        let snap1 = dives.map(\.number)
        ctx.renumberDives(from: profile)
        let snap2 = dives.map(\.number)

        #expect(snap1 == snap2)
        #expect(snap1 == [42, 43, 44, 45, 46])
    }

    // MARK: - PoolSessions excluded

    @Test("renumberDives ignores PoolSessions and does not crash on them")
    @MainActor
    func poolSessionsExcluded() throws {
        let (ctx, profile) = try makeContext(startingNumber: 1)

        let dive = Dive(date: .now)
        let pool = PoolSession()
        pool.slotCode = "CW1"
        pool.courseType = "OWD"
        ctx.insert(dive)
        ctx.insert(pool)
        ctx.renumberDives(from: profile)
        try ctx.save()

        #expect(dive.number == 1)
        // PoolSession has no .number property — the test verifies that
        // renumberDives does not blow up when other model types coexist.
    }
}
