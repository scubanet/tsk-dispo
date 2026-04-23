# Instructor Skill-Assessment Design

**Status:** Draft → Pending Review
**Date:** 2026-04-23
**Author:** Dominik Weckherlin (Design) / Claude (Drafting)
**Feature Area:** Instructor-specific course tracking and skill assessment

---

## 1. Context & Problem Statement

As a PADI Course Director, I regularly run OW and AOW courses — sometimes with 1–2 students running in parallel, sometimes dropping into another instructor's existing course for just 1–2 dives. The current DiveLog Pro only tracks dives as atomic events. It lacks:

1. **Student-awareness** — who was on this dive and what did they still need to learn?
2. **PADI Performance Requirements tracking** — which skills are mastered, practiced, or outstanding?
3. **Pool-session capture** — Confined Water sessions aren't "dives" but must be tracked.
4. **Pre-dive planning** — what does each student on today's OW3 still need to practice?
5. **Mid-day progress snapshot** — am I on track to complete this course by Friday?

The feature solves (1)–(5) with a **dive-centric** (not course-centric) architecture, explicitly optimised for the **Course Director drop-in use case**.

## 2. Scope

**In-scope:**
- `Student`, `PoolSession`, `SkillCompletion` SwiftData models
- Additive changes to `Dive` (optional `courseType`, `courseSlot`, `students`)
- Bundled static JSON catalog for PADI OW + AOW Performance Requirements
- Dive-Detail Schüler-Tab with per-student `SkillAssessmentGrid`
- PoolSession Create/Detail flow
- Quick-Log shortcut (FAB long-press) for drop-in use case
- Pre-Dive-Preview with prior-mastery seed option
- Student-Profile overview with aggregated progress

**Out-of-scope (future):**
- HealthKit / Garmin Connect / UDDF import
- Course-level entity (explicitly rejected — dive-centric by design)
- Instructor-to-Instructor handoff / shared courses
- E-Record submission to PADI
- Rescue / Divemaster / Instructor-Development tracking (CW + OW only for now)

## 3. Design Decisions (with rationale)

### 3.1 Dive-Centric, not Course-Centric
A `Course` entity was considered and rejected. Reality: I'm often a drop-in CD who didn't start the course and won't finish it. A `Course` entity forces premature structure; `courseType` + `courseSlot` on the dive is enough, and the student's history across dives gives the implicit "course" view.

### 3.2 PoolSession as a separate model (not a flagged Dive)
`LogbookTab` already uses `@Query(sort: \Dive.date, order: .reverse)`. Keeping `PoolSession` as its own model means pool sessions **cannot accidentally count as dives** — the existing query simply doesn't see them. Skill-tracking is identical via shared `SkillCompletion`.

### 3.3 SkillCompletion is append-only
Every status change creates a new `SkillCompletion` record. Never mutated. This gives:
- Full audit trail per skill
- No CloudKit update-conflict scenarios
- Graceful multi-device sync

"Current status" = latest `SkillCompletion` per `(student, skillCode)`.

### 3.4 PADI catalog in bundle, not CloudKit
Performance Requirements are immutable app-version-scoped content. Bundled JSON means:
- No CloudKit migration on content update (ship via App Store update)
- Works offline, no fetch cost
- Trivially localisable via `ow.json` / `ow.de.json`

### 3.5 Prior-Mastery Seed for drop-in students
When I join a course at OW3 with a student I've never seen, I can seed their prior slots as "mastered" via a quick-pick sheet. This seed creates `SkillCompletion` records with `dive == nil && poolSession == nil` and `reviewNotes = "Seeded at enrollment"` — making them visibly distinct from skills I personally assessed.

## 4. Data Model

