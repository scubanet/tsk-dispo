# Instructor Skill-Assessment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add per-student PADI performance-requirement tracking to DiveLog Pro, with a dive-centric architecture that supports the Course Director drop-in workflow.

**Architecture:** Three new SwiftData models (`Student`, `PoolSession`, `SkillCompletion`) plus additive fields on `Dive` (`courseType`, `courseSlot`, `students`). Append-only `SkillCompletion` records form an audit trail; "current status" = latest record per `(student, skillCode)`. Immutable PADI catalog lives in bundled JSON (DE + EN). Pool sessions are a separate entity so the existing `@Query(\Dive.date)` cleanly excludes them from dive counts.

**Tech Stack:** Swift 5.9+, SwiftUI, SwiftData + CloudKit (NSPersistentCloudKitContainer), iOS 17+, Swift Testing framework.

**Reference Spec:** `docs/superpowers/specs/2026-04-23-instructor-skill-assessment-design.md`

---

## File Structure

**New Models:**
- `DiveLog Pro/Models/Student.swift` — persistent @Model
- `DiveLog Pro/Models/PoolSession.swift` — persistent @Model
- `DiveLog Pro/Models/SkillCompletion.swift` — persistent @Model
- `DiveLog Pro/Models/SkillStatus.swift` — enum + cycle logic
- `DiveLog Pro/Models/PADIStandards.swift` — loader singleton
- `DiveLog Pro/Models/PADICatalog.swift` — Codable structs (Course, Slot, Skill)

**New Resources:**
- `DiveLog Pro/Resources/padi-standards/ow.json`, `ow.de.json`
- `DiveLog Pro/Resources/padi-standards/aow.json`, `aow.de.json`

**New Utilities:**
- `DiveLog Pro/Utils/ModelContextExtensions.swift` — `cycleSkill`, `seedStudent`

**New Components:**
- `DiveLog Pro/Views/Components/SkillStatusBadge.swift`
- `DiveLog Pro/Views/Components/SkillAssessmentGrid.swift`
- `DiveLog Pro/Views/Components/StudentPicker.swift`
- `DiveLog Pro/Views/Components/PreDivePreviewCard.swift`

**New Screens:**
- `DiveLog Pro/Views/Screens/PoolSessionCreateView.swift`
- `DiveLog Pro/Views/Screens/PoolSessionDetailView.swift`
- `DiveLog Pro/Views/Screens/QuickLogView.swift`
- `DiveLog Pro/Views/Screens/StudentProfileView.swift`
- `DiveLog Pro/Views/Screens/PriorMasterySeedSheet.swift`
- `DiveLog Pro/Views/Screens/SkillReviewSheet.swift`

**Modified Files:**
- `DiveLog Pro/Models/Dive.swift` — add `courseType`, `courseSlot`, `students`, `skillCompletions`
- `DiveLog Pro/Utils/DiveLogProApp.swift` — register new models in schema
- `DiveLog Pro/Views/Tabs/LogbookTab.swift` — FAB → Menu-FAB
- `DiveLog Pro/Views/Screens/DiveFormView.swift` — course fields + student picker + pre-dive preview
- `DiveLog Pro/Views/Screens/DiveDetailView.swift` — Schüler-Section

**New Tests:**
- `DiveLog ProTests/PADIStandardsTests.swift`
- `DiveLog ProTests/SkillStatusTests.swift`
- `DiveLog ProTests/StudentTests.swift`
- `DiveLog ProTests/SkillCompletionTests.swift`
- `DiveLog ProTests/PoolSessionTests.swift`
- `DiveLog ProTests/ModelContextExtensionsTests.swift`

---

# Phase 1 — Foundation (Models + Catalog + Migration)

## Task 1: SkillStatus Enum

**Files:**
- Create: `DiveLog Pro/Models/SkillStatus.swift`
- Test: `DiveLog ProTests/SkillStatusTests.swift`

- [ ] **Step 1.1: Write failing tests**

Create `DiveLog ProTests/SkillStatusTests.swift`:

```swift
import Testing
@testable import DiveLog_Pro

@Suite("SkillStatus")
struct SkillStatusTests {
    @Test("cycleNext progresses notStarted → introduced → practiced → mastered")
    func cycleNextProgression() {
        #expect(SkillStatus.notStarted.cycleNext == .introduced)
        #expect(SkillStatus.introduced.cycleNext == .practiced)
        #expect(SkillStatus.practiced.cycleNext == .mastered)
    }

    @Test("cycleNext from mastered resets to notStarted")
    func cycleFromMasteredResets() {
        #expect(SkillStatus.mastered.cycleNext == .notStarted)
    }

    @Test("cycleNext from needsReview resolves to practiced")
    func cycleFromNeedsReviewResolves() {
        #expect(SkillStatus.needsReview.cycleNext == .practiced)
    }

    @Test("raw values round-trip")
    func rawValueRoundTrip() {
        for status in SkillStatus.allCases {
            #expect(SkillStatus(rawValue: status.rawValue) == status)
        }
    }
}
```

- [ ] **Step 1.2: Run tests, verify they fail**

Run: `xcodebuild test -scheme "DiveLog Pro" -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:"DiveLog ProTests/SkillStatusTests"`
Expected: FAIL — `SkillStatus` is not defined.

- [ ] **Step 1.3: Implement SkillStatus**

Create `DiveLog Pro/Models/SkillStatus.swift`:

```swift
import Foundation
import SwiftUI

enum SkillStatus: String, CaseIterable, Codable {
    case notStarted
    case introduced
    case practiced
    case mastered
    case needsReview

    var cycleNext: SkillStatus {
        switch self {
        case .notStarted:  return .introduced
        case .introduced:  return .practiced
        case .practiced:   return .mastered
        case .mastered:    return .notStarted
        case .needsReview: return .practiced
        }
    }

    var displayLabel: String {
        let isDE = L10n.currentLanguage == "de"
        switch self {
        case .notStarted:  return isDE ? "Nicht begonnen" : "Not started"
        case .introduced:  return isDE ? "Eingeführt"     : "Introduced"
        case .practiced:   return isDE ? "Geübt"          : "Practiced"
        case .mastered:    return isDE ? "Gemeistert"     : "Mastered"
        case .needsReview: return isDE ? "Wdh. nötig"     : "Needs review"
        }
    }

    var sfSymbol: String {
        switch self {
        case .notStarted:  return "circle"
        case .introduced:  return "circle.lefthalf.filled"
        case .practiced:   return "circle.righthalf.filled"
        case .mastered:    return "checkmark.circle.fill"
        case .needsReview: return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .notStarted:  return .gray
        case .introduced:  return .blue.opacity(0.7)
        case .practiced:   return .orange
        case .mastered:    return .green
        case .needsReview: return .red
        }
    }
}
```

- [ ] **Step 1.4: Run tests, verify they pass**

Run the same xcodebuild command.
Expected: PASS (4/4 tests).

- [ ] **Step 1.5: Commit**

```bash
git add "DiveLog Pro/Models/SkillStatus.swift" "DiveLog ProTests/SkillStatusTests.swift"
git commit -m "feat: add SkillStatus enum with cycleNext logic"
```

---

## Task 2: PADICatalog Codable Models

**Files:**
- Create: `DiveLog Pro/Models/PADICatalog.swift`

- [ ] **Step 2.1: Implement PADICatalog structs**

Create `DiveLog Pro/Models/PADICatalog.swift`:

```swift
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
```

- [ ] **Step 2.2: Commit**

```bash
git add "DiveLog Pro/Models/PADICatalog.swift"
git commit -m "feat: add PADICatalog Codable structs"
```

---

## Task 3: PADI Standards JSON Content (OW English)

**Files:**
- Create: `DiveLog Pro/Resources/padi-standards/ow.json`

- [ ] **Step 3.1: Create directory and OW English JSON**

Create `DiveLog Pro/Resources/padi-standards/ow.json` with the full PADI Open Water Course Performance Requirements, taken from the current PADI OW Instructor Manual.

**Structure + representative sample (populate all 9 slots in full):**

```json
{
  "version": "2024.1",
  "course": "OW",
  "language": "en",
  "slots": [
    {
      "code": "CW1",
      "title": "Confined Water Dive 1",
      "type": "pool",
      "order": 1,
      "skills": [
        {
          "code": "CW1.1",
          "title": "Equipment Assembly and Donning",
          "description": "Assemble scuba unit correctly and don all equipment with buddy assistance.",
          "category": "preparation",
          "performanceStandard": "Student demonstrates correct scuba unit assembly and dons all equipment properly."
        },
        {
          "code": "CW1.2",
          "title": "Pre-dive Safety Check (BWRAF)",
          "description": "Conduct a complete pre-dive safety check with buddy.",
          "category": "preparation",
          "performanceStandard": "Student completes BWRAF with buddy before every dive."
        },
        {
          "code": "CW1.3",
          "title": "Proper Water Entry",
          "description": "Enter water using giant stride or controlled seated entry.",
          "category": "surface",
          "performanceStandard": "Student enters water safely without dislodging equipment."
        },
        {
          "code": "CW1.4",
          "title": "Regulator Breathing Underwater",
          "description": "Breathe continuously and comfortably from regulator.",
          "category": "underwater",
          "performanceStandard": "Student breathes normally underwater without equipment issues."
        }
      ]
    },
    {
      "code": "CW2",
      "title": "Confined Water Dive 2",
      "type": "pool",
      "order": 2,
      "skills": []
    },
    {
      "code": "CW3",
      "title": "Confined Water Dive 3",
      "type": "pool",
      "order": 3,
      "skills": []
    },
    {
      "code": "CW4",
      "title": "Confined Water Dive 4",
      "type": "pool",
      "order": 4,
      "skills": []
    },
    {
      "code": "CW5",
      "title": "Confined Water Dive 5",
      "type": "pool",
      "order": 5,
      "skills": []
    },
    {
      "code": "OW1",
      "title": "Open Water Dive 1",
      "type": "ocean",
      "order": 6,
      "skills": []
    },
    {
      "code": "OW2",
      "title": "Open Water Dive 2",
      "type": "ocean",
      "order": 7,
      "skills": []
    },
    {
      "code": "OW3",
      "title": "Open Water Dive 3",
      "type": "ocean",
      "order": 8,
      "skills": []
    },
    {
      "code": "OW4",
      "title": "Open Water Dive 4",
      "type": "ocean",
      "order": 9,
      "skills": []
    }
  ]
}
```

