# iOS Etappe 2 — Tab-Restruktur

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Von 5 Tabs (Heute / Kalender / Einsätze / Saldo / Profil) auf 4 Tabs (Heute / Kurse / Studenten / Profil) reduzieren. Saldo + Einsätze entfallen. Neuer Studenten-Tab kommt als Placeholder rein, der in Etappe 6 ausgebaut wird.

**Architecture:** Minimal-Refactor. `MainTabView` baut die Tabs neu. `CalendarView.swift` bleibt als Datei und Struct, nur das Label im Tab wird von "Kalender" auf "Kurse" geändert (interne Umbenennung ist nicht relevant — Filenames sind Devs-Sicht, kein User-Impact). `StudentsView.swift` kommt als Placeholder hinzu. Veraltete Files für die zwei entfernten Tabs werden via Xcode-UI gelöscht (Code-Files und Xcode-Project-Reference).

**Tech Stack:** Swift 5.10, SwiftUI, Xcode 15, TestFlight.

**Branch:** `ios-etappe-2-tab-restructure`

**Spec-Amendment (im Plan dokumentiert):** Spec sagt in Section 3/5 "AssignmentsStore + Assignment + AssignmentDetailView werden in Etappe 2 entfernt". Real-Inspektion zeigt: TodayView und CalendarView nutzen beide noch `AssignmentsStore` zum Laden ihrer Einsätze, und beide haben `NavigationDestination(for: Assignment.self)` mit `AssignmentDetailView` als Ziel. Diese drei Files BLEIBEN in Etappe 2, sonst kompiliert nichts. Sie können erst entfernt werden wenn Etappe 3 (CourseDetailView ersetzt AssignmentDetailView) durch ist — oder werden in einer späteren Refactoring-Etappe sauber umbenannt zu `MyCoursesStore`/`Course`/`CourseDetailView`. Für die Pitch-Latenz ist Pragmatismus richtig.

---

## File Structure

**Created:**
- `apps/ios-native/ATOLL/Views/Students/StudentsView.swift` — Placeholder

**Modified:**
- `apps/ios-native/ATOLL/Views/MainTabView.swift` — 4 Tabs, neue Reihenfolge, Label "Kalender" → "Kurse"

**Deleted (Code + Xcode-Project-Reference):**
- `apps/ios-native/ATOLL/Views/AssignmentsView.swift` (war "Einsätze"-Tab)
- `apps/ios-native/ATOLL/Views/SaldoView.swift` (war "Saldo"-Tab)
- `apps/ios-native/ATOLL/Services/MovementsStore.swift` (nur SaldoView Konsument)
- `apps/ios-native/ATOLL/Models/Movement.swift` (nur SaldoView Konsument)
- `apps/ios-native/ATOLL/Views/MovementDetailView.swift` (Push-Ziel aus SaldoView)

**KEEP (trotz Spec):**
- `Services/AssignmentsStore.swift` — TodayView + CalendarView Quelle
- `Models/Assignment.swift` — TodayView + CalendarView Type
- `Views/AssignmentDetailView.swift` — NavigationDestination aus TodayView + CalendarView; wird in Etappe 3 ersetzt
- `Components/RoleBadge.swift`, `Components/StatusChip.swift` — werden in AssignmentCard verwendet

---

## Tasks

### Task 1: Feature-Branch anlegen

**Voraussetzung:** Xcode schliessen (verhindert HEAD-Lock — siehe Memory `feedback_git_xcode_lock.md`).

- [ ] **Step 1: Branch erstellen**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git status            # sollte sauber auf main sein
git checkout -b ios-etappe-2-tab-restructure
```

Expected: "Switched to a new branch 'ios-etappe-2-tab-restructure'"

---

### Task 2: StudentsView-Placeholder anlegen (Subagent-Edit)

**Files:**
- Create: `apps/ios-native/ATOLL/Views/Students/StudentsView.swift`

- [ ] **Step 1: Verzeichnis erstellen**

```bash
mkdir -p /Users/dominik/Desktop/Developer/Dispo/apps/ios-native/ATOLL/Views/Students
```

- [ ] **Step 2: StudentsView.swift erstellen** mit folgendem Inhalt:

```swift
import SwiftUI

/// Placeholder für Etappe 6 — Global Studenten-Tab mit Suche & Filter.
/// In Etappe 2 wird nur der Tab eingeführt, damit die App-Navigation
/// die finale 4-Tab-Form hat.
struct StudentsView: View {
  let user: CurrentUser

  var body: some View {
    NavigationStack {
      ContentUnavailableView {
        Label("Studenten", systemImage: "person.2.fill")
      } description: {
        Text("Übersicht über alle deine Schüler — kommt in einer der nächsten Updates.")
      }
      .navigationTitle("Studenten")
    }
  }
}
```

---

### Task 3: MainTabView auf 4 Tabs umstellen (Subagent-Edit)

**Files:**
- Modify: `apps/ios-native/ATOLL/Views/MainTabView.swift`

- [ ] **Step 1: MainTabView.swift komplett ersetzen**

```swift
import SwiftUI

