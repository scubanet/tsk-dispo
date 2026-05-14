# iOS Etappe 1 — Auth-Migration auf contact_instructor

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** iOS-App liest Auth-State aus `contact_instructor` + `contacts` statt aus Legacy-`instructors`. `CurrentUser.id` = `contacts.id` (canonical, für neue Etappen 3–6). Legacy `instructorId` bleibt als Sidecar, damit TodayView/ProfileView weiter funktionieren bis Etappe 2 die Stores umzieht.

**Architecture:** Zwei parallele Queries in `AuthState.loadCurrentUser`: (1) primary `contact_instructor` JOIN `contacts` für canonical Daten, (2) legacy `instructors` für rückwärtskompatible `instructorId` + `color`. `CurrentUser` erweitert um `firstName`, `lastName`, `preferredLanguage`, `instructorId`. Alle existierenden Call-Sites die `user.id` als Instructor-FK verwendet haben, switchen auf `user.instructorId`.

**Tech Stack:** Swift 5.10, SwiftUI, Supabase-Swift 2.x, Xcode 15, TestFlight.

**Branch:** `ios-auth-contact-instructor`

---

## File Structure

**Modified:**
- `apps/ios-native/ATOLL/Models/CurrentUser.swift` — Felder erweitert (firstName, lastName, preferredLanguage, instructorId; name als computed property)
- `apps/ios-native/ATOLL/Services/AuthState.swift` — neue Load-Logik mit zwei parallelen Queries
- `apps/ios-native/ATOLL/Views/TodayView.swift` — `user.id` → `user.instructorId ?? user.id`
- `apps/ios-native/ATOLL/Views/CalendarView.swift` — `user.id` → `user.instructorId ?? user.id`
- `apps/ios-native/ATOLL/Views/AssignmentsView.swift` — `user.id` → `user.instructorId ?? user.id` (wird in E2 entfernt)
- `apps/ios-native/ATOLL/Views/SaldoView.swift` — `user.id` → `user.instructorId ?? user.id` (wird in E2 entfernt)
- `apps/ios-native/ATOLL/Views/ProfileView.swift` — Nutzt `user.firstName` direkt; `skillsStore.load` mit `instructorId`

**Created:**
- (keine — Etappe 1 ist rein Refactor)

**Deleted:**
- (keine — Cleanup passiert in Etappe 2)

---

## Tasks

### Task 1: Feature-Branch anlegen

**Files:** —

- [ ] **Step 1: Sicherstellen, dass main sauber ist**

Copy-paste in Terminal:
```bash
cd /Users/dominik/Desktop/Developer/Dispo
git status
```
Expected: "nothing to commit, working tree clean" auf main.

- [ ] **Step 2: Branch erstellen**

```bash
git checkout -b ios-auth-contact-instructor
```
Expected: "Switched to a new branch 'ios-auth-contact-instructor'"

---

### Task 2: CurrentUser-Model erweitern

**Files:**
- Modify: `apps/ios-native/ATOLL/Models/CurrentUser.swift`

- [ ] **Step 1: CurrentUser.swift komplett ersetzen**

```swift
import Foundation

struct CurrentUser: Codable, Identifiable, Equatable {
  enum Role: String, Codable {
    case instructor
    case dispatcher
    case owner
    case cd

    /// Lesbares Label für UI-Anzeige (z.B. "Course Director" statt "Cd").
    var displayName: String {
      switch self {
      case .instructor: return "Instructor"
      case .dispatcher: return "Dispatcher"
      case .owner:      return "Owner"
      case .cd:         return "Course Director"
      }
    }
  }

  /// Canonical Identifier ab Phase J — entspricht `contacts.id`.
  let id: UUID

  /// Legacy `instructors.id` — bleibt als Alias bis Stores (Assignments, Movements,
  /// instructor_skills) in späteren Etappen auf `contacts.id` migriert sind.
  /// Nil, wenn der User noch keinen Legacy-Eintrag hat.
  let instructorId: UUID?

  let firstName: String
  let lastName: String
  let email: String?
  let padiLevel: String
  let role: Role
  let authUserId: UUID?
  let preferredLanguage: String?
  let initials: String?
  /// Legacy-Avatar-Farbe aus `instructors.color`. Geht verloren wenn die
  /// Tabelle gedroppt wird — UI muss dann auf ID-Hash-Farbe ausweichen.
  let color: String?

  /// Zusammengesetzter Anzeige-Name für Begrüssungen.
  var name: String {
    let trimmed = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    return trimmed.isEmpty ? "—" : trimmed
  }

  /// Fallback wenn ein auth.users-Account weder einem `contact_instructor` noch
  /// einem `instructors`-Eintrag verknüpft ist.
  static func unlinked(authUserId: UUID) -> CurrentUser {
    CurrentUser(
      id: UUID(),
      instructorId: nil,
      firstName: "—",
      lastName: "",
      email: nil,
      padiLevel: "—",
      role: .instructor,
      authUserId: authUserId,
      preferredLanguage: nil,
      initials: nil,
      color: nil
    )
  }
}
```

