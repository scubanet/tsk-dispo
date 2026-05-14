# iOS Etappe 5 — Skill-Check OWD

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tap auf den Skill-Check-Tab in der CourseDetailView zeigt eine sektionierte Liste aller OWD-PADI-Skills. Pro Skill stehen die Teilnehmer-Chips dahinter (Initialen-Avatar). Tap auf Chip togglet "done/undone" für die Kombination (Skill × Teilnehmer). Optimistische UI mit Rollback bei Fehler.

**Architecture:** Neue DB-Tabelle `skill_definitions` mit allen OWD-Skills als Seed. iOS-Store lädt einmal Definitions (cached) plus pro-Kurs die Records. Toggle erzeugt INSERT (mit completed_on=today) oder DELETE (bei undone). Records keyed by `(participantId, skillCode)`.

**Tech Stack:** Swift 5.10, SwiftUI, Supabase-Swift 2.x, Postgres + RLS.

**Branch:** `ios-etappe-5-skill-check-owd` — wegen DB-Migration.

**DB-Migration (User wendet manuell an):**
`supabase/migrations/0095_skill_definitions.sql` — Tabelle + OWD-Seed (32 Rows).

**Bewusst out-of-scope dieser Etappe:**
- Web-Refactor `SkillCheckTab.tsx` von hardcoded Constant auf DB-Hook → post-Pitch separate Etappe. Begründung: Seed = Constant 1:1, kein Drift-Risiko in 2-Wochen-Soft-Live.
- Long-Press Detail-Sheet (TG#/Quiz/Video/Notes per Cell) → post-Pitch. Aktuell pitch-genug ist binärer Toggle.
- Heute-vs-Alle-Filter (basierend auf course_dates type) → post-Pitch.
- Andere PADI-Kurse (AOWD/Rescue/etc.) → nur OWD-Seed.

---

## File Structure

**Created:**
- `supabase/migrations/0095_skill_definitions.sql`
- `apps/ios-native/ATOLL/Models/SkillDefinition.swift`
- `apps/ios-native/ATOLL/Models/SkillRecord.swift`
- `apps/ios-native/ATOLL/Services/SkillCheckStore.swift`
- `apps/ios-native/ATOLL/Components/SkillChip.swift`

**Modified:**
- `apps/ios-native/ATOLL/Views/SkillCheckTabView.swift` — von Placeholder zur echten Implementation
- `apps/ios-native/ATOLL/Views/CourseDetailView.swift` — propagiert `participants` (via Store) an SkillCheckTabView
- `apps/ios-native/ATOLL/Views/ParticipantsTabView.swift` — extrahiert ParticipantsStore in den Parent für Sharing mit SkillCheckTabView (optional — siehe Self-Review)

---

## Tasks

### Task 1: Feature-Branch + Plan-Commit (User)

Xcode schliessen vorher.

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git status
git add docs/superpowers/plans/2026-05-14-ios-etappe-5-skill-check-owd.md
git commit -m 'docs(plan): iOS Etappe 5 — Skill-Check OWD plan'
git checkout -b ios-etappe-5-skill-check-owd
```

---

### Task 2: DB-Migration schreiben (Subagent)

**Files:**
- Create: `supabase/migrations/0095_skill_definitions.sql`

- [ ] **Step 1: Migration-File:**

```sql
-- 0095: skill_definitions — Katalog aller PADI-Skills pro Kurs-Typ.
-- Quelle: apps/web/src/lib/padiOwdSkills.ts (wird post-Pitch in separate Etappe
-- durch Hook ersetzt, der aus dieser Tabelle liest).
-- iOS-SkillCheckStore liest direkt aus dieser Tabelle.

CREATE TABLE public.skill_definitions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_type_code TEXT NOT NULL,        -- 'owd', künftig auch 'aowd', 'rescue', ...
  skill_code TEXT NOT NULL,
  section TEXT NOT NULL,                 -- 'cw_dive' | 'assessment' | 'cw_flex' | 'kd' | 'ow_dive' | 'ow_flex'
  label_de TEXT NOT NULL,
  label_en TEXT NOT NULL,
  display_order INT NOT NULL DEFAULT 0,
  has_date BOOLEAN NOT NULL DEFAULT false,
  has_quiz BOOLEAN NOT NULL DEFAULT false,
  has_video BOOLEAN NOT NULL DEFAULT false,
  has_tg_number BOOLEAN NOT NULL DEFAULT false,
  tg_number_options INT[],
  course_day_kind TEXT,                  -- 'cw1'..'cw5' / 'ow1'..'ow4' / NULL
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(course_type_code, skill_code)
);