struct MainTabView: View {
    let user: CurrentUser

    var body: some View {
        TabView {
            TodayView(user: user)
                .tabItem {
                    Label("Heute", systemImage: "sun.max.fill")
                }
            CalendarView(user: user)
                .tabItem {
                    Label("Kurse", systemImage: "calendar")
                }
            StudentsView(user: user)
                .tabItem {
                    Label("Studenten", systemImage: "person.2.fill")
                }
            ProfileView(user: user)
                .tabItem {
                    Label("Profil", systemImage: "person.crop.circle.fill")
                }
        }
        .tint(.accentColor)
    }
}
```

Hinweise:
- Label von "Kalender" → "Kurse", System-Icon `calendar` bleibt (auch ein Kurs hat Daten)
- `StudentsView(user: user)` zwischen Kurse und Profil
- `AssignmentsView` und `SaldoView` raus
- Struct-Name `CalendarView` bleibt unverändert — nur die UI-Label-Anpassung

- [ ] **Step 2: Innerhalb von CalendarView die NavigationTitle anpassen**

In `apps/ios-native/ATOLL/Views/CalendarView.swift` Zeile 25:

```swift
            .navigationTitle("Kalender")
```
→
```swift
            .navigationTitle("Kurse")
```

(Dann passt die NavigationTitle zum Tab-Label.)

---

### Task 4: Build prüfen (User in Xcode)

**Files:** —

- [ ] **Step 1: Xcode öffnen**

Xcode öffnen, Projekt `ATOLL.xcodeproj` aufmachen. Im Project-Navigator (links) sollte `StudentsView.swift` noch NICHT auftauchen — das ist der nächste Schritt.

- [ ] **Step 2: StudentsView.swift zum Xcode-Projekt hinzufügen**

In Xcode-Project-Navigator:
1. Rechtsklick auf das `Views`-Verzeichnis im Navigator
2. "Add Files to ATOLL..." wählen
3. Im Dialog: navigiere zu `apps/ios-native/ATOLL/Views/Students/StudentsView.swift`
4. Sicherstellen dass das ATOLL-Target gehakt ist
5. "Add" klicken

Expected: `StudentsView.swift` erscheint im Navigator unter `Views/Students/`.

- [ ] **Step 3: Erster Build**

Xcode → `Product → Build` (⌘B).

Expected: Compile-Errors in MainTabView.swift wegen Verweisen auf `AssignmentsView`, `SaldoView` und/oder ihre Dependencies — DA WIR DIE FILES NOCH NICHT GELÖSCHT HABEN, sollte das eigentlich noch kompilieren. Wenn rot, lies die Errors und schick mir den ersten zur Diagnose.

---

### Task 5: Veraltete Files löschen (User in Xcode + Shell)

**Files:**
- Delete: 5 Files (siehe Liste oben)

- [ ] **Step 1: Files in Xcode "Move to Trash"**

Im Xcode-Project-Navigator:
1. `Views/AssignmentsView.swift` selektieren → rechtsklick → "Delete" → **"Move to Trash"**
2. Gleich für: `Views/SaldoView.swift`, `Services/MovementsStore.swift`, `Models/Movement.swift`, `Views/MovementDetailView.swift`

Jeweils "Move to Trash" wählen (nicht "Remove Reference") — damit ist Datei UND Xcode-Project-Reference weg.

- [ ] **Step 2: Verifikation per Shell**

```bash
cd /Users/dominik/Desktop/Developer/Dispo/apps/ios-native/ATOLL
ls Views/AssignmentsView.swift Views/SaldoView.swift Views/MovementDetailView.swift Services/MovementsStore.swift Models/Movement.swift 2>&1 | head
```

Expected: Alle 5 Files "No such file or directory" — sie sind weg.

- [ ] **Step 3: Build erneut**

Xcode → Build (⌘B).

Expected: Build erfolgreich. Wenn rote Errors auftauchen wegen verbleibender Referenzen auf gelöschte Symbole, sind das die Fix-Punkte:
- `AssignmentsView` Referenz irgendwo? Nicht in MainTabView mehr (wir haben's rausgenommen). Suche im Codebase, falls etwas anderes referenziert
- `SaldoView` / `Movement` / `MovementDetailView` / `MovementsStore` Referenzen? Sollten alle nur in den gelöschten Files vorgekommen sein

Bei Fehler: mir Error-Message schicken, dann Subagent für Diagnose dispatchen.

---

### Task 6: Simulator-Smoke

- [ ] **Step 1: Simulator starten**

Xcode → ⌘R (iPhone 15 z.B.). Login (sollte schon vom letzten Build durch TestFlight gecached sein, oder Magic-Link erneut).

Expected:
- **Heute-Tab:** wie vorher — Begrüssung, heutige Einsätze, Diese Woche
- **Kurse-Tab:** Monatsgrid (war Kalender), Navigation funktioniert
- **Studenten-Tab:** ContentUnavailableView mit Person-Icon und Text "kommt in einer der nächsten Updates"
- **Profil-Tab:** unverändert
- TabBar zeigt 4 Items, kein "Einsätze", kein "Saldo"

- [ ] **Step 2: Tap-Through-Smoke**

- Heute-Tab: tap auf einen Assignment-Card → AssignmentDetailView öffnet sich (immer noch da, weil nicht gelöscht)
- Kurse-Tab: tap auf einen Tag mit Punkten → Day-Details unten zeigen sich
- Logout/Login durchspielen → noch ok

---

### Task 7: Commit + TestFlight

- [ ] **Step 1: Xcode schliessen** (vor Terminal-Commit, gegen Lock)

- [ ] **Step 2: Stagen + committen**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/ios-native/ATOLL/Views/MainTabView.swift \
        apps/ios-native/ATOLL/Views/CalendarView.swift \
        apps/ios-native/ATOLL/Views/Students/StudentsView.swift
git rm apps/ios-native/ATOLL/Views/AssignmentsView.swift \
       apps/ios-native/ATOLL/Views/SaldoView.swift \
       apps/ios-native/ATOLL/Views/MovementDetailView.swift \
       apps/ios-native/ATOLL/Services/MovementsStore.swift \
       apps/ios-native/ATOLL/Models/Movement.swift
# Xcode-Project-File hat sich auch geändert durch Add/Delete
git add apps/ios-native/ATOLL.xcodeproj/project.pbxproj
git status
```