- [ ] **Step 2: Build prüfen (Xcode-Compile)**

Xcode öffnen → `Product → Build` (⌘B).
Expected: Erstmal Compile-Errors in TodayView, ProfileView, CalendarView, AssignmentsView, SaldoView — sie nutzen `user.name` als stored property, ist jetzt computed. Das ist OK, wird in den nächsten Tasks gefixt.

---

### Task 3: AuthState mit zwei parallelen Queries

**Files:**
- Modify: `apps/ios-native/ATOLL/Services/AuthState.swift`

- [ ] **Step 1: AuthState.swift komplett ersetzen**

```swift
import Foundation
import Supabase
import SwiftUI

/// App-weiter Auth-Zustand. Verwaltet Session, lädt aktuellen Instructor aus
/// `contact_instructor` (canonical) + `instructors` (legacy fallback).
@MainActor
@Observable
final class AuthState {
  enum Status {
    case loading
    case signedOut
    case signedIn(currentUser: CurrentUser)
  }

  private(set) var status: Status = .loading

  private let supabase = SupabaseClient.shared

  init() {
    Task { await bootstrap() }
    Task { await listenToAuthChanges() }
  }

  // MARK: – Bootstrap

  func bootstrap() async {
    do {
      let session = try await supabase.auth.session
      await loadCurrentUser(authUserId: session.user.id)
    } catch {
      status = .signedOut
    }
  }

  // MARK: – Sign in

  func sendMagicLink(to email: String) async throws {
    try await supabase.auth.signInWithOTP(
      email: email,
      redirectTo: Config.authRedirectURL
    )
  }

  /// Wird aufgerufen wenn die App mit `atoll://auth/callback?...` geöffnet wird.
  func handleAuthCallback(url: URL) async throws {
    try await supabase.auth.session(from: url)
    if let userID = try? await supabase.auth.session.user.id {
      await loadCurrentUser(authUserId: userID)
    }
  }

  // MARK: – Sign out

  func signOut() async {
    try? await supabase.auth.signOut()
    status = .signedOut
  }

  // MARK: – Listener

  private func listenToAuthChanges() async {
    for await change in supabase.auth.authStateChanges {
      switch change.event {
      case .signedIn, .tokenRefreshed, .userUpdated:
        if let user = change.session?.user {
          await loadCurrentUser(authUserId: user.id)
        }
      case .signedOut:
        status = .signedOut
      default:
        break
      }
    }
  }

  // MARK: – Load user (contact_instructor + legacy instructors)

  /// PostgREST-Row-Wrapper für den primären `contact_instructor`-Lookup.
  private struct ContactInstructorRow: Decodable {
    let padiLevel: String?
    let appRole: String?
    let preferredLanguage: String?
    let initials: String?
    let contact: ContactRow

    enum CodingKeys: String, CodingKey {
      case padiLevel = "padi_level"
      case appRole = "app_role"
      case preferredLanguage = "preferred_language"
      case initials
      case contact = "contacts"
    }

    struct ContactRow: Decodable {
      let id: UUID
      let firstName: String
      let lastName: String
      let primaryEmail: String?

      enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case primaryEmail = "primary_email"
      }
    }
  }

  /// PostgREST-Row-Wrapper für den Legacy-Fallback aus `instructors`.
  private struct InstructorLegacyRow: Decodable {
    let id: UUID
    let color: String?
  }

  private func loadCurrentUser(authUserId: UUID) async {
    // Primary: contact_instructor → contacts (canonical)
    let primary: ContactInstructorRow?
    do {
      primary = try await supabase
        .from("contact_instructor")
        .select("padi_level, app_role, preferred_language, initials, contacts!inner(id, first_name, last_name, primary_email)")
        .eq("auth_user_id", value: authUserId)
        .single()
        .execute()
        .value
    } catch {
      primary = nil
    }

    // Legacy: instructors.id für rückwärtskompatible Stores
    let legacy: InstructorLegacyRow? = try? await supabase
      .from("instructors")
      .select("id, color")
      .eq("auth_user_id", value: authUserId)
      .single()
      .execute()
      .value

    guard let p = primary else {
      // Account existiert in auth.users aber kein contact_instructor.
      status = .signedIn(currentUser: CurrentUser.unlinked(authUserId: authUserId))
      return
    }

    let role = CurrentUser.Role(rawValue: p.appRole ?? "instructor") ?? .instructor

    let user = CurrentUser(
      id: p.contact.id,
      instructorId: legacy?.id,
      firstName: p.contact.firstName,
      lastName: p.contact.lastName,
      email: p.contact.primaryEmail,
      padiLevel: p.padiLevel ?? "—",
      role: role,
      authUserId: authUserId,
      preferredLanguage: p.preferredLanguage,
      initials: p.initials,
      color: legacy?.color
    )
    status = .signedIn(currentUser: user)
  }
}
```

- [ ] **Step 2: Build prüfen**

Xcode → Build (⌘B).
Expected: Compile-Errors NUR noch in den Views, die `user.id` als Instructor-FK verwenden. AuthState selbst kompiliert.

---

### Task 4: Views auf `user.instructorId` umstellen

**Files:**
- Modify: `apps/ios-native/ATOLL/Views/TodayView.swift`
- Modify: `apps/ios-native/ATOLL/Views/CalendarView.swift`
- Modify: `apps/ios-native/ATOLL/Views/AssignmentsView.swift`
- Modify: `apps/ios-native/ATOLL/Views/SaldoView.swift`
- Modify: `apps/ios-native/ATOLL/Views/ProfileView.swift`

- [ ] **Step 1: Helper-Computed-Property auf CurrentUser**

Damit der Switch in den Call-Sites kürzer wird, eine Convenience auf `CurrentUser` ergänzen.

In `apps/ios-native/ATOLL/Models/CurrentUser.swift` direkt nach `var name: String { ... }` einfügen:

```swift
  /// Convenience für Stores die noch mit Legacy `instructors.id` arbeiten.
  /// Fällt auf `id` (= contacts.id) zurück wenn kein Legacy-Eintrag existiert —
  /// dann liefern die Stores einfach eine leere Liste.
  var legacyInstructorId: UUID { instructorId ?? id }
