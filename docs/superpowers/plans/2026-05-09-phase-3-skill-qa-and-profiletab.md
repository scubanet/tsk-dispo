# Phase 3 Implementation Plan — Skill-Assessment QA + ProfileTab Decomposition

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Den Instructor-Skill-Assessment-Layer auf zwei Geräten durchstressen + gefundene Critical/Important-Bugs fixen, danach `ProfileTab.swift` (934 LoC) in sechs fokussierte Sub-Komponenten zerlegen, verhaltensneutral.

**Architecture:**
- **Phase 3a:** Strukturierter Checklist-Walkthrough auf iPhone 16 Pro Max + iPad. Bug-Triage nach Severity. Critical+Important werden in Bug-Bash-Runde gefixt; Minor gehen ins Follow-up-File.
- **Phase 3b:** ProfileTab decomposition entlang der echten 6 MARK-Sections. Erst `ProfileCardStyle`-ViewModifier extrahieren als visuelle Baseline, dann Sections in dieser Reihenfolge: QuickStats → Profile → Stamp → Settings → Account → DataManagement (von risikoarm zu risikoreich). Jede Sub-Komponente bekommt Daten/Callbacks via Parameter, kein direkter Singleton-Zugriff. Top-Level ProfileTab hält alle `@Query`/`@AppStorage`/`@State` und reicht durch.

**Tech Stack:** Swift 5.9+, SwiftUI, SwiftData + CloudKit (NSPersistentCloudKitContainer), iOS 17+, Xcode 26 / iOS 26 SDK, Swift Testing framework. Existing Files: alle Phase 1+2 Stabilization-Änderungen sind auf main (commit `695bbb8`).

**Reference Spec:** `docs/superpowers/specs/2026-05-09-phase-3-skill-qa-and-profiletab-design.md`

**Branch:** `feat/phase-3-qa-and-profiletab` (bereits angelegt, HEAD `c11fd9b` mit Spec).

---

## File Structure

**Phase 3a — keine neuen Code-Files initial.** Bug-Fix-Tasks werden mid-flight ergänzt, abhängig von Findings.

Operationale Doku:
- Create: `docs/operational/2026-05-09-phase-3-qa-findings.md` — Bug-Liste mit Severity + Repro.

**Phase 3b — neue Files:**

```
DiveLog Pro/Views/Components/ProfileTab/
├── ProfileCardStyle.swift           (ViewModifier, ~35 LoC)
├── QuickStatsCard.swift             (~50 LoC)
├── ProfileCard.swift                (~85 LoC)
├── ProfileStampCard.swift           (~80 LoC)
├── SettingsSection.swift            (~85 LoC)
├── AccountCard.swift                (~200 LoC)
└── DataManagementCard.swift         (~180 LoC)
```

**Modifizierte Files:**
- `DiveLog Pro/Views/Tabs/ProfileTab.swift` — von 934 LoC auf ~200 LoC reduziert.

---

# Phase 3a — Skill-Assessment QA-Pass

## Task 1: QA-Setup auf beiden Geräten

**Files:** keine.

- [ ] **Step 1.1: Build aufs iPhone 16 Pro Max**

In Xcode: Schema „DiveLog Pro" → Device-Picker auf „iPhone von Dominik" → Cmd+R. Warten bis App startet.

- [ ] **Step 1.2: Build aufs iPad**

Device-Picker auf „Dominik's iPad" → Cmd+R. Warten bis App startet.

- [ ] **Step 1.3: Beide Geräte verifizieren**

- Beide Geräte zeigen denselben aktuellen Logbuch-Stand
- iCloud-Account aktiv auf beiden
- Sign-in mit Apple ID auf beiden erledigt

- [ ] **Step 1.4: Findings-File anlegen**

Erstelle `docs/operational/2026-05-09-phase-3-qa-findings.md`:

```markdown
# Phase 3 QA Findings — 2026-05-09

**Setup:** iPhone 16 Pro Max + iPad, iCloud-Account `<email>`, beide auf HEAD `<sha>` der `feat/phase-3-qa-and-profiletab`-Branch.

## Spur A — Happy Path

(wird in Task 2 ausgefüllt)

## Spur B — Edge Cases

(wird in Task 3 ausgefüllt)

## Spur C — Sync Stress

(wird in Task 4 ausgefüllt)

## Triage-Liste

| # | Severity | Beschreibung | Repro | Fix-Status |
|---|----------|--------------|-------|------------|
| | | | | |

## Minor-Findings (Follow-up)

(werden ins zentrale `follow-ups-stabilize-2026-05-09.md` übertragen)
```

```bash
git add docs/operational/2026-05-09-phase-3-qa-findings.md
git commit -m "docs(qa): create findings file for phase 3 QA pass"
```

---

## Task 2: Spur A — Happy-Path-Walkthrough

**Files:** `docs/operational/2026-05-09-phase-3-qa-findings.md` (Eintragung).

Pro Schritt: durchführen am iPhone, wenn etwas hakt → in der Findings-Datei eintragen mit Severity (Critical / Important / Minor) und Repro.

- [ ] **Step 2.1: Sign-In + leeres Logbuch**

