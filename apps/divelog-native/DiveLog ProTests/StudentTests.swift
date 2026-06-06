import Testing
import SwiftData
@testable import DiveLog_Pro

@Suite("Student model")
struct StudentTests {
    @MainActor
    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Dive.self, DiverProfile.self, DiveSite.self, Buddy.self, DiveSignature.self,
            Student.self, PoolSession.self, SkillCompletion.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    @Test("Student persists with firstName + lastName")
    @MainActor
    func studentPersists() throws {
        let ctx = try makeContext()
        let student = Student()
        student.firstName = "Maya"
        student.lastName = "Chen"
        ctx.insert(student)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<Student>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.firstName == "Maya")
        #expect(fetched.first?.lastName == "Chen")
    }

    @Test("fullName joins firstName and lastName")
    @MainActor
    func fullNameJoins() {
        let s = Student()
        s.firstName = "Jan"
        s.lastName = "Müller"
        #expect(s.fullName == "Jan Müller")
    }

    @Test("fullName handles missing lastName gracefully")
    @MainActor
    func fullNameNoLastName() {
        let s = Student()
        s.firstName = "Maya"
        #expect(s.fullName == "Maya")
    }

    @Test("parameterless init sets safe defaults")
    @MainActor
    func parameterlessInit() {
        let s = Student()
        #expect(s.firstName == "")
        #expect(s.lastName == "")
        #expect(s.email == "")
    }
}