**Populate all 9 slots with the complete Performance Requirements from the PADI OW Instructor Manual** (24 CW skills + 20 OW skills total).

Canonical skill codes for reference:
- CW1: 4 skills (assembly, BWRAF, entry, regulator breathing)
- CW2: 5 skills (mask clearing, regulator recovery, air-sharing stationary, controlled descent with reference, neutral buoyancy introduction)
- CW3: 5 skills (giant-stride or controlled seated entry deep end, snorkel/regulator exchange at surface, partially flooded mask, no-mask breathing, neutral-buoyancy fin pivot)
- CW4: 5 skills (free-flow regulator breathing, weight system removal & replacement at surface, CESA simulation, mini-dive, neutral-buoyancy hover)
- CW5: 5 skills (skin-diving surface dive, scuba unit removal & replacement at surface, scuba unit removal & replacement underwater, emergency weight drop, loose cylinder adjustment)
- OW1: 5 skills (assembly check, BWRAF, giant-stride or controlled seated entry, regulator-snorkel exchange, controlled descent with reference)
- OW2: 5 skills (free-descent with reference, CESA 6–9m, underwater swim with compass straight-line, mask flood & clear, air-sharing ascent)
- OW3: 5 skills (controlled emergency swimming ascent, neutrally buoyant swim, loose cylinder underwater, underwater compass navigation 30m square)
- OW4: 5 skills (free-descent without reference, fin-pivot hovering, tired diver tow, neutrally buoyant exit, knowledge review)

- [ ] **Step 3.2: Commit**

```bash
git add "DiveLog Pro/Resources/padi-standards/ow.json"
git commit -m "feat: add PADI OW standards catalog (English)"
```

---

## Task 4: PADI Standards JSON Content (OW German)

**Files:**
- Create: `DiveLog Pro/Resources/padi-standards/ow.de.json`

- [ ] **Step 4.1: Create OW German JSON**

Translate the English file from Task 3 into German. Preserve all `code` values unchanged (only `title`, `description`, `performanceStandard` translate). Set `"language": "de"`.

Example for CW1.1:
```json
{
  "code": "CW1.1",
  "title": "Ausrüstung zusammenbauen und anziehen",
  "description": "Tauchausrüstung korrekt zusammenbauen und mit Buddy-Hilfe komplett anlegen.",
  "category": "preparation",
  "performanceStandard": "Schüler baut Scuba-Unit korrekt zusammen und legt alle Teile ordnungsgemäß an."
}
```

- [ ] **Step 4.2: Commit**

```bash
git add "DiveLog Pro/Resources/padi-standards/ow.de.json"
git commit -m "feat: add PADI OW standards catalog (German)"
```

---

## Task 5: PADI Standards JSON Content (AOW English + German)

**Files:**
- Create: `DiveLog Pro/Resources/padi-standards/aow.json`
- Create: `DiveLog Pro/Resources/padi-standards/aow.de.json`

- [ ] **Step 5.1: Create AOW English JSON**

Same structure as OW. Include **all AOW specialty dives**:

Core (required): `AOW-Deep`, `AOW-Nav`

Electives (include all from current PADI AOW manual):
`AOW-Night`, `AOW-PPB` (Peak Performance Buoyancy), `AOW-UWNav` (Underwater Navigator), `AOW-Wreck`, `AOW-Drift`, `AOW-Boat`, `AOW-SAR` (Search & Recovery), `AOW-FishID`, `AOW-DUP` (Digital Underwater Photographer), `AOW-EANx` (Enriched Air), `AOW-Naturalist`, `AOW-Altitude`, `AOW-DrySuit`, `AOW-DPV` (Diver Propulsion Vehicle), `AOW-Sidemount`, `AOW-SelfReliant`.

Each elective slot contains that specialty's Performance Requirements from its current PADI Adventures in Diving manual section (3–5 skills per slot typical).

- [ ] **Step 5.2: Create AOW German translation**

Translate `aow.json` → `aow.de.json`, preserve codes.

- [ ] **Step 5.3: Commit**

```bash
git add "DiveLog Pro/Resources/padi-standards/aow.json" "DiveLog Pro/Resources/padi-standards/aow.de.json"
git commit -m "feat: add PADI AOW standards catalog (EN + DE, all specialties)"
```

---

## Task 6: Register JSON Resources in Xcode Project

**Files:**
- Modify: `DiveLog Pro.xcodeproj/project.pbxproj`

- [ ] **Step 6.1: Add the `padi-standards` folder to the project**

In Xcode:
1. Right-click `DiveLog Pro` target in Project navigator → "Add Files to 'DiveLog Pro'…"
2. Select the `DiveLog Pro/Resources/padi-standards` folder
3. Check "Create folder references" (NOT "Create groups") — so the folder stays in sync
4. Ensure target membership: `DiveLog Pro` ✓
5. Verify build phase "Copy Bundle Resources" now includes `padi-standards`

- [ ] **Step 6.2: Verify bundling**

Build the app. Add a temporary print in `DiveLogProApp.init()`:

```swift
print("OW JSON URL:", Bundle.main.url(forResource: "ow", withExtension: "json", subdirectory: "padi-standards") as Any)
```

Run on simulator. Expected: prints a non-nil URL. Remove the print after verifying.

- [ ] **Step 6.3: Commit**

```bash
git add "DiveLog Pro.xcodeproj/project.pbxproj"
git commit -m "chore: bundle padi-standards folder as app resource"
```

---

## Task 7: PADIStandards Loader

**Files:**
- Create: `DiveLog Pro/Models/PADIStandards.swift`
- Test: `DiveLog ProTests/PADIStandardsTests.swift`

- [ ] **Step 7.1: Write failing tests**

Create `DiveLog ProTests/PADIStandardsTests.swift`:

```swift
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

    @Test("CW1 has at least 4 skills")
    func cw1HasSkills() {
        let skills = PADIStandards.shared.skills(forSlot: "CW1", courseType: "OW")
        #expect(skills.count >= 4)
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
```

- [ ] **Step 7.2: Run tests, verify they fail**

Run: `xcodebuild test -scheme "DiveLog Pro" -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:"DiveLog ProTests/PADIStandardsTests"`
Expected: FAIL — `PADIStandards` undefined.

- [ ] **Step 7.3: Implement loader**

Create `DiveLog Pro/Models/PADIStandards.swift`:

```swift
import Foundation

/// Loads immutable PADI Performance Requirement catalogs from bundled JSON.
/// Non-SwiftData: ships with the app, updates via App Store releases.
final class PADIStandards {
    static let shared = PADIStandards()

    private var catalog: [String: PADICourse] = [:]  // key = course code ("OW", "AOW")

    private init() { load() }

    private func load() {
        let courses = ["ow", "aow"]
        let lang = L10n.currentLanguage  // "de" or "en"

        for course in courses {
            let localised = "\(course).\(lang)"
            let url = Bundle.main.url(forResource: localised, withExtension: "json", subdirectory: "padi-standards")
                ?? Bundle.main.url(forResource: course, withExtension: "json", subdirectory: "padi-standards")

            guard let url else {
                print("[PADIStandards] ⚠️ Missing catalog for \(course) (lang=\(lang))")
                continue
            }

            do {
                let data = try Data(contentsOf: url)
                let decoded = try JSONDecoder().decode(PADICourse.self, from: data)
                catalog[decoded.course] = decoded
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
        for course in catalog.values {
            for slot in course.slots {
                if let skill = slot.skills.first(where: { $0.code == code }) {
                    return skill.title
                }
            }
        }
        return code
    }
}
```

- [ ] **Step 7.4: Run tests, verify they pass**

Run the same xcodebuild command.
Expected: PASS (5/5 tests).

- [ ] **Step 7.5: Commit**

```bash
git add "DiveLog Pro/Models/PADIStandards.swift" "DiveLog ProTests/PADIStandardsTests.swift"
git commit -m "feat: add PADIStandards bundle-JSON loader with localisation"
```

---

## Task 8: Student SwiftData Model

**Files:**
- Create: `DiveLog Pro/Models/Student.swift`
- Test: `DiveLog ProTests/StudentTests.swift`

- [ ] **Step 8.1: Write failing tests**

Create `DiveLog ProTests/StudentTests.swift`:

```swift
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
```

- [ ] **Step 8.2: Run tests, verify they fail**

Run: `xcodebuild test -scheme "DiveLog Pro" -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:"DiveLog ProTests/StudentTests"`
Expected: FAIL — `Student` undefined + schema won't match.

- [ ] **Step 8.3: Implement Student**

Create `DiveLog Pro/Models/Student.swift`:

```swift
import Foundation
import SwiftData

@Model
final class Student {
    // All scalars have inline defaults — required for CloudKit integration.
    var firstName: String = ""
    var lastName: String = ""
    var email: String = ""
    var padiELearningID: String = ""
    var enrolledOn: Date = Date()
    var notes: String = ""

    // All relationships optional with array defaults.
    @Relationship(deleteRule: .nullify, inverse: \Dive.students)
    var dives: [Dive]? = []

    @Relationship(deleteRule: .nullify, inverse: \PoolSession.students)
    var poolSessions: [PoolSession]? = []

    @Relationship(deleteRule: .cascade, inverse: \SkillCompletion.student)
    var skillCompletions: [SkillCompletion]? = []

    init() {}

    // MARK: - Computed

    var fullName: String {
        [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
    }

    var initials: String {
        let first = firstName.first.map(String.init) ?? ""
        let last = lastName.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }

    /// Most recent activity (dive or pool) for sorting/recency filters.
    var lastActivityDate: Date? {
        let diveDate = (dives ?? []).map(\.date).max()
        let poolDate = (poolSessions ?? []).map(\.date).max()
        return [diveDate, poolDate].compactMap { $0 }.max()
    }
}
```

