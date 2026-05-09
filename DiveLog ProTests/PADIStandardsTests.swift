import Testing
import Foundation
@testable import DiveLog_Pro

@Suite("PADIStandards loader")
struct PADIStandardsTests {
    @Test("OWD catalog loads with 9 slots")
    func owdCatalogHasNineSlots() {
        let slots = PADIStandards.shared.slots(for: "OWD")
        #expect(slots.count == 9)
    }

    @Test("CW1 has at least one skill (skeleton placeholder or filled content)")
    func cw1HasSkills() {
        let skills = PADIStandards.shared.skills(forSlot: "CW1", courseType: "OWD")
        #expect(skills.count >= 1)
        #expect(skills.contains { $0.code == "CW1.1" })
    }

    @Test("AOWD catalog loads with Deep + Nav as core")
    func aowdHasCoreSlots() {
        let slots = PADIStandards.shared.slots(for: "AOWD")
        #expect(slots.contains { $0.code == "AOWD-Deep" })
        #expect(slots.contains { $0.code == "AOWD-Nav" })
    }

    @Test("slot lookup for unknown course returns empty")
    func unknownCourseReturnsEmpty() {
        let slots = PADIStandards.shared.slots(for: "INVALID")
        #expect(slots.isEmpty)
    }

    @Test("active skills filter excludes deprecated entries")
    func deprecatedFiltered() {
        let all = PADIStandards.shared.skills(forSlot: "CW1", courseType: "OWD", activeOnly: false)
        let active = PADIStandards.shared.skills(forSlot: "CW1", courseType: "OWD", activeOnly: true)
        #expect(active.count <= all.count)
        #expect(active.allSatisfy { $0.isActive })
    }
}