```

- [ ] **Step 2: TodayView.swift Stelle 1**

In `apps/ios-native/ATOLL/Views/TodayView.swift` Zeile 28–29:

```swift
      .refreshable { await store.load(instructorId: user.legacyInstructorId) }
      .task { await store.load(instructorId: user.legacyInstructorId) }
```

- [ ] **Step 3: TodayView.swift Stelle 2**

In `TodayView.swift` Zeile 49:

```swift
        Button("Nochmal versuchen") {
          Task { await store.load(instructorId: user.legacyInstructorId) }
        }
```

- [ ] **Step 4: CalendarView.swift**

In `apps/ios-native/ATOLL/Views/CalendarView.swift` Zeile 28–29 (analog):

```swift
            .refreshable { await store.load(instructorId: user.legacyInstructorId) }
            .task { await store.load(instructorId: user.legacyInstructorId) }
```

- [ ] **Step 5: AssignmentsView.swift**

In `apps/ios-native/ATOLL/Views/AssignmentsView.swift` Zeilen 20, 36, 37:

```swift
              Task { await store.load(instructorId: user.legacyInstructorId) }
```
und unten:
```swift
      .refreshable { await store.load(instructorId: user.legacyInstructorId) }
      .task { await store.load(instructorId: user.legacyInstructorId) }