- [ ] **Step 8.4: Commit (tests still fail — need Dive changes + PoolSession + SkillCompletion)**

```bash
git add "DiveLog Pro/Models/Student.swift" "DiveLog ProTests/StudentTests.swift"
git commit -m "feat: add Student SwiftData model (tests pending)"
```

---

## Task 9: SkillCompletion SwiftData Model

**Files:**
- Create: `DiveLog Pro/Models/SkillCompletion.swift`
- Test: `DiveLog ProTests/SkillCompletionTests.swift`

- [ ] **Step 9.1: Write failing tests**

Create `DiveLog ProTests/SkillCompletionTests.swift`:

```swift
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
        d.courseType = "OW"
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
```

- [ ] **Step 9.2: Implement SkillCompletion**

Create `DiveLog Pro/Models/SkillCompletion.swift`:

```swift
import Foundation
import SwiftData

@Model
final class SkillCompletion {
    // Scalar fields with inline defaults (CloudKit requirement).
    var skillCode: String = ""      // e.g. "OW2.4"
    var status: String = SkillStatus.notStarted.rawValue
    var assessedOn: Date = Date()
    var reviewNotes: String = ""

    // Context relationships — exactly one of dive/poolSession is set,
    // OR both nil for seed records (historical mastery).
    var student: Student?
    var dive: Dive?
    var poolSession: PoolSession?

    init() {}

    // MARK: - Computed

    var statusEnum: SkillStatus {
        SkillStatus(rawValue: status) ?? .notStarted
    }

    var isSeedRecord: Bool {
        dive == nil && poolSession == nil
    }
}
```

- [ ] **Step 9.3: Commit**

```bash
git add "DiveLog Pro/Models/SkillCompletion.swift" "DiveLog ProTests/SkillCompletionTests.swift"
git commit -m "feat: add SkillCompletion SwiftData model"
```

---

## Task 10: PoolSession SwiftData Model

**Files:**
- Create: `DiveLog Pro/Models/PoolSession.swift`
- Test: `DiveLog ProTests/PoolSessionTests.swift`

- [ ] **Step 10.1: Write failing tests**

Create `DiveLog ProTests/PoolSessionTests.swift`:

```swift
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
        p.courseType = "OW"
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
```

- [ ] **Step 10.2: Implement PoolSession**

Create `DiveLog Pro/Models/PoolSession.swift`:

```swift
import Foundation
import SwiftData

@Model
final class PoolSession {
    var slotCode: String = "CW1"       // CW1-CW5
    var courseType: String = "OW"      // OW, AOW (AOW typically doesn't use pool, but allow it)
    var date: Date = Date()
    var durationMinutes: Int = 45
    var location: String = ""
    var notes: String = ""

    @Relationship(deleteRule: .nullify, inverse: \Student.poolSessions)
    var students: [Student]? = []

    @Relationship(deleteRule: .cascade, inverse: \SkillCompletion.poolSession)
    var skillAssessments: [SkillCompletion]? = []

    init() {}

    // MARK: - Computed

    var formattedDate: String {
        date.formatted(.dateTime.day().month(.abbreviated).year())
    }

    var formattedTime: String {
        date.formatted(.dateTime.hour().minute())
    }
}
```

- [ ] **Step 10.3: Commit**

```bash
git add "DiveLog Pro/Models/PoolSession.swift" "DiveLog ProTests/PoolSessionTests.swift"
git commit -m "feat: add PoolSession SwiftData model"
```

---

## Task 11: Extend Dive with Course Fields

**Files:**
- Modify: `DiveLog Pro/Models/Dive.swift`

- [ ] **Step 11.1: Add new optional properties to Dive**

Edit `DiveLog Pro/Models/Dive.swift`. After the `buddies` relationship block (around line 86), add:

```swift
    // ─── Instructor / Course ─────────────
    // Optional — nil = recreational fun dive, not course-related.
    var courseType: String?        // "OW", "AOW"
    var courseSlot: String?        // "OW1", "OW2", "AOW-Deep"

    @Relationship(deleteRule: .nullify, inverse: \Student.dives)
    var students: [Student]? = []

    @Relationship(deleteRule: .cascade, inverse: \SkillCompletion.dive)
    var skillCompletions: [SkillCompletion]? = []
```

- [ ] **Step 11.2: Verify init still compiles**

The existing `init` signature doesn't need changes — new fields are all optional or have `[]` defaults. Build the app to confirm:

Run: `xcodebuild -scheme "DiveLog Pro" -destination 'platform=iOS Simulator,name=iPhone 15' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 11.3: Commit**

```bash
git add "DiveLog Pro/Models/Dive.swift"
git commit -m "feat(Dive): add courseType, courseSlot, students, skillCompletions"
```

---

## Task 12: Register New Models in Schema

**Files:**
- Modify: `DiveLog Pro/Utils/DiveLogProApp.swift`

- [ ] **Step 12.1: Add new models to Schema**

Edit `DiveLog Pro/Utils/DiveLogProApp.swift`, lines 52–58. Replace the `Schema([...])` block:

```swift
        let schema = Schema([
            Dive.self,
            DiverProfile.self,
            DiveSite.self,
            Buddy.self,
            DiveSignature.self,
            Student.self,
            PoolSession.self,
            SkillCompletion.self
        ])
```

- [ ] **Step 12.2: Run all tests — they should now pass**

Run: `xcodebuild test -scheme "DiveLog Pro" -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: All new tests pass (StudentTests, SkillCompletionTests, PoolSessionTests, PADIStandardsTests, SkillStatusTests).

- [ ] **Step 12.3: Launch app on simulator, verify migration**

Run the app on a clean simulator. Existing SampleData dives must still load (migration is lightweight — new fields are optional).

Manually test:
1. Fresh install → no crash
2. Launch after upgrading from a store with existing Dives → no crash, dives visible

- [ ] **Step 12.4: Commit**

```bash
git add "DiveLog Pro/Utils/DiveLogProApp.swift"
git commit -m "feat: register Student, PoolSession, SkillCompletion in ModelContainer"
```

---

## Task 13: ModelContext cycleSkill + seedStudent Helpers

**Files:**
- Create: `DiveLog Pro/Utils/ModelContextExtensions.swift`
- Test: `DiveLog ProTests/ModelContextExtensionsTests.swift`

- [ ] **Step 13.1: Write failing tests**

Create `DiveLog ProTests/ModelContextExtensionsTests.swift`:

```swift
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
        let d = Dive(number: 1); d.courseType = "OW"; d.courseSlot = "OW2"
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
```

- [ ] **Step 13.2: Implement ModelContext extensions**

Create `DiveLog Pro/Utils/ModelContextExtensions.swift`:

```swift
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
```

- [ ] **Step 13.3: Run tests, verify they pass**

Run: `xcodebuild test -scheme "DiveLog Pro" -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:"DiveLog ProTests/ModelContextExtensionsTests"`
Expected: PASS (3/3).

- [ ] **Step 13.4: Commit**

```bash
git add "DiveLog Pro/Utils/ModelContextExtensions.swift" "DiveLog ProTests/ModelContextExtensionsTests.swift"
git commit -m "feat: add cycleSkill, seedStudent, currentStatus helpers"
```

---

# Phase 2 — Core UX

## Task 14: SkillStatusBadge Component

**Files:**
- Create: `DiveLog Pro/Views/Components/SkillStatusBadge.swift`

- [ ] **Step 14.1: Implement SkillStatusBadge**

Create `DiveLog Pro/Views/Components/SkillStatusBadge.swift`:

```swift
import SwiftUI

struct SkillStatusBadge: View {
    let status: SkillStatus
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.sfSymbol)
                .font(.system(size: compact ? 11 : 13, weight: .semibold))
            if !compact {
                Text(status.displayLabel)
                    .font(.system(size: 11, weight: .medium))
            }
        }
        .foregroundStyle(status.color)
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(status.color.opacity(0.12))
        )
        .accessibilityLabel(status.displayLabel)
    }
}

#Preview {
    VStack(spacing: 8) {
        ForEach(SkillStatus.allCases, id: \.self) { s in
            HStack {
                SkillStatusBadge(status: s)
                SkillStatusBadge(status: s, compact: true)
            }
        }
    }
    .padding()
}
```

- [ ] **Step 14.2: Commit**

```bash
git add "DiveLog Pro/Views/Components/SkillStatusBadge.swift"
git commit -m "feat: add SkillStatusBadge component"
```

---

## Task 15: SkillReviewSheet (Long-Press Editor)

**Files:**
- Create: `DiveLog Pro/Views/Screens/SkillReviewSheet.swift`

- [ ] **Step 15.1: Implement SkillReviewSheet**

Create `DiveLog Pro/Views/Screens/SkillReviewSheet.swift`:

```swift
import SwiftUI
import SwiftData

struct SkillReviewSheet: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    let student: Student
    let skill: PADISkill
    let context: SkillAssessmentContext

    @State private var selectedStatus: SkillStatus
    @State private var notes: String = ""

    init(student: Student, skill: PADISkill, context: SkillAssessmentContext) {
        self.student = student
        self.skill = skill
        self.context = context
        _selectedStatus = State(initialValue: student.currentStatus(for: skill.code))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(skill.title).font(.headline)
                    Text(skill.performanceStandard)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                } header: {
                    Text(skill.code)
                }

                Section(L10n.currentLanguage == "de" ? "Status" : "Status") {
                    ForEach(SkillStatus.allCases, id: \.self) { s in
                        Button {
                            selectedStatus = s
                        } label: {
                            HStack {
                                SkillStatusBadge(status: s)
                                Spacer()
                                if s == selectedStatus {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.appAccent)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section(L10n.currentLanguage == "de" ? "Notiz" : "Notes") {
                    TextField(L10n.currentLanguage == "de" ? "Optional…" : "Optional…",
                              text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                if !student.history(for: skill.code).isEmpty {
                    Section(L10n.currentLanguage == "de" ? "Historie" : "History") {
                        ForEach(student.history(for: skill.code), id: \.assessedOn) { c in
                            HStack {
                                SkillStatusBadge(status: c.statusEnum, compact: true)
                                Text(c.assessedOn.formatted(.dateTime.day().month().year()))
                                    .font(.system(size: 12))
                                Spacer()
                                if c.isSeedRecord {
                                    Text("seed")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.tertiary)
                                } else if let diveNum = c.dive?.number {
                                    Text("TG #\(diveNum)")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.tertiary)
                                } else if c.poolSession != nil {
                                    Text("Pool")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(student.fullName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.currentLanguage == "de" ? "Abbrechen" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.currentLanguage == "de" ? "Speichern" : "Save") {
                        ctx.setSkillStatus(selectedStatus, student: student, skillCode: skill.code,
                                           context: context, notes: notes)
                        dismiss()
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 15.2: Commit**

```bash
git add "DiveLog Pro/Views/Screens/SkillReviewSheet.swift"
git commit -m "feat: add SkillReviewSheet for detailed skill editing"
```

---

## Task 16: SkillAssessmentGrid Component

**Files:**
- Create: `DiveLog Pro/Views/Components/SkillAssessmentGrid.swift`

- [ ] **Step 16.1: Implement SkillAssessmentGrid**

Create `DiveLog Pro/Views/Components/SkillAssessmentGrid.swift`:

```swift
import SwiftUI
import SwiftData

struct SkillAssessmentGrid: View {
    @Environment(\.modelContext) private var ctx
    let student: Student
    let slotCode: String
    let courseType: String
    let context: SkillAssessmentContext
    var readonly: Bool = false

    @State private var reviewing: PADISkill?

    private var skills: [PADISkill] {
        PADIStandards.shared.skills(forSlot: slotCode, courseType: courseType)
    }

    private var progress: (done: Int, total: Int) {
        let done = skills.filter { student.currentStatus(for: $0.code) == .mastered }.count
        return (done, skills.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            progressHeader
            ForEach(skills, id: \.code) { skill in
                skillRow(skill)
            }
            if !readonly { bulkActions }
        }
        .sheet(item: $reviewing) { skill in
            SkillReviewSheet(student: student, skill: skill, context: context)
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(L10n.currentLanguage == "de" ? "Fortschritt" : "Progress")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(progress.done)/\(progress.total)")
                    .font(.system(size: 13, weight: .bold).monospacedDigit())
                    .foregroundStyle(Color.appAccent)
            }
            ProgressView(value: Double(progress.done), total: Double(progress.total))
                .tint(Color.appAccent)
        }
    }

    private func skillRow(_ skill: PADISkill) -> some View {
        let status = student.currentStatus(for: skill.code)
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(skill.code)
                    .font(.system(size: 10, weight: .bold).monospaced())
                    .foregroundStyle(.tertiary)
                Text(skill.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.appText)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
            SkillStatusBadge(status: status, compact: false)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.appCard))
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture {
            guard !readonly else { return }
            ctx.cycleSkill(student: student, skillCode: skill.code, context: context)
        }
        .onLongPressGesture(minimumDuration: 0.4) {
            guard !readonly else { return }
            reviewing = skill
        }
        .swipeActions(edge: .trailing) {
            if !readonly {
                Button(role: .destructive) {
                    ctx.setSkillStatus(.notStarted, student: student, skillCode: skill.code,
                                       context: context)
                } label: {
                    Label(L10n.currentLanguage == "de" ? "Reset" : "Reset",
                          systemImage: "arrow.counterclockwise")
                }
            }
        }
    }

    private var bulkActions: some View {
        HStack(spacing: 8) {
            Button {
                for skill in skills {
                    ctx.setSkillStatus(.mastered, student: student, skillCode: skill.code,
                                       context: context)
                }
            } label: {
                Label(L10n.currentLanguage == "de" ? "Alle auf mastered" : "All to mastered",
                      systemImage: "checkmark.seal.fill")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
            .tint(.green)

            Button {
                for skill in skills where student.currentStatus(for: skill.code) == .notStarted {
                    ctx.setSkillStatus(.introduced, student: student, skillCode: skill.code,
                                       context: context)
                }
            } label: {
                Label(L10n.currentLanguage == "de" ? "Offene auf introduced" : "Pending to introduced",
                      systemImage: "arrow.right.circle")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
            .tint(.blue)
        }
        .padding(.top, 8)
    }
}
```

- [ ] **Step 16.2: Commit**

```bash
git add "DiveLog Pro/Views/Components/SkillAssessmentGrid.swift"
git commit -m "feat: add SkillAssessmentGrid with tap-cycle, long-press, swipe-reset, bulk actions"
```

---

## Task 17: StudentPicker Component

**Files:**
- Create: `DiveLog Pro/Views/Components/StudentPicker.swift`

- [ ] **Step 17.1: Implement StudentPicker**

Create `DiveLog Pro/Views/Components/StudentPicker.swift`:

```swift
import SwiftUI
import SwiftData

struct StudentPicker: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Student.enrolledOn, order: .reverse) private var allStudents: [Student]
    @Binding var selected: [Student]
    var allowCreate: Bool = true

    @State private var showingPicker = false
    @State private var showingNewStudentSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(selected) { student in
                HStack {
                    avatar(student)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(student.fullName).font(.system(size: 14, weight: .semibold))
                        if !student.padiELearningID.isEmpty {
                            Text(student.padiELearningID)
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Spacer()
                    Button {
                        selected.removeAll { $0.id == student.id }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.appCard))
            }
            Button {
                showingPicker = true
            } label: {
                Label(L10n.currentLanguage == "de" ? "Schüler hinzufügen" : "Add student",
                      systemImage: "person.badge.plus")
                    .font(.system(size: 14))
            }
            .buttonStyle(.bordered)
        }
        .sheet(isPresented: $showingPicker) {
            pickerSheet
        }
        .sheet(isPresented: $showingNewStudentSheet) {
            NewStudentSheet { newStudent in
                ctx.insert(newStudent)
                try? ctx.save()
                selected.append(newStudent)
            }
        }
    }

    private func avatar(_ s: Student) -> some View {
        Text(s.initials)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(Circle().fill(Color.appAccent))
    }

    @ViewBuilder
    private var pickerSheet: some View {
        NavigationStack {
            List {
                ForEach(allStudents) { s in
                    let isSelected = selected.contains { $0.id == s.id }
                    Button {
                        if isSelected {
                            selected.removeAll { $0.id == s.id }
                        } else {
                            selected.append(s)
                        }
                    } label: {
                        HStack {
                            avatar(s)
                            Text(s.fullName)
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.appAccent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle(L10n.currentLanguage == "de" ? "Schüler wählen" : "Select student")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.currentLanguage == "de" ? "Fertig" : "Done") { showingPicker = false }
                }
                if allowCreate {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingPicker = false
                            showingNewStudentSheet = true
                        } label: {
                            Label(L10n.currentLanguage == "de" ? "Neu" : "New", systemImage: "plus")
                        }
                    }
                }
            }
        }
    }
}

// Inline quick-create sheet (name + optional course + seed)
struct NewStudentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    let onCreate: (Student) -> Void

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var padiID = ""
    @State private var courseType = "OW"
    @State private var courseSlot = "OW1"
    @State private var seedChoice: SeedChoice = .skip
    @State private var showingSeedSheet = false

    enum SeedChoice: Hashable { case allMastered, partial, skip }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.currentLanguage == "de" ? "Schüler" : "Student") {
                    TextField(L10n.currentLanguage == "de" ? "Vorname *" : "First name *",
                              text: $firstName)
                    TextField(L10n.currentLanguage == "de" ? "Nachname *" : "Last name *",
                              text: $lastName)
                    TextField(L10n.currentLanguage == "de" ? "Email (optional)" : "Email (optional)",
                              text: $email)
                        .keyboardType(.emailAddress)
                    TextField("PADI eLearning ID (optional)", text: $padiID)
                }
                Section(L10n.currentLanguage == "de" ? "Kurs" : "Course") {
                    Picker("Kurs", selection: $courseType) {
                        Text("OW").tag("OW")
                        Text("AOW").tag("AOW")
                    }
                    Picker(L10n.currentLanguage == "de" ? "Aktueller Slot" : "Current slot",
                           selection: $courseSlot) {
                        ForEach(PADIStandards.shared.slots(for: courseType), id: \.code) { slot in
                            Text(slot.code).tag(slot.code)
                        }
                    }
                }
                Section(L10n.currentLanguage == "de" ? "Vorherige Slots?" : "Prior slots?") {
                    Picker("Seed", selection: $seedChoice) {
                        Text(L10n.currentLanguage == "de" ? "Alles gemeistert" : "All mastered")
                            .tag(SeedChoice.allMastered)
                        Text(L10n.currentLanguage == "de" ? "Teilweise…" : "Partial…")
                            .tag(SeedChoice.partial)
                        Text(L10n.currentLanguage == "de" ? "Überspringen" : "Skip")
                            .tag(SeedChoice.skip)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle(L10n.currentLanguage == "de" ? "Neuer Schüler" : "New student")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.currentLanguage == "de" ? "Abbrechen" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.currentLanguage == "de" ? "Anlegen" : "Create") {
                        let s = Student()
                        s.firstName = firstName
                        s.lastName = lastName
                        s.email = email
                        s.padiELearningID = padiID
                        handleSeed(for: s)
                        onCreate(s)
                        dismiss()
                    }
                    .disabled(firstName.isEmpty || lastName.isEmpty)
                }
            }
            .sheet(isPresented: $showingSeedSheet) {
                // Forward declaration — see Task 25 (PriorMasterySeedSheet)
            }
        }
    }

    private func handleSeed(for student: Student) {
        switch seedChoice {
        case .allMastered:
            // Seed everything before currentSlot
            let allSlots = PADIStandards.shared.slots(for: courseType)
            let currentOrder = allSlots.first { $0.code == courseSlot }?.order ?? 0
            let prior = allSlots.filter { $0.order < currentOrder }
            let codes = Set(prior.flatMap { $0.skills.map(\.code) })
            ctx.seedStudent(student, priorMastery: codes)
        case .partial:
            // Partial seed sheet opens after create in DiveCreate flow — for inline new-student
            // here we skip the partial-picker UI and just keep it unseeded. A follow-up seed can
            // be triggered from the Student Profile view.
            break
        case .skip:
            break
        }
    }
}
```

- [ ] **Step 17.2: Commit**

```bash
git add "DiveLog Pro/Views/Components/StudentPicker.swift"
git commit -m "feat: add StudentPicker with inline NewStudentSheet + seed choice"
```

---

## Task 18: LogbookTab FAB — Menu on Long-Press

**Files:**
- Modify: `DiveLog Pro/Views/Tabs/LogbookTab.swift`

- [ ] **Step 18.1: Locate current FAB implementation**

Run:
```bash
grep -n "Button\|addDive\|\"plus\"" "/sessions/beautiful-gifted-darwin/mnt/DiveLog Pro/DiveLog Pro/Views/Tabs/LogbookTab.swift" | head -10
```

- [ ] **Step 18.2: Replace the FAB with a Menu**

Locate the `Button { ... } label: { Image(systemName: "plus") ... }` FAB in `LogbookTab.swift` and replace with:

```swift
@State private var showingPoolCreate = false
@State private var showingQuickLog = false
@State private var showingDiveCreate = false
// ... add to @State block at top of LogbookTab