CREATE INDEX idx_skill_definitions_course_type ON public.skill_definitions(course_type_code);
CREATE INDEX idx_skill_definitions_section ON public.skill_definitions(course_type_code, section, display_order);

ALTER TABLE public.skill_definitions ENABLE ROW LEVEL SECURITY;
CREATE POLICY skill_definitions_read ON public.skill_definitions
  FOR SELECT TO authenticated USING (true);
-- Schreibrechte nur via Studio / Migrations (kein UI-Editor in dieser Phase)

COMMENT ON TABLE public.skill_definitions IS
  'Katalog aller trackbaren PADI-Skills pro Kurs-Typ. Seed aus padiOwdSkills.ts.';

-- ─── OWD-Seed ───────────────────────────────────────────────────────────────

INSERT INTO public.skill_definitions
  (course_type_code, skill_code, section, label_de, label_en, display_order, has_date, has_quiz, has_video, has_tg_number, tg_number_options, course_day_kind)
VALUES
  -- Confined Water Tauchgänge
  ('owd', 'cw_1', 'cw_dive', 'CW Tauchgang 1', 'CW Dive 1', 10, true, false, false, false, NULL, 'cw1'),
  ('owd', 'cw_2', 'cw_dive', 'CW Tauchgang 2', 'CW Dive 2', 20, true, false, false, false, NULL, 'cw2'),
  ('owd', 'cw_3', 'cw_dive', 'CW Tauchgang 3', 'CW Dive 3', 30, true, false, false, false, NULL, 'cw3'),
  ('owd', 'cw_4', 'cw_dive', 'CW Tauchgang 4', 'CW Dive 4', 40, true, false, false, false, NULL, 'cw4'),
  ('owd', 'cw_5', 'cw_dive', 'CW Tauchgang 5', 'CW Dive 5', 50, true, false, false, false, NULL, 'cw5'),

  -- Beurteilung Wasserfertigkeiten
  ('owd', 'assessment_swim',  'assessment', '200m / 300m schwimmen',       '200m / 300m swim',    60, true, false, false, false, NULL, NULL),
  ('owd', 'assessment_float', 'assessment', '10 Min Oberfläche treiben',   '10 min float/tread',  70, true, false, false, false, NULL, NULL),

  -- Tauchgangsflexible Fertigkeiten CW
  ('owd', 'cw_flex_prep_gear',        'cw_flex', 'Vorbereitung und Pflege der Ausrüstung*',                 'Gear preparation & care*',                  80,  true, false, false, false, NULL, NULL),
  ('owd', 'cw_flex_inflator',         'cw_flex', 'Abkoppeln des Inflatorschlauchs vom Tarierjacket*',       'Disconnecting inflator hose*',              90,  true, false, false, false, NULL, NULL),
  ('owd', 'cw_flex_band',             'cw_flex', 'Lockeres Band einer Flaschenhalterung',                   'Loose tank band',                           100, true, false, false, false, NULL, NULL),
  ('owd', 'cw_flex_weight_off_surf',  'cw_flex', 'Ablegen und Anlegen Gewichtssystem (Oberfläche)*',        'Weight system off/on at surface*',          110, true, false, false, false, NULL, NULL),
  ('owd', 'cw_flex_emergency_weight', 'cw_flex', 'Abwerfen von Bleigewichten im Notfall*',                  'Emergency weight drop*',                    120, true, false, false, false, NULL, NULL),
  ('owd', 'cw_flex_snorkel',          'cw_flex', 'Schnorcheltauchen',                                       'Snorkel diving',                            130, true, false, false, false, NULL, NULL),
  ('owd', 'cw_flex_drysuit_orient',   'cw_flex', 'Orientierung zum Tauchen im Trockentauchanzug',           'Dry suit orientation',                      140, true, false, false, false, NULL, NULL),

  -- Knowledge Development
  ('owd', 'kd_teil_1',        'kd', 'Teil 1',                  'Part 1',                  150, true, true,  true,  false, NULL, NULL),
  ('owd', 'kd_teil_2',        'kd', 'Teil 2',                  'Part 2',                  160, true, true,  true,  false, NULL, NULL),
  ('owd', 'kd_teil_3',        'kd', 'Teil 3',                  'Part 3',                  170, true, true,  true,  false, NULL, NULL),
  ('owd', 'kd_teil_4',        'kd', 'Teil 4',                  'Part 4',                  180, true, true,  true,  false, NULL, NULL),
  ('owd', 'kd_teil_5',        'kd', 'Teil 5',                  'Part 5',                  190, true, true,  true,  false, NULL, NULL),
  ('owd', 'kd_quick_review',  'kd', 'Quick Review (eLearning)','Quick Review (eLearning)',200, true, true,  true,  false, NULL, NULL),

  -- Freiwasser-Tauchgänge
  ('owd', 'ow_1', 'ow_dive', 'OW Tauchgang 1', 'OW Dive 1', 210, true, false, false, false, NULL, 'ow1'),
  ('owd', 'ow_2', 'ow_dive', 'OW Tauchgang 2', 'OW Dive 2', 220, true, false, false, false, NULL, 'ow2'),
  ('owd', 'ow_3', 'ow_dive', 'OW Tauchgang 3', 'OW Dive 3', 230, true, false, false, false, NULL, 'ow3'),
  ('owd', 'ow_4', 'ow_dive', 'OW Tauchgang 4', 'OW Dive 4', 240, true, false, false, false, NULL, 'ow4'),

  -- Tauchgangsflexible OW (10 Items, alle haben TG#, manche mit beschränkten Optionen)
  ('owd', 'ow_flex_cramp',            'ow_flex', 'Einen Krampf lösen*',                     'Release a cramp*',                  250, false, false, false, true, NULL,       NULL),
  ('owd', 'ow_flex_tow',              'ow_flex', 'Ermüdeten Taucher schleppen/schieben*',   'Tow/push tired diver*',             260, false, false, false, true, NULL,       NULL),
  ('owd', 'ow_flex_dsmb',             'ow_flex', 'Signalboje/DSMB einsetzen*',              'Use DSMB/marker buoy*',             270, false, false, false, true, NULL,       NULL),
  ('owd', 'ow_flex_compass_straight', 'ow_flex', 'Gerade Strecke mit Kompass*',             'Straight line w/ compass*',         280, false, false, false, true, NULL,       NULL),
  ('owd', 'ow_flex_snorkel_reg',      'ow_flex', 'Wechsel Schnorchel/Lungenautomat*',       'Snorkel/regulator exchange*',       290, false, false, false, true, NULL,       NULL),
  ('owd', 'ow_flex_weight_drop',      'ow_flex', 'Bleigewichte im Notfall abwerfen*',       'Emergency weight drop*',            300, false, false, false, true, NULL,       NULL),
  ('owd', 'ow_flex_scuba_off_surf',   'ow_flex', 'Tauchgerät ab-/anlegen (Oberfläche)*',    'Scuba off/on at surface*',          310, false, false, false, true, NULL,       NULL),
  ('owd', 'ow_flex_weight_off_surf',  'ow_flex', 'Gewichtssystem ab-/anlegen (Oberfläche)*', 'Weight system off/on at surface*', 320, false, false, false, true, NULL,       NULL),
  ('owd', 'ow_flex_uw_compass',       'ow_flex', 'U/W-Navigation mit Kompass (TG 2, 3 oder 4)', 'U/W navigation with compass (TG 2, 3 or 4)', 330, false, false, false, true, ARRAY[2,3,4], NULL),
  ('owd', 'ow_flex_cesa',             'ow_flex', 'CESA (TG 2, 3 oder 4)',                   'CESA (TG 2, 3 or 4)',               340, false, false, false, true, ARRAY[2,3,4], NULL);
```

---

### Task 3: iOS-Models + Store + Chip (Subagent)

**Files:**
- Create: `apps/ios-native/ATOLL/Models/SkillDefinition.swift`
- Create: `apps/ios-native/ATOLL/Models/SkillRecord.swift`
- Create: `apps/ios-native/ATOLL/Services/SkillCheckStore.swift`
- Create: `apps/ios-native/ATOLL/Components/SkillChip.swift`

- [ ] **Step 1: `SkillDefinition.swift`:**

```swift
import Foundation

struct SkillDefinition: Codable, Identifiable, Hashable {
  let id: UUID
  let courseTypeCode: String
  let skillCode: String
  let section: String
  let labelDe: String
  let labelEn: String
  let displayOrder: Int

  enum CodingKeys: String, CodingKey {
    case id, section
    case courseTypeCode = "course_type_code"
    case skillCode      = "skill_code"
    case labelDe        = "label_de"
    case labelEn        = "label_en"
    case displayOrder   = "display_order"
  }

  /// Default-Label fürs Deutsche-UI.
  var label: String { labelDe }
}

/// Section-Labels gemappt aus dem section-Code. Für Pitch hardcoded — kann
/// post-Pitch in eine separate Tabelle ausgelagert werden.
enum SkillSection {
  static let labelsDe: [String: String] = [
    "cw_dive":    "Confined Water Tauchgänge",
    "assessment": "Beurteilung der Wasserfertigkeiten",
    "cw_flex":    "Tauchgangsflexible Fertigkeiten (CW)",
    "kd":         "Entwicklung der Kenntnisse",
    "ow_dive":    "Freiwasser-Tauchgänge",
    "ow_flex":    "Tauchgangsflexible Fertigkeiten (OW)",
  ]
  static let order: [String] = ["cw_dive", "assessment", "cw_flex", "kd", "ow_dive", "ow_flex"]
}
```

- [ ] **Step 2: `SkillRecord.swift`:**

```swift
import Foundation

/// `padi_skill_records`-Zeile. Einzige Schreib-Bedingung für iOS-MVP:
/// completed_on = today + instructor_id = legacy.
struct SkillRecord: Codable, Identifiable, Hashable {
  let id: UUID?
  let courseId: UUID
  let participantId: UUID
  let skillCode: String
  let completedOn: String?       // ISO yyyy-MM-dd
  let instructorId: UUID?

  enum CodingKeys: String, CodingKey {
    case id
    case courseId      = "course_id"
    case participantId = "participant_id"
    case skillCode     = "skill_code"
    case completedOn   = "completed_on"
    case instructorId  = "instructor_id"
  }
}

/// Insert-Payload — minimal.
struct SkillRecordInsert: Encodable {
  let courseId: UUID
  let participantId: UUID
  let skillCode: String
  let completedOn: String
  let instructorId: UUID?

  enum CodingKeys: String, CodingKey {
    case courseId      = "course_id"
    case participantId = "participant_id"
    case skillCode     = "skill_code"
    case completedOn   = "completed_on"
    case instructorId  = "instructor_id"
  }
}
```

- [ ] **Step 3: `SkillCheckStore.swift`:**

```swift
import Foundation
import Supabase

@MainActor
@Observable
final class SkillCheckStore {
  enum LoadState {
    case idle, loading, loaded, error
  }

  /// Skill-Definitionen pro Kurs-Typ (cached, einmal pro Session geladen pro Code).
  private(set) var definitions: [SkillDefinition] = []
  /// Records keyed by "\(participantId)-\(skillCode)" für O(1)-Lookup beim Toggle.
  private(set) var recordsByKey: [String: SkillRecord] = [:]
  private(set) var loadState: LoadState = .idle
  private(set) var errorMessage: String?

  private let supabase = SupabaseClient.shared

  /// Definitions laden für einen Kurs-Typ (z.B. "owd"), sortiert nach display_order.
  func loadDefinitions(courseTypeCode: String) async {
    do {
      let rows: [SkillDefinition] = try await supabase
        .from("skill_definitions")
        .select("id, course_type_code, skill_code, section, label_de, label_en, display_order")
        .eq("course_type_code", value: courseTypeCode)
        .order("display_order", ascending: true)
        .execute()
        .value
      definitions = rows
    } catch {
      #if DEBUG
      print("⚠️ SkillCheckStore.loadDefinitions failed: \(error)")
      #endif
      errorMessage = error.localizedDescription
    }
  }

  /// Records laden für einen konkreten Kurs.
  func loadRecords(courseId: UUID) async {
    loadState = .loading
    errorMessage = nil
    do {
      let rows: [SkillRecord] = try await supabase
        .from("padi_skill_records")
        .select("id, course_id, participant_id, skill_code, completed_on, instructor_id")
        .eq("course_id", value: courseId)
        .execute()
        .value

      recordsByKey = Dictionary(uniqueKeysWithValues: rows.map {
        (Self.key(participantId: $0.participantId, skillCode: $0.skillCode), $0)
      })
      loadState = .loaded
    } catch {
      #if DEBUG
      print("⚠️ SkillCheckStore.loadRecords failed: \(error)")
      #endif
      loadState = .error
      errorMessage = error.localizedDescription
    }
  }

  /// Toggle: wenn schon "done" → DELETE Row. Sonst → INSERT mit completed_on=today.
  /// Optimistische UI: lokales Dictionary sofort aktualisieren, bei Fehler rollback.
  func toggle(
    courseId: UUID,
    participantId: UUID,
    skillCode: String,
    instructorId: UUID?
  ) async {
    let key = Self.key(participantId: participantId, skillCode: skillCode)
    let previous = recordsByKey[key]

    // Optimistic: toggle local state first.
    if previous != nil {
      recordsByKey.removeValue(forKey: key)
    } else {
      recordsByKey[key] = SkillRecord(
        id: nil,
        courseId: courseId,
        participantId: participantId,
        skillCode: skillCode,
        completedOn: Self.isoDateFormatter.string(from: Date()),
        instructorId: instructorId
      )
    }

    do {
      if let prev = previous, let id = prev.id {
        // DELETE
        try await supabase
          .from("padi_skill_records")
          .delete()
          .eq("id", value: id)
          .execute()
      } else {
        // INSERT
        let payload = SkillRecordInsert(
          courseId: courseId,
          participantId: participantId,
          skillCode: skillCode,
          completedOn: Self.isoDateFormatter.string(from: Date()),
          instructorId: instructorId
        )
        let inserted: SkillRecord = try await supabase
          .from("padi_skill_records")
          .insert(payload)
          .select()
          .single()
          .execute()
          .value
        recordsByKey[key] = inserted
      }
      errorMessage = nil
    } catch {
      // Rollback
      if let prev = previous {
        recordsByKey[key] = prev
      } else {
        recordsByKey.removeValue(forKey: key)
      }
      #if DEBUG
      print("⚠️ SkillCheckStore.toggle failed: \(error)")
      #endif
      errorMessage = error.localizedDescription
    }
  }

  func isDone(participantId: UUID, skillCode: String) -> Bool {
    recordsByKey[Self.key(participantId: participantId, skillCode: skillCode)] != nil
  }

  private static func key(participantId: UUID, skillCode: String) -> String {
    "\(participantId.uuidString)-\(skillCode)"
  }

  private static let isoDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: "Europe/Zurich")
    return f
  }()
}
```

- [ ] **Step 4: `SkillChip.swift`:**

```swift
import SwiftUI