Falls die App noch Sample-Daten oder echte Dives hat: in Profile-Tab → Sample-Data zurücksetzen (oder App neu installieren). Ziel: leeres Logbuch.

- [ ] **Step 2.2: Schüler anlegen**

Logbook-Tab → FAB → „Tauchgang anlegen" → DiveFormView → Course-Training-Toggle ON → Course-Type wählen (z.B. „OWD") → Slot wählen (z.B. „OW1") → „Schüler hinzufügen" → `StudentPicker` → „+ Neuer Schüler" → Felder ausfüllen (name, padi#, email) → speichern.

**Erwartet:** Schüler erscheint im StudentPicker ausgewählt.

- [ ] **Step 2.3: Prior Mastery seeden**

Im StudentPicker: bei dem neu angelegten Schüler → „Prior Mastery seeden" antippen → `PriorMasterySeedSheet` öffnet → ein paar Skills auswählen (z.B. CW1.1, CW1.2) → speichern.

**Erwartet:** Geseeded Skills sind als „mastered" markiert für den Schüler.

- [ ] **Step 2.4: Pool-Session anlegen**

DiveFormView verlassen ohne speichern → Logbook → FAB → „Pool-Session anlegen" → `PoolSessionCreateView` → Slot „CW1", Course „OWD", Datum heute → speichern.

**Erwartet:** Pool-Session ist im Logbuch sichtbar.

- [ ] **Step 2.5: Skills im Pool cyclen**

Pool-Session öffnen → `PoolSessionDetailView` → Schüler aus Liste wählen → Skills im Grid antippen (notStarted → introduced → practiced → mastered).

**Erwartet:** Status-Badges aktualisieren sich pro Tap.

- [ ] **Step 2.6: OWD-Dive anlegen mit Course-Training**

Logbook → FAB → „Tauchgang anlegen" → DiveFormView → Pflichtfelder (Datum, Tauchplatz, Tiefe, Zeit) → Course-Training ON → Slot „OW1" → Schüler wählen → speichern.

**Erwartet:** Dive ist im Logbuch, hat course-training=true.

- [ ] **Step 2.7: DiveDetail Schüler-Section**

Den OWD-Dive im Logbuch antippen → `DiveDetailView` → bis zur Schüler-Section runter scrollen.

**Erwartet:** Schüler-Section zeigt den Schüler mit Skill-Grid. Skills aus der Pool-Session sind als „mastered" sichtbar.

- [ ] **Step 2.8: Im DiveDetail Skills cyclen**

Im Skill-Grid des Dive-Detail einen Skill antippen.

**Erwartet:** Status cycelt; das ist ein neuer SkillCompletion-Record (append-only).

- [ ] **Step 2.9: StudentProfileView**

Aus DiveDetail oder StudentPicker zum `StudentProfileView` navigieren.

**Erwartet:** Per-Slot-Fortschritt korrekt (z.B. „CW1: 5/12 mastered"), Next-Up-Hint zeigt einen sinnvollen Skill.

- [ ] **Step 2.10: Sync auf iPad**

Auf iPad warten ~30-60s → Logbook-Tab öffnen.

**Erwartet:** Schüler, Pool-Session, Dive sind alle vorhanden mit identischen Daten.

- [ ] **Step 2.11: Buddy-Signature**

Sign-Tab → Buddy für den OWD-Dive zeichnen → Signatur speichern.

**Erwartet:** Signatur ist gespeichert und mit dem Dive verknüpft.

- [ ] **Step 2.12: PDF-Export**

Wo auch immer der PDF-Export-Trigger ist (Sign-Tab oder Profile-Tab → Export) → PDF generieren mit Schüler+Skill-Daten.

**Erwartet:** PDF enthält Dive-Header, Schüler-Liste mit Skill-Status pro Slot.

- [ ] **Step 2.13: Spur A Findings dokumentieren**

In der Findings-Datei unter „Spur A — Happy Path" pro Schritt notieren: Pass / Fail / Bug. Bugs in die Triage-Liste eintragen mit Severity.

```bash
git add docs/operational/2026-05-09-phase-3-qa-findings.md
git commit -m "docs(qa): spur A — happy path findings"
```

---

## Task 3: Spur B — Edge-Cases

**Files:** `docs/operational/2026-05-09-phase-3-qa-findings.md`.

- [ ] **Step 3.1: DiveFormView mit leerer Schüler-Liste**

Neuer Dive → Course-Training ON → Schüler-Liste leer (vorher alle Schüler löschen oder über Test-Account).

**Erwartet:** UI zeigt sinnvollen Empty-State („Noch keine Schüler — neuen anlegen?"), nicht Crash.

- [ ] **Step 3.2: Schüler ohne Pool-Session direkt im OWD-Dive**

Neuen Schüler anlegen ohne Pool-Session → direkt in OWD-Dive 1 wählen → Skill-Grid öffnen.

**Erwartet:** Skill-Grid zeigt alle Skills als notStarted, kein Crash, Cycle funktioniert.

- [ ] **Step 3.3: notStarted-Badge-Rendering**

Im SkillReviewSheet einen Skill auf notStarted zurücksetzen (Long-Press → notStarted).

**Erwartet:** Badge zeigt notStarted-Style klar (z.B. graue Outline), unterscheidet sich von introduced.

- [ ] **Step 3.4: Multi-Sprache mid-flow**

DiveFormView mit Course-Training öffnen, ein paar Schüler-Skills cyclen → ohne zu schließen in iOS-Settings → DiveLog Pro Settings → Sprache wechseln (DE↔EN) → zurück in App.

**Erwartet:** UI rendert sauber in neuer Sprache; offene Edits gehen nicht verloren.

- [ ] **Step 3.5: Massen-Daten — 10 Schüler in einer Session**

Pool-Session anlegen → 10 Schüler nacheinander hinzufügen → Skills cyclen.

**Erwartet:** Performance bleibt nutzbar (kein spürbarer Lag), Picker-UX ist scrollbar, Skill-Grid ist navigierbar.

- [ ] **Step 3.6: Dive löschen mit angehängten Skill-Records**

Logbook → Dive mit Schülern + Skills swipe-deleten → Undo-Snackbar erscheint kurz → 5s warten (commit).

**Erwartet:** Dive ist weg, SkillCompletion-Records sind weg (oder als „verwaist" markiert je nach delete rule), Schüler-Profile zeigt entsprechend weniger Skills.

- [ ] **Step 3.7: Schüler löschen mit StudentEditSheet destructive delete**

StudentPicker → Schüler editieren → „Schüler löschen" → bestätigen.

**Erwartet:** Schüler ist weg, alle SkillCompletion-Records des Schülers sind weg, Pool-Sessions/Dives die ihn referenzierten zeigen ihn nicht mehr.

- [ ] **Step 3.8: Spur B Findings dokumentieren**

```bash
git add docs/operational/2026-05-09-phase-3-qa-findings.md
git commit -m "docs(qa): spur B — edge case findings"
```

---

## Task 4: Spur C — Sync-Stress

**Files:** `docs/operational/2026-05-09-phase-3-qa-findings.md`.

- [ ] **Step 4.1: Konkurrente Skill-Cycles**

iPhone und iPad ins Flugzeugmodus → auf iPhone für Schüler X den Skill „CW2.4" zu „practiced" cyclen → auf iPad für denselben Schüler+Skill auf „mastered" cyclen → beide online → 30-60s warten.

**Erwartet:** Beide Geräte zeigen denselben Skill-Status (das spätere von beiden Cycles, da SkillCompletion append-only ist und `currentStatus` = latest record). Keine doppelten Status-Badges.

- [ ] **Step 4.2: Konkurrentes Schüler-Anlegen mit gleichem Namen**

Beide Geräte Flugzeugmodus → auf iPhone Schüler „Max Mustermann" anlegen → auf iPad ebenfalls Schüler „Max Mustermann" anlegen → beide online → 30-60s warten.

**Erwartet:** Beide Geräte zeigen entweder zwei separate Schüler (mit gleichem Namen aber verschiedenen UUIDs) oder Dedupe-Logik fängt das ab. Was passiert in der Realität ist die Frage — Bug ja oder nein hängt von der Erwartung ab. **Findings dokumentieren mit Notiz, was die App tut.**

- [ ] **Step 4.3: Spur C Findings dokumentieren**

```bash
git add docs/operational/2026-05-09-phase-3-qa-findings.md
git commit -m "docs(qa): spur C — sync stress findings"
```

---

## Task 5: Triage und Bug-Bash-Plan

**Files:** `docs/operational/2026-05-09-phase-3-qa-findings.md`.

- [ ] **Step 5.1: Triage-Liste konsolidieren**

Alle Bugs aus Spuren A/B/C zusammenfassen in der Triage-Liste der Findings-Datei. Pro Bug: Severity (Critical/Important/Minor), Beschreibung, Repro-Steps.

- [ ] **Step 5.2: Stop-Bedingung prüfen**

Wenn die Triage-Liste **mehr als 5 Critical+Important Bugs** zeigt:
1. Markiere den Plan als „blocked — needs scope adjustment".
2. Stop. Bring den Status zum User. Ggf. wird Phase 3a zu einem eigenen Branch und Phase 3b verschoben.

Sonst: weiter zu Step 5.3.

- [ ] **Step 5.3: Minor-Bugs ins Follow-up-File**

Alle Minor-Bugs in `docs/operational/follow-ups-stabilize-2026-05-09.md` als neue Sektion „# Phase-3 Minor-Findings" eintragen. Format: gleich wie die existing Issues.

- [ ] **Step 5.4: Bug-Bash-Tasks definieren**

Pro Critical/Important-Bug einen Bug-Bash-Task im Plan ergänzen unterhalb dieser Section. Format:

```markdown
## Bug-Bash Task X: <kurze Beschreibung>

**Severity:** Critical | Important
**Repro:** <aus Findings>
**File(s):** <wahrscheinlich betroffen>
**Approach:** <kurzer Fix-Plan>

- [ ] Step X.1: Reproduzieren am Device
- [ ] Step X.2: Code lokalisieren (grep, lesen)
- [ ] Step X.3: Fix implementieren (ggf. via Subagent-Dispatch)
- [ ] Step X.4: Test wenn sinnvoll
- [ ] Step X.5: Re-Test am Device
- [ ] Step X.6: Commit
```

- [ ] **Step 5.5: Triage-File committen**

```bash
git add docs/operational/2026-05-09-phase-3-qa-findings.md \
        docs/operational/follow-ups-stabilize-2026-05-09.md
git commit -m "docs(qa): triage results + bug-bash plan"
```

---

## Task 6: Bug-Bash-Runde (Inhalt mid-flight ergänzt)

**Hinweis:** Diese Section wird in Step 5.4 mit konkreten Bug-Bash-Tasks gefüllt. Wenn nach Triage 0 Critical/Important-Bugs vorliegen → Section überspringen, direkt zu Phase 3b.

(Pro Bug ein Sub-Task wie in Step 5.4 beschrieben. Jeder Bug bekommt seinen eigenen Commit. Nach allen Bug-Fixes: ein Re-Test-Step der das Original-QA-Szenario nochmal durchspielt um Regressionen auszuschließen.)

---

# Phase 3b — ProfileTab Decomposition

**Vor-Bedingung:** Phase 3a ist abgeschlossen, alle Critical/Important-Bugs gefixt, Working-Tree clean.

## Task 7: ProfileCardStyle ViewModifier extrahieren

**Files:**
- Create: `DiveLog Pro/Views/Components/ProfileTab/ProfileCardStyle.swift` (~35 LoC)
- Modify: `DiveLog Pro/Views/Tabs/ProfileTab.swift` (apply modifier inline to existing computed properties)

- [ ] **Step 7.1: Existing Card-Background-Pattern erfassen**

Lies `DiveLog Pro/Views/Tabs/ProfileTab.swift` Zeilen 684-755 (`profileCard`-Computed-Property) und identifiziere das gemeinsame Wrapper-Pattern:

```bash
grep -n "padding\|background\|cornerRadius\|RoundedRectangle\|DSRadius\|DSSpacing" "DiveLog Pro/Views/Tabs/ProfileTab.swift" | head -20
```

Schreibe das Wrapper-Pattern auf (typisch: padding, RoundedRectangle background, optional shadow).

- [ ] **Step 7.2: ProfileCardStyle.swift schreiben**

Folder anlegen falls nötig:

```bash
mkdir -p "DiveLog Pro/Views/Components/ProfileTab"
```

File-Inhalt:

```swift
import SwiftUI

/// Shared visual style for cards in the Profile tab. Applying this modifier
/// keeps padding, background and corner-radius identical across all
/// extracted sub-cards so the decomposition does not drift visually.
///
/// Adjust this in one place if Profile-tab card styling changes.
struct ProfileCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(DSSpacing.l)
            .background(
                RoundedRectangle(cornerRadius: DSRadius.l)
                    .fill(Color.cardBackground)
            )
    }
}

extension View {
    /// Apply the standard Profile-tab card style (padding + rounded background).
    func profileCardStyle() -> some View {
        modifier(ProfileCardStyle())
    }
}
```

(Sollten `DSSpacing.l`, `DSRadius.l`, oder `Color.cardBackground` in der Codebase anders heißen, anpassen — `Color.cardBackground` ist möglicherweise `Color.appCardBackground` oder ein anderes Theme-Token. Mit `grep -n "cardBackground\|appCardBackground" "DiveLog Pro/Utils/Theme.swift"` verifizieren bevor du das File committest.)

- [ ] **Step 7.3: Style auf bestehende Cards anwenden**

In `DiveLog Pro/Views/Tabs/ProfileTab.swift`: bei jeder der 6 Computed-Properties (`profileCard`, `stampCard`, `quickStatsCard`, `settingsSection`, `dataManagementCard`, `accountCard`) das existing Wrapper-Pattern (padding, RoundedRectangle background) durch `.profileCardStyle()` ersetzen — *nur falls* das Wrapper-Pattern wirklich einheitlich ist. Wenn eine Card ein abweichendes Padding hat, das beibehalten und in einem späteren Task harmonisieren.

- [ ] **Step 7.4: Build prüfen**

```bash
cd "/Users/dominik/Desktop/Developer/DiveLog Pro"
xcodebuild build -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'generic/platform=iOS' 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7.5: Visueller Smoke-Test**

App im Simulator (iPhone 17 Pro Max) starten → Profile-Tab öffnen → vergleichen mit „Vor-Refactor"-Erinnerung. Cards müssen identisch aussehen (Spacing, Background, Corner-Radius). Falls visuelle Drift: Style-File anpassen, Step 7.4 wiederholen.

- [ ] **Step 7.6: Commit**

```bash
git add "DiveLog Pro/Views/Components/ProfileTab/ProfileCardStyle.swift" \
        "DiveLog Pro/Views/Tabs/ProfileTab.swift"
git commit -m "refactor(profile): extract ProfileCardStyle ViewModifier

Shared visual style (padding + rounded background) for all six
sub-cards in the Profile tab. Applied inline to the existing
computed properties in ProfileTab.swift; sub-card extraction in
follow-up commits."
```

---

## Task 8: Extract QuickStatsCard

**Files:**
- Create: `DiveLog Pro/Views/Components/ProfileTab/QuickStatsCard.swift` (~50 LoC)
- Modify: `DiveLog Pro/Views/Tabs/ProfileTab.swift` (remove `quickStatsCard` computed property, use `QuickStatsCard(...)` in body)

- [ ] **Step 8.1: Original-Code lesen**

Lies `DiveLog Pro/Views/Tabs/ProfileTab.swift` Zeilen 826-858 (`quickStatsCard`-Computed-Property). Identifiziere die Daten-Dependencies (welche Properties der Card werden gelesen? Wahrscheinlich `dives` für Counts).

- [ ] **Step 8.2: QuickStatsCard.swift erstellen**

Datei anlegen:

```swift
import SwiftUI

/// Compact stats row showing total dives, total bottom-time, deepest dive.
/// Stateless — receives the dive list from `ProfileTab`.
struct QuickStatsCard: View {
    let dives: [Dive]

    var body: some View {
        // ─── Code aus ProfileTab.swift Zeilen 826-858 hier rein ───
        // Replace direct query/state references mit `dives` parameter
        // Apply `.profileCardStyle()` am Ende (oder genau wie im Original)
        // ────────────────────────────────────────────────────────────
    }
}
```

(Den genauen View-Body kopiere wörtlich aus dem Original, ersetze `dives` (aus @Query) durch den Parameter `dives`.)

- [ ] **Step 8.3: ProfileTab.swift anpassen**

In `DiveLog Pro/Views/Tabs/ProfileTab.swift`:

1. Lösche die Computed-Property `private var quickStatsCard: some View { ... }` (Zeilen 826-858).
2. Im `body` ersetze `quickStatsCard` durch `QuickStatsCard(dives: dives)`.

- [ ] **Step 8.4: Build prüfen**

```bash
xcodebuild build -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'generic/platform=iOS' 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 8.5: Visueller Smoke-Test**

App im Simulator starten → Profile-Tab → QuickStats-Bereich erscheint identisch (Counts korrekt, Layout unverändert).

- [ ] **Step 8.6: Commit**

```bash
git add "DiveLog Pro/Views/Components/ProfileTab/QuickStatsCard.swift" \
        "DiveLog Pro/Views/Tabs/ProfileTab.swift"
git commit -m "refactor(profile): extract QuickStatsCard sub-component

Stateless view, takes [Dive] as parameter. ProfileTab calls it
with QuickStatsCard(dives: dives) — same rendering, no behavior
change."
```

---

## Task 9: Extract ProfileCard

**Files:**
- Create: `DiveLog Pro/Views/Components/ProfileTab/ProfileCard.swift` (~85 LoC)
- Modify: `DiveLog Pro/Views/Tabs/ProfileTab.swift`

- [ ] **Step 9.1: Original-Code lesen**

Zeilen 684-755 (`profileCard`-Computed-Property). Identifiziere Dependencies:
- `profile: DiverProfile?` (computed)
- `appleSignIn: AppleSignInService` (für Email-Fallback)
- `showingEdit` (Trigger für Edit-Sheet)

- [ ] **Step 9.2: ProfileCard.swift erstellen**

```swift
import SwiftUI
import SwiftData

/// Profile header card: avatar, name, PADI level, contact preview.
/// Stateless except for triggering the edit sheet via callback.
struct ProfileCard: View {
    let profile: DiverProfile?
    let onEdit: () -> Void

    var body: some View {
        // ─── Code aus ProfileTab.swift Zeilen 684-755 hier rein ───
        // - Statt `profile` (computed property) → der Parameter `profile`
        // - Edit-Tap-Action → `onEdit()` callback
        // - Apple-SignIn-Service-Zugriffe für Email-Fallback bleiben
        //   (AppleSignInService.shared ist Singleton, OK direkt zu callen)
        // ────────────────────────────────────────────────────────────
    }
}
```

- [ ] **Step 9.3: ProfileTab.swift anpassen**

1. Lösche `private var profileCard: some View { ... }` (Zeilen 684-755).
2. Im `body` ersetze `profileCard` durch `ProfileCard(profile: profile, onEdit: { showingEdit = true })`.

(Falls die original `profileCard` direkt `showingEdit = true` setzt statt eines Callback, war das vor dem Refactor inline OK; jetzt wird's via Closure gemacht.)

- [ ] **Step 9.4: Build prüfen**

```bash
xcodebuild build -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'generic/platform=iOS' 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 9.5: Visueller Smoke-Test**

App-Profile-Tab öffnen → Profile-Card erscheint identisch → Edit-Button öffnet `ProfileEditView` (Sheet) → Sheet schließen.

- [ ] **Step 9.6: Commit**

```bash
git add "DiveLog Pro/Views/Components/ProfileTab/ProfileCard.swift" \
        "DiveLog Pro/Views/Tabs/ProfileTab.swift"
git commit -m "refactor(profile): extract ProfileCard sub-component

Renders profile avatar, name, level, contact preview. Profile
data via parameter, edit action via closure. No behavior change."
```

---

## Task 10: Extract ProfileStampCard

**Files:**
- Create: `DiveLog Pro/Views/Components/ProfileTab/ProfileStampCard.swift` (~80 LoC)
- Modify: `DiveLog Pro/Views/Tabs/ProfileTab.swift`

- [ ] **Step 10.1: Original-Code lesen**

Zeilen 756-825 (`stampCard`). Dependencies:
- `profile?.stampImageData` (oder direkt aus dem profile-Param)
- Photo-Picker-State (vermutlich mit `@State` für `pickerItem`)
- Möglicherweise: Funktion `loadPickedStamp(...)` oder ähnlich

- [ ] **Step 10.2: ProfileStampCard.swift erstellen**

```swift
import SwiftUI
import PhotosUI
import SwiftData

/// Stamp-image picker card. Lets the user attach a digital stamp PNG to
/// their profile. Owns its own picker state (PhotosPickerItem) but
/// persists the resulting Data via callback so ProfileTab can update
/// the model.
struct ProfileStampCard: View {
    let profile: DiverProfile?
    let onStampDataChanged: (Data?) -> Void

    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        // ─── Code aus ProfileTab.swift Zeilen 756-825 hier rein ───
        // - PhotosPickerItem-Bindung wird zum lokalen @State pickerItem
        // - .onChange(of: pickerItem) lädt Data und ruft onStampDataChanged
        // - Stamp-Bild wird aus profile.stampImageData (Parameter) gerendert
        // - Delete-Stamp-Button → onStampDataChanged(nil)
        // ────────────────────────────────────────────────────────────
    }
}
```

- [ ] **Step 10.3: ProfileTab.swift anpassen**

1. Lösche `private var stampCard: some View { ... }` (Zeilen 756-825).
2. Im `body` ersetze `stampCard` durch:

```swift
ProfileStampCard(profile: profile) { newStampData in
    profile?.stampImageData = newStampData
    try? ctx.save()
}
```

- [ ] **Step 10.4: Build prüfen**

```bash
xcodebuild build -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'generic/platform=iOS' 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 10.5: Visueller Smoke-Test**

Profile-Tab → Stamp-Card sichtbar → Foto-Picker öffnet → ein Foto wählen → Stamp wird gerendert → App schließen+neu öffnen → Stamp ist persistiert.

- [ ] **Step 10.6: Commit**

```bash
git add "DiveLog Pro/Views/Components/ProfileTab/ProfileStampCard.swift" \
        "DiveLog Pro/Views/Tabs/ProfileTab.swift"
git commit -m "refactor(profile): extract ProfileStampCard sub-component

Owns its PhotosPickerItem state locally; reports stamp-image
changes back to ProfileTab via closure. Profile data via parameter."
```

---

## Task 11: Extract SettingsSection

**Files:**
- Create: `DiveLog Pro/Views/Components/ProfileTab/SettingsSection.swift` (~85 LoC)
- Modify: `DiveLog Pro/Views/Tabs/ProfileTab.swift`

**Hinweis:** Diese Section war im ursprünglichen Spec übersehen — wir nehmen sie hier mit, sonst bleibt ProfileTab ~100 LoC zu groß.

- [ ] **Step 11.1: Original-Code lesen**

Zeilen 270-342 (`settingsSection`-Computed-Property). Schau dir an, was die Section enthält — typisch: Sprache umschalten, Maßeinheiten, Onboarding-Reset, etc.

- [ ] **Step 11.2: SettingsSection.swift erstellen**

```swift
import SwiftUI
import SwiftData

/// User-facing settings: language, unit system, onboarding reset, etc.
/// Reads + writes AppStorage via @Binding so ProfileTab stays the source
/// of truth for those AppStorage keys.
struct SettingsSection: View {
    let profile: DiverProfile?
    @Binding var language: String
    @Binding var hasCompletedOnboarding: Bool
    let onShowQR: () -> Void
    let onExport: () -> Void
    // ... weitere Callbacks abhängig vom Original

    var body: some View {
        // ─── Code aus ProfileTab.swift Zeilen 270-342 hier rein ───
        // ────────────────────────────────────────────────────────────
    }
}
```

(Die genaue Parameter-Liste ergibt sich aus den verwendeten `@AppStorage`/`@State`-Properties im Original. Beim Lesen identifizieren, dann hier durchreichen.)

- [ ] **Step 11.3: ProfileTab.swift anpassen**

1. Lösche `private var settingsSection: some View { ... }` (Zeilen 270-342).
2. Im `body` ersetze durch `SettingsSection(...)` mit den entsprechenden Bindings/Callbacks.

- [ ] **Step 11.4: Build prüfen**

```bash
xcodebuild build -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'generic/platform=iOS' 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 11.5: Visueller Smoke-Test**

Profile-Tab → Settings-Section sichtbar → Sprach-Toggle ändert die Sprache → Maßeinheiten-Toggle ändert Anzeige → QR-Code-Button öffnet `MyQRCodeView` Sheet.

- [ ] **Step 11.6: Commit**

```bash
git add "DiveLog Pro/Views/Components/ProfileTab/SettingsSection.swift" \
        "DiveLog Pro/Views/Tabs/ProfileTab.swift"
git commit -m "refactor(profile): extract SettingsSection sub-component

Language toggle, unit system, onboarding reset, QR-code action.
AppStorage-bound bindings flow through from ProfileTab."
```

---

## Task 12: Extract AccountCard

**Files:**
- Create: `DiveLog Pro/Views/Components/ProfileTab/AccountCard.swift` (~200 LoC)
- Modify: `DiveLog Pro/Views/Tabs/ProfileTab.swift`

- [ ] **Step 12.1: Original-Code lesen**

Zeilen 500-683 (`accountCard` + Account-actions Helpers). Identifiziere:
- Apple-Sign-In-Status-Display (`appleSignIn.currentUserID`, Email-Fallback)
- Sign-out-Button (triggert `showingSignOutConfirm`)
- Delete-Account-Button (triggert `showingDeleteConfirm`)
- Helper-Funktionen wie `performSignOut()`, `performDeleteAccount()` (typisch in dem Bereich)

- [ ] **Step 12.2: AccountCard.swift erstellen**

```swift
import SwiftUI
import SwiftData

/// Apple-Sign-In status, sign-out / delete-account actions.
/// Sign-out and delete-account confirmations stay in ProfileTab (they
/// drive @State that controls the alerts). This card just exposes
/// callbacks for the destructive button taps.
struct AccountCard: View {
    let profile: DiverProfile?
    let appleSignIn: AppleSignInService
    let onSignOutTap: () -> Void
    let onDeleteAccountTap: () -> Void

    var body: some View {
        // ─── Code aus ProfileTab.swift Zeilen 500-590 hier rein ───
        // (nur die View, NICHT die Helper-Funktionen)
        // ────────────────────────────────────────────────────────────
    }
}
```

**Wichtig:** die Helper-Funktionen `performSignOut()`, `performDeleteAccount()` etc. **bleiben in ProfileTab**, weil sie ModelContext + Singletons mutieren. Sie werden via Callbacks angesprungen.

- [ ] **Step 12.3: ProfileTab.swift anpassen**

1. Lösche `private var accountCard: some View { ... }` (Zeilen 500-590, *nur* die View, nicht die Helpers).
2. Im `body` ersetze durch:

```swift
AccountCard(
    profile: profile,
    appleSignIn: appleSignIn,
    onSignOutTap: { showingSignOutConfirm = true },
    onDeleteAccountTap: { showingDeleteConfirm = true }
)
```

- [ ] **Step 12.4: Build prüfen**

```bash
xcodebuild build -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'generic/platform=iOS' 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 12.5: Visueller Smoke-Test**

Profile-Tab → Account-Card sichtbar → Sign-out-Button öffnet Confirmation-Dialog → Cancel funktioniert → echter Sign-out funktioniert (App-Status zurücksetzen).

- [ ] **Step 12.6: Commit**

```bash
git add "DiveLog Pro/Views/Components/ProfileTab/AccountCard.swift" \
        "DiveLog Pro/Views/Tabs/ProfileTab.swift"
git commit -m "refactor(profile): extract AccountCard sub-component

Apple-Sign-In status display, sign-out + delete-account triggers.
Destructive confirmations stay on ProfileTab; AccountCard just
exposes button-tap callbacks."
```

---

## Task 13: Extract DataManagementCard

**Files:**
- Create: `DiveLog Pro/Views/Components/ProfileTab/DataManagementCard.swift` (~180 LoC)
- Modify: `DiveLog Pro/Views/Tabs/ProfileTab.swift`

- [ ] **Step 13.1: Original-Code lesen**

Zeilen 343-499 (`dataManagementCard` + dedupe + sample-data). Komplexester Block: enthält Export-Button, Sample-Data-Loader, Dedupe-Trigger, Delete-All-Data-Trigger, Result-Messages.

Identifiziere:
- Inputs: `dives`, `profiles`, `duplicateGroups`, `dedupeResultMessage`, `sampleLoadedMessage`
- Outputs (Callbacks): onExport, onLoadSampleData, onDedupe, onDeleteAll
- Helper-Funktionen `performDedupe`, `loadSampleData`, `duplicateGroups` etc. — **bleiben in ProfileTab**

- [ ] **Step 13.2: DataManagementCard.swift erstellen**

```swift
import SwiftUI
import SwiftData

/// Data management actions: export, load sample data, deduplicate,
/// delete all data. All destructive actions are confirmed via
/// ProfileTab's @State-driven dialogs; this card only triggers them.
struct DataManagementCard: View {
    let dives: [Dive]
    let isLogbookEmpty: Bool
    let duplicateCount: Int
    let dedupeResultMessage: String?
    let sampleLoadedMessage: String?
    let onExport: () -> Void
    let onLoadSampleData: () -> Void
    let onDedupe: () -> Void
    let onDeleteAll: () -> Void

    var body: some View {
        // ─── Code aus ProfileTab.swift Zeilen 343-499 hier rein ───
        // - duplicateGroups.count Lookups → duplicateCount
        // - dives.isEmpty checks → isLogbookEmpty
        // - Result messages bleiben gleich, kommen via Parameter
        // ────────────────────────────────────────────────────────────
    }
}
```

- [ ] **Step 13.3: ProfileTab.swift anpassen**

1. Lösche `private var dataManagementCard: some View { ... }` (Zeilen 343-499 — nur die View, nicht die Helpers).
2. Im `body` ersetze durch:

```swift
DataManagementCard(
    dives: dives,
    isLogbookEmpty: dives.isEmpty,
    duplicateCount: duplicateGroups.count,
    dedupeResultMessage: dedupeResultMessage,
    sampleLoadedMessage: sampleLoadedMessage,
    onExport: { showingExport = true },
    onLoadSampleData: { showingLoadSampleConfirm = true },
    onDedupe: { showingDedupeConfirm = true },
    onDeleteAll: { showingDeleteConfirm = true }
)
```

- [ ] **Step 13.4: Build prüfen**

```bash
xcodebuild build -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'generic/platform=iOS' 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 13.5: Tests laufen lassen — bestehende müssen weiter grün sein**

```bash
xcodebuild test -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:"DiveLog ProTests/NumberingTests" \
  -only-testing:"DiveLog ProTests/PhotoStoreTests" \
  -only-testing:"DiveLog ProTests/ModelContextExtensionsTests" 2>&1 | tail -15
```

Expected: alle Tests pass.

- [ ] **Step 13.6: Visueller Smoke-Test**

Profile-Tab → DataManagement-Card sichtbar → Export-Button öffnet Sheet → Sample-Data-Loader funktioniert auf leerem Logbuch → Dedupe-Trigger zeigt Confirmation → Delete-All zeigt Confirmation.

- [ ] **Step 13.7: Commit**

```bash
git add "DiveLog Pro/Views/Components/ProfileTab/DataManagementCard.swift" \
        "DiveLog Pro/Views/Tabs/ProfileTab.swift"
git commit -m "refactor(profile): extract DataManagementCard sub-component

Largest of the six sub-cards — export, sample-data-loader, dedupe
trigger, delete-all-data trigger. Confirmations stay on ProfileTab;
DataManagementCard exposes a callback per action.

ProfileTab is now ~200 LoC (down from 934), holds all queries +
state + helper functions, composes the six sub-cards."
```

---

## Task 14: Final-Verification + LoC-Reduktion-Check

**Files:** keine code changes, nur Verifikation.

- [ ] **Step 14.1: ProfileTab.swift LoC-Count**

```bash
wc -l "DiveLog Pro/Views/Tabs/ProfileTab.swift"
```

Expected: <250 LoC. Falls deutlich darüber: schauen, was übrig ist, ob noch eine Section übersehen wurde.

- [ ] **Step 14.2: Sub-Card-Folder-Listing**

```bash
ls -la "DiveLog Pro/Views/Components/ProfileTab/"
wc -l "DiveLog Pro/Views/Components/ProfileTab/"*.swift
```

Expected: 7 Files (1 ViewModifier + 6 Sub-Cards), keiner über ~210 LoC.

- [ ] **Step 14.3: Voller Build + Test-Suite**

```bash
xcodebuild build -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'generic/platform=iOS' 2>&1 | tail -5

xcodebuild test -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' 2>&1 | tail -20
```

Expected: alle Tests pass.

- [ ] **Step 14.4: End-to-End Smoke-Test**

App im Simulator starten → ProfileTab durchklicken: Edit, Stamp-Picker, Export, Sample-Data, Sign-out-Dialog, alle Settings — alles muss wie vorher funktionieren.

- [ ] **Step 14.5: Branch-State final festhalten**

```bash
git log --oneline main..HEAD
```

Erwartete Commits: docs(spec), QA-Findings (3-4 Commits), Bug-Bash-Fixes (variabel), 7 refactor(profile)-Commits.

---

## Self-Review Checklist (vor Plan-Abschluss)

- [ ] Spec coverage: Phase 3a hat Tasks 1-6 (Setup, 3 Spuren, Triage, Bug-Bash). Phase 3b hat Tasks 7-13 (1 ViewModifier + 6 Cards) + Task 14 (Verification). Spec-Section "Was nicht in diesem Spec ist" wird respektiert.
- [ ] Settings-Section ist als Task 11 mitaufgenommen (Spec hatte sie übersehen).
- [ ] Reihenfolge der Refactor-Tasks: ViewModifier → kleinste Cards (QuickStats, Profile, Stamp) → mittel (Settings) → größte (Account, DataManagement). Risikoarm zuerst.
- [ ] Jeder Refactor-Task hat: Read-Step, Create-Step, Modify-Step, Build-Step, Smoke-Test-Step, Commit-Step.
- [ ] Helper-Funktionen (`performDedupe`, `loadSampleData`, `performSignOut`, `deduplicateProfiles`) bleiben in ProfileTab — explizit erwähnt in Task 12 + 13.
- [ ] Bug-Bash (Task 6) bleibt bewusst skeleton, weil die Bugs erst in Triage (Task 5) bekannt sind.
- [ ] Stop-Bedingung (>5 Critical+Important Bugs) ist in Task 5.2 explizit.
- [ ] Keine Placeholder. Jeder Step hat konkreten Befehl oder Code-Snippet.
- [ ] Existing Tests müssen weiter grün laufen (Task 13.5).

## Out-of-scope für diesen Plan

- Phase 4 (Pro-Gating-Audit, App Store Connect, TestFlight).
- Refactor anderer Tabs (LogbookTab, JournalTab, StatsTab).
- ProfileEditView-Refactor.
- Snapshot-Test-Framework.
- Bugs unterhalb Severity „Important" — gehen ins Follow-up-File.