// Replace FAB button with:
Menu {
    Button {
        showingDiveCreate = true
    } label: {
        Label(L10n.currentLanguage == "de" ? "Tauchgang" : "Dive", systemImage: "water.waves")
    }
    Button {
        showingPoolCreate = true
    } label: {
        Label(L10n.currentLanguage == "de" ? "Pool-Session" : "Pool Session",
              systemImage: "figure.pool.swim")
    }
    Button {
        showingQuickLog = true
    } label: {
        Label(L10n.currentLanguage == "de" ? "Quick-Log" : "Quick Log",
              systemImage: "bolt.fill")
    }
} label: {
    Image(systemName: "plus")
        .font(.system(size: 24, weight: .bold))
        .foregroundStyle(.white)
        .frame(width: 56, height: 56)
        .background(Circle().fill(Color.appAccent))
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
} primaryAction: {
    showingDiveCreate = true   // Short tap = dive (preserves existing behaviour)
}
.sheet(isPresented: $showingDiveCreate) {
    DiveFormView()
}
.sheet(isPresented: $showingPoolCreate) {
    PoolSessionCreateView()
}
.sheet(isPresented: $showingQuickLog) {
    QuickLogView()
}
```

(Remove the old `@State private var showingAddDive` and its sheet if duplicated.)

- [ ] **Step 18.3: Build — expect missing symbols**

Run: `xcodebuild -scheme "DiveLog Pro" -destination 'platform=iOS Simulator,name=iPhone 15' build`
Expected: FAIL — `PoolSessionCreateView` and `QuickLogView` undefined. Next tasks add them.

- [ ] **Step 18.4: Commit (build broken, temporary)**

```bash
git add "DiveLog Pro/Views/Tabs/LogbookTab.swift"
git commit -m "feat(LogbookTab): convert FAB to Menu — Dive/Pool/QuickLog"
```

---

## Task 19: PoolSessionCreateView

**Files:**
- Create: `DiveLog Pro/Views/Screens/PoolSessionCreateView.swift`

- [ ] **Step 19.1: Implement**

Create `DiveLog Pro/Views/Screens/PoolSessionCreateView.swift`:

```swift
import SwiftUI
import SwiftData

struct PoolSessionCreateView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    @State private var slotCode = "CW1"
    @State private var courseType = "OW"
    @State private var date = Date()
    @State private var durationMinutes: Int = 45
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var students: [Student] = []
    @State private var showingAssessment = false
    @State private var createdSession: PoolSession?

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.currentLanguage == "de" ? "Session" : "Session") {
                    Picker("Kurs", selection: $courseType) {
                        Text("OW").tag("OW")
                        Text("AOW").tag("AOW")
                    }
                    Picker(L10n.currentLanguage == "de" ? "Slot" : "Slot", selection: $slotCode) {
                        ForEach(PADIStandards.shared.slots(for: courseType)
                                    .filter { $0.type == .pool }, id: \.code) { slot in
                            Text(slot.code).tag(slot.code)
                        }
                    }
                    DatePicker(L10n.currentLanguage == "de" ? "Datum" : "Date",
                               selection: $date)
                    Stepper("\(durationMinutes) min", value: $durationMinutes, in: 15...180, step: 5)
                    TextField(L10n.currentLanguage == "de" ? "Ort" : "Location", text: $location)
                }
                Section(L10n.currentLanguage == "de" ? "Schüler" : "Students") {
                    StudentPicker(selected: $students)
                }
                Section(L10n.currentLanguage == "de" ? "Notizen" : "Notes") {
                    TextField("", text: $notes, axis: .vertical).lineLimit(3...6)
                }
            }
            .navigationTitle(L10n.currentLanguage == "de" ? "Pool-Session" : "Pool Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.currentLanguage == "de" ? "Abbrechen" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.currentLanguage == "de" ? "Speichern" : "Save") {
                        let p = PoolSession()
                        p.slotCode = slotCode
                        p.courseType = courseType
                        p.date = date
                        p.durationMinutes = durationMinutes
                        p.location = location
                        p.notes = notes
                        p.students = students
                        ctx.insert(p)
                        try? ctx.save()
                        createdSession = p
                        showingAssessment = true
                    }
                    .disabled(students.isEmpty)
                }
            }
            .navigationDestination(isPresented: $showingAssessment) {
                if let session = createdSession {
                    PoolSessionDetailView(session: session)
                        .onDisappear { dismiss() }
                }
            }
        }
    }
}
```

- [ ] **Step 19.2: Commit**

```bash
git add "DiveLog Pro/Views/Screens/PoolSessionCreateView.swift"
git commit -m "feat: add PoolSessionCreateView"
```

---

## Task 20: PoolSessionDetailView

**Files:**
- Create: `DiveLog Pro/Views/Screens/PoolSessionDetailView.swift`

- [ ] **Step 20.1: Implement**

Create `DiveLog Pro/Views/Screens/PoolSessionDetailView.swift`:

```swift
import SwiftUI
import SwiftData

struct PoolSessionDetailView: View {
    @Bindable var session: PoolSession
    @State private var selectedStudentID: PersistentIdentifier?

    private var students: [Student] { session.students ?? [] }
    private var selectedStudent: Student? {
        students.first { $0.id == selectedStudentID } ?? students.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if students.count > 1 {
                    studentPicker
                }
                if let student = selectedStudent {
                    SkillAssessmentGrid(
                        student: student,
                        slotCode: session.slotCode,
                        courseType: session.courseType,
                        context: .pool(session)
                    )
                }
            }
            .padding()
        }
        .navigationTitle("\(session.slotCode) · \(session.formattedDate)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if selectedStudentID == nil { selectedStudentID = students.first?.id }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "figure.pool.swim").foregroundStyle(Color.appAccent)
                Text(session.courseType).font(.headline)
                Text("·").foregroundStyle(.tertiary)
                Text(session.slotCode).font(.headline)
            }
            if !session.location.isEmpty {
                Text(session.location)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Text("\(session.durationMinutes) min · \(session.formattedTime)")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
    }

    private var studentPicker: some View {
        Picker("", selection: $selectedStudentID) {
            ForEach(students) { s in
                Text(s.fullName).tag(Optional(s.id))
            }
        }
        .pickerStyle(.segmented)
    }
}
```

- [ ] **Step 20.2: Rebuild — should succeed**

Run: `xcodebuild -scheme "DiveLog Pro" -destination 'platform=iOS Simulator,name=iPhone 15' build`
Expected: Still fails (`QuickLogView` undefined). Proceed.

- [ ] **Step 20.3: Commit**

```bash
git add "DiveLog Pro/Views/Screens/PoolSessionDetailView.swift"
git commit -m "feat: add PoolSessionDetailView with student-segmented skill grid"
```

---

## Task 21: DiveFormView — Course Fields + StudentPicker

**Files:**
- Modify: `DiveLog Pro/Views/Screens/DiveFormView.swift`

- [ ] **Step 21.1: Add course state + picker section**

In `DiveFormView.swift`, near other `@State` declarations, add:

```swift
@State private var isCourseTraining = false
@State private var courseType = "OW"
@State private var courseSlot = "OW1"
@State private var students: [Student] = []
```

After the existing `diveType` picker section, add a new Section:

```swift
Section {
    Toggle(L10n.currentLanguage == "de" ? "Kurs-Tauchgang" : "Course dive",
           isOn: $isCourseTraining)
    if isCourseTraining {
        Picker(L10n.currentLanguage == "de" ? "Kurs" : "Course", selection: $courseType) {
            Text("OW").tag("OW")
            Text("AOW").tag("AOW")
        }
        Picker(L10n.currentLanguage == "de" ? "Slot" : "Slot", selection: $courseSlot) {
            ForEach(PADIStandards.shared.slots(for: courseType)
                        .filter { $0.type == .ocean }, id: \.code) { slot in
                Text(slot.code).tag(slot.code)
            }
        }
        StudentPicker(selected: $students)
        if !students.isEmpty {
            ForEach(students) { student in
                PreDivePreviewCard(student: student, slotCode: courseSlot, courseType: courseType)
            }
        }
    }
} header: {
    Text(L10n.currentLanguage == "de" ? "Kurs & Schüler" : "Course & Students")
}
```

- [ ] **Step 21.2: Hook save to assign course fields**

In the save-action closure, after `dive.diveType = ...`, add:

```swift
if isCourseTraining {
    dive.courseType = courseType
    dive.courseSlot = courseSlot
    dive.students = students
} else {
    dive.courseType = nil
    dive.courseSlot = nil
    dive.students = []
}
```

- [ ] **Step 21.3: Commit (still broken — PreDivePreviewCard + QuickLogView pending)**

```bash
git add "DiveLog Pro/Views/Screens/DiveFormView.swift"
git commit -m "feat(DiveFormView): add course-training toggle + slot + student picker"
```

---

## Task 22: PreDivePreviewCard

**Files:**
- Create: `DiveLog Pro/Views/Components/PreDivePreviewCard.swift`

- [ ] **Step 22.1: Implement**

Create `DiveLog Pro/Views/Components/PreDivePreviewCard.swift`:

```swift
import SwiftUI

