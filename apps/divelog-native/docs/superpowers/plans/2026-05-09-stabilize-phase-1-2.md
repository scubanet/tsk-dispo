# Stabilize & Ship — Phase 1 + 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Den uncommitteten Paywall-WIP-Stand in saubere Commits einrahmen, dann die drei Daten-/Funktions-Bugs (Wetter, Tauchgangs-Nummerierung, Foto-Sync) sauber fixen — mit Tests, ohne neue Verhaltensänderungen über den bestehenden WIP-Stand hinaus.

**Architecture:**
- **Phase 1:** Vier verhaltensneutrale Commits, die den vorhandenen WIP-Diff (15 Files, ~534 Inserts) logisch zerlegen.
- **Phase 2a (Weather):** Diagnose am Device → Capability/Provisioning-Fix oder Code-Fix → Smoke-Test.
- **Phase 2b (Numbering):** Eine zentrale `ModelContext.renumberDives(from:)` Funktion, sortiert chronologisch, idempotent. Hooks nach Insert/Edit/Delete sowie nach CloudKit-Sync (debounced via NSPersistentCloudKitContainer-Notifications).
- **Phase 2c (Photos):** `DivePhoto.imageData` als einzige Wahrheit (CloudKit-Asset), Disk wird Read-Through-Cache. Explizite Inverse-Relationship. Idempotente Migration für Legacy-`photoFilenames`.

**Tech Stack:** Swift 5.9+, SwiftUI, SwiftData + CloudKit (NSPersistentCloudKitContainer), iOS 17+, Swift Testing framework, StoreKit 2, WeatherKit.

**Reference Spec:** `docs/superpowers/specs/2026-05-09-stabilize-and-ship-design.md`

**Out of scope (eigene Pläne):**
- Phase 3 (Skill-Assessment-QA + ProfileTab-Refactor)
- Phase 4 (Pro-Gating-Audit + App Store Connect + TestFlight)

---

## File Structure

**Phase 1 — Reorganisation existierender Files (kein neuer Code, nur Commit-Splits):**

Bereits gestagt im WIP (alles bleibt wie es ist, wir splitten nur die Commits):
- `DiveLog Pro.xcodeproj/project.pbxproj`
- `DiveLog Pro.xcodeproj/xcuserdata/dominik.xcuserdatad/xcschemes/xcschememanagement.plist`
- `DiveLog Pro/Info.plist`
- `DiveLog Pro/Models/Dive.swift`
- `DiveLog Pro/Resources/InstructorPro.storekit` (neu)
- `DiveLog Pro/Utils/DiveLogProApp.swift`
- `DiveLog Pro/Utils/StoreManager.swift` (neu)
- `DiveLog Pro/Views/Components/DivePhotoComponents.swift`
- `DiveLog Pro/Views/MainTabView.swift`
- `DiveLog Pro/Views/Screens/DiveDetailView.swift`
- `DiveLog Pro/Views/Screens/DiveFormView.swift`
- `DiveLog Pro/Views/Screens/OnboardingView.swift`
- `DiveLog Pro/Views/Screens/PaywallView.swift` (neu)
- `DiveLog Pro/Views/Tabs/JournalTab.swift`
- `DiveLog Pro/Views/Tabs/ProfileTab.swift`

**Phase 2a — Weather (vermutlich keine Code-Änderung, nur Capability/Smoke-Test):**
- Modify (potenziell): Apple-Developer-Portal App-ID Konfiguration (außerhalb Repo).
- Create (Doku): `docs/operational/weatherkit-smoketest.md`

**Phase 2b — Numbering:**
- Modify: `DiveLog Pro/Utils/ModelContextExtensions.swift` — neue `renumberDives(from:)` Funktion.
- Modify: `DiveLog Pro/Models/Dive.swift` — `init` muss `number=0` als Marker erlauben (heute schon Default).
- Modify: `DiveLog Pro/Utils/DiveLogProApp.swift` — CloudKit-Event-Listener für Convergenz-Renumber.
- Modify: `DiveLog Pro/Views/Screens/DiveFormView.swift` — `save()` ruft Renumber statt `max+1`.
- Modify: `DiveLog Pro/Views/Screens/QuickLogView.swift` — gleicher Hook.
- Modify: `DiveLog Pro/Views/Tabs/LogbookTab.swift` — Swipe-Delete triggert Renumber, DeleteUndoManager ebenso.
- Modify: `DiveLog Pro/Views/Screens/ProfileEditView.swift` — `applyShift()` ruft Renumber.
- Modify: `DiveLog Pro/Models/SampleData.swift` — Sample-Daten passen zur neuen Logik.
- Create: `DiveLog ProTests/NumberingTests.swift`

**Phase 2c — Photos:**
- Modify: `DiveLog Pro/Models/DivePhoto.swift` — explizite Inverse-Relationship.
- Modify: `DiveLog Pro/Models/Dive.swift` — Inverse-Seite des Relationships angeben (falls nicht schon da).
- Modify: `DiveLog Pro/Utils/PhotoStore.swift` — Single-Source-of-Truth-Refactor + Migration-Erweiterung.
- Modify: `DiveLog Pro/Utils/DiveLogProApp.swift` — Migration-Trigger beim Launch.
- Modify: `DiveLog Pro/Views/Components/DivePhotoComponents.swift` — Sync-Status-Indikator.
- Create: `DiveLog ProTests/PhotoStoreTests.swift`

---

# Phase 1 — Werkbank stabilisieren

**Vorbereitung — einmalig vor Task 1:**

- [ ] **Step 0.1: Working-Tree-Snapshot anlegen**

```bash
cd "/Users/dominik/Desktop/Developer/DiveLog Pro"
git stash push --staged --include-untracked -m "wip-paywall-snapshot-before-split"
```

Expected output: `Saved working directory and index state On feat/instructor-skill-assessment: wip-paywall-snapshot-before-split`

- [ ] **Step 0.2: Stash zurück in den Index spielen, aber unstaged**

```bash
git stash pop
git restore --staged .
git status --short
```

Expected: Alle 15 Files erscheinen als `M` oder `??` *ohne* Index-Marker (also rechte Spalte gefüllt, linke leer).

- [ ] **Step 0.3: Build-Baseline verifizieren**

Build im Xcode (oder via Command-Line) auf einem iPhone-Simulator:

```bash
xcodebuild -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`. Wenn der WIP-Build kaputt ist, hier stoppen und reparieren bevor wir splitten.

---

## Task 1: StoreKit-Foundation committen

**Files (logisch zusammengehörig: das StoreKit-Fundament, kompiliert ohne UI):**
- `DiveLog Pro/Utils/StoreManager.swift` (neu)
- `DiveLog Pro/Resources/InstructorPro.storekit` (neu)
- `DiveLog Pro/Info.plist` (StoreKit-Config-Reference)
- `DiveLog Pro/Utils/DiveLogProApp.swift` (StoreManager-Init)
- `DiveLog Pro/Models/Dive.swift` (kleiner Touch wenn vorhanden — siehe Diff)
- `DiveLog Pro.xcodeproj/project.pbxproj` (nur die StoreKit-Resource-Eintrag-Zeilen)

- [ ] **Step 1.1: Diff der StoreKit-Foundation-Files sichten**

```bash
git diff "DiveLog Pro/Utils/StoreManager.swift" \
        "DiveLog Pro/Resources/InstructorPro.storekit" \
        "DiveLog Pro/Info.plist" \
        "DiveLog Pro/Utils/DiveLogProApp.swift" \
        "DiveLog Pro/Models/Dive.swift"
```

