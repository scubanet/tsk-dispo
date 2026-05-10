# DiveLog Pro — Phase 3: Skill-Assessment QA + ProfileTab Decomposition

**Datum:** 2026-05-09
**Branch:** wird `feat/phase-3-qa-and-profiletab` (eigener Branch von `main`).
**Status:** Spec / awaiting user review
**Vorgänger:** Phase 1+2 abgeschlossen und gemerged (commit `695bbb8`).

## Ziel

Zwei lose gekoppelte Workstreams in einem Plan:

**3a.** Den Instructor-Skill-Assessment-Layer (40+ Commits seit April) einmal real auf zwei Geräten durchstressen, gefundene Bugs nach Severity triagieren und Critical+Important fixen.

**3b.** `ProfileTab.swift` (aktuell 934 LoC, 9 MARK-Sections) in fokussierte Sub-Komponenten zerlegen. Top-Level wird zur Komposition (~200 LoC). Verhaltensneutral.

3a kommt zuerst, weil dort gefundene Bugs in `ProfileTab` möglicherweise im Refactor mitfließen sollten, statt sie zweimal anzufassen.

## Heutiger Stand

`main` hat den `feat/instructor-skill-assessment`-Branch gemerged (`695bbb8`). Phase 1+2 (Bug-Fixes für Numbering, Wetter, Foto-Sync; Paywall-Foundation; CloudKit-Konvergenz) sind verifiziert auf iPhone + iPad. Skill-Assessment-Layer-Files alle in Place: `StudentProfileView`, `SkillAssessmentGrid`, `StudentPicker`, `SkillReviewSheet`, `PriorMasterySeedSheet`, `ExtraSkillPickerSheet`, `PoolSessionCreateView`/`DetailView`. PDF-Export über `Sign`-Tab existiert.

Phase 4 (Pro-Gating-Coverage-Audit, Onboarding-Touchpoint, App-Store-Connect, TestFlight) ist explizit out of scope.

## Phase 3a — Skill-Assessment QA-Pass

### Vorgehen

Strukturierter Checklist-Walkthrough auf iPhone 16 Pro Max + iPad, beide am selben iCloud-Account, beide auf HEAD `main`. Für jeden Schritt: Pass / Fail / Bug-Notiz. Bugs werden mit Severity (Critical / Important / Minor) und kurzer Repro-Beschreibung gesammelt. Nach dem QA-Pass wird die Bug-Liste triagiert; Critical und Important werden in einer Bug-Bash-Runde gefixt (separate Commits, ggf. Tests). Minor gehen ins `docs/operational/follow-ups-stabilize-2026-05-09.md` (oder neue Datei für Phase-3-Findings).

### Test-Setup

- iPhone 16 Pro Max + iPad, beide mit aktuellem Build von `main`.
- iCloud-Account aktiv, Sign-In erledigt.
- Test-Daten: leeres Logbuch oder Sample-Data-geladen — wird in der Checklist pro Schritt klar gestellt.

### Checklist-Aufbau

Drei Spuren, die der Plan in eindeutige Steps zerlegen wird:

**Spur A — Happy Path End-to-End** (~25 Min):