struct PreDivePreviewCard: View {
    let student: Student
    let slotCode: String
    let courseType: String

    @State private var expanded = false

    private var slotSkills: [PADISkill] {
        PADIStandards.shared.skills(forSlot: slotCode, courseType: courseType)
    }

    private var mastered: [PADISkill] {
        PADIStandards.shared.allSkills(for: courseType).filter {
            student.currentStatus(for: $0.code) == .mastered
        }
    }

    private var needsReview: [PADISkill] {
        PADIStandards.shared.allSkills(for: courseType).filter {
            student.currentStatus(for: $0.code) == .needsReview
        }
    }

    private var hasHistory: Bool {
        !(student.skillCompletions ?? []).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation { expanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .foregroundStyle(Color.appAccent)
                    Text(L10n.currentLanguage == "de" ? "Pre-Dive-Check" : "Pre-Dive Check")
                        .font(.system(size: 13, weight: .semibold))
                    Text("· \(student.fullName)").font(.system(size: 12)).foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            if expanded {
                if !hasHistory {
                    noHistoryCard
                } else {
                    summaryLines
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.appCard.opacity(0.6)))
    }

    private var noHistoryCard: some View {
        HStack {
            Image(systemName: "info.circle").foregroundStyle(.orange)
            Text(L10n.currentLanguage == "de"
                 ? "Keine Historie. Starte heute mit \(slotCode)."
                 : "No history. Start today at \(slotCode).")
                .font(.system(size: 12))
        }
    }

    private var summaryLines: some View {
        VStack(alignment: .leading, spacing: 6) {
            line(label: L10n.currentLanguage == "de" ? "Bereits gemeistert" : "Already mastered",
                 count: mastered.count, icon: "checkmark.seal.fill", color: .green)
            line(label: L10n.currentLanguage == "de" ? "Heute zu üben (\(slotCode))" : "To practice today (\(slotCode))",
                 count: slotSkills.filter { student.currentStatus(for: $0.code) != .mastered }.count,
                 icon: "target", color: .blue)
            if !needsReview.isEmpty {
                line(label: L10n.currentLanguage == "de" ? "Wdh. nötig" : "Needs review",
                     count: needsReview.count, icon: "exclamationmark.triangle.fill", color: .red)
            }
        }
    }

    private func line(label: String, count: Int, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(color)
            Text(label).font(.system(size: 12))
            Spacer()
            Text("\(count)").font(.system(size: 12, weight: .bold).monospacedDigit())
                .foregroundStyle(color)
        }
    }
}
```

- [ ] **Step 22.2: Commit**

```bash
git add "DiveLog Pro/Views/Components/PreDivePreviewCard.swift"
git commit -m "feat: add PreDivePreviewCard showing mastered/pending/needsReview per student"
```

---

## Task 23: DiveDetailView — Schüler-Section

**Files:**
- Modify: `DiveLog Pro/Views/Screens/DiveDetailView.swift`

- [ ] **Step 23.1: Add Schüler section at top of ScrollView**

In `DiveDetailView.swift`, inside the main `ScrollView { VStack(spacing: 0) { ... } }` body (around line 39), insert **before** the existing header block:

```swift
if dive.courseType != nil && (dive.students?.count ?? 0) > 0 {
    studentsSection
        .padding(16)
        .background(Color.appCard)
        .cornerRadius(16)
        .padding(.horizontal)
        .padding(.top, 8)
}
```

At the end of the `DiveDetailView` struct (before the closing brace), add:

```swift
@State private var selectedStudentID: PersistentIdentifier? = nil

@ViewBuilder
private var studentsSection: some View {
    let students = dive.students ?? []
    let slot = dive.courseSlot ?? ""
    let course = dive.courseType ?? "OW"

    VStack(alignment: .leading, spacing: 12) {
        HStack {
            Image(systemName: "graduationcap.fill").foregroundStyle(Color.appAccent)
            Text(L10n.currentLanguage == "de"
                 ? "\(course) · \(slot) · \(students.count) Schüler"
                 : "\(course) · \(slot) · \(students.count) students")
                .font(.system(size: 14, weight: .semibold))
        }
        if students.count > 1 {
            Picker("", selection: $selectedStudentID) {
                ForEach(students) { s in
                    Text(s.fullName).tag(Optional(s.id))
                }
            }
            .pickerStyle(.segmented)
        }
        if let selected = students.first(where: { $0.id == selectedStudentID }) ?? students.first {
            SkillAssessmentGrid(
                student: selected,
                slotCode: slot,
                courseType: course,
                context: .dive(dive)
            )
        }
    }
    .onAppear {
        if selectedStudentID == nil { selectedStudentID = students.first?.id }
    }
}
```

- [ ] **Step 23.2: Build + smoke test**

Run: `xcodebuild -scheme "DiveLog Pro" -destination 'platform=iOS Simulator,name=iPhone 15' build`
Expected: still FAIL (`QuickLogView` undefined). Next tasks fix.

- [ ] **Step 23.3: Commit**

```bash
git add "DiveLog Pro/Views/Screens/DiveDetailView.swift"
git commit -m "feat(DiveDetailView): add Schüler-Section with per-student skill grid"
```

---

## Task 24: Dive-Delete Confirmation Dialog with Assessment Count

**Files:**
- Modify: `DiveLog Pro/Views/Tabs/LogbookTab.swift` (or wherever dive-delete is invoked)

- [ ] **Step 24.1: Find current delete flow**

```bash
grep -n "delete\|Delete" "/sessions/beautiful-gifted-darwin/mnt/DiveLog Pro/DiveLog Pro/Views/Tabs/LogbookTab.swift" | head -10
grep -n "delete\|Delete" "/sessions/beautiful-gifted-darwin/mnt/DiveLog Pro/DiveLog Pro/Services/DeleteUndoManager.swift" | head -10
```

- [ ] **Step 24.2: Add confirmation dialog**

Wherever the delete is triggered for a Dive (likely a swipe-action), wrap the delete trigger in a confirmation that counts linked students and assessments:

```swift
@State private var pendingDelete: Dive?

// In swipe action or delete button:
Button(role: .destructive) {
    pendingDelete = dive
} label: {
    Label(L10n.currentLanguage == "de" ? "Löschen" : "Delete", systemImage: "trash")
}

// As a view modifier on the List or parent:
.confirmationDialog(
    confirmMessage(for: pendingDelete),
    isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
    titleVisibility: .visible
) {
    Button(L10n.currentLanguage == "de" ? "Löschen" : "Delete", role: .destructive) {
        if let d = pendingDelete {
            deleteUndoManager.scheduleDelete(dive: d, in: ctx)
        }
        pendingDelete = nil
    }
    Button(L10n.currentLanguage == "de" ? "Abbrechen" : "Cancel", role: .cancel) {
        pendingDelete = nil
    }
}

// Helper:
private func confirmMessage(for dive: Dive?) -> String {
    guard let dive else { return "" }
    let assessments = dive.skillCompletions?.count ?? 0
    let studentCount = dive.students?.count ?? 0
    let isDE = L10n.currentLanguage == "de"
    if assessments > 0 {
        return isDE
            ? "TG #\(dive.number) löschen?\n\(assessments) Skill-Assessments für \(studentCount) Schüler werden ebenfalls gelöscht."
            : "Delete dive #\(dive.number)?\n\(assessments) skill assessments for \(studentCount) students will also be deleted."
    }
    return isDE ? "TG #\(dive.number) löschen?" : "Delete dive #\(dive.number)?"
}
```

- [ ] **Step 24.3: Commit**

```bash
git add "DiveLog Pro/Views/Tabs/LogbookTab.swift"
git commit -m "feat(LogbookTab): confirmation dialog for dive delete with assessment count"
```

---

# Phase 3 — Drop-In Magic

## Task 25: PriorMasterySeedSheet

**Files:**
- Create: `DiveLog Pro/Views/Screens/PriorMasterySeedSheet.swift`

- [ ] **Step 25.1: Implement**

Create `DiveLog Pro/Views/Screens/PriorMasterySeedSheet.swift`:

```swift
import SwiftUI
import SwiftData