Expected: Modified MainTabView, CalendarView, project.pbxproj. New: StudentsView.swift. Deleted: 5 Files.

```bash
git commit -m "ios(nav): reduce to 4 tabs (Heute/Kurse/Studenten/Profil)

Einsätze + Saldo entfernt, Studenten-Tab als Placeholder eingeführt.
Kalender-Tab umbenannt zu 'Kurse'. AssignmentsStore + Assignment +
AssignmentDetailView bleiben (Konsumenten: TodayView, CalendarView) —
werden in Etappe 3 abgelöst durch CourseDetailView.

Refs: docs/superpowers/specs/2026-05-14-ios-instructor-mobile-companion-design.md (Etappe 2)"
git push -u origin ios-etappe-2-tab-restructure
```

- [ ] **Step 3: Xcode wieder öffnen, Build-Number bumpen, Archive**

In Xcode → Project-Settings → ATOLL Target → General → "Build" hochzählen (z.B. von 12 auf 13). Sonst wirft TestFlight-Upload "Build already exists" zurück.

Scheme oben links: "Any iOS Device (arm64)" → `Product → Archive` → Organizer → "Distribute App" → "App Store Connect" → "TestFlight Only" → Upload.

Warten bis Processing fertig (App Store Connect web), dann auf iPhone TestFlight aktualisieren und Smoke durchspielen wie in Task 6.

---

### Task 8: Merge nach main

- [ ] **Step 1: Xcode schliessen**

- [ ] **Step 2: Merge per FF**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git checkout main
git pull --ff-only
git merge --ff-only ios-etappe-2-tab-restructure
git push
```

- [ ] **Step 3: Branch aufräumen**

```bash
git branch -d ios-etappe-2-tab-restructure
git push origin --delete ios-etappe-2-tab-restructure
git log --oneline -3
```

---

## Self-Review

**Spec coverage check:**
- ✅ MainTabView: 4 Tabs (Heute/Kurse/Studenten/Profil) — Task 3
- ✅ Kalender → Kurse Umbenennung (Label + NavigationTitle) — Task 3
- ✅ StudentsView Placeholder — Task 2
- ⚠️ Spec sagt "delete AssignmentsView, AssignmentDetailView, SaldoView, AssignmentsStore, MovementsStore, Assignment, Movement, MovementDetailView". **Real-Stand:** AssignmentsStore + Assignment + AssignmentDetailView werden gebraucht (TodayView + CalendarView). Plan löscht nur 5 von 8 Files. Begründung im Plan-Header dokumentiert. Spec sollte nach Etappe 2 ergänzt werden (Section 3 + 5 Etappe 2).

**Placeholder scan:** Keine TBDs, alle Code-Blöcke vollständig.

**Type consistency:** `StudentsView(user: user)` matched die Signatur (CurrentUser), wie alle anderen Tab-Views. Filename `StudentsView.swift` und Struct-Name `StudentsView` stimmen überein.

**Pre-flight check:** Prüfe vor Start, dass `CalendarView.swift` Zeile 25 wirklich `.navigationTitle("Kalender")` enthält (nicht zwischenzeitlich von jemandem geändert).

**Risiko-Check:**
- Niedrig — keine Auth-Änderung, keine DB-Migration. Wenn was kaputt geht, einfach 1 Commit zurück.
- Build-Number-Bump vergessen ist häufigster Stolperstein bei TestFlight.

**Optionale Spec-Aktualisierung:** Nach Etappe 2 ist es sinnvoll, die Spec Section 3 (Entfernte Files) und Section 5 Etappe 2 (Delete-Liste) zu korrigieren — die drei Assignment-bezogenen Files werden erst in Etappe 3 abgelöst. Kann separat als kleinen docs-Commit nachgereicht werden.
