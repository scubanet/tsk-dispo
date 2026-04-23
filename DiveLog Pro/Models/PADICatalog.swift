import Foundation

// Plain Codable representation of the bundled PADI standard JSON files.
// Not a SwiftData model — this is immutable content shipped with the app.

struct PADICourse: Codable, Hashable {
    let version: String
    let course: String          // "OW", "AOW"
    let language: String        // "en", "de"
    let slots: [PADISlot]
}

struct PADISlot: Codable, Hashable, Identifiable {
    var id: String { code }
    let code: String            // "CW1", "OW2", "AOW-Deep"
    let title: String
    let type: SlotType          // pool or ocean
    let order: Int
    let skills: [PADISkill]

    enum SlotType: String, Codable {
        case pool
        case ocean
    }
}

struct PADISkill: Codable, Hashable, Identifiable {
    var id: String { code }
    let code: String            // "CW1.1", "OW2.4"
    let title: String
    let description: String
    let category: String        // "preparation", "surface", "underwater", "safety"
    let performanceStandard: String
    let deprecated: Bool?       // nil or false = active; true = retained for legacy records

    var isActive: Bool { !(deprecated ?? false) }
}