```

- [ ] **Step 6: SaldoView.swift**

In `apps/ios-native/ATOLL/Views/SaldoView.swift` Zeilen 20, 36, 37 analog:

```swift
                            Task { await store.load(instructorId: user.legacyInstructorId) }
```
```swift
            .refreshable { await store.load(instructorId: user.legacyInstructorId) }
            .task { await store.load(instructorId: user.legacyInstructorId) }
```

- [ ] **Step 7: ProfileView.swift — `skillsStore.load`**

In `apps/ios-native/ATOLL/Views/ProfileView.swift` Zeilen 84–85:

```swift
            .refreshable { await skillsStore.load(instructorId: user.legacyInstructorId) }
            .task { await skillsStore.load(instructorId: user.legacyInstructorId) }
```

- [ ] **Step 8: ProfileView.swift — Initialen-Fallback prüfen**

Zeile 14 nutzt `user.initials ?? String(user.firstName.prefix(2))`. Beide Felder gibt's noch — bleibt unverändert.

- [ ] **Step 9: ATOLLApp.swift — `user.id` für PushManager**

In `apps/ios-native/ATOLL/ATOLLApp.swift` Zeile 32:

```swift
    if case .signedIn(let user) = status { return user.legacyInstructorId }
```

Begründung: `PushManager` registriert Devices in `device_tokens.instructor_id` — Legacy-FK, also `instructorId`-Pfad.

- [ ] **Step 10: Build prüfen**

Xcode → Build (⌘B).
Expected: Build erfolgreich, keine Errors, keine Warnings die mit dieser Änderung zu tun haben.

---

### Task 5: Lokaler Simulator-Smoke

**Files:** —

- [ ] **Step 1: Sign-In-Flow durchspielen**

Xcode → Simulator (iPhone 15) → Build & Run (⌘R).
Im Sign-In-Screen die eigene Email eintippen → Magic-Link anfordern → Mail öffnen → Link tippen → App öffnet sich.

Expected:
- Heute-Tab zeigt Begrüssung "Hi, [FirstName] 👋"
- Heutige Einsätze (falls vorhanden) erscheinen
- Profil-Tab zeigt Name, Email, Rolle, PADI-Level
- Skills-Liste lädt (falls hinterlegt)

- [ ] **Step 2: Sign-Out + Re-Login**

In Profil → Logout → SignIn-Screen erscheint → Re-Login mit Magic-Link → zurück in der App, gleicher Zustand.

Expected: Session-Restore funktioniert ohne App-Restart.

- [ ] **Step 3: Edge-Case "Kein contact_instructor"**

Falls nicht eh schon: in Supabase Studio einen Test-Auth-User anlegen ohne `contact_instructor`-Sidecar. Login damit → App zeigt CurrentUser-unlinked (Name = "—", Profile zeigt Standardwerte, keine Crashes).

---

### Task 6: Commit + TestFlight-Upload

**Files:** —

- [ ] **Step 1: Files stagen + commit**

Copy-paste:
```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/ios-native/ATOLL/Models/CurrentUser.swift \
        apps/ios-native/ATOLL/Services/AuthState.swift \
        apps/ios-native/ATOLL/Views/TodayView.swift \
        apps/ios-native/ATOLL/Views/CalendarView.swift \
        apps/ios-native/ATOLL/Views/AssignmentsView.swift \
        apps/ios-native/ATOLL/Views/SaldoView.swift \
        apps/ios-native/ATOLL/Views/ProfileView.swift \
        apps/ios-native/ATOLL/ATOLLApp.swift
git commit -m "ios(auth): cutover to contact_instructor + contacts (Phase J Etappe 3d)

CurrentUser.id is now canonical contacts.id. Legacy instructorId is kept
as a fallback while Etappe 2 (tab restructure) still references it via
legacyInstructorId in TodayView/Profile/etc.

Drops 'name' from instructors-row read; composes from contacts.first_name +
contacts.last_name. Preferred_language and initials now come from
contact_instructor sidecar.