1. Schüler anlegen über `StudentPicker` → `NewStudentSheet` (Felder: name, padi#, email).
2. Prior Mastery seeden über `PriorMasterySeedSheet` (Skill-by-Skill-Checklist für drop-in CD-Use-Case).
3. Pool-Session anlegen über `PoolSessionCreateView` (slot, course type, location), Skills im Grid cyclen (notStarted → introduced → practiced → mastered).
4. OWD-Dive anlegen über `DiveFormView`, Course-Training-Toggle aktivieren, Schüler aus Liste wählen, im Skill-Grid Skills cyclen.
5. `DiveDetailView` öffnen — Schüler-Section sichtbar, jeder Schüler mit eigenem Skill-Grid.
6. `StudentProfileView` öffnen — Per-Slot-Fortschritt korrekt (mastered/total pro Slot, next-up Hint).
7. iPad ansehen — nach ~30-60s ist alles synchron (Schüler, Pool-Session, Dive, Skills, StudentProfile).
8. `Sign`-Tab → Buddy-Signature für den Dive zeichnen, mit Schüler-Daten.
9. PDF-Export über `Sign`-Tab (oder wo auch immer der Trigger ist) — PDF enthält Dive-Daten plus Schüler-Skill-Status.

**Spur B — Edge Cases** (~15 Min):

1. `DiveFormView` mit Course-Training=on aber leerer Schüler-Liste — was zeigt das UI?
2. Schüler ohne Pool-Session, direkt in OWD-Dive 1 — kommt das Skill-Grid sauber?
3. Skill mit Status `notStarted` — wie wird das Badge gerendert?
4. Multi-Sprache: in DE assessment öffnen, in den Settings auf EN umschalten, zurück — bleibt UI stimmig?
5. Massen-Daten: 10 Schüler in einer Pool-Session — Performance, Scrolling, Picker-UX.
6. Dive löschen mit angehängten Schülern + Skills — Cascade-Verhalten der `SkillCompletion`-Records?
7. Schüler löschen über `StudentEditSheet` mit destructive delete — was passiert mit zugehörigen Records?

**Spur C — Sync-Stress-Test** (~10 Min):

1. Auf iPhone und iPad parallel im Flugzeugmodus jeweils einen Skill cyclen (gleicher Schüler, gleicher Skill, unterschiedliche Status). Online → konkurrierende Records?
2. Auf einem Gerät einen Schüler hinzufügen, auf dem anderen denselben Namen — Duplikate? Dedupe-Logik vorhanden?

### Bug-Triage-Kriterien

- **Critical** — App crasht, Datenverlust, Skill-Status wird falsch dargestellt, CloudKit-Sync produziert Duplikate oder verliert Records, PDF-Export schlägt fehl. Muss vor Phase 4 gefixt sein.
- **Important** — UX-Friction, die einen realen Use-Case spürbar verschlechtert (z.B. unklare Empty-States, fehlende Loading-Indikatoren, Lokalisierungs-Lücken in zentralen Views). Sollte vor Phase 4 gefixt werden.
- **Minor** — Polish, kosmetische Inkonsistenzen, Edge-Cases die im normalen Workflow nicht auftreten. Wird ins Follow-up-File aufgenommen, kein Fix in Phase 3.

### Bug-Bash-Runde

Nach dem QA-Pass:

1. Bug-Liste sortieren nach Severity.
2. Pro Critical/Important-Bug:
   - Reproduzieren am betroffenen Gerät.
   - Ursache lokalisieren (Code, Daten-Modell, Sync-Verhalten).
   - Fix implementieren — bei nicht-trivialen Fixes Subagent-Dispatch mit gezieltem Prompt.
   - Test wenn sinnvoll (Unit oder manuelle Smoke-Test-Step im Plan).
   - Eigener Commit pro Fix mit `fix(skill-assessment): ...` o.ä.
3. Re-Test am Device, dass der Bug weg ist.
4. Minor-Bugs als Follow-up-File-Einträge.

Wenn die Bug-Bash-Runde >5 Critical/Important-Bugs ergibt, **stoppen und Status-Update mit dem User** — wir splitten dann ggf. einen Phase-3a-Bug-Fix-Branch ab und 3b verschiebt sich.

## Phase 3b — ProfileTab Decomposition

### Ziel

`ProfileTab.swift` von 934 LoC auf ~200 LoC reduzieren, indem die fünf großen MARK-Sections in eigene View-Files extrahiert werden. Top-Level wird zur Komposition. Verhaltensneutral — keine UI-Änderung, keine Logik-Änderung, nur File-Strukturierung.

### Decomposition

Folder-Struktur:

```
DiveLog Pro/Views/Components/ProfileTab/
├── ProfileCard.swift              (~80 LoC)
├── ProfileStampCard.swift         (~75 LoC)
├── DataManagementCard.swift       (~210 LoC, includes dedupe + sample loader + export trigger)
├── AccountCard.swift              (~160 LoC, includes sign-out actions)
└── QuickStatsCard.swift           (~40 LoC)
```

`ProfileTab.swift` selbst:

- Hält alle `@Query`-, `@AppStorage`-, `@State`-Properties
- `body` ist nur noch Komposition: `ScrollView { VStack { ProfileCard(...) ProfileStampCard(...) QuickStatsCard(...) DataManagementCard(...) AccountCard(...) } }`
- Bootstrap-Funktion (`profile`-Computed-Property, `deduplicateProfiles` als Effekt) bleibt im Top-Level
- `.onChange(of: profiles.count)` für Dedupe-Trigger bleibt im Top-Level
- `.toolbar`, `.sheet`, `.confirmationDialog`-Modifier bleiben im Top-Level (sie reagieren auf zentrale @State)

### Sub-Komponenten-Schnittstellen

**Konvention.** Jede Sub-Card:

- Bekommt benötigte Daten via Parameter (typisch: `profile: DiverProfile?`, `dives: [Dive]`, etc.)
- Bekommt Callbacks für Aktionen (`onEdit: () -> Void`, `onSignOut: () -> Void`, etc.) — niemals direkter ModelContext-Zugriff in der Sub-Card
- Hat keine eigenen `@Query`-Properties — die holen wir im Top-Level
- Hat nur sehr lokales `@State` (z.B. `showingPicker` für Photo-Picker innerhalb der Card)

Beispiel `ProfileCard`:

```swift
struct ProfileCard: View {
    let profile: DiverProfile?
    let onEdit: () -> Void
    let onTapPhoto: () -> Void
    @Binding var profileImageData: Data?
    // ... rendering only
}
```

`DataManagementCard` ist die größte und braucht die meisten Dependencies:

```swift
struct DataManagementCard: View {
    let dives: [Dive]
    let isLogbookEmpty: Bool
    let duplicateGroups: [[Dive]]
    let onDedupeTap: () -> Void
    let onLoadSampleData: () -> Void
    let onExport: () -> Void
    let dedupeResultMessage: String?
    let sampleLoadedMessage: String?
}
```

(Die genauen Parameter werden im Plan-Step-by-Step ausgearbeitet.)

### Card-Wrapper-ViewModifier

Damit Spacing, Background, Corner-Radius einheitlich bleiben und der Refactor nicht visuelle Drift einbringt, extrahieren wir einen `ProfileCardStyle`-ViewModifier:

```swift
struct ProfileCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(DSSpacing.l)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: DSRadius.l))
            .padding(.horizontal, DSSpacing.l)
    }
}

extension View {
    func profileCardStyle() -> some View { modifier(ProfileCardStyle()) }
}
```

Alle fünf Sub-Cards verwenden `.profileCardStyle()` — wenn das visuell mit dem heutigen Stand identisch ist, ist die Decomposition automatisch optisch konsistent.

### Refactor-Reihenfolge

Von risikoarm zu risikoreich, damit die ersten Schritte als Smoke-Test für das Decomposition-Pattern dienen:

1. **`ProfileCardStyle`-ViewModifier** zuerst extrahieren, in ProfileTab inline anwenden auf bestehende Cards. Optisch identisch verifizieren.
2. **`QuickStatsCard`** — kleinste Section (~34 LoC), niedrigste Risiko.
3. **`ProfileCard`** — Profile Card (~71 LoC).
4. **`ProfileStampCard`** — Stamp Card (~69 LoC).
5. **`AccountCard`** — Account Card + Account actions (~150 LoC).
6. **`DataManagementCard`** — Data Management Card (~191 LoC), höchste Risiko (komplexester Code, Sheets, Confirmations).

Pro Schritt:

1. Neuen File anlegen mit Sub-Card-struct.
2. Code aus `ProfileTab` rüberkopieren, Parameter durchreichen.
3. `ProfileTab.body` anpassen, neue Sub-Card aufrufen.
4. Build prüfen (`xcodebuild build` mit `generic/platform=iOS`).
5. App im Simulator starten, ProfileTab öffnen, visueller Smoke-Test der betroffenen Card + benachbarter Cards.
6. Commit als `refactor(profile): extract <CardName>`.

### Visueller Smoke-Test pro Schritt

- ProfileTab öffnen — alle Cards rendern korrekt, kein leerer Bereich, kein doppeltes Padding.
- Buttons in der extrahierten Card funktionieren (Edit, Tap-Stamp, Sign-out, etc.).
- Sheets öffnen/schließen sauber.
- Sprache umschalten (DE↔EN) während ProfileTab offen ist — Cards aktualisieren sich.

Smoke-Test ist *nicht* exhaustiv — wenn etwas brennt, fixen, sonst weiter.

### Was NICHT geändert wird

- Kein Naming-Refactor außerhalb der Sub-Cards.
- Keine neuen Tests, keine Snapshot-Test-Frameworks.
- Keine UI-Verbesserungen (kein neues Spacing, keine Font-Tweaks, keine Farb-Anpassungen).
- ProfileEditView (separates File) bleibt unangetastet.

## Architektur-Übersicht

```
Phase 3a (QA + Bug Bash)         Phase 3b (Refactor)
─────────────────────────        ──────────────────────────────────
Spur A: Happy Path                Step 1: ProfileCardStyle modifier
Spur B: Edge Cases                Step 2: Extract QuickStatsCard
Spur C: Sync Stress               Step 3: Extract ProfileCard
   ↓                              Step 4: Extract ProfileStampCard
Bug Triage                        Step 5: Extract AccountCard
   ↓                              Step 6: Extract DataManagementCard
Critical+Important Fixes
   ↓
Minor → follow-ups file
```

3a-Bug-Fixes können ProfileTab-Code modifizieren — in dem Fall passt 3b sich an die neue Realität an.

## Risiken und offene Punkte

- **Bug-Bash-Druck.** Wenn 3a viele Critical-Bugs findet, sprengt das den 3-Wochen-Plan. Mitigation: Stop-Bedingung bei >5 Critical/Important Bugs, Status-Update mit User, Plan ggf. splitten.
- **State-Forwarding-Disziplin.** ProfileTab hat 5+ Queries (profiles, dives, buddies, sites, etc.) plus `AppleSignInService.shared` plus `@AppStorage("appLanguage")`. Diese sauber an Sub-Cards durchzureichen ohne Spaghetti braucht Disziplin. Mitigation: klare Schnittstellen-Konvention oben, kein Sub-Card greift auf Singletons direkt zu.
- **Visuelle Regressionen.** Card-Padding, Background, Corner-Radius können bei Extract zerbrechen. Mitigation: `ProfileCardStyle`-ViewModifier zuerst extrahieren und in einem Pass anwenden, bevor wir die Sub-Cards rausziehen — so haben wir eine visuelle Baseline.
- **Sheets-Lifecycle.** Manche Sheets (`showingExport`, `showingMyQR`, `showingSignOutConfirm`, `showingEdit`) hängen an `@State` im ProfileTab. Wenn wir die Trigger-Buttons in eine Sub-Card verschieben, muss die Sub-Card via Closure den State-Toggle im Top-Level auslösen. Klar dokumentieren in der Konvention.

## Was nicht in diesem Spec ist

Bewusst nicht enthalten, kommt in eigene Specs:

- Phase 4 (Pro-Gating-Coverage-Audit, Onboarding-Touchpoint, App-Store-Connect, TestFlight).
- Refactor anderer Tabs (LogbookTab, JournalTab, StatsTab) — die haben eigene Probleme, aber nicht jetzt.
- ProfileEditView-Refactor.
- Snapshot-Test-Framework.

## Nächster Schritt

Nach User-Review dieses Specs: Übergang in `superpowers:writing-plans` für einen task-by-task Implementation-Plan, der die Checkliste-Steps und Refactor-Schritte ausformuliert.