struct PriorMasterySeedSheet: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    let student: Student
    let courseType: String
    let upToSlotOrder: Int    // seed only slots with order < this

    @State private var selected: Set<String> = []

    private var priorSlots: [PADISlot] {
        PADIStandards.shared.slots(for: courseType)
            .filter { $0.order < upToSlotOrder }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(priorSlots) { slot in
                    Section {
                        ForEach(slot.skills, id: \.code) { skill in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(skill.code).font(.system(size: 10, weight: .bold).monospaced())
                                        .foregroundStyle(.tertiary)
                                    Text(skill.title).font(.system(size: 14))
                                }
                                Spacer()
                                Image(systemName: selected.contains(skill.code)
                                      ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(selected.contains(skill.code)
                                                     ? Color.appAccent : .secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selected.contains(skill.code) {
                                    selected.remove(skill.code)
                                } else {
                                    selected.insert(skill.code)
                                }
                            }
                        }
                    } header: {
                        HStack {
                            Text(slot.code).font(.system(size: 12, weight: .bold))
                            Text(slot.title).font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(L10n.currentLanguage == "de" ? "Bisher gemeistert" : "Prior mastery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.currentLanguage == "de" ? "Abbrechen" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.currentLanguage == "de" ? "Übernehmen (\(selected.count))"
                                                      : "Apply (\(selected.count))") {
                        ctx.seedStudent(student, priorMastery: selected)
                        dismiss()
                    }
                    .disabled(selected.isEmpty)
                }
            }
        }
    }
}
```

- [ ] **Step 25.2: Wire into NewStudentSheet partial-seed path**

In `StudentPicker.swift`'s `NewStudentSheet.handleSeed(for:)`, replace the `.partial:` branch:

```swift
case .partial:
    let allSlots = PADIStandards.shared.slots(for: courseType)
    let currentOrder = allSlots.first { $0.code == courseSlot }?.order ?? 0
    // Defer to PriorMasterySeedSheet — opened from caller context (student profile).
    // Set a marker in UserDefaults so the Student Profile suggests "Seed nachtragen".
    UserDefaults.standard.set(true, forKey: "seedPending.\(student.persistentModelID)")
    _ = currentOrder
```

(Simpler path: when "partial" is chosen, create the student without seeding; the profile view detects this and offers the sheet.)

- [ ] **Step 25.3: Commit**

```bash
git add "DiveLog Pro/Views/Screens/PriorMasterySeedSheet.swift" "DiveLog Pro/Views/Components/StudentPicker.swift"
git commit -m "feat: add PriorMasterySeedSheet with skill-by-skill checklist"
```

---

## Task 26: StudentProfileView

**Files:**
- Create: `DiveLog Pro/Views/Screens/StudentProfileView.swift`

- [ ] **Step 26.1: Implement**

Create `DiveLog Pro/Views/Screens/StudentProfileView.swift`:

```swift
import SwiftUI
import SwiftData

struct StudentProfileView: View {
    @Bindable var student: Student
    @State private var courseType = "OW"
    @State private var showingSeedSheet = false

    private var progress: (mastered: Int, total: Int) {
        student.masteryProgress(courseType: courseType)
    }

    private var slots: [PADISlot] {
        PADIStandards.shared.slots(for: courseType)
    }

    private func slotProgress(_ slot: PADISlot) -> (done: Int, total: Int) {
        let done = slot.skills.filter { student.currentStatus(for: $0.code) == .mastered }.count
        return (done, slot.skills.count)
    }

    private var suggestedNextSlot: PADISlot? {
        slots.first { slot in
            slotProgress(slot).done < slot.skills.count
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                coursePicker
                overallProgress
                slotBreakdown
                if let next = suggestedNextSlot {
                    nextSlotCard(next)
                }
                seedPrompt
                contactSection
            }
            .padding()
        }
        .navigationTitle(student.fullName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingSeedSheet) {
            PriorMasterySeedSheet(
                student: student,
                courseType: courseType,
                upToSlotOrder: Int.max
            )
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(student.initials)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(Circle().fill(Color.appAccent))
            VStack(alignment: .leading, spacing: 4) {
                Text(student.fullName).font(.title3.bold())
                Text(L10n.currentLanguage == "de"
                     ? "Seit \(student.enrolledOn.formatted(.dateTime.day().month().year()))"
                     : "Since \(student.enrolledOn.formatted(.dateTime.day().month().year()))")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var coursePicker: some View {
        Picker("", selection: $courseType) {
            Text("OW").tag("OW")
            Text("AOW").tag("AOW")
        }
        .pickerStyle(.segmented)
    }

    private var overallProgress: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(L10n.currentLanguage == "de" ? "Gesamt" : "Overall")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(progress.mastered) / \(progress.total)")
                    .font(.system(size: 13, weight: .bold).monospacedDigit())
            }
            ProgressView(value: Double(progress.mastered),
                         total: Double(max(1, progress.total)))
                .tint(Color.appAccent)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.appCard))
    }

    private var slotBreakdown: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(slots) { slot in
                let p = slotProgress(slot)
                NavigationLink {
                    slotDetail(slot)
                } label: {
                    HStack {
                        Text(slot.code).font(.system(size: 12, weight: .bold).monospaced())
                            .frame(width: 60, alignment: .leading)
                        ProgressView(value: Double(p.done), total: Double(max(1, p.total)))
                            .tint(p.done == p.total && p.total > 0 ? .green : Color.appAccent)
                        Text("\(p.done)/\(p.total)")
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.appCard))
    }

    @ViewBuilder
    private func slotDetail(_ slot: PADISlot) -> some View {
        ScrollView {
            SkillAssessmentGrid(
                student: student,
                slotCode: slot.code,
                courseType: courseType,
                context: .none,
                readonly: true
            )
            .padding()
        }
        .navigationTitle("\(slot.code) · \(slot.title)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func nextSlotCard(_ slot: PADISlot) -> some View {
        HStack {
            Image(systemName: "arrow.right.circle.fill").foregroundStyle(Color.appAccent)
            Text(L10n.currentLanguage == "de" ? "Nächster Slot: \(slot.code)" : "Next slot: \(slot.code)")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.appAccent.opacity(0.1)))
    }

    private var seedPrompt: some View {
        Group {
            if (student.skillCompletions ?? []).isEmpty {
                Button {
                    showingSeedSheet = true
                } label: {
                    Label(L10n.currentLanguage == "de"
                          ? "Historischen Fortschritt nachtragen"
                          : "Add historical progress",
                          systemImage: "clock.arrow.circlepath")
                        .font(.system(size: 13))
                }
                .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private var contactSection: some View {
        if !student.email.isEmpty || !student.padiELearningID.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                if !student.email.isEmpty {
                    Label(student.email, systemImage: "envelope").font(.system(size: 12))
                }
                if !student.padiELearningID.isEmpty {
                    Label(student.padiELearningID, systemImage: "person.text.rectangle")
                        .font(.system(size: 12))
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.appCard))
        }
    }
}
```

- [ ] **Step 26.2: Commit**

```bash
git add "DiveLog Pro/Views/Screens/StudentProfileView.swift"
git commit -m "feat: add StudentProfileView with per-slot progress + seed prompt"
```

---

## Task 27: QuickLogView

**Files:**
- Create: `DiveLog Pro/Views/Screens/QuickLogView.swift`

- [ ] **Step 27.1: Implement**

Create `DiveLog Pro/Views/Screens/QuickLogView.swift`:

```swift
import SwiftUI
import SwiftData

struct QuickLogView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Query private var allStudents: [Student]

    @State private var selectedStudents: [Student] = []
    @State private var mode: Mode = .dive
    @State private var showingDiveCreate = false
    @State private var showingPoolCreate = false
    @State private var showingNewStudent = false

    enum Mode: Hashable { case dive, pool }

    private var activeStudents: [Student] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: Date())!
        return allStudents
            .filter { ($0.lastActivityDate ?? .distantPast) >= cutoff }
            .sorted { ($0.lastActivityDate ?? .distantPast) > ($1.lastActivityDate ?? .distantPast) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section(L10n.currentLanguage == "de"
                        ? "Aktive Schüler (14 Tage)"
                        : "Active students (14 days)") {
                    if activeStudents.isEmpty {
                        Text(L10n.currentLanguage == "de"
                             ? "Keine aktiven Schüler. Starte mit Drop-In."
                             : "No active students. Start with a drop-in.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(activeStudents) { s in
                        let isSelected = selectedStudents.contains { $0.id == s.id }
                        Button {
                            if isSelected {
                                selectedStudents.removeAll { $0.id == s.id }
                            } else {
                                selectedStudents.append(s)
                            }
                        } label: {
                            HStack {
                                Text(s.initials).font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 28, height: 28)
                                    .background(Circle().fill(Color.appAccent))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(s.fullName).font(.system(size: 14))
                                    if let last = s.lastActivityDate {
                                        Text(L10n.currentLanguage == "de"
                                             ? "Zuletzt: \(last.formatted(.dateTime.day().month()))"
                                             : "Last: \(last.formatted(.dateTime.day().month()))")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                Spacer()
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.appAccent)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        showingNewStudent = true
                    } label: {
                        Label(L10n.currentLanguage == "de" ? "Neuer Schüler (Drop-In)"
                                                         : "New student (drop-in)",
                              systemImage: "person.badge.plus")
                    }
                }

                Section(L10n.currentLanguage == "de" ? "Typ" : "Type") {
                    Picker("", selection: $mode) {
                        Text(L10n.currentLanguage == "de" ? "Tauchgang" : "Dive").tag(Mode.dive)
                        Text("Pool").tag(Mode.pool)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Quick-Log")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.currentLanguage == "de" ? "Abbrechen" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.currentLanguage == "de" ? "Weiter" : "Next") {
                        switch mode {
                        case .dive: showingDiveCreate = true
                        case .pool: showingPoolCreate = true
                        }
                    }
                    .disabled(selectedStudents.isEmpty)
                }
            }
            .sheet(isPresented: $showingNewStudent) {
                NewStudentSheet { s in
                    ctx.insert(s)
                    try? ctx.save()
                    selectedStudents.append(s)
                }
            }
            .sheet(isPresented: $showingDiveCreate) {
                DiveFormView()
                    // TODO: DiveFormView-Init ergänzen, der selectedStudents + nextSlot vorausfüllt
            }
            .sheet(isPresented: $showingPoolCreate) {
                PoolSessionCreateView()
                    // TODO: gleiche Vorbelegung für PoolSessionCreateView
            }
        }
    }
}
```

- [ ] **Step 27.2: Build — should now succeed**

Run: `xcodebuild -scheme "DiveLog Pro" -destination 'platform=iOS Simulator,name=iPhone 15' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 27.3: Commit**