/// Toggle-Chip für einen Teilnehmer in einer Skill-Reihe.
/// Done-Status: grün-getönt mit Check-Icon. Sonst: hellgrau Rand.
struct SkillChip: View {
  let initials: String
  let participantId: UUID
  let isDone: Bool
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 4) {
        Text(initials)
          .font(.caption.bold().monospacedDigit())
          .foregroundStyle(isDone ? Color(red: 0.02, green: 0.20, blue: 0.17) : Color.primary.opacity(0.7))
        if isDone {
          Image(systemName: "checkmark")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(Color(red: 0.02, green: 0.20, blue: 0.17))
        }
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 5)
      .frame(maxWidth: .infinity)
      .background(
        RoundedRectangle(cornerRadius: 6)
          .fill(isDone ? Color(red: 0.62, green: 0.88, blue: 0.79) : Color(.systemGray6))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 6)
          .stroke(isDone ? Color.clear : Color(.systemGray3), lineWidth: 0.5)
      )
    }
    .buttonStyle(.plain)
  }
}
```

---

### Task 4: SkillCheckTabView ausbauen (Subagent)

**Files:**
- Modify: `apps/ios-native/ATOLL/Views/SkillCheckTabView.swift`

Bisheriger Inhalt ist Placeholder. Komplett ersetzen mit:

- [ ] **Step 1:**

```swift
import SwiftUI

