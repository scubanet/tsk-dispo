import Testing
import Foundation
@testable import DiveLog_Pro

@Suite("PADIStandards loader")
struct PADIStandardsTests {
    @Test("OW catalog loads with 9 slots")
    func owCatalogHasNineSlots() {
        let slots = PADIStandards.shared.slots(for: "OW")
        #expect(slots.count == 9)
    }

    @Test("CW1 has at least one skill (skeleton placeholder or filled content)")
    func cw1HasSkills() {
        let skills = PADIStandards.shared.skills(forSlot: "CW1", courseType: "OW")
        #expect(skills.count >= 1)
        #expect(skills.contains { $0.code == "CW1.1" })
    }

    @Test("AOW catalog loads with Deep + Nav as core")
    func aowHasCoreSlots() {
        let slots = PADIStandards.shared.slots(for: "AOW")
        #expect(slots.contains { $0.code == "AOW-Deep" })
        #expect(slots.contains { $0.code == "AOW-Nav" })
    }

    @Test("slot lookup for unknown course returns empty")
    func unknownCourseReturnsEmpty() {
        let slots = PADIStandards.shared.slots(for: "INVALID")
        #expect(slots.isEmpty)
    }

    @Test("active skills filter excludes deprecated entries")
    func deprecatedFiltered() {
        let all = PADIStandards.shared.skills(forSlot: "CW1", courseType: "OW", activeOnly: false)
        let active = PADIStandards.shared.skills(forSlot: "CW1", courseType: "OW", activeOnly: true)
        #expect(active.count <= all.count)
        #expect(active.allSatisfy { $0.isActive })
    }
}