```bash
git add "DiveLog Pro/Views/Screens/QuickLogView.swift"
git commit -m "feat: add QuickLogView with 14-day active students + drop-in new student"
```

---

## Task 28: DiveFormView + PoolSessionCreateView — Smart Pre-fill from QuickLog

**Files:**
- Modify: `DiveLog Pro/Views/Screens/DiveFormView.swift`
- Modify: `DiveLog Pro/Views/Screens/PoolSessionCreateView.swift`

- [ ] **Step 28.1: Add optional prefill init to DiveFormView**

At the top of `DiveFormView` struct, add:

```swift
var prefillStudents: [Student] = []
var prefillCourseType: String? = nil
var prefillCourseSlot: String? = nil
```

In `onAppear` (or `init`-equivalent via `@State` defaults), when `prefillStudents` is non-empty, set:

```swift
.onAppear {
    if !prefillStudents.isEmpty {
        isCourseTraining = true
        students = prefillStudents
        if let t = prefillCourseType { courseType = t }
        if let slot = prefillCourseSlot {
            courseSlot = slot
        } else {
            courseSlot = suggestedNextSlot(forStudents: prefillStudents, courseType: courseType)
        }
    }
}

private func suggestedNextSlot(forStudents students: [Student], courseType: String) -> String {
    // For each student, find the highest slot where any skill is mastered,
    // then pick the next slot. Use the minimum across students (most conservative).
    let slots = PADIStandards.shared.slots(for: courseType).filter { $0.type == .ocean }
    guard !slots.isEmpty else { return "" }
    var minIndex = slots.count - 1
    for student in students {
        var lastMasteredIdx = -1
        for (idx, slot) in slots.enumerated() {
            let anyMastered = slot.skills.contains {
                student.currentStatus(for: $0.code) == .mastered
            }
            if anyMastered { lastMasteredIdx = idx }
        }
        let next = min(lastMasteredIdx + 1, slots.count - 1)
        minIndex = min(minIndex, next)
    }
    return slots[max(0, minIndex)].code
}
```

- [ ] **Step 28.2: Same prefill pattern for PoolSessionCreateView**

Add similar `prefillStudents`, `prefillCourseType`, `prefillSlotCode` to `PoolSessionCreateView` with a matching `onAppear` that sets initial state.

- [ ] **Step 28.3: Wire QuickLogView prefill calls**

In `QuickLogView.swift`, replace the sheet contents:

```swift
.sheet(isPresented: $showingDiveCreate) {
    DiveFormView(
        prefillStudents: selectedStudents,
        prefillCourseType: selectedStudents.first?.dives?.first?.courseType ?? "OW"
    )
}
.sheet(isPresented: $showingPoolCreate) {
    PoolSessionCreateView(
        prefillStudents: selectedStudents,
        prefillCourseType: "OW"
    )
}
```

- [ ] **Step 28.4: Commit**

```bash
git add "DiveLog Pro/Views/Screens/DiveFormView.swift" "DiveLog Pro/Views/Screens/PoolSessionCreateView.swift" "DiveLog Pro/Views/Screens/QuickLogView.swift"
git commit -m "feat: smart pre-fill for DiveCreate and PoolCreate from QuickLog"
```

---

## Task 29: Wire Student Navigation from Dive-Detail

**Files:**
- Modify: `DiveLog Pro/Views/Screens/DiveDetailView.swift`

- [ ] **Step 29.1: Make student names tappable in the segmented picker**

Above the segmented-picker inside `studentsSection`, add a small "Profil"-chip for the selected student:

```swift
if let selected = students.first(where: { $0.id == selectedStudentID }) ?? students.first {
    NavigationLink {
        StudentProfileView(student: selected)
    } label: {
        HStack(spacing: 6) {
            Image(systemName: "person.crop.circle.badge.questionmark")
            Text(L10n.currentLanguage == "de" ? "Profil öffnen" : "Open profile")
        }
        .font(.system(size: 12))
        .foregroundStyle(Color.appAccent)
    }
}
```

- [ ] **Step 29.2: Commit**

```bash
git add "DiveLog Pro/Views/Screens/DiveDetailView.swift"
git commit -m "feat(DiveDetailView): navigate to StudentProfileView from student tab"
```

---

# Phase 4 — Polish

## Task 30: Accessibility Audit

**Files:**
- Modify: `DiveLog Pro/Views/Components/SkillStatusBadge.swift`
- Modify: `DiveLog Pro/Views/Components/SkillAssessmentGrid.swift`

- [ ] **Step 30.1: Add accessibility labels to skill rows**

In `SkillAssessmentGrid.swift`, `skillRow(_:)`, wrap the HStack with:

```swift
.accessibilityElement(children: .combine)
.accessibilityLabel("\(skill.code), \(skill.title), \(student.currentStatus(for: skill.code).displayLabel)")
.accessibilityHint(L10n.currentLanguage == "de"
    ? "Tippen zum Weiterschalten, lang drücken für Details"
    : "Tap to cycle, long-press for details")
.accessibilityAction(named: L10n.currentLanguage == "de" ? "Zurücksetzen" : "Reset") {
    ctx.setSkillStatus(.notStarted, student: student, skillCode: skill.code, context: context)
}
```

- [ ] **Step 30.2: Verify VoiceOver behaviour on simulator**

Run the app, enable VoiceOver (Settings → Accessibility → VoiceOver on simulator), open a dive with students, tap a skill row. Expected: announces code + title + current status.

- [ ] **Step 30.3: Commit**

```bash
git add "DiveLog Pro/Views/Components/SkillAssessmentGrid.swift"
git commit -m "feat(a11y): VoiceOver labels for skill rows + reset action"
```

---

## Task 31: Full End-to-End Manual QA

- [ ] **Step 31.1: Run all tests**

Run: `xcodebuild test -scheme "DiveLog Pro" -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: All pass.

- [ ] **Step 31.2: Manual QA checklist**

Work through this checklist on a clean simulator install:

- [ ] Create Student via QuickLog → appears in active list
- [ ] Create Pool Session CW2 with 2 students → appears in Student Profile, NOT in Logbook
- [ ] Logbook counter still reflects only Dive records
- [ ] Create Dive, toggle "Kurs-Tauchgang", pick OW + OW2 + 2 students
- [ ] Pre-Dive-Preview shows correct counts per student
- [ ] Tap skills in Dive-Detail → status cycles, haptic on mastered
- [ ] Long-press skill → sheet with picker + notes + history
- [ ] Swipe-left reset → status returns to notStarted
- [ ] Bulk "Alle auf mastered" → progress bar fills
- [ ] Delete dive with assessments → confirmation shows correct count
- [ ] Delete dive → assessments cascade; student status reverts
- [ ] Prior-Mastery Seed via Student Profile → selected skills marked mastered
- [ ] Seed records visible as "seed" chip in SkillReviewSheet history
- [ ] Switch app language DE ↔ EN → all new UI translated
- [ ] Close app, reopen on same device → all state persists
- [ ] Install on iPad with same iCloud account → students + completions sync within 60s

- [ ] **Step 31.3: Commit (docs-only if anything fixed)**

If any fixes were needed during QA, commit them with a clear message.

---

## Task 32: Mark Plan Complete

- [ ] **Step 32.1: Update task tracker**

Run the `TaskUpdate` tool to mark tasks #13, #14, #15, #16 as completed.

- [ ] **Step 32.2: Create CloudKit deployment reminder**

Task #12 (CloudKit Schema → Production deploy) becomes urgent before App Store release. Ensure it's still in the pending list and scheduled before any TestFlight distribution that includes this feature.

- [ ] **Step 32.3: Final commit**

```bash
git add docs/
git commit -m "docs: mark instructor skill-assessment plan complete"
```

---

## Self-Review

**Spec coverage check:**
- ✅ Models (Student, PoolSession, SkillCompletion, Dive extensions) — Tasks 8, 10, 9, 11
- ✅ PADI bundled catalog + loader — Tasks 2–7
- ✅ SkillStatus enum with cycleNext — Task 1
- ✅ Dive-Detail Schüler section — Task 23
- ✅ SkillAssessmentGrid (tap-cycle, long-press, swipe-reset, bulk actions) — Tasks 14–16
- ✅ PoolSession Create/Detail flows — Tasks 19, 20
- ✅ Pool NOT counted as dive — verified in Task 10 test `poolSessionExcludedFromDiveQuery`
- ✅ Quick-Log drop-in flow — Task 27
- ✅ Pre-Dive-Preview card — Task 22
- ✅ Prior-Mastery seed (skill-by-skill checklist) — Task 25
- ✅ Dive-delete confirmation with count — Task 24
- ✅ Student Profile overview — Task 26
- ✅ FAB menu (Dive / Pool / QuickLog) — Task 18
- ✅ DE + EN from day 1 — Tasks 3, 4, 5 (both languages shipped)
- ✅ firstName + lastName as two fields — Task 8
- ✅ All AOW specialties — Task 5
- ✅ Accessibility — Task 30

**Placeholder scan:** ✅ no "TBD", no "fill in details". Task 3 / 4 / 5 refer the populator to the PADI Instructor Manual as canonical source — this is legitimate (PADI content is proprietary and Dominik as Course Director is the expert).

**Type consistency:** ✅ `cycleSkill`, `setSkillStatus`, `seedStudent`, `currentStatus`, `masteryProgress` consistent across Tasks 13, 15, 16, 17, 23, 26. `SkillAssessmentContext` used consistently.

**Known nits:**
- Task 25 seed "partial" branch uses `UserDefaults` as a marker — acceptable MVP, revisit if it proves fragile
- Task 27 QuickLog smart-defaults for site/date are implemented minimally; Task 28 addresses prefill but site-inheritance is left for a follow-up polish ticket

---

**Plan complete and saved to `docs/superpowers/plans/2026-04-23-instructor-skill-assessment.md`.**

Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