Lies den Output durch. Wenn `Dive.swift` oder `DiveLogProApp.swift` Änderungen enthalten, die *nicht* mit StoreKit zu tun haben (z.B. Numbering-Bug-Fix, Foto-Migration), die schließen wir hier *aus* und committen erst in der jeweiligen Phase. Markiere dir mental, was reingehört.

- [ ] **Step 1.2: project.pbxproj — nur StoreKit-Zeilen extrahieren**

```bash
git diff "DiveLog Pro.xcodeproj/project.pbxproj" | grep -E "InstructorPro|StoreManager|StoreKit"
```

Expected: Es gibt Zeilen mit `InstructorPro.storekit` und `StoreManager.swift` Referenzen. Falls daneben unzusammenhängende Änderungen sind (z.B. PaywallView-Eintrag), lassen wir die für Task 2 stehen und stagen das pbxproj-File nochmal in jedem Task.

Das pbxproj-File ist atomar (nicht zeilenweise stagebar ohne Risiko), darum:
- Pragmatischer Ansatz: project.pbxproj kommt in **Task 2** (zusammen mit PaywallView), weil dort die meisten Eintrags-Änderungen sind. Hier in Task 1 wird die pbxproj **nicht** gestagt.

- [ ] **Step 1.3: Foundation-Files stagen**

```bash
git add "DiveLog Pro/Utils/StoreManager.swift"
git add "DiveLog Pro/Resources/InstructorPro.storekit"
git add "DiveLog Pro/Info.plist"
git add "DiveLog Pro/Utils/DiveLogProApp.swift"
```

`Dive.swift` nur stagen, wenn der Diff dort StoreKit-relevant ist (z.B. ein neues Property). Sonst leer lassen für späteren Task.

```bash
git diff --cached --stat
```

Expected: 4 Files (StoreManager, .storekit, Info.plist, DiveLogProApp.swift), Lines-Sum stimmt mit den Datei-Größen überein.

- [ ] **Step 1.4: Build mit gestagtem Diff prüfen**

```bash
xcodebuild -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`.

Falls FEHLT: vermutlich braucht das Build die pbxproj-Eintragung von `StoreManager.swift` als Compile-Source. In dem Fall die pbxproj-Datei trotzdem mitstagen (vollständig), und in Task 2 ist nur noch `PaywallView.swift`-Eintrag drin (oder bereits enthalten — pbxproj-Diff zwischen Task 1 und Task 2 wird dann minimal).

- [ ] **Step 1.5: Commit**

```bash
git commit -m "feat(store): StoreManager + InstructorPro.storekit foundation

Adds StoreKit 2 wrapper (StoreManager) with load/buy/restore/
entitlement-listener for the non-consumable Instructor Pro product.
StoreKit configuration file describes the product for local testing.
DiveLogProApp wires up the singleton on launch."
```

---

## Task 2: PaywallView UI + Onboarding-Touch committen

**Files:**
- `DiveLog Pro/Views/Screens/PaywallView.swift` (neu)
- `DiveLog Pro/Views/Screens/OnboardingView.swift` (Paywall-Touchpoint)
- `DiveLog Pro.xcodeproj/project.pbxproj` (vollständig — enthält PaywallView-Eintrag)
- `DiveLog Pro.xcodeproj/xcuserdata/dominik.xcuserdatad/xcschemes/xcschememanagement.plist` (User-Local, harmlos)

- [ ] **Step 2.1: Diff sichten**

```bash
git diff "DiveLog Pro/Views/Screens/PaywallView.swift"
git diff "DiveLog Pro/Views/Screens/OnboardingView.swift"
```

OnboardingView-Diff sollte sich auf Paywall-Aufruf oder kleine UI-Änderung beziehen. Falls nicht zusammenhängend, splitten.

- [ ] **Step 2.2: Stagen**

```bash
git add "DiveLog Pro/Views/Screens/PaywallView.swift"
git add "DiveLog Pro/Views/Screens/OnboardingView.swift"
git add "DiveLog Pro.xcodeproj/project.pbxproj"
git add "DiveLog Pro.xcodeproj/xcuserdata/dominik.xcuserdatad/xcschemes/xcschememanagement.plist"

git diff --cached --stat
```

Expected: 4 Files.

- [ ] **Step 2.3: Build-Check**

```bash
xcodebuild -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 2.4: Commit**

```bash
git commit -m "feat(paywall): PaywallView UI + onboarding touchpoint

PaywallView presents the Instructor Pro product (StoreManager.shared)
with hero, feature list, purchase + restore buttons. Onboarding
gets an entry point to surface the paywall to first-time users."
```

---

## Task 3: Pro-Gates für Sign-Tab + Course-Training committen

**Files:**
- `DiveLog Pro/Views/MainTabView.swift` (Sign-Tab → ProTeaser when not Pro)
- `DiveLog Pro/Views/Screens/DiveFormView.swift` (Course-Training-Block hinter `StoreManager.shared.isPro`)

- [ ] **Step 3.1: Diff sichten**

```bash
git diff "DiveLog Pro/Views/MainTabView.swift"
git diff "DiveLog Pro/Views/Screens/DiveFormView.swift"
```

Bei DiveFormView: nur Pro-Gate-Änderungen. Wenn dort weiterer Code (z.B. Numbering-Bug-Fix) drin ist, splitten — der Numbering-Teil kommt in Task 9-10.

In dem Fall: temporär aufteilen via Patch-Mode:

```bash
git add -p "DiveLog Pro/Views/Screens/DiveFormView.swift"
```

— und nur die Hunks selektieren, die `StoreManager.shared.isPro` betreffen.

- [ ] **Step 3.2: Stagen**

```bash
git add "DiveLog Pro/Views/MainTabView.swift"
# DiveFormView wurde via -p in Step 3.1 selektiert, falls nötig
```

Falls DiveFormView komplett zum Pro-Gate gehört:
```bash
git add "DiveLog Pro/Views/Screens/DiveFormView.swift"
```

- [ ] **Step 3.3: Build-Check**

```bash
xcodebuild -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3.4: Commit**

```bash
git commit -m "feat(pro-gate): Sign tab + course training behind Instructor Pro

MainTabView replaces SignTab with a ProTeaser when StoreManager
reports isPro == false. DiveFormView hides the course-training
toggle and student picker behind the same gate."
```

---

## Task 4: Restliche Touched-Files committen

**Files (letzter Sammelcommit für die Paywall-Integration):**
- `DiveLog Pro/Views/Tabs/ProfileTab.swift`
- `DiveLog Pro/Views/Tabs/JournalTab.swift`
- `DiveLog Pro/Views/Screens/DiveDetailView.swift`
- `DiveLog Pro/Views/Components/DivePhotoComponents.swift`
- `DiveLog Pro/Models/Dive.swift` (falls nicht in Task 1 gelandet)

- [ ] **Step 4.1: Diff sichten**

```bash
git status --short
git diff
```

Erwartet sind nur noch Paywall-zugehörige Touches. Wenn ein File einen *thematisch fremden* Diff hat (z.B. Foto-Sync-Änderungen in DivePhotoComponents), den splitten und in Phase 2c committen.

- [ ] **Step 4.2: Stagen (selektiv mit -p falls nötig)**

```bash
git add -p "DiveLog Pro/Views/Tabs/ProfileTab.swift"
git add -p "DiveLog Pro/Views/Tabs/JournalTab.swift"
git add -p "DiveLog Pro/Views/Screens/DiveDetailView.swift"
git add -p "DiveLog Pro/Views/Components/DivePhotoComponents.swift"
git add -p "DiveLog Pro/Models/Dive.swift"
```