Refs: docs/superpowers/specs/2026-05-14-ios-instructor-mobile-companion-design.md (Etappe 1)"
```

- [ ] **Step 2: Branch pushen**

```bash
git push -u origin ios-auth-contact-instructor
```

- [ ] **Step 3: Archive für TestFlight**

Xcode → Schema "Any iOS Device" → `Product → Archive`. Im Organizer "Distribute App" → "App Store Connect" → "TestFlight Only". Bei Code-Signing-Issues: Settings → Signing & Capabilities → "Automatically manage signing" prüfen.

Expected: Archive erfolgreich, Upload-Status in App-Store-Connect "Processing".

- [ ] **Step 4: TestFlight-Build testen**

Auf iPhone: TestFlight-App öffnen → ATOLL → neueste Version installieren → Login durchspielen wie in Task 5.

Expected: Login funktioniert auf realem Gerät. Profile zeigt korrekte Daten. Persistente Session über App-Kill nachweisbar.

---

### Task 7: Merge nach main

**Files:** —

- [ ] **Step 1: Smoke-Test bestätigt**

Erst wenn Task 5 + Task 6 Step 4 grün sind weiter.

- [ ] **Step 2: Merge per FF wenn keine Konflikte**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git checkout main
git pull --ff-only
git merge --ff-only ios-auth-contact-instructor
git push
```

Falls FF nicht möglich (main vorgerückt): rebase auf main, dann FF:
```bash
git checkout ios-auth-contact-instructor
git rebase main
git checkout main
git merge --ff-only ios-auth-contact-instructor
git push
```

- [ ] **Step 3: Branch lokal aufräumen**

```bash
git branch -d ios-auth-contact-instructor
git push origin --delete ios-auth-contact-instructor
```

- [ ] **Step 4: Memory aktualisieren**

In `project_phase_j.md`: Punkt 1 "iOS-Audit: AuthState.swift auf contact_instructor migrieren" als done markieren. Hinweis ergänzen: instructors-Tabelle bleibt für Stores (course_assignments, movements, instructor_skills) bis Etappe 2 + Etappe 5 + Edge-Function-Migration durch sind.

---

## Self-Review

**Spec coverage check (Abschnitt 5 Etappe 1):**
- ✅ AuthState.swift Read-Pfad auf contact_instructor — Task 3
- ✅ CurrentUser-Felder erweitert (contactId/appRole/preferredLanguage) — Task 2
- ✅ Legacy instructorId-Alias erhalten — Task 2 + Task 4 (`legacyInstructorId`)
- ✅ Smoke-Test: Login, Re-Login, CD-Login — Task 5 + Task 6 Step 4
- ✅ Branch + TestFlight — Task 1, Task 6, Task 7

**Placeholder scan:** Keine TBDs, alle Code-Blöcke vollständig.

**Type consistency:** `legacyInstructorId` durchgängig in TodayView/CalendarView/AssignmentsView/SaldoView/ProfileView/ATOLLApp. Methodensignatur `store.load(instructorId: UUID)` aller Stores unverändert.

**Spec-Annahme bestätigen vor Start:** Hat die Production-DB für deinen Test-User schon einen `contact_instructor`-Eintrag mit `auth_user_id`? Falls nein, vorher in Studio anlegen (sonst landet jeder Login im unlinked-Pfad). Stand 14.05. sollte Phase-J-3a/3b durch sein, aber kurz gegenchecken.

**Bekannte Nebeneffekte:**
- `instructors.color` wird nach `instructors`-Drop verloren gehen. Etappe 2 oder später muss `AvatarView` auf ID-Hash-Farbe umstellen (gleiches Pattern wie geplanter `StudentAvatar` in Etappe 3).
- `padi_skill_records.instructor_id` schreiben wir nicht in dieser Etappe — passiert erst in Etappe 5. Bis dahin schreiben weder iOS noch Web neue Records mit der neuen ID.

**Spec-Gap entdeckt:** Spec Section 10 sagt "Heute-Tab bleibt unverändert" — das stimmt für Etappe 1, aber NICHT für Etappe 2 (wo AssignmentsStore gelöscht wird, also TodayView refactored werden muss). Etappe-2-Plan muss das adressieren.