```swift
@Model final class Student {
    var firstName: String = ""
    var lastName: String = ""
    var email: String = ""
    var padiELearningID: String = ""
    var enrolledOn: Date = Date()
    var notes: String = ""

    // Computed display name
    var fullName: String {
        [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
    }

    @Relationship(deleteRule: .nullify, inverse: \Dive.students)
    var dives: [Dive]? = []

    @Relationship(deleteRule: .nullify, inverse: \PoolSession.students)
    var poolSessions: [PoolSession]? = []

    @Relationship(deleteRule: .cascade, inverse: \SkillCompletion.student)
    var skillCompletions: [SkillCompletion]? = []

    init() {}
}

@Model final class PoolSession {
    var slotCode: String = "CW1"        // CW1-CW5
    var courseType: String = "OW"
    var date: Date = Date()
    var durationMinutes: Int = 45
    var location: String = ""
    var notes: String = ""

    @Relationship(deleteRule: .nullify, inverse: \Student.poolSessions)
    var students: [Student]? = []

    @Relationship(deleteRule: .cascade, inverse: \SkillCompletion.poolSession)
    var skillAssessments: [SkillCompletion]? = []

    init() {}
}

@Model final class SkillCompletion {
    var skillCode: String = ""          // e.g. "OW2.4"
    var status: String = "notStarted"   // SkillStatus raw value
    var assessedOn: Date = Date()
    var reviewNotes: String = ""

    var student: Student?
    var dive: Dive?                     // OR poolSession — exactly one set (or both nil for seed)
    var poolSession: PoolSession?

    init() {}
}

// Additions to existing Dive model (all optional / additive):
extension Dive {
    // var courseType: String?        // "OW", "AOW", nil = fun-dive
    // var courseSlot: String?        // "OW1", "OW2", "AOW Deep"
    // @Relationship(...) var students: [Student]?
    // @Relationship(deleteRule: .cascade, inverse: \SkillCompletion.dive)
    //   var skillCompletions: [SkillCompletion]?
}

enum SkillStatus: String, CaseIterable {
    case notStarted, introduced, practiced, mastered, needsReview

    var cycleNext: SkillStatus {
        switch self {
        case .notStarted:  return .introduced
        case .introduced:  return .practiced
        case .practiced:   return .mastered
        case .mastered:    return .notStarted   // reset
        case .needsReview: return .practiced    // resolve
        }
    }
}
```

### 4.1 PADI Catalog JSON Schema