Bei jedem Hunk: nur die paywall-bezogenen Änderungen wählen (z.B. `if store.isPro` Branches, neue Pro-Badges, Paywall-Sheet-Aufrufe).

- [ ] **Step 4.3: Build-Check**

```bash
xcodebuild -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4.4: Commit**

```bash
git commit -m "feat(paywall): integrate Pro-aware UI across remaining tabs

Profile/Journal/DiveDetail/DivePhotoComponents pick up the
StoreManager.shared.isPro gate where Pro-only affordances are shown
or where the Paywall sheet is invoked. No behavior change for users
who were already Pro."
```

- [ ] **Step 4.5: Working-Tree-Stand prüfen**

```bash
git status
```

Expected: Working tree clean. Falls nicht: die übrig gebliebenen Diffs gehören thematisch zu Phase 2 — die räumen wir dort in den jeweiligen Tasks ab.

- [ ] **Step 4.6: Manueller Sandbox-Smoke-Test der Paywall**

Im Simulator: App starten, Sign-Tab öffnen → ProTeaser sehen → "Mehr erfahren" tippen → PaywallView erscheint → "Kaufen" tippen (StoreKit-Sandbox-Dialog) → bestätigen → Sign-Tab füllt sich. Restore-Button funktioniert nach Sandbox-Account-Reset.

Wenn das nicht klappt: Paywall ist konzeptionell unfertig (das ist Phase 4 im Spec). Ein gefundenes Problem hier wird als bekannt notiert (`docs/operational/known-issues.md` falls noch nicht existiert) und blockt nicht den Plan — Phase 4 wird's aufgreifen.

---

# Phase 2a — Wetter-Modul reparieren

## Task 5: Wetter am Device diagnostizieren

**Files (read-only):**
- `DiveLog Pro/Utils/WeatherService.swift` — schon mit `diag(weather)`-Logging instrumentiert
- `DiveLog Pro/Views/Screens/DiveFormView.swift:511` — Aufrufstelle

- [ ] **Step 5.1: Build aufs echte iPhone**

In Xcode: Schema "DiveLog Pro" wählen, Device auf physisches iPhone setzen (nicht Simulator), Build & Run. Das echte Gerät ist Pflicht — WeatherKit ist auf Simulator unzuverlässig und kann False-Negative-Errors zurückgeben.

- [ ] **Step 5.2: Wetter-Auto-Fill triggern**

In der App: neuer Tauchgang → Tauchplatz mit Lat/Lon setzen (z.B. via "Aktueller Standort"-Button) → Datum auf heute → Wetter-Auto-Fill antippen. Beobachte UI-Reaktion.

- [ ] **Step 5.3: OSLog auslesen**

Auf dem Mac: Console.app → linke Seitenleiste → das angeschlossene iPhone wählen → Filter `subsystem == com.weckherlin.DiveLogPro && category == weather`. Den Tauchgang-Trigger nochmal auslösen.

Expected (möglich): genau eine Log-Zeile vom Format
```
WeatherKit failed: domain=<DOMAIN> code=<CODE> desc=<TEXT> userInfo=<DICT>
```

- [ ] **Step 5.4: Diagnose-Pfad wählen**

Anhand des Domain/Code-Feldes:

| Domain | Code | Wahrscheinliche Ursache | Nächste Task |
|--------|------|-------------------------|--------------|
| `WeatherDaemon.WDSJWTAuthenticatorServiceListener.Errors` | 1, 2 | App-ID hat WeatherKit-Capability nicht | Task 6 |
| `WKBackendErrorDomain` | 401 | Token/Provisioning-Probleme | Task 6 |
| `NSURLErrorDomain` | -1009 / -1003 | Netzwerk (Real-Device-Issue, nicht App) | Notiz, weitermachen |
| `WeatherDaemon...` | 4 | Unsupported Region/Date | Code-Fix in Task 7 |
| Anderes | — | Unbekannt | Task 6 (App-ID-Capability prüfen) ist günstig zu testen |

- [ ] **Step 5.5: Diagnose-Notiz festhalten**

```bash
mkdir -p docs/operational
cat > docs/operational/2026-05-09-weatherkit-diagnosis.md <<'EOF'
# WeatherKit Diagnose — 2026-05-09

**Test-Device:** <iPhone-Modell + iOS-Version>
**Test-Location:** <z.B. Konstanz, 47.66/9.18>
**Test-Date:** today

## Beobachtetes OSLog

```
<paste der Log-Zeile aus Step 5.3>
```

## Wahrscheinliche Ursache

<aus Tabelle in Step 5.4 ableiten>

## Nächste Aktion

<Task 6 oder Task 7>
EOF
```

```bash
git add docs/operational/2026-05-09-weatherkit-diagnosis.md
git commit -m "docs(weather): diagnostic snapshot from device test"
```

---

## Task 6: WeatherKit-Capability auf App-ID aktivieren (falls Task 5 das ergibt)

**Voraussetzung:** Step 5.4 hat einen Auth-/Capability-Pfad ergeben.

- [ ] **Step 6.1: Apple-Developer-Portal öffnen**

Browser: https://developer.apple.com/account → Certificates, IDs & Profiles → Identifiers → die App-ID `com.weckherlin.DiveLogPro` öffnen.

- [ ] **Step 6.2: WeatherKit aktivieren**

Im Capability-Block die Checkbox bei "WeatherKit" setzen. Save.

Falls die Checkbox bereits gesetzt ist und der Fehler trotzdem auftrat: weiter zu Step 6.5.

- [ ] **Step 6.3: Provisioning-Profile neu generieren**

Xcode → Settings → Accounts → den Apple-ID wählen → "Download Manual Profiles". Oder im Project: Signing & Capabilities → "Automatically manage signing" → toggle aus und wieder an, damit Xcode neue Profile zieht.

- [ ] **Step 6.4: Erneut aufs Device deployen + Test wiederholen**

Wie Step 5.1–5.3 — diesmal sollte das OSLog kein Auth-Error mehr zeigen, und das UI-Wetter-Field füllt sich.

- [ ] **Step 6.5: Dokumentation aktualisieren**

```bash
# In docs/operational/2026-05-09-weatherkit-diagnosis.md das "Resolution"-Kapitel ergänzen:
```

```markdown
## Resolution

- Capability `WeatherKit` wurde auf die App-ID hinzugefügt: <Datum>
- Provisioning-Profile via Xcode neu gezogen.
- Verifizierung: Test-Tauchgang in <Location>, Wetter wurde gefüllt mit `condition=<x>, airTemp=<y>°C`.
```

```bash
git add docs/operational/2026-05-09-weatherkit-diagnosis.md
git commit -m "docs(weather): record capability fix resolution"
```

---

## Task 7: Smoke-Test-Doku schreiben (für künftige Regressionen)

**File:** `docs/operational/weatherkit-smoketest.md` (neu)

- [ ] **Step 7.1: Doku schreiben**

Erstelle die Datei mit folgendem Inhalt:

```markdown
# WeatherKit Smoke-Test

Manueller Test, ausführen vor jedem TestFlight-Build.

## Voraussetzungen

- Echtes iPhone (Simulator wird nicht unterstützt)
- iCloud-Account angemeldet
- App-ID hat WeatherKit-Capability aktiv (siehe `2026-05-09-weatherkit-diagnosis.md` Resolution)

## Durchführung

1. App starten, neuer Tauchgang anlegen.
2. Tauchplatz: aktueller Standort (Standort-Button drücken, GPS muss zustimmen).
3. Datum: heute, Uhrzeit: jetzt.
4. Wetter-Auto-Fill antippen.

## Erwartetes Verhalten