struct SkillCheckTabView: View {
  let course: Course
  let user: CurrentUser
  let participants: [CourseParticipant]

  @State private var store = SkillCheckStore()

  var body: some View {
    Group {
      switch store.loadState {
      case .idle, .loading where store.recordsByKey.isEmpty && store.definitions.isEmpty:
        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
      case .error:
        ContentUnavailableView {
          Label("Fehler beim Laden", systemImage: "exclamationmark.triangle")
        } description: {
          Text(store.errorMessage ?? "")
        } actions: {
          Button("Nochmal versuchen") {
            Task { await reload() }
          }
        }
      default:
        if store.definitions.isEmpty {
          ContentUnavailableView(
            "Keine Skills hinterlegt",
            systemImage: "checkmark.circle",
            description: Text("Für diesen Kurs-Typ sind keine Skill-Definitionen vorhanden.")
          )
        } else if participants.isEmpty {
          ContentUnavailableView(
            "Keine Teilnehmer",
            systemImage: "person.2",
            description: Text("Sobald Schüler eingeschrieben sind, kannst du Skills abhaken.")
          )
        } else {
          skillsList
        }
      }
    }
    .refreshable { await reload() }
    .task { await reload() }
  }

  private var skillsList: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 18, pinnedViews: []) {
        ForEach(orderedSections, id: \.self) { section in
          if let skills = skillsBySection[section], !skills.isEmpty {
            sectionHeader(section)
            ForEach(skills) { skill in
              skillRow(skill)
            }
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
    }
  }

  private func sectionHeader(_ section: String) -> some View {
    Text(SkillSection.labelsDe[section] ?? section.uppercased())
      .font(.caption.bold())
      .tracking(0.5)
      .foregroundStyle(.secondary)
      .padding(.top, 8)
  }

  private func skillRow(_ skill: SkillDefinition) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(skill.label)
        .font(.subheadline.weight(.medium))
      LazyVGrid(columns: chipColumns, alignment: .leading, spacing: 6) {
        ForEach(participants) { p in
          SkillChip(
            initials: p.student?.initials ?? "—",
            participantId: p.id,
            isDone: store.isDone(participantId: p.id, skillCode: skill.skillCode),
            onTap: {
              Task {
                await store.toggle(
                  courseId: course.id,
                  participantId: p.id,
                  skillCode: skill.skillCode,
                  instructorId: user.instructorId
                )
              }
            }
          )
        }
      }
    }
    .padding(10)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(Color(.systemBackground))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color(.systemGray5), lineWidth: 0.5)
    )
  }

  private var chipColumns: [GridItem] {
    Array(repeating: GridItem(.flexible(minimum: 44, maximum: .infinity), spacing: 6), count: 4)
  }

  private var skillsBySection: [String: [SkillDefinition]] {
    Dictionary(grouping: store.definitions, by: \.section)
  }

  private var orderedSections: [String] {
    SkillSection.order.filter { skillsBySection[$0] != nil }
  }

  private func reload() async {
    if store.definitions.isEmpty {
      await store.loadDefinitions(courseTypeCode: "owd")
    }
    await store.loadRecords(courseId: course.id)
  }
}
```

Hinweise:
- LazyVGrid mit 4 Spalten — bei 5+ Teilnehmern wrappt das automatisch. Für die typischen Soft-Live-Kurse (3-5 Schüler) sieht es sauber aus.
- `courseTypeCode: "owd"` hardcoded — für AOWD/etc. post-Pitch erweitern auf `course.courseType?.code`.
- Loading-Trigger: `definitions` laden nur wenn leer (cached). `records` immer reload bei `.task`/`.refreshable`.

---

### Task 5: CourseDetailView passt participants an SkillCheckTabView durch (Subagent)

**Files:**
- Modify: `apps/ios-native/ATOLL/Views/CourseDetailView.swift`
- Modify: `apps/ios-native/ATOLL/Views/ParticipantsTabView.swift`

Problem: Heute lebt der `ParticipantsStore` als `@State` IN `ParticipantsTabView`. Damit SkillCheckTabView auf die selben participants zugreifen kann, ohne sie doppelt zu laden, ziehen wir den Store in `CourseDetailView` als Owner hoch.

- [ ] **Step 1: CourseDetailView komplett ersetzen:**

```swift
import SwiftUI

