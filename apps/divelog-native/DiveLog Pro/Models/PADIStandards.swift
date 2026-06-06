import Foundation

/// Loads immutable PADI Performance Requirement catalogs from bundled JSON.
/// Non-SwiftData: ships with the app, updates via App Store releases.
final class PADIStandards {
    static let shared = PADIStandards()

    private var catalog: [String: PADICourse] = [:]  // key = course code ("OWD", "AOWD")

    private init() { load() }

    private func load() {
        let courses = ["owd", "aowd", "drysuit", "rescue"]
        let lang = L10n.currentLanguage  // "de" or "en"

        for course in courses {
            let localised = "\(course).\(lang)"

            // Xcode 15+ PBXFileSystemSynchronizedRootGroup flattens non-Swift resources
            // into the bundle root, so `subdirectory:` lookups can silently fail.
            // Try all four plausible locations before giving up.
            let url = Bundle.main.url(forResource: localised, withExtension: "json", subdirectory: "padi-standards")
                ?? Bundle.main.url(forResource: course,    withExtension: "json", subdirectory: "padi-standards")
                ?? Bundle.main.url(forResource: localised, withExtension: "json")
                ?? Bundle.main.url(forResource: course,    withExtension: "json")

            guard let url else {
                print("[PADIStandards] ⚠️ Missing catalog for \(course) (lang=\(lang))")
                print("[PADIStandards]   tried: padi-standards/\(localised).json, padi-standards/\(course).json, \(localised).json, \(course).json")
                if let bundlePath = Bundle.main.resourcePath {
                    let contents = (try? FileManager.default.contentsOfDirectory(atPath: bundlePath)) ?? []
                    let jsons = contents.filter { $0.hasSuffix(".json") }.sorted()
                    print("[PADIStandards]   bundle root JSONs: \(jsons)")
                }
                continue
            }

            do {
                let data = try Data(contentsOf: url)
                let decoded = try JSONDecoder().decode(PADICourse.self, from: data)
                catalog[decoded.course] = decoded
                print("[PADIStandards] ✅ Loaded \(decoded.course) (\(decoded.slots.count) slots) from \(url.lastPathComponent)")
            } catch {
                print("[PADIStandards] ❌ Failed to decode \(course): \(error)")
            }
        }
    }

    // MARK: - Public API

    func slots(for courseType: String) -> [PADISlot] {
        catalog[courseType]?.slots.sorted(by: { $0.order < $1.order }) ?? []
    }

    func slot(code: String, courseType: String) -> PADISlot? {
        slots(for: courseType).first { $0.code == code }
    }

    func skills(forSlot slotCode: String, courseType: String, activeOnly: Bool = true) -> [PADISkill] {
        let all = slot(code: slotCode, courseType: courseType)?.skills ?? []
        return activeOnly ? all.filter(\.isActive) : all
    }

    /// All skills across all slots of a course. Used for progress aggregation.
    func allSkills(for courseType: String, activeOnly: Bool = true) -> [PADISkill] {
        slots(for: courseType).flatMap { activeOnly ? $0.skills.filter(\.isActive) : $0.skills }
    }

    /// Look up a skill's title by code. Used in UI when referencing historical records.
    func title(forSkillCode code: String) -> String {
        skill(byCode: code)?.title ?? code
    }

    /// Look up a single skill by code across all courses.
    func skill(byCode code: String) -> PADISkill? {
        for course in catalog.values {
            for slot in course.slots {
                if let skill = slot.skills.first(where: { $0.code == code }) {
                    return skill
                }
            }
        }
        return nil
    }

    /// Flexible skills (FLEX slot) for a course — can be done on any ocean dive.
    func flexibleSkills(for courseType: String) -> [PADISkill] {
        slot(code: "FLEX", courseType: courseType)?.skills.filter(\.isActive) ?? []
    }

    /// All available courses (for cross-course skill picker).
    var availableCourses: [String] {
        Array(catalog.keys).sorted()
    }
}