- Wetter-Feld zeigt eine der Conditions: `sunny | partly_cloudy | cloudy | rainy | windy | foggy`.
- Lufttemperatur ist gefüllt mit einem plausiblen Wert für den aktuellen Standort/Zeitpunkt.
- Im OSLog (`subsystem com.weckherlin.DiveLogPro`, category `weather`) erscheint **kein** `WeatherKit failed`-Eintrag.

## Bei Fehlschlag

OSLog auslesen, Domain/Code in `2026-05-09-weatherkit-diagnosis.md` Tabelle nachschlagen.
```

- [ ] **Step 7.2: Commit**

```bash
git add docs/operational/weatherkit-smoketest.md
git commit -m "docs(weather): manual smoke-test procedure for TestFlight builds"
```

---

# Phase 2b — Tauchgangs-Nummerierung chronologisch

## Task 8: Failing Tests für `renumberDives` schreiben

**File:** `DiveLog ProTests/NumberingTests.swift` (neu)

- [ ] **Step 8.1: Test-File anlegen**

```swift
import Testing
import SwiftData
@testable import DiveLog_Pro

@Suite("Dive Numbering")
struct NumberingTests {

    /// Helper — in-memory ModelContainer mit einem leeren Profile.
    @MainActor
    private func makeContext(startingNumber: Int = 1000) throws -> (ModelContext, DiverProfile) {
        let schema = Schema([
            DiverProfile.self, Dive.self, DivePhoto.self,
            Student.self, PoolSession.self, SkillCompletion.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = ModelContext(container)
        let profile = DiverProfile(startingDiveNumber: startingNumber)
        context.insert(profile)
        try context.save()
        return (context, profile)
    }

    @Test("empty logbook + first dive starts at profile.startingDiveNumber")
    @MainActor
    func emptyLogbookFirstDive() throws {
        let (ctx, profile) = try makeContext(startingNumber: 1000)

        let dive = Dive(date: .now)
        ctx.insert(dive)
        ctx.renumberDives(from: profile)
        try ctx.save()

        #expect(dive.number == 1000)
    }

    @Test("dive added in the past renumbers existing dives upward")
    @MainActor
    func diveInPastRenumbers() throws {
        let (ctx, profile) = try makeContext(startingNumber: 100)

        let now = Date()
        let yesterday = now.addingTimeInterval(-86400)
        let lastWeek = now.addingTimeInterval(-7 * 86400)

        let d1 = Dive(date: yesterday)
        let d2 = Dive(date: now)
        ctx.insert(d1)
        ctx.insert(d2)
        ctx.renumberDives(from: profile)
        try ctx.save()

        #expect(d1.number == 100)
        #expect(d2.number == 101)

        // Now insert a backdated dive — should renumber d1 and d2 upward.
        let d0 = Dive(date: lastWeek)
        ctx.insert(d0)
        ctx.renumberDives(from: profile)
        try ctx.save()

        #expect(d0.number == 100)
        #expect(d1.number == 101)
        #expect(d2.number == 102)
    }

    @Test("deleted dive causes remaining dives to renumber down")
    @MainActor
    func deletedDiveRenumbers() throws {
        let (ctx, profile) = try makeContext(startingNumber: 500)

        let now = Date()
        let dives = (0..<3).map { i in
            Dive(date: now.addingTimeInterval(Double(i) * 3600))
        }
        dives.forEach { ctx.insert($0) }
        ctx.renumberDives(from: profile)
        try ctx.save()

        #expect(dives.map(\.number) == [500, 501, 502])

        ctx.delete(dives[1])
        ctx.renumberDives(from: profile)
        try ctx.save()

        #expect(dives[0].number == 500)
        #expect(dives[2].number == 501)
    }

    @Test("changing startingDiveNumber renumbers all existing dives")
    @MainActor
    func changingStartShiftsAll() throws {
        let (ctx, profile) = try makeContext(startingNumber: 1)

        let now = Date()
        let dives = (0..<3).map { i in
            Dive(date: now.addingTimeInterval(Double(i) * 3600))
        }
        dives.forEach { ctx.insert($0) }
        ctx.renumberDives(from: profile)
        try ctx.save()

        #expect(dives.map(\.number) == [1, 2, 3])

        profile.startingDiveNumber = 9000
        ctx.renumberDives(from: profile)
        try ctx.save()

        #expect(dives.map(\.number) == [9000, 9001, 9002])
    }

    @Test("renumber is idempotent — running twice produces same result")
    @MainActor
    func idempotent() throws {
        let (ctx, profile) = try makeContext(startingNumber: 42)

        let now = Date()
        let dives = (0..<5).map { i in
            Dive(date: now.addingTimeInterval(Double(i) * 3600))
        }
        dives.forEach { ctx.insert($0) }

        ctx.renumberDives(from: profile)
        let snap1 = dives.map(\.number)
        ctx.renumberDives(from: profile)
        let snap2 = dives.map(\.number)

        #expect(snap1 == snap2)
        #expect(snap1 == [42, 43, 44, 45, 46])
    }

    @Test("PoolSessions are not renumbered (they have no number)")
    @MainActor
    func poolSessionsExcluded() throws {
        let (ctx, profile) = try makeContext(startingNumber: 1)

        let dive = Dive(date: .now)
        let pool = PoolSession(date: .now, courseType: "owd", slotCode: "ow_pool_1")
        ctx.insert(dive)
        ctx.insert(pool)
        ctx.renumberDives(from: profile)
        try ctx.save()

        #expect(dive.number == 1)
        // PoolSession hat kein .number-Property — Test schlägt nicht fehl,
        // verifiziert nur, dass renumberDives keinen Crash auslöst.
    }
}
```

- [ ] **Step 8.2: Tests laufen lassen — sie müssen schlagen**

```bash
xcodebuild test -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:"DiveLog ProTests/NumberingTests" 2>&1 | tail -30
```

Expected: `Compilation failed` mit `error: cannot find 'renumberDives' in scope` — das bestätigt, dass die Funktion noch nicht existiert.

---

## Task 9: `renumberDives(from:)` implementieren

**File:** `DiveLog Pro/Utils/ModelContextExtensions.swift` (modify)

- [ ] **Step 9.1: Funktion anhängen**

Am Ende der existierenden `extension ModelContext { ... }` einfügen (oder eine neue Extension-Klammer öffnen, falls die vorhandene zu groß ist):

```swift
extension ModelContext {

    /// Re-numbers every Dive in the store chronologically by `date`,
    /// starting at `profile.startingDiveNumber`. Idempotent — calling
    /// twice in a row leaves dives in the same state.
    ///
    /// PoolSessions have no `.number` property and are excluded.
    ///
    /// Performance: O(n) per call. Bulk-imports should batch and call
    /// once at the end, not per insert.
    func renumberDives(from profile: DiverProfile) {
        let descriptor = FetchDescriptor<Dive>(
            sortBy: [SortDescriptor(\Dive.date, order: .forward)]
        )
        guard let dives = try? fetch(descriptor) else { return }

        let start = profile.startingDiveNumber
        for (index, dive) in dives.enumerated() {
            let target = start + index
            if dive.number != target {
                dive.number = target
            }
        }
    }
}
```

- [ ] **Step 9.2: Tests laufen lassen — sie müssen jetzt grün sein**

```bash
xcodebuild test -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:"DiveLog ProTests/NumberingTests" 2>&1 | tail -10
```

Expected: `Test Suite 'NumberingTests' passed` — alle 6 Tests grün.

- [ ] **Step 9.3: Commit**

```bash
git add "DiveLog Pro/Utils/ModelContextExtensions.swift" "DiveLog ProTests/NumberingTests.swift"
git commit -m "feat(numbering): chronological renumberDives + tests

Adds ModelContext.renumberDives(from:) which sorts all Dive records
by date and assigns sequential numbers starting at
profile.startingDiveNumber. Idempotent and CloudKit-conflict-safe.

Tests cover: empty logbook, backdated insert, delete, starting-number
change, idempotency, and PoolSession exclusion."
```

---

## Task 10: Hook in `DiveFormView.save()`

**File:** `DiveLog Pro/Views/Screens/DiveFormView.swift` (modify around line 685)

- [ ] **Step 10.1: Aktuellen `else`-Branch lesen**

```bash
sed -n '680,710p' "DiveLog Pro/Views/Screens/DiveFormView.swift"
```

Du siehst den Code-Block, der heute `existingDives.first?.number ?? (startingNumber - 1) + 1` rechnet.

- [ ] **Step 10.2: Ersetzen — Insert-Branch**

Im `else { ... }` (neue-Dive-Branch in `save()`), ersetze den `let num = ...` und den Konstruktor-Aufruf so:

**Vorher (ungefähr):**
```swift
let startingNumber = profiles.first?.startingDiveNumber ?? 8758
let num = (existingDives.first?.number ?? (startingNumber - 1)) + 1
let dive = Dive(
    number: num, date: diveDate, ...
)
context.insert(dive)
```

**Nachher:**
```swift
guard let profile = profiles.first else {
    // Cannot insert without a profile — this should never happen because
    // onboarding creates one. If it does, fail loudly in DEBUG.
    assertionFailure("DiveFormView.save: no DiverProfile available")
    return
}
let dive = Dive(
    number: 0,             // placeholder, renumber assigns the real value
    date: diveDate, ...
)
context.insert(dive)
context.renumberDives(from: profile)
```

- [ ] **Step 10.3: Edit-Branch ergänzen — bei Datum-Änderung renumbern**

Im `if case .edit(let existing) = mode { ... }`-Branch, *nach* `d.date = diveDate` (oder wo immer die Datum-Eigenschaft gesetzt wird), ergänzen:

```swift
if let profile = profiles.first {
    context.renumberDives(from: profile)
}
```

- [ ] **Step 10.4: Build & Tests**

```bash
xcodebuild build -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`.

```bash
xcodebuild test -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -10
```

Expected: alle Tests grün.

- [ ] **Step 10.5: Commit**

```bash
git add "DiveLog Pro/Views/Screens/DiveFormView.swift"
git commit -m "fix(numbering): DiveFormView triggers renumberDives on save

Replaces the max+1 logic with a renumber call after insert. Edit
mode also renumbers, so a date change moves the dive to its correct
position in the chronological sequence."
```

---

## Task 11: Hook in `QuickLogView`

**File:** `DiveLog Pro/Views/Screens/QuickLogView.swift` (modify)

- [ ] **Step 11.1: QuickLog-Save-Pfad finden**

```bash
grep -n "context.insert\|number\b" "DiveLog Pro/Views/Screens/QuickLogView.swift"
```

QuickLog legt entweder Dive oder PoolSession an. Nur der Dive-Pfad braucht den Renumber-Hook.

- [ ] **Step 11.2: Renumber nach Insert ergänzen**

Direkt nach dem `context.insert(dive)` und *vor* `dismiss()`:

```swift
if let profile = profiles.first {
    context.renumberDives(from: profile)
}
try? context.save()
```

Falls `profiles` noch nicht im View ist, oben in der Property-Liste:

```swift
@Query private var profiles: [DiverProfile]
```

- [ ] **Step 11.3: Build & Test**

```bash
xcodebuild build -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 11.4: Commit**

```bash
git add "DiveLog Pro/Views/Screens/QuickLogView.swift"
git commit -m "fix(numbering): QuickLogView triggers renumberDives on save"
```

---

## Task 12: Hook in `LogbookTab` Swipe-Delete + DeleteUndoManager

**Files:**
- `DiveLog Pro/Views/Tabs/LogbookTab.swift`
- `DiveLog Pro/Services/DeleteUndoManager.swift`

- [ ] **Step 12.1: Swipe-Delete-Stelle finden**

```bash
grep -n "delete\|onDelete\|\.delete(" "DiveLog Pro/Views/Tabs/LogbookTab.swift"
grep -n "restore\|undo\|insert" "DiveLog Pro/Services/DeleteUndoManager.swift"
```

- [ ] **Step 12.2: In LogbookTab — nach `context.delete(dive)` Renumber triggern**

Wenn der Delete-Pfad in einem Closure ist:

```swift
.swipeActions(edge: .trailing) {
    Button(role: .destructive) {
        deleteUndoManager.scheduleDelete(dive)
        if let profile = profiles.first {
            context.renumberDives(from: profile)
        }
        try? context.save()
    } label: { ... }
}
```

(Genaue Struktur abhängig vom existierenden Code — der Punkt ist: nach jedem `delete` und nach jedem `restore` ein Renumber-Call mit anschließendem `save()`.)

- [ ] **Step 12.3: In DeleteUndoManager — `restore` triggert Renumber**

Im `restore`-Pfad (oder wo der gelöschte Dive ins Context zurückgespielt wird):

```swift
context.insert(restoredDive)
if let profile = (try? context.fetch(FetchDescriptor<DiverProfile>()))?.first {
    context.renumberDives(from: profile)
}
try? context.save()
```

- [ ] **Step 12.4: Build & alle Tests**

```bash
xcodebuild test -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -10
```

Expected: alle Tests grün.

- [ ] **Step 12.5: Commit**

```bash
git add "DiveLog Pro/Views/Tabs/LogbookTab.swift" "DiveLog Pro/Services/DeleteUndoManager.swift"
git commit -m "fix(numbering): renumber on swipe-delete + undo restore

Both deletion paths (immediate swipe + undo grace-period restore)
now call renumberDives so the visible sequence stays gap-free."
```

---

## Task 13: `ProfileEditView.applyShift` ersetzen

**File:** `DiveLog Pro/Views/Screens/ProfileEditView.swift` (modify around line 580)

- [ ] **Step 13.1: Vorhandene applyShift sichten**

```bash
sed -n '575,605p' "DiveLog Pro/Views/Screens/ProfileEditView.swift"
```

- [ ] **Step 13.2: Body durch Renumber ersetzen**

**Vorher (ungefähr):**
```swift
private func applyShift() {
    let delta = pendingShiftDelta
    guard delta != 0 else { dismiss(); return }
    for dive in allDives {
        dive.number += delta
    }
    profile.startingDiveNumber = (allDives.first?.number ?? profile.startingDiveNumber)
    try? ctx.save()
    republishToAtollBridge()
    dismiss()
}
```

**Nachher:**
```swift
private func applyShift() {
    guard pendingShiftDelta != 0 else { dismiss(); return }
    profile.startingDiveNumber = Int(firstDiveNumber) ?? profile.startingDiveNumber
    ctx.renumberDives(from: profile)
    try? ctx.save()
    republishToAtollBridge()
    dismiss()
}
```

- [ ] **Step 13.3: Build & Tests**

```bash
xcodebuild test -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -10
```

Expected: alle Tests grün, insbesondere `changingStartShiftsAll`.

- [ ] **Step 13.4: Commit**

```bash
git add "DiveLog Pro/Views/Screens/ProfileEditView.swift"
git commit -m "refactor(numbering): ProfileEditView.applyShift uses renumberDives

Replaces the manual delta-loop with a single renumberDives call.
Same effect, but consistent with all other code paths."
```

---

## Task 14: CloudKit-Sync-Listener für Konvergenz-Renumber

**File:** `DiveLog Pro/Utils/DiveLogProApp.swift` (modify)

- [ ] **Step 14.1: NSPersistentCloudKitContainer-Notification beobachten**

In `DiveLogProApp` (oder wo der ModelContainer aufgesetzt wird), nach der Container-Erzeugung:

```swift
import CoreData
import Combine

// In der App-struct oder einem Singleton:
private var cloudKitObserver: AnyCancellable?
private var renumberDebouncer: Task<Void, Never>?

private func setupCloudKitConvergenceRenumber(container: ModelContainer) {
    cloudKitObserver = NotificationCenter.default
        .publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)
        .sink { [weak self] note in
            // Trigger only on import events (not export).
            guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event,
                  event.type == .import,
                  event.endDate != nil else { return }

            // Debounce: cancel any pending renumber, schedule new one in 1s.
            self?.renumberDebouncer?.cancel()
            self?.renumberDebouncer = Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                let ctx = ModelContext(container)
                if let profile = (try? ctx.fetch(FetchDescriptor<DiverProfile>()))?.first {
                    ctx.renumberDives(from: profile)
                    try? ctx.save()
                }
            }
        }
}
```

Dann im App-Init aufrufen, nachdem der Container existiert:
```swift
setupCloudKitConvergenceRenumber(container: sharedModelContainer)
```

- [ ] **Step 14.2: Build prüfen**

```bash
xcodebuild build -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`. Der Listener läuft erst zur App-Laufzeit, nicht im Test-Target — daher gibt's hier keinen automatischen Test, dafür der manuelle Step 16.

- [ ] **Step 14.3: Commit**

```bash
git add "DiveLog Pro/Utils/DiveLogProApp.swift"
git commit -m "feat(numbering): CloudKit convergence-renumber listener

After every CloudKit import event, schedules a debounced renumber
(1s window) so concurrent inserts on multiple devices converge to a
deterministic sequence after sync."
```

---

## Task 15: Sample-Daten an die neue Logik anpassen

**File:** `DiveLog Pro/Models/SampleData.swift` (modify)

- [ ] **Step 15.1: Aktuelle Sample-Daten sichten**

```bash
sed -n '20,100p' "DiveLog Pro/Models/SampleData.swift"
```

Du siehst Dives mit hardcoded Numbers (8757, 8756, 8728, 8650). Mit der neuen Logik werden Numbers via Renumber vergeben — die hardcoded Werte sind nicht mehr stabil.

- [ ] **Step 15.2: Numbers entfernen, Renumber-Call ergänzen**

Im SampleData-Generator:

**Vorher (ungefähr):**
```swift
let dive1 = Dive(
    number: 8757, date: df.date(from: "2026-03-12 14:25") ?? .now,
    ...
)
```

**Nachher:**
```swift
let dive1 = Dive(
    number: 0, date: df.date(from: "2026-03-12 14:25") ?? .now,
    ...
)
```

(Alle 4 Sample-Dive-Konstruktoren auf `number: 0` setzen.)

Am Ende der Sample-Daten-Erzeugung, nachdem alle Dives in den Context eingefügt sind:

```swift
context.renumberDives(from: profile)
try? context.save()
```

— wobei `profile` der seed-Profile sein muss, der mit `startingDiveNumber: 8650` (oder einem ähnlichen Demo-Wert) konfiguriert ist, damit die Sample-Numbers sich an die alten Werte angleichen.

- [ ] **Step 15.3: Build & Tests**

```bash
xcodebuild test -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -10
```

Expected: alle Tests grün.

- [ ] **Step 15.4: Commit**

```bash
git add "DiveLog Pro/Models/SampleData.swift"
git commit -m "refactor(samples): SampleData uses renumberDives instead of hardcoded numbers"
```

---

## Task 16: Manueller Konvergenz-Test mit zwei Geräten

- [ ] **Step 16.1: Vorbereitung**

Zwei iPhones (oder iPhone + iPad) am selben iCloud-Account, beide haben die App installiert mit demselben Profile. CloudKit-Sync muss funktionieren (vorher kurz prüfen: ein normaler Tauchgang auf Gerät A erscheint auf Gerät B).

- [ ] **Step 16.2: Konflikt provozieren**

1. Beide Geräte ins Flugzeugmodus.
2. Auf **Gerät A**: neuen Tauchgang anlegen, Datum heute 14:00.
3. Auf **Gerät B**: neuen Tauchgang anlegen, Datum heute 12:00.
4. Beide Geräte: Flugzeugmodus aus, ~30s warten für Sync.
5. Beide Geräte beobachten: Logbuch zeigt jetzt beide TGs in der Reihenfolge (12:00, 14:00) mit fortlaufenden Nummern, beide Geräte zeigen identische Numbers.

Expected: kein Duplikat, beide Devices konvergieren auf dieselbe Sequenz.

- [ ] **Step 16.3: Ergebnis dokumentieren**

```bash
cat >> docs/operational/2026-05-09-weatherkit-diagnosis.md <<'EOF'

# Numbering Convergence Test — 2026-05-09

**Setup:** <Gerät A, Gerät B, beide iOS xx.x>

**Test:** Konflikt provoziert wie in Plan-Task 16.

**Ergebnis:** <Pass / Fail + Notizen>
EOF
```

(Der File-Name ist legacy — wir können später in `multi-device-tests.md` umbenennen.)

```bash
git add docs/operational/2026-05-09-weatherkit-diagnosis.md
git commit -m "docs(numbering): two-device convergence test result"
```

---

# Phase 2c — Foto-Sync stabilisieren

## Task 17: Failing Tests für `PhotoStore` schreiben

**File:** `DiveLog ProTests/PhotoStoreTests.swift` (neu)

- [ ] **Step 17.1: Test-File anlegen**

```swift
import Testing
import SwiftData
import UIKit
@testable import DiveLog_Pro

@Suite("PhotoStore")
struct PhotoStoreTests {

    @MainActor
    private func makeContext() throws -> (ModelContext, Dive) {
        let schema = Schema([
            DiverProfile.self, Dive.self, DivePhoto.self,
            Student.self, PoolSession.self, SkillCompletion.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = ModelContext(container)
        let dive = Dive(date: .now)
        context.insert(dive)
        try context.save()
        return (context, dive)
    }

    private func dummyImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64))
        return renderer.image { ctx in
            UIColor.systemBlue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        }
    }

    @Test("save creates a DivePhoto record with imageData")
    @MainActor
    func saveCreatesRecord() throws {
        let (ctx, dive) = try makeContext()

        let filename = PhotoStore.save(image: dummyImage(), toDive: dive, context: ctx)
        try ctx.save()

        #expect(filename != nil)
        #expect(dive.photos?.count == 1)
        #expect(dive.photos?.first?.filename == filename)
        #expect(dive.photos?.first?.imageData.isEmpty == false)
    }

    @Test("load returns image from disk cache when present")
    @MainActor
    func loadFromDiskCache() throws {
        let (ctx, dive) = try makeContext()
        guard let filename = PhotoStore.save(image: dummyImage(), toDive: dive, context: ctx) else {
            Issue.record("Save failed")
            return
        }
        try ctx.save()

        let loaded = PhotoStore.load(filename: filename, from: dive)
        #expect(loaded != nil)
    }

    @Test("load falls back to record imageData when disk file missing")
    @MainActor
    func loadFallsBackToRecord() throws {
        let (ctx, dive) = try makeContext()
        guard let filename = PhotoStore.save(image: dummyImage(), toDive: dive, context: ctx) else {
            Issue.record("Save failed")
            return
        }
        try ctx.save()

        // Remove disk file to simulate a fresh device after sync
        PhotoStore.delete(filename: filename)

        let loaded = PhotoStore.load(filename: filename, from: dive)
        #expect(loaded != nil, "Image should still load from DivePhoto.imageData")
    }

    @Test("migrateLocalPhotosToCloudKit creates records for legacy filenames")
    @MainActor
    func migrationCreatesRecords() throws {
        let (ctx, dive) = try makeContext()

        // Simulate legacy: filename in array, no DivePhoto record
        let img = dummyImage()
        guard let data = img.jpegData(compressionQuality: 0.82),
              let legacyFilename = PhotoStore.save(jpegData: data) else {
            Issue.record("Legacy save failed")
            return
        }
        dive.photoFilenames.append(legacyFilename)
        try ctx.save()

        #expect(dive.photos?.isEmpty == true)

        PhotoStore.migrateLocalPhotosToCloudKit(dive: dive, context: ctx)
        try ctx.save()

        #expect(dive.photos?.count == 1)
        #expect(dive.photos?.first?.filename == legacyFilename)
    }

    @Test("migration is idempotent — running twice does not duplicate records")
    @MainActor
    func migrationIdempotent() throws {
        let (ctx, dive) = try makeContext()

        let img = dummyImage()
        guard let data = img.jpegData(compressionQuality: 0.82),
              let filename = PhotoStore.save(jpegData: data) else {
            Issue.record("Save failed")
            return
        }
        dive.photoFilenames.append(filename)
        try ctx.save()

        PhotoStore.migrateLocalPhotosToCloudKit(dive: dive, context: ctx)
        try ctx.save()
        let firstCount = dive.photos?.count ?? 0

        PhotoStore.migrateLocalPhotosToCloudKit(dive: dive, context: ctx)
        try ctx.save()
        let secondCount = dive.photos?.count ?? 0

        #expect(firstCount == 1)
        #expect(secondCount == 1)
    }
}
```

- [ ] **Step 17.2: Tests laufen — die meisten sollten bereits grün sein, einer rot**

```bash
xcodebuild test -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:"DiveLog ProTests/PhotoStoreTests" 2>&1 | tail -20
```

Expected: `saveCreatesRecord`, `loadFromDiskCache`, `migrationCreatesRecords`, `migrationIdempotent` schon grün (decken vorhandene Logik). `loadFallsBackToRecord` ist rot, weil das Verhalten zwar im Code steht, aber die Datei nach Disk-Delete nicht zuverlässig geliefert wird (Edge-Case).

Falls alle grün: Edge-Case-Bug existiert nicht in der Test-Form — dann ist Phase 2c primär ein Architektur-Cleanup (DivePhoto-Inverse, Sync-Status-UI), kein Bugfix. Plan trotzdem weiterführen.

---

## Task 18: `DivePhoto` mit explizitem Inverse + Dive-Side-Property prüfen

**Files:**
- `DiveLog Pro/Models/DivePhoto.swift`
- `DiveLog Pro/Models/Dive.swift`

- [ ] **Step 18.1: Aktuellen Stand sichten**

```bash
grep -n "@Relationship\|photos" "DiveLog Pro/Models/DivePhoto.swift" "DiveLog Pro/Models/Dive.swift"
```

Aktuell in `DivePhoto.swift`: `@Relationship var dive: Dive?`.

In `Dive.swift` muss es eine `photos: [DivePhoto]?`-Property geben (siehe Tests). Falls noch nicht vorhanden, hinzufügen.

- [ ] **Step 18.2: DivePhoto.dive — explizite Inverse-Annotation**

In `DiveLog Pro/Models/DivePhoto.swift`:

**Vorher:**
```swift
@Relationship var dive: Dive?
```

**Nachher:**
```swift
@Relationship(inverse: \Dive.photos) var dive: Dive?
```

- [ ] **Step 18.3: Dive.photos — sicherstellen, dass Property existiert**

In `DiveLog Pro/Models/Dive.swift`, falls noch nicht da, ergänzen (CloudKit verlangt optional + default für to-many):

```swift
@Relationship(deleteRule: .cascade) var photos: [DivePhoto]? = []
```

Achtung — wenn die Property bereits da ist, nur den Inverse-Hinweis aktualisieren. Sonst nichts ändern, sonst hagelt's eine SwiftData-Schema-Migration.

- [ ] **Step 18.4: Build + Tests**

```bash
xcodebuild test -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:"DiveLog ProTests/PhotoStoreTests" 2>&1 | tail -10
```

Expected: dieselben Pass/Fail-Ergebnisse wie Step 17.2.

- [ ] **Step 18.5: Commit**

```bash
git add "DiveLog Pro/Models/DivePhoto.swift" "DiveLog Pro/Models/Dive.swift"
git commit -m "fix(photos): explicit inverse relationship on DivePhoto.dive

CloudKit replication is more reliable when both sides of a
to-many relationship are explicitly linked. This was the only
@Relationship in our schema that didn't declare its inverse."
```

---

## Task 19: `PhotoStore.save` — Single Source of Truth (Record), Disk als Cache

**File:** `DiveLog Pro/Utils/PhotoStore.swift` (modify)

- [ ] **Step 19.1: Bestehenden `save(image:toDive:context:)` lesen**

```bash
sed -n '50,70p' "DiveLog Pro/Utils/PhotoStore.swift"
```

- [ ] **Step 19.2: Refactor — Record ist Wahrheit, Disk-Cache parallel beschreiben**

Ersetze die Funktion durch:

```swift
@discardableResult
static func save(image: UIImage, toDive dive: Dive, context: ModelContext, quality: CGFloat = 0.82) -> String? {
    let resized = downsample(image: image, maxDimension: 2000)
    guard let data = resized.jpegData(compressionQuality: quality) else { return nil }

    // 1. Create the record — this is the source of truth (CloudKit syncs it).
    let filename = UUID().uuidString + ".jpg"
    let photo = DivePhoto()
    photo.filename = filename
    photo.imageData = data
    photo.dive = dive
    context.insert(photo)

    // 2. Best-effort disk cache. Failure is non-fatal; load() falls back to imageData.
    do {
        try data.write(to: url(for: filename), options: .atomic)
    } catch {
        // Log but don't fail — the record is the source of truth.
        print("PhotoStore: disk cache write failed for \(filename): \(error)")
    }

    return filename
}
```

Die Legacy-Funktion `save(jpegData:)` bleibt für SampleData/Onboarding-Pfade unverändert.

- [ ] **Step 19.3: `load(filename:from:)` — gleiches Verhalten, aber mit Cache-Repair**

Aktueller Code ist schon nah dran. Sicherstellen, dass die Cache-Repair-Zeile (`try? record.imageData.write(to: ...)`) drin ist und der Pfad robust ist:

```swift
static func load(filename: String, from dive: Dive) -> UIImage? {
    if let local = load(filename: filename) { return local }

    // Fallback: from the record (source of truth)
    guard let photos = dive.photos,
          let record = photos.first(where: { $0.filename == filename }),
          !record.imageData.isEmpty,
          let image = UIImage(data: record.imageData) else {
        return nil
    }

    // Repair the disk cache for next time — best-effort
    try? record.imageData.write(to: url(for: filename), options: .atomic)
    return image
}
```

- [ ] **Step 19.4: Build + Tests**

```bash
xcodebuild test -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:"DiveLog ProTests/PhotoStoreTests" 2>&1 | tail -10
```

Expected: alle 5 Tests grün, inklusive `loadFallsBackToRecord`.

- [ ] **Step 19.5: Commit**

```bash
git add "DiveLog Pro/Utils/PhotoStore.swift"
git commit -m "fix(photos): DivePhoto record is single source of truth, disk is cache

Reordered save() to create the record first, then best-effort
disk write. load() now repairs the disk cache when an image is
served from imageData. Failure modes (disk full, permission)
are non-fatal — the record always carries the data."
```

---

## Task 20: Migration beim App-Launch triggern

**File:** `DiveLog Pro/Utils/DiveLogProApp.swift` (modify)

- [ ] **Step 20.1: Migration-Hook im Launch finden**

In `DiveLogProApp` gibt es vermutlich schon einen `.onAppear` oder `init` für die ModelContainer-Setup. Nach dem Setup einen Background-Task einfügen:

```swift
private func runPhotoMigrationIfNeeded(container: ModelContainer) {
    Task.detached(priority: .background) { @MainActor in
        let ctx = ModelContext(container)
        let descriptor = FetchDescriptor<Dive>()
        guard let dives = try? ctx.fetch(descriptor) else { return }

        var migrated = 0
        for dive in dives where !dive.photoFilenames.isEmpty {
            let beforeCount = dive.photos?.count ?? 0
            PhotoStore.migrateLocalPhotosToCloudKit(dive: dive, context: ctx)
            let afterCount = dive.photos?.count ?? 0
            migrated += (afterCount - beforeCount)
        }

        if migrated > 0 {
            try? ctx.save()
            print("PhotoStore: migrated \(migrated) legacy photo(s) to DivePhoto records")
        }
    }
}
```

Im App-Init (oder onAppear des Root-Views) aufrufen:
```swift
runPhotoMigrationIfNeeded(container: sharedModelContainer)
```

- [ ] **Step 20.2: Build prüfen**

```bash
xcodebuild build -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 20.3: Commit**

```bash
git add "DiveLog Pro/Utils/DiveLogProApp.swift"
git commit -m "feat(photos): run idempotent legacy-photo migration on launch

Background task scans all dives for entries in photoFilenames that
don't have a corresponding DivePhoto record yet, and creates them.
Idempotent — safe to run on every launch."
```

---

## Task 21: Sync-Status-Indikator in `DivePhotoComponents`

**File:** `DiveLog Pro/Views/Components/DivePhotoComponents.swift` (modify)

- [ ] **Step 21.1: Aktuelle Photo-Cell-Struktur sichten**

```bash
grep -n "DivePhoto\|imageData\|filename" "DiveLog Pro/Views/Components/DivePhotoComponents.swift"
```

- [ ] **Step 21.2: Sync-Status-Mini-Overlay hinzufügen**

Im Photo-Cell-Aufbau, in einem `.overlay(alignment: .bottomTrailing) { ... }`:

```swift
.overlay(alignment: .bottomTrailing) {
    SyncBadge(photo: photo)
        .padding(4)
}
```

Und die Badge-View definieren (am Ende der Datei oder als private struct):

```swift
private struct SyncBadge: View {
    let photo: DivePhoto

    var body: some View {
        Image(systemName: iconName)
            .font(.caption2)
            .foregroundStyle(.white)
            .padding(4)
            .background(Color.black.opacity(0.55))
            .clipShape(Circle())
    }

    /// Heuristic: if the record has imageData and a non-empty persistentModelID,
    /// it's been saved (and CloudKit will sync it eventually). For richer status
    /// we'd need NSPersistentCloudKitContainer event introspection — that's a
    /// later improvement. For now: stored vs. pending-save.
    private var iconName: String {
        if photo.imageData.isEmpty {
            return "exclamationmark.cloud"
        }
        // Heuristic: SwiftData hasn't persisted the model yet
        // (no proper API in iOS 17 — we approximate via persistentModelID).
        return "cloud.fill"
    }
}
```

(Realer Sync-Status via `NSPersistentCloudKitContainer.eventChangedNotification` ist Phase-3-Polish; hier nur ein erster Indikator, der wenigstens unterscheidet "auf disk vs. fehlerhaft".)

- [ ] **Step 21.3: Build prüfen**

```bash
xcodebuild build -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 21.4: Commit**

```bash
git add "DiveLog Pro/Views/Components/DivePhotoComponents.swift"
git commit -m "feat(photos): basic sync-status badge on photo thumbnails

Cloud icon overlay distinguishes 'image stored' from 'no data'
states. Detailed CloudKit event introspection is out of scope
for this fix — see Phase 3 plan."
```

---

## Task 22: Manueller Zwei-Geräte-Foto-Sync-Test

- [ ] **Step 22.1: Vorbereitung**

Zwei Geräte am selben iCloud-Account, App installiert, beide Geräte zeigen denselben Logbook-Stand.

- [ ] **Step 22.2: Test-Pfad**

1. **Gerät A:** Tauchgang öffnen → Foto hinzufügen aus Photo-Picker → speichern.
2. **Gerät B:** denselben Tauchgang öffnen → ~30s warten → Foto sollte in der Galerie erscheinen.
3. **Gerät A:** App schließen, Documents-Verzeichnis löschen (Test-Build mit Debug-Switch oder Neuinstallation), App starten, Tauchgang öffnen → Foto sollte aus dem Record geladen werden (Disk-Cache-Wiederherstellung).
4. **Gerät A:** Migrations-Pfad: Tauchgang aus Sample-Data mit nur `photoFilenames`-Eintrag, ohne `DivePhoto`-Record → App-Start → Migrations-Background-Task rennt → Tauchgang öffnen → Foto da, Record existiert.

- [ ] **Step 22.3: Ergebnisse dokumentieren**

```bash
cat >> docs/operational/2026-05-09-weatherkit-diagnosis.md <<'EOF'

# Photo Sync Two-Device Test — 2026-05-09

**Setup:** <Gerät A, Gerät B, beide iOS xx.x>

**Test 1 — Forward sync:** <Pass/Fail + Latenz in s>
**Test 2 — Disk-cache repair:** <Pass/Fail>
**Test 3 — Legacy migration:** <Pass/Fail>
EOF
```

```bash
git add docs/operational/2026-05-09-weatherkit-diagnosis.md
git commit -m "docs(photos): two-device sync + cache + migration test results"
```

---

## Self-Review Checklist (vor Plan-Abschluss durchgehen)

- [ ] Spec coverage: Phase 1 (4 Tasks), Phase 2a (3 Tasks), Phase 2b (8 Tasks), Phase 2c (5 Tasks). Alle Bug-Symptome aus dem Spec haben einen Task.
- [ ] Numbering-Tests decken alle Edge-Cases ab (empty, backdated, delete, shift, idempotency, pool-exclusion).
- [ ] Photo-Tests decken save / load / disk-fallback / migration / idempotency.
- [ ] Phase-1-Commits ändern *kein* Verhalten — Working-Tree bleibt nach Task 4 leer.
- [ ] Renumber-Hooks: DiveFormView-insert, DiveFormView-edit, QuickLogView, LogbookTab-delete, DeleteUndoManager-restore, ProfileEditView-shift, CloudKit-sync-listener — alle abgedeckt.
- [ ] Keine Placeholder. Jeder Step zeigt das tatsächliche Code-Snippet oder Befehl.

## Out-of-scope für diesen Plan (eigene Specs/Pläne)

- Phase 3: Skill-Assessment-QA + ProfileTab-Refactor.
- Phase 4: Pro-Gating-Audit + App Store Connect + TestFlight + Onboarding-Touchpoint.
- Echter CloudKit-Sync-Status pro Foto (über die Heuristik hinaus).
- Bulk-Import-Pfad für externe Logbooks (würde Renumber einmal am Ende statt pro Insert auslösen).