```
DiveLog Pro/Resources/padi-standards/
  ├─ ow.json       (English default)
  ├─ ow.de.json    (German)
  ├─ aow.json
  └─ aow.de.json
```

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
          "title": "Equipment Assembly",
          "description": "...",
          "category": "preparation",
          "performanceStandard": "Student assembles without assistance"
        }
      ]
    }
  ]
}
```

Loader: `PADIStandards.shared.skills(for: slotCode, courseType: "OW") -> [Skill]`.

## 5. UX Flows

### 5.1 Dive-Detail: Schüler-Tab
New tab appears only when `dive.courseType != nil && (dive.students?.count ?? 0) > 0`.

- Segmented picker switches between students
- Progress bar: `14/24 mastered`
- Skill rows: tap = cycle status, long-press = sheet (status picker + notes + needsReview)
- Swipe left = reset to notStarted
- Toolbar: "Alle auf mastered", "Alle ungeprüften auf introduced"

### 5.2 PoolSession Create
- FAB becomes menu-FAB on long-press: Tauchgang / Pool-Session / Quick-Log
- Form: Slot (CW1–5), Course, Date, Duration, Location, Students, Notes
- Post-save → same Schüler-Tab layout for immediate assessment
- **Never** appears in Logbook or Stats (existing `@Query(\Dive.date)` excludes it)

### 5.3 Quick-Log (Drop-In CD Killer Feature)
- Trigger: FAB long-press → "Quick-Log"
- Shows active students (last 14 days)
- Smart defaults: slot = lastSlot + 1, date = today, site = today's first dive's site
- Inline "+ Neuer Schüler (Drop-In)" with name-only form + optional prior-mastery seed

### 5.4 Pre-Dive-Preview
On Dive-Create, when `courseType` + students selected, expandable preview card per student:
- "Bereits gemeistert (14)" — collapsed list
- "Heute zu üben (OW3) — 5 Skills" — from catalog
- "⚠ Needs Review (1)" — skills flagged from prior dives
- For unknown students: "Keine Historie. [Seed nachtragen?]"

### 5.5 Student Profile
- Aggregated progress bar (overall + per slot)
- Tap a slot → readonly `SkillAssessmentGrid`
- "Nächster Slot: OW2 (empfohlen)" — next unmastered slot

### 5.6 Prior-Mastery Seed Sheet
Three options when adding an existing student mid-course:
1. **Alles gemeistert** — seed all prior slots as mastered
2. **Teilweise** — checkbox list of prior slots' skills, user ticks off
3. **Überspringen** — no seed, treat as blank history

Seed records have `dive == nil && poolSession == nil`, distinguishable in UI.

## 6. Technical Plan

### 6.1 SwiftData Migration
Lightweight migration: all new fields are optional or have inline defaults. No custom migration stage.

```swift
enum DiveLogProMigrationPlan: SchemaMigrationPlan {
    static var schemas: [VersionedSchema.Type] = [SchemaV1.self, SchemaV2.self]
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)]
    }
}
```

### 6.2 CloudKit Compliance
- All scalars have inline defaults
- All relationships optional + arrays default to `[]`
- No unique constraints
- All `@Model` classes have `init()` parameterless constructor
- Deploy development schema to production **before** TestFlight release

### 6.3 Progress Calculation
On-the-fly computed properties, cached in SwiftUI `@State` per view. Recompute only on `.onChange(of: skillCompletions?.count)`. No persisted cache — simpler and CloudKit-safe.

```swift
extension Student {
    func masteryProgress(courseType: String) -> (mastered: Int, total: Int) {
        let latestPerSkill = Dictionary(grouping: skillCompletions ?? [], by: \.skillCode)
            .compactMapValues { $0.max(by: { $0.assessedOn < $1.assessedOn }) }
        let mastered = latestPerSkill.values.filter { $0.status == "mastered" }.count
        let total = PADIStandards.shared.allSkills(for: courseType).count
        return (mastered, total)
    }
}
```

### 6.4 Status Cycle Helper
Append-only, centralised in a `ModelContext` extension:

```swift
extension ModelContext {
    func cycleSkill(student: Student, skillCode: String, context: SkillContext) {
        let current = student.currentStatus(for: skillCode)
        let next = current.cycleNext
        let completion = SkillCompletion()
        completion.skillCode = skillCode
        completion.status = next.rawValue
        completion.student = student
        completion.assessedOn = Date()
        switch context {
        case .dive(let d): completion.dive = d
        case .pool(let p): completion.poolSession = p
        }
        self.insert(completion)
        try? self.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
```

### 6.5 Testing Plan
Unit tests (Swift Testing):
- `cycleSkillCreatesNewRecord`
- `seedStudentInsertsMasteredStates`
- `masteryProgressUsesLatestPerSkill`
- `poolSessionNotCountedInDiveQuery`
- `catalogLoaderFallsBackToEnglish`

Integration tests:
- In-memory ModelContainer with SampleData
- Multi-device sync simulation

Manual QA checklist: see Section 3.6 of brainstorm notes.

## 7. Rollout

**Phase 1 — Foundation (~1 week):**
- Models + migration
- Bundle JSON loader
- CloudKit schema deploy

**Phase 2 — Core UX (~1 week):**
- Dive-Create course fields + Student-Picker
- Dive-Detail Schüler-Tab + SkillAssessmentGrid
- PoolSession Create/Detail

**Phase 3 — Drop-In Magic (~1 week):**
- Quick-Log shortcut
- Pre-Dive-Preview
- Prior-Mastery-Seed sheet
- Student-Profile overview

**Phase 4 — Polish:**
- Bulk actions, haptics, animations
- Accessibility audit

## 8. Resolved Decisions

1. **Localised catalogs** — ship **DE + EN from day 1**. Both `ow.json` + `ow.de.json` + `aow.json` + `aow.de.json` bundled at launch.
2. **Student identity** — always **`firstName` + `lastName`** (two separate fields, both required). `fullName` is a computed display property. No primary-key ambiguity unless two students share both first + last name (rare; email/PADI-ID as tiebreaker in UI).
3. **Batch-seed UI** — **skill-by-skill checklist** only. No slot-level quick-toggles (keeps it explicit and deliberate).
4. **Dive-Delete cascade** — confirmation dialog before delete: *"3 skill assessments for 2 students will also be deleted."* Cascade behaviour stays as designed.
5. **AOW scope** — **all AOW specialty dives**, not just top 5. Full catalog: Deep, Navigation (core) + all electives (Night, PPB, Underwater Navigator, Wreck, Drift, Boat, Search & Recovery, Fish ID, Digital Underwater Photographer, Enriched Air, Naturalist, Altitude, Dry Suit, etc.).

## 9. Still-Open (deferred to v2)

- **Skill versioning** — when PADI updates standards (e.g. 2025.1), old completions reference old skill codes. Plan: keep historical codes in catalog with `deprecated: true` flag. Handle in first content-update release.
- **PDF export** — student skill log for handoff to another instructor. Useful but not blocking v1.

## 9. References

- PADI OW Course Standards (Instructor Manual, Section 3)
- PADI AOW Course Standards (Instructor Manual, Section 4)
- SwiftData + CloudKit requirements: inline defaults, optional relations, parameterless init
- Existing Dive model: `DiveLog Pro/Models/Dive.swift`
- Sample data pattern: `DiveLog Pro/Models/SampleData.swift`

---

## Self-Review

### Strengths
- Dive-centric model matches real drop-in CD workflow
- Append-only SkillCompletion eliminates CloudKit merge conflicts
- Bundle JSON avoids schema churn for content updates
- PoolSession separation cleanly excludes pool from dive stats
- Prior-Mastery seed handles the most awkward drop-in edge case

### Risks / Concerns
- **JSON catalog as source of truth for skill codes.** If a skill code is renamed in a future PADI update, existing completions reference the old code. Mitigation: keep old codes as `deprecated: true` entries.
- **Student identity.** Two students named "Maya" — how do we disambiguate? Need email or PADI eLearning ID as secondary key. Currently email is optional. Consider: show `padiELearningID` as secondary label when name collides.
- **Seed records with both `dive` and `poolSession` nil** — are we sure queries handle this gracefully? Needs explicit test.
- **Progress bar in student list** could be O(n × m) on large libraries. For now acceptable, revisit if >50 students.
- **Dive-Delete cascade** — deleting a dive cascades `SkillCompletion` records. If a student's "mastered" status was recorded on that deleted dive, the student drops back to their previous status. This is arguably correct (the assessment is gone), but surprising. Need UI confirmation on dive-delete: "3 skill assessments for 2 students will be deleted."

### Gaps
- No spec for **what happens if a student is removed from a dive after skills were assessed**. Probably: the SkillCompletion stays (linked to student, not dive), but `dive` relationship nullifies. Needs explicit deleteRule test.
- No spec for **undo** on skill cycle. Append-only helps (just delete latest record), but UI affordance missing.
- No **conflict resolution** for offline multi-device edits (unlikely in practice but worth a note).

### Decisions Deferred
- Localised catalog at launch → DE only initially, EN fallback loader already handles missing file
- AOW elective scope → start with Deep + Nav + Night + Peak Performance Buoyancy + Underwater Navigator (5 most common)
- PDF export → post-v1