struct CourseDetailView: View {
  let course: Course
  let user: CurrentUser

  enum Tab: String, CaseIterable, Identifiable {
    case participants, skillCheck, info
    var id: Self { self }
    var label: String {
      switch self {
      case .participants: "Teilnehmer"
      case .skillCheck:   "Skill-Check"
      case .info:         "Info"
      }
    }
  }

  @State private var selectedTab: Tab = .participants
  @State private var participantsStore = ParticipantsStore()

  var body: some View {
    VStack(spacing: 0) {
      Picker("Bereich", selection: $selectedTab) {
        ForEach(Tab.allCases) { tab in
          Text(tab.label).tag(tab)
        }
      }
      .pickerStyle(.segmented)
      .padding(.horizontal)
      .padding(.top, 8)

      Divider().padding(.top, 8)

      switch selectedTab {
      case .participants:
        ParticipantsTabView(course: course, user: user, store: participantsStore)
      case .skillCheck:
        SkillCheckTabView(course: course, user: user, participants: participantsStore.participants)
      case .info:
        CourseInfoTabView(course: course)
      }
    }
    .navigationTitle(course.title)
    .navigationBarTitleDisplayMode(.inline)
    .task { await participantsStore.load(courseId: course.id) }
  }
}
```

- [ ] **Step 2: ParticipantsTabView Signatur anpassen — `store` als externer Parameter:**

In `ParticipantsTabView.swift`:

Bisher:
```swift
struct ParticipantsTabView: View {
  let course: Course
  let user: CurrentUser
  @State private var store = ParticipantsStore()
  ...
```

→ Neu:
```swift
struct ParticipantsTabView: View {
  let course: Course
  let user: CurrentUser
  @Bindable var store: ParticipantsStore     // injected by CourseDetailView
  @State private var intakeStore = IntakeStore()
  @State private var selectedParticipant: CourseParticipant?
  ...
```

(`@Bindable` ist die @Observable-Convention für injizierte Observable-Stores; alternativ `let store: ParticipantsStore` ohne den `@Bindable`-Wrapper — beides geht für read-only.)

Der `.task`-Block in ParticipantsTabView lädt jetzt nicht mehr `await store.load(courseId:)`, weil das schon CourseDetailView macht. Nur noch `await reloadIntakes()`:

```swift
    .refreshable { await reloadIntakes() }
    .task { await reloadIntakes() }
```

---

### Task 6: Xcode-Project + Build (User)

- [ ] **Step 1: Migration anwenden** im Supabase-Studio (vor dem App-Smoke):

SQL-Editor → Inhalt von `0095_skill_definitions.sql` einfügen → Run.

Verifizieren:

```sql
SELECT count(*) FROM public.skill_definitions WHERE course_type_code = 'owd';
```

Erwartet: 32.

- [ ] **Step 2: Xcode öffnen, 4 neue Files adden:**
  - Models/SkillDefinition.swift → Models-Gruppe
  - Models/SkillRecord.swift → Models-Gruppe
  - Services/SkillCheckStore.swift → Services-Gruppe
  - Components/SkillChip.swift → Components-Gruppe

- [ ] **Step 3:** ⌘B → grün.

Mögliche Stolpersteine:
- "Cannot find 'SkillSection' in scope" → Datei nicht im Target — Target Membership prüfen
- "Type 'SkillCheckTabView' has no member 'participants'" → File-Version stimmt nicht — neu compilen
- "Cannot convert ParticipantsStore to Binding" → das `@Bindable`-Pattern kompiliert nur mit @Observable-Stores (was wir verwenden) — sollte gehen

---

### Task 7: Simulator-Smoke (User)

- [ ] **Step 1: ⌘R**, login, Kurs öffnen.
- [ ] **Step 2:** Segmented-Picker auf "Skill-Check" tippen.
- [ ] **Step 3:** Du solltest die 6 Sektionen sehen (Confined Water Tauchgänge, Beurteilung, Tauchgangsflexible CW, Knowledge Development, Freiwasser-Tauchgänge, Tauchgangsflexible OW), je mit Skills darin.
- [ ] **Step 4:** Pro Skill-Reihe: Teilnehmer-Chips mit Initialen (4 pro Reihe, wrappen wenn mehr).
- [ ] **Step 5:** Tap auf einen Chip → er sollte grün werden mit Check-Icon. Tap nochmal → grau zurück.
- [ ] **Step 6:** App killen + neu öffnen → Status persistent (lädt aus DB).
- [ ] **Step 7:** Web-Cross-Check: gleiches Kurs öffnen, Skill-Check-Tab → der iOS-Tap sollte als grün-getönte Zelle sichtbar sein (Web-SkillCheckTab nutzt noch hardcoded skills, aber padi_skill_records-Rows kommen rein).

---

### Task 8: Commit + TestFlight (User)

Xcode schliessen.

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add -A
git status
git commit -m 'ios(skills): SkillCheckTabView with OWD skill matrix + chip toggle

Neue DB-Tabelle skill_definitions mit allen 32 OWD-Skills als Seed
(1:1 aus padiOwdSkills.ts). Web-Refactor bleibt post-Pitch — Web liest
weiter aus dem hardcoded Constant, iOS aus der DB. Da Seed = Constant
exakt, kein Drift-Risiko in 2 Wochen Soft-Live.

iOS:
- SkillDefinition + SkillRecord Models
- SkillCheckStore mit loadDefinitions(courseTypeCode), loadRecords(courseId),
  toggle(...) optimistisch mit Rollback bei Fehler
- SkillChip Component mit done/undone-Visualisierung
- SkillCheckTabView mit sektionierter LazyVStack-Liste, 4-Spalten-Grid für Chips
- CourseDetailView hostet jetzt ParticipantsStore (geteilt mit SkillCheck)

Out of scope, deferred post-Pitch:
- Long-Press Detail-Sheet (TG#, Quiz/Video, Notes, Datum-Override)
- Heute-vs-Alle-Filter
- Web-Hook useSkillDefinitions(courseTypeCode)
- Andere Kurse als OWD

Refs: docs/superpowers/specs/2026-05-14-ios-instructor-mobile-companion-design.md (Etappe 5)'

git push -u origin ios-etappe-5-skill-check-owd
```

Dann: Xcode → Build hochzählen → Archive → TestFlight → Real-Device-Smoke.

---

### Task 9: Merge nach main (User)

Xcode schliessen.

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git checkout main
git status                    # check
git pull --ff-only
git merge --ff-only ios-etappe-5-skill-check-owd
git push
git branch -d ios-etappe-5-skill-check-owd
git push origin --delete ios-etappe-5-skill-check-owd
git log --oneline -3
```

---

## Self-Review

**Spec coverage check (Section 5 Etappe 5):**
- ✅ Migration 0095 skill_definitions Tabelle + OWD-Seed — Task 2
- ✅ Models SkillDefinition + SkillRecord — Task 3
- ✅ SkillCheckStore mit toggle optimistisch — Task 3
- ✅ SkillCheckTabView mit Skill-Reihen + Chips — Task 4
- ✅ SkillChip Component — Task 3
- ⚠️ **Web-Refactor SkillCheckTab.tsx → DB-Hook AUSGESCHLOSSEN aus E5.** Spec-Risiko R3 sagt das Web muss in selber Etappe mit. Reale Begründung: Seed = Constant 1:1, kein Drift in 2 Wochen, dafür spart's halben Tag Arbeit. Nach Pitch separate kleine Etappe.
- ⚠️ Long-Press Detail-Sheet (Spec Section 10 Open-Question) — auch deferred.

**Placeholder scan:** Keine TBDs.

**Type consistency:**
- `SkillDefinition.skillCode` = String, identisch zu `SkillRecord.skillCode`
- `SkillRecord.participantId` = `CourseParticipant.id` (beide UUID)
- `SkillCheckStore.toggle(courseId:participantId:skillCode:instructorId:)` Signatur konsistent

**Risiken:**
- R1: padi_skill_records.instructor_id FK auf instructors(id) — solange instructors-Tabelle lebt, fine. User schreibt mit user.instructorId (legacy).
- R2: 32 INSERT-Statements könnten in einer Transaction langsam sein — trivial bei 32 Rows.
- R3: Web zeigt nach Migration weiter dieselben Skills (hardcoded). Risk: nach E5 könnte jemand die DB editieren und denken Web sieht die Änderung — nein, Web ist hardcoded bis Web-Refactor-Etappe.
- R4: `@Bindable` Pattern auf injizierten Store funktioniert nur ab Swift 5.9 / iOS 17 — Dispo läuft auf iOS 17+, also OK. Falls Build-Error: fallback auf `let store: ParticipantsStore` (read-only Reference, no binding).

**Pre-flight check:**
- Vor Migration-Apply prüfen ob `padi_skill_records` korrekte FK hat (`instructor_id` auf `instructors(id)`) — wenn schon retargetet, der Smoke-Test muss als User mit gültiger `contacts.id` als `instructor_id` schreiben können (= `user.id`, nicht `user.instructorId`). Aktuell legacy.
