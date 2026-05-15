# ATOLL App Suite Foundation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Die wiederverwendbaren Bestandteile der bestehenden ATOLL-iOS-App (Auth, Supabase-Client, Models, Locale, Brand-Theme, gemeinsame UI-Components) in zwei lokale Swift Packages (`AtollCore`, `AtollDesign`) extrahieren, damit AtollCal und AtollLog später darauf aufbauen können.

**Architecture:** Monorepo bleibt (`Dispo/`). Existierender `apps/ios-native/` wird umbenannt zu `apps/atoll-ios/`. Neuer Top-Level-Ordner `swift-packages/` enthält `AtollCore/` und `AtollDesign/` als reguläre Swift Packages mit `Package.swift`. Beide werden via `project.yml` (XcodeGen) als Local Package Dependencies in der ATOLL-iOS-App referenziert. Existierende Files werden umgezogen, Access-Levels auf `public` gehoben, Imports in der App umgestellt — schrittweise mit einem Build-Smoke-Test pro Task.

**Tech Stack:** Swift 5.9 · SwiftUI · Supabase Swift SDK 2.x · XcodeGen für `.xcodeproj`-Generierung · iOS 17+ Deployment Target.

**Quellspec:** `docs/superpowers/specs/2026-05-14-atoll-suite-foundation-design.md`

**Wichtige Constraints:**
- Sandbox kann KEIN `xcodebuild` ausführen (kein Xcode in der Sandbox). Build-Verifikation passiert immer beim User auf seinem Mac via `xcodegen generate && open ATOLL.xcodeproj && cmd-B`.
- Bundle-ID `swiss.atoll.app` darf sich nicht ändern (sonst neue App im App-Store).
- XcodeGen muss installiert sein: `brew install xcodegen`.

---

## Pre-Flight

- [ ] **Step P.1: XcodeGen verfügbar?**

User auf seinem Mac:
```bash
which xcodegen && xcodegen version
```
Erwartet: Pfad + Version-String. Wenn fehlt: `brew install xcodegen`.

- [ ] **Step P.2: Aktueller Build erfolgreich?**

User auf seinem Mac:
```bash
cd /Users/dominik/Desktop/Developer/Dispo/apps/ios-native
xcodegen generate
xcodebuild -project ATOLL.xcodeproj -scheme ATOLL -destination 'generic/platform=iOS Simulator' -configuration Debug clean build 2>&1 | tail -20
```
Erwartet: `BUILD SUCCEEDED`. Wenn nicht: erst den vorhandenen Build-Bug fixen, **bevor** wir die Migration starten — sonst kennen wir nicht den Unterschied zwischen „durch Migration verursachter Fehler" und „war vorher schon kaputt".

- [ ] **Step P.3: Working-Tree clean**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git status --short
```
Erwartet: keine Output-Zeilen. Wenn etwas pending: erst commiten oder stashen.

---

## Task 1: Repo-Rename `apps/ios-native` → `apps/atoll-ios`

**Files:**
- Rename: directory `apps/ios-native/` → `apps/atoll-ios/`

- [ ] **Step 1.1: Directory umbenennen**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git mv apps/ios-native apps/atoll-ios
```

`git mv` erhält die History. Bei `git status` sollten alle ~50 Files als `renamed:` erscheinen (nicht als `deleted` + `new`).

- [ ] **Step 1.2: Stale `.xcodeproj` aus dem alten Pfad sicherstellen**

```bash
ls /Users/dominik/Desktop/Developer/Dispo/apps/atoll-ios/ATOLL.xcodeproj 2>&1 | head -3
```
Falls die `.xcodeproj` mit umgezogen ist (gitignored, also im Git nicht sichtbar aber auf der Disk): mit der nächsten `xcodegen generate`-Runde wird sie neu erstellt.

```bash
rm -rf /Users/dominik/Desktop/Developer/Dispo/apps/atoll-ios/ATOLL.xcodeproj
```

- [ ] **Step 1.3: `xcodegen generate` ausführen**

```bash
cd /Users/dominik/Desktop/Developer/Dispo/apps/atoll-ios
xcodegen generate
```
Erwartet: `Created project at ATOLL.xcodeproj`.

- [ ] **Step 1.4: Build verifizieren**

```bash
xcodebuild -project ATOLL.xcodeproj -scheme ATOLL -destination 'generic/platform=iOS Simulator' -configuration Debug clean build 2>&1 | tail -20
```
Erwartet: `BUILD SUCCEEDED`.

- [ ] **Step 1.5: Commit (Controller)**

```bash
git add apps/atoll-ios/
git commit -m "refactor(ios): rename apps/ios-native → apps/atoll-ios (Foundation Phase 1)"
```

---

## Task 2: `AtollCore`-Package-Skeleton anlegen

**Files:**
- Create: `swift-packages/AtollCore/Package.swift`
- Create: `swift-packages/AtollCore/Sources/AtollCore/AtollCore.swift` (placeholder)
- Create: `swift-packages/AtollCore/Tests/AtollCoreTests/AtollCoreTests.swift`

- [ ] **Step 2.1: Package.swift anlegen**

`swift-packages/AtollCore/Package.swift`:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "AtollCore",
  defaultLocalization: "de",
  platforms: [
    .iOS(.v17),
    .macOS(.v14),
  ],
  products: [
    .library(
      name: "AtollCore",
      targets: ["AtollCore"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/supabase/supabase-swift", from: "2.0.0"),
  ],
  targets: [
    .target(
      name: "AtollCore",
      dependencies: [
        .product(name: "Supabase", package: "supabase-swift"),
      ]
    ),
    .testTarget(
      name: "AtollCoreTests",
      dependencies: ["AtollCore"]
    ),
  ]
)
```

- [ ] **Step 2.2: Placeholder-Source-File anlegen**

`swift-packages/AtollCore/Sources/AtollCore/AtollCore.swift`:

```swift
// AtollCore — geteilte Foundation für die ATOLL App-Suite.
// Models, Auth, Supabase-Client, Locale-Handling.
//
// Konsumiert von: apps/atoll-ios, apps/atollcal-native (geplant), apps/atolllog-native (geplant).
```

- [ ] **Step 2.3: Placeholder-Test-File anlegen**

`swift-packages/AtollCore/Tests/AtollCoreTests/AtollCoreTests.swift`:

```swift
import XCTest
@testable import AtollCore

final class AtollCoreSmokeTests: XCTestCase {
  func test_packageImports() {
    // Wenn diese Test-Datei kompiliert + ausgeführt wird, kann die Library importiert werden.
    XCTAssertTrue(true)
  }
}
```

- [ ] **Step 2.4: `project.yml` der iOS-App aktualisieren**

In `apps/atoll-ios/project.yml` im `packages:`-Block oben den Local-Path-Verweis auf AtollCore hinzufügen:

**Alt:**
```yaml
packages:
  Supabase:
    url: https://github.com/supabase/supabase-swift
    from: 2.0.0
```

**Neu:**
```yaml
packages:
  Supabase:
    url: https://github.com/supabase/supabase-swift
    from: 2.0.0
  AtollCore:
    path: ../../swift-packages/AtollCore
```

Im `targets.ATOLL`-Block den Dependencies-Eintrag hinzufügen (falls nicht vorhanden, Block neu anlegen direkt unter `sources`):

**Vorher:**
```yaml
targets:
  ATOLL:
    type: application
    platform: iOS
    sources:
      - path: ATOLL
    resources:
      - path: ATOLL/Resources/Assets.xcassets
    info:
```

**Nachher:**
```yaml
targets:
  ATOLL:
    type: application
    platform: iOS
    sources:
      - path: ATOLL
    resources:
      - path: ATOLL/Resources/Assets.xcassets
    dependencies:
      - package: AtollCore
    info:
```

- [ ] **Step 2.5: `xcodegen generate` + Build**

```bash
cd /Users/dominik/Desktop/Developer/Dispo/apps/atoll-ios
xcodegen generate
xcodebuild -project ATOLL.xcodeproj -scheme ATOLL -destination 'generic/platform=iOS Simulator' -configuration Debug clean build 2>&1 | tail -20
```
Erwartet: `BUILD SUCCEEDED`. (Package wird leer geladen, App referenziert noch nichts daraus, also keine Funktionsänderung.)

- [ ] **Step 2.6: Commit (Controller)**

```bash
git add swift-packages/AtollCore/ apps/atoll-ios/project.yml
git commit -m "feat(foundation): AtollCore-Package-Skeleton + project.yml-Wiring"
```

---

## Task 3: Models nach `AtollCore` verschieben

**Files:**
- Move: `apps/atoll-ios/ATOLL/Models/*.swift` → `swift-packages/AtollCore/Sources/AtollCore/Models/`
- Modify: alle Files (Access-Level auf `public` heben)
- Modify: jede `import`-Stelle in `apps/atoll-ios/ATOLL/` die Models verwendet

Models-Liste (Stand vor Migration, alle in `apps/atoll-ios/ATOLL/Models/`):
`AppDate.swift`, `Assignment.swift`, `Course.swift`, `CourseParticipant.swift`, `CurrentUser.swift`, `IntakeChecklist.swift`, `Skill.swift`, `SkillDefinition.swift`, `SkillRecord.swift`, `Student.swift`.

- [ ] **Step 3.1: Models verschieben**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
mkdir -p swift-packages/AtollCore/Sources/AtollCore/Models
git mv apps/atoll-ios/ATOLL/Models/AppDate.swift swift-packages/AtollCore/Sources/AtollCore/Models/AppDate.swift
git mv apps/atoll-ios/ATOLL/Models/Assignment.swift swift-packages/AtollCore/Sources/AtollCore/Models/Assignment.swift
git mv apps/atoll-ios/ATOLL/Models/Course.swift swift-packages/AtollCore/Sources/AtollCore/Models/Course.swift
git mv apps/atoll-ios/ATOLL/Models/CourseParticipant.swift swift-packages/AtollCore/Sources/AtollCore/Models/CourseParticipant.swift
git mv apps/atoll-ios/ATOLL/Models/CurrentUser.swift swift-packages/AtollCore/Sources/AtollCore/Models/CurrentUser.swift
git mv apps/atoll-ios/ATOLL/Models/IntakeChecklist.swift swift-packages/AtollCore/Sources/AtollCore/Models/IntakeChecklist.swift
git mv apps/atoll-ios/ATOLL/Models/Skill.swift swift-packages/AtollCore/Sources/AtollCore/Models/Skill.swift
git mv apps/atoll-ios/ATOLL/Models/SkillDefinition.swift swift-packages/AtollCore/Sources/AtollCore/Models/SkillDefinition.swift
git mv apps/atoll-ios/ATOLL/Models/SkillRecord.swift swift-packages/AtollCore/Sources/AtollCore/Models/SkillRecord.swift
git mv apps/atoll-ios/ATOLL/Models/Student.swift swift-packages/AtollCore/Sources/AtollCore/Models/Student.swift

# Leeres Models/-Directory in der App entfernen
rmdir apps/atoll-ios/ATOLL/Models
```

- [ ] **Step 3.2: Access-Levels auf `public` heben**

In jeder verschobenen Models-Datei:
- Type-Deklarationen (`struct X`, `enum X`, `class X`, `final class X`) → `public struct X` etc.
- Properties (`let foo: String`) → `public let foo: String` (alle die von außerhalb gelesen werden)
- Initializer für Codable-Decode: keine Änderung nötig (Auto-Synth ist `public` für `public struct`)
- Memberwise-Init bei `public struct` muss explizit als `public init(...)` deklariert werden, falls die App Models manuell konstruiert (z.B. in Tests). Für Codable-only-Models (die nur aus Supabase-Decode kommen) optional.
- Computed Properties + Methoden → `public var` / `public func` falls extern verwendet
- Enum-Cases bleiben sichtbar wenn das Enum `public` ist — keine zusätzliche Markierung pro Case nötig

Beispiel `Course.swift` (vorher → nachher):

**Vorher:**
```swift
enum CourseStatus: String, Codable, CaseIterable, Hashable {
    case confirmed
    case tentative
    case cancelled
    case completed

    var label: String {
        switch self {
        case .confirmed: "Bestätigt"
        ...
        }
    }
}

struct CourseType: Codable, Hashable {
    let id: UUID?
    let code: String
    let label: String
}

struct Course: Codable, Identifiable, Hashable {
    ...
}
```

**Nachher:**
```swift
public enum CourseStatus: String, Codable, CaseIterable, Hashable {
    case confirmed
    case tentative
    case cancelled
    case completed

    public var label: String {
        switch self {
        case .confirmed: "Bestätigt"
        ...
        }
    }
}

public struct CourseType: Codable, Hashable {
    public let id: UUID?
    public let code: String
    public let label: String
}

public struct Course: Codable, Identifiable, Hashable {
    ...
}
```

Pro Datei einmal durchgehen, keine Ausnahmen — wenn ein Type nicht von außerhalb genutzt wird, kann er später wieder `internal` werden, aber für die Migration setzen wir alle Top-Level-Types und ihre exposed Properties auf `public`.

- [ ] **Step 3.3: Sources/AtollCore/AtollCore.swift erweitern**

Den Placeholder-Comment in `swift-packages/AtollCore/Sources/AtollCore/AtollCore.swift` aktualisieren:

```swift
// AtollCore — geteilte Foundation für die ATOLL App-Suite.
// Models, Auth, Supabase-Client, Locale-Handling.
//
// Konsumiert von: apps/atoll-ios, apps/atollcal-native (geplant), apps/atolllog-native (geplant).
//
// Module:
//   • Models/  — Course, Assignment, Student, Skill, etc.
//   • (Auth/   — kommt in Task 4)
//   • (Supabase/ — kommt in Task 4)
//   • (Locale/ — kommt in Task 4)
```

- [ ] **Step 3.4: App auf neue Imports umstellen**

In jeder Datei in `apps/atoll-ios/ATOLL/` die ein Model verwendet (Views, Services), oben `import AtollCore` hinzufügen — direkt nach den `import SwiftUI` / `import Foundation`-Zeilen.

Schnell-Check welche Files Models verwenden:

```bash
cd /Users/dominik/Desktop/Developer/Dispo/apps/atoll-ios/ATOLL
grep -rln "Course\|Assignment\|CourseParticipant\|Student\|Skill\|IntakeChecklist\|CurrentUser\|AppDate" --include="*.swift" Views/ Services/ Components/
```

Pro Treffer-Datei einmal `import AtollCore` an die Spitze setzen (nach existierenden Imports). Wenn die Datei selbst nichts anderes braucht außer Models, sind keine weiteren Änderungen nötig.

- [ ] **Step 3.5: `xcodegen generate` + Build**

```bash
cd /Users/dominik/Desktop/Developer/Dispo/apps/atoll-ios
xcodegen generate
xcodebuild -project ATOLL.xcodeproj -scheme ATOLL -destination 'generic/platform=iOS Simulator' -configuration Debug clean build 2>&1 | tail -30
```

Erwartet: `BUILD SUCCEEDED`. Bei Fehlern wie `cannot find type 'Course' in scope`: in der gemeldeten Datei `import AtollCore` ergänzen. Bei `'X' is inaccessible due to internal protection level`: in `swift-packages/AtollCore/Sources/AtollCore/Models/X.swift` das fehlende `public` ergänzen.

Iterieren bis grün.

- [ ] **Step 3.6: Commit (Controller)**

```bash
git add swift-packages/AtollCore/ apps/atoll-ios/
git commit -m "refactor(ios): Models nach AtollCore extrahiert (10 Files), Access-Level public"
```

---

## Task 4: Services (`AuthState`, `SupabaseClient+Shared`, `LocaleStore`) nach `AtollCore`

**Files:**
- Move: `apps/atoll-ios/ATOLL/Services/AuthState.swift` → `swift-packages/AtollCore/Sources/AtollCore/Auth/AuthState.swift`
- Move: `apps/atoll-ios/ATOLL/Services/SupabaseClient+Shared.swift` → `swift-packages/AtollCore/Sources/AtollCore/Supabase/SupabaseClientShared.swift`
- Move: `apps/atoll-ios/ATOLL/Services/LocaleStore.swift` → `swift-packages/AtollCore/Sources/AtollCore/Locale/LocaleStore.swift`
- Create: `swift-packages/AtollCore/Sources/AtollCore/Supabase/SupabaseConfig.swift` (NEU — Protocol für App-spezifische Config)
- Modify: `apps/atoll-ios/ATOLL/Config.swift` (App-eigene Config-Implementation)
- Modify: alle App-Files die `AuthState`/`SupabaseClient.shared`/`LocaleStore` verwenden

- [ ] **Step 4.1: Verzeichnisse anlegen + Files verschieben**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
mkdir -p swift-packages/AtollCore/Sources/AtollCore/Auth
mkdir -p swift-packages/AtollCore/Sources/AtollCore/Supabase
mkdir -p swift-packages/AtollCore/Sources/AtollCore/Locale

git mv apps/atoll-ios/ATOLL/Services/AuthState.swift swift-packages/AtollCore/Sources/AtollCore/Auth/AuthState.swift
git mv apps/atoll-ios/ATOLL/Services/SupabaseClient+Shared.swift swift-packages/AtollCore/Sources/AtollCore/Supabase/SupabaseClientShared.swift
git mv apps/atoll-ios/ATOLL/Services/LocaleStore.swift swift-packages/AtollCore/Sources/AtollCore/Locale/LocaleStore.swift
```

- [ ] **Step 4.2: SupabaseConfig-Protocol anlegen**

`swift-packages/AtollCore/Sources/AtollCore/Supabase/SupabaseConfig.swift`:

```swift
// SupabaseConfig — App-spezifische Supabase-URL + Anon-Key.
//
// Jede ATOLL-App (atoll-ios, atollcal-native, ...) liefert ihre eigene
// SupabaseConfig-Implementation, damit AtollCore.shared den richtigen
// Client bauen kann.

import Foundation

public protocol SupabaseConfig {
  var supabaseURL: URL { get }
  var supabaseAnonKey: String { get }
}

/// App muss vor erstem Zugriff auf SupabaseClient.shared ihre Config registrieren.
public enum AtollCoreConfig {
  nonisolated(unsafe) private static var _config: SupabaseConfig?

  public static func register(_ config: SupabaseConfig) {
    _config = config
  }

  internal static var current: SupabaseConfig {
    guard let c = _config else {
      preconditionFailure("AtollCoreConfig.register(...) must be called before accessing SupabaseClient.shared")
    }
    return c
  }
}
```

- [ ] **Step 4.3: `SupabaseClientShared.swift` umstellen**

`swift-packages/AtollCore/Sources/AtollCore/Supabase/SupabaseClientShared.swift` öffnen, kompletten Inhalt ersetzen mit:

```swift
import Foundation
import Supabase

extension SupabaseClient {
  /// App-weiter Singleton, initialisiert aus der registrierten AtollCoreConfig.
  ///
  /// `emitLocalSessionAsInitialSession: true` opt-in für das neue (korrekte)
  /// Verhalten — siehe https://github.com/supabase/supabase-swift/pull/822
  /// Damit verschwindet die Deprecation-Warning beim App-Start.
  public static let shared: SupabaseClient = {
    let config = AtollCoreConfig.current
    return SupabaseClient(
      supabaseURL: config.supabaseURL,
      supabaseKey: config.supabaseAnonKey,
      options: SupabaseClientOptions(
        auth: SupabaseClientOptions.AuthOptions(
          emitLocalSessionAsInitialSession: true
        )
      )
    )
  }()
}
```

- [ ] **Step 4.4: `AuthState.swift` Access-Level**

In `swift-packages/AtollCore/Sources/AtollCore/Auth/AuthState.swift`:
- `final class AuthState` → `public final class AuthState`
- `enum Status` (innerhalb von AuthState) → `public enum Status`
- `private(set) var status: Status` → `public private(set) var status: Status`
- `init()` → `public init()`
- Alle Methoden, die von der App aufgerufen werden (z.B. `handleAuthCallback(url:)`, `signOut()`) → `public func`
- `private` Methoden bleiben `private`

Hinweis: das `@MainActor`-Attribut bleibt — Swift Packages unterstützen das ohne Probleme bei Swift 5.9.

- [ ] **Step 4.5: `LocaleStore.swift` Access-Level**

In `swift-packages/AtollCore/Sources/AtollCore/Locale/LocaleStore.swift`:
- `final class LocaleStore` → `public final class LocaleStore`
- `init()` → `public init()`
- Alle gelesenen Properties + aufgerufenen Methoden → `public`

- [ ] **Step 4.6: App-eigene `Config.swift` als SupabaseConfig-Konformität deklarieren**

In `apps/atoll-ios/ATOLL/Config.swift` (heute ein `enum Config { static let supabaseURL ... }`):

**Alt (Ist-Stand):**
```swift
import Foundation

enum Config {
  static let supabaseURL = URL(string: "https://....supabase.co")!
  static let supabaseAnonKey = "..."
}
```

**Neu:**
```swift
import Foundation
import AtollCore

enum Config {
  static let supabaseURL = URL(string: "https://....supabase.co")!
  static let supabaseAnonKey = "..."
}

/// AtollCore-Konformität — verbindet Config mit dem geteilten Supabase-Client.
struct AppSupabaseConfig: SupabaseConfig {
  var supabaseURL: URL { Config.supabaseURL }
  var supabaseAnonKey: String { Config.supabaseAnonKey }
}
```

- [ ] **Step 4.7: `ATOLLApp.swift` — Config beim App-Start registrieren**

In `apps/atoll-ios/ATOLL/ATOLLApp.swift` ganz oben in `init()` von `ATOLLApp` (oder im `@main`-Setup):

**Alt (Ausschnitt):**
```swift
@main
struct ATOLLApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  @State private var auth = AuthState()
  @State private var localeStore = LocaleStore()

  var body: some Scene {
    ...
  }
}
```

**Neu:**
```swift
import AtollCore  // ← falls nicht schon da
...

@main
struct ATOLLApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  @State private var auth = AuthState()
  @State private var localeStore = LocaleStore()

  init() {
    // Muss VOR erstem Zugriff auf SupabaseClient.shared (in AuthState.init) passieren.
    AtollCoreConfig.register(AppSupabaseConfig())
  }

  var body: some Scene {
    ...
  }
}
```

**Wichtig:** Die Reihenfolge im struct-Init muss stimmen. SwiftUI initialisiert `@State`-Properties **vor** der eigenen `init()`. Wenn `AuthState.init()` bereits auf `SupabaseClient.shared` zugreift, ist das zu spät — die Config muss VOR `@State private var auth` registriert werden. Lösung: `auth` lazy machen oder Config in einer separaten static-Initialization registrieren.

Saubere Lösung — Config als computed static, registriert im Property-Default:

```swift
@main
struct ATOLLApp: App {
  // 1. Config-Registrierung als Side-Effect eines static-let, läuft VOR @State-Init
  private static let _configRegistered: Void = {
    AtollCoreConfig.register(AppSupabaseConfig())
  }()

  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  @State private var auth: AuthState

  init() {
    // Force-evaluate the static-let
    _ = Self._configRegistered
    // Jetzt ist Config registriert, AuthState kann initialisieren
    _auth = State(initialValue: AuthState())
  }
  ...
}
```

Wenn das zu fragil wirkt: Alternative — `AuthState.init()` nicht direkt `SupabaseClient.shared` aufrufen lassen, sondern den Client als Init-Parameter injizieren. Aber das wäre eine größere API-Änderung. Für jetzt nehmen wir den static-let-Ansatz.

- [ ] **Step 4.8: App-Files auf `import AtollCore` umstellen**

Alle Files in `apps/atoll-ios/ATOLL/` die `AuthState`, `LocaleStore`, oder `SupabaseClient.shared` (außer der Config selbst) verwenden, brauchen `import AtollCore` falls noch nicht da.

Schnell-Check:
```bash
cd /Users/dominik/Desktop/Developer/Dispo/apps/atoll-ios/ATOLL
grep -rln "AuthState\|LocaleStore\|SupabaseClient" --include="*.swift" .
```

Pro Treffer-Datei `import AtollCore` ergänzen.

- [ ] **Step 4.9: `xcodegen generate` + Build**

```bash
cd /Users/dominik/Desktop/Developer/Dispo/apps/atoll-ios
xcodegen generate
xcodebuild -project ATOLL.xcodeproj -scheme ATOLL -destination 'generic/platform=iOS Simulator' -configuration Debug clean build 2>&1 | tail -40
```

Erwartet: `BUILD SUCCEEDED`. Bei `cannot find 'X' in scope`: passenden `import AtollCore` ergänzen. Bei `'X' is inaccessible`: `public` in der Package-Datei ergänzen.

- [ ] **Step 4.10: Commit (Controller)**

```bash
git add swift-packages/AtollCore/ apps/atoll-ios/
git commit -m "refactor(ios): Auth + Supabase + Locale nach AtollCore (mit SupabaseConfig-Protocol)"
```

---

## Task 5: `AtollDesign`-Package — Theme + Components

**Files:**
- Create: `swift-packages/AtollDesign/Package.swift`
- Create: `swift-packages/AtollDesign/Sources/AtollDesign/AtollDesign.swift` (placeholder)
- Move: `apps/atoll-ios/ATOLL/Theme/BrandColors.swift` → `swift-packages/AtollDesign/Sources/AtollDesign/Theme/BrandColors.swift`
- Move: `apps/atoll-ios/ATOLL/Components/AtollLogo.swift` → `swift-packages/AtollDesign/Sources/AtollDesign/Components/AtollLogo.swift`
- Move: `apps/atoll-ios/ATOLL/Components/AvatarView.swift` → `swift-packages/AtollDesign/Sources/AtollDesign/Components/AvatarView.swift`
- Move: `apps/atoll-ios/ATOLL/Components/BrandHeader.swift` → `swift-packages/AtollDesign/Sources/AtollDesign/Components/BrandHeader.swift`
- Move: `apps/atoll-ios/ATOLL/Components/RoleBadge.swift` → `swift-packages/AtollDesign/Sources/AtollDesign/Components/RoleBadge.swift`
- Move: `apps/atoll-ios/ATOLL/Components/SkillChip.swift` → `swift-packages/AtollDesign/Sources/AtollDesign/Components/SkillChip.swift`
- Move: `apps/atoll-ios/ATOLL/Components/StatusChip.swift` → `swift-packages/AtollDesign/Sources/AtollDesign/Components/StatusChip.swift`
- Modify: alle App-Files die diese Components/BrandColors verwenden
- Modify: `apps/atoll-ios/project.yml`

Bleibt in der App (nicht in AtollDesign):
- `Components/StudentAvatar.swift` — ATOLL-Domain-spezifisch, bleibt App-lokal. Kann später raus, wenn AtollLog die gleiche Avatar-Variante braucht.

- [ ] **Step 5.1: Package.swift anlegen**

`swift-packages/AtollDesign/Package.swift`:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "AtollDesign",
  defaultLocalization: "de",
  platforms: [
    .iOS(.v17),
    .macOS(.v14),
  ],
  products: [
    .library(
      name: "AtollDesign",
      targets: ["AtollDesign"]
    ),
  ],
  dependencies: [],
  targets: [
    .target(
      name: "AtollDesign",
      dependencies: []
    ),
  ]
)
```

(Keine Tests in v0.1 — Visual-Components sind besser via Snapshot-Tests verifizierbar, was wir hier nicht aufsetzen.)

- [ ] **Step 5.2: Placeholder anlegen**

`swift-packages/AtollDesign/Sources/AtollDesign/AtollDesign.swift`:

```swift
// AtollDesign — geteilte Brand-Identity + UI-Components für die ATOLL App-Suite.
//
// Konsumiert von: apps/atoll-ios, apps/atollcal-native (geplant), apps/atolllog-native (geplant).
//
// Module:
//   • Theme/      — BrandColors, Typography (geplant), Spacing (geplant)
//   • Components/ — AvatarView, BrandHeader, RoleBadge, SkillChip, StatusChip, AtollLogo
```

- [ ] **Step 5.3: Theme-Verzeichnis anlegen + Files verschieben**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
mkdir -p swift-packages/AtollDesign/Sources/AtollDesign/Theme
mkdir -p swift-packages/AtollDesign/Sources/AtollDesign/Components

git mv apps/atoll-ios/ATOLL/Theme/BrandColors.swift swift-packages/AtollDesign/Sources/AtollDesign/Theme/BrandColors.swift

git mv apps/atoll-ios/ATOLL/Components/AtollLogo.swift swift-packages/AtollDesign/Sources/AtollDesign/Components/AtollLogo.swift
git mv apps/atoll-ios/ATOLL/Components/AvatarView.swift swift-packages/AtollDesign/Sources/AtollDesign/Components/AvatarView.swift
git mv apps/atoll-ios/ATOLL/Components/BrandHeader.swift swift-packages/AtollDesign/Sources/AtollDesign/Components/BrandHeader.swift
git mv apps/atoll-ios/ATOLL/Components/RoleBadge.swift swift-packages/AtollDesign/Sources/AtollDesign/Components/RoleBadge.swift
git mv apps/atoll-ios/ATOLL/Components/SkillChip.swift swift-packages/AtollDesign/Sources/AtollDesign/Components/SkillChip.swift
git mv apps/atoll-ios/ATOLL/Components/StatusChip.swift swift-packages/AtollDesign/Sources/AtollDesign/Components/StatusChip.swift

# Theme-Directory in App ist jetzt leer
rmdir apps/atoll-ios/ATOLL/Theme
```

- [ ] **Step 5.4: Access-Level auf `public` heben in den Components + Theme**

In jeder verschobenen Datei (analog zu Models in Task 3.2):
- Top-level Type-Deklarationen → `public struct/enum/class`
- Properties die von außen gelesen werden → `public let/var`
- `init(...)` → `public init(...)` (Memberwise muss explizit gemacht werden)
- `body: some View` → `public var body: some View`

Beispiel `AvatarView.swift`:

**Vorher:**
```swift
import SwiftUI

/// Runder Avatar mit Initialen, optional gefärbt.
struct AvatarView: View {
  let initials: String
  let color: String?

  var body: some View {
    ...
  }
}
```

**Nachher:**
```swift
import SwiftUI

/// Runder Avatar mit Initialen, optional gefärbt.
public struct AvatarView: View {
  public let initials: String
  public let color: String?

  public init(initials: String, color: String? = nil) {
    self.initials = initials
    self.color = color
  }

  public var body: some View {
    ...
  }
}
```

Für `BrandColors.swift`: alle `static let brandX = Color(hex: ...)` → `public static let brandX = Color(hex: ...)`. Die `Color(hex:)`-Init-Helper-Extension (falls in derselben Datei) auch `public` machen.

- [ ] **Step 5.5: project.yml — AtollDesign als Dependency**

In `apps/atoll-ios/project.yml`:

**`packages:`-Block erweitern:**
```yaml
packages:
  Supabase:
    url: https://github.com/supabase/supabase-swift
    from: 2.0.0
  AtollCore:
    path: ../../swift-packages/AtollCore
  AtollDesign:
    path: ../../swift-packages/AtollDesign
```

**`targets.ATOLL.dependencies` erweitern:**
```yaml
    dependencies:
      - package: AtollCore
      - package: AtollDesign
```

- [ ] **Step 5.6: App auf neue Imports umstellen**

Schnell-Check welche Files Components/BrandColors verwenden:

```bash
cd /Users/dominik/Desktop/Developer/Dispo/apps/atoll-ios/ATOLL
grep -rln "AvatarView\|BrandHeader\|RoleBadge\|SkillChip\|StatusChip\|AtollLogo\|brandBlue\|brandTeal\|brandAmber\|brandRed\|brandPurple\|brandPink\|brandDeep\|brandSand" --include="*.swift" .
```

Pro Treffer-Datei `import AtollDesign` ergänzen.

- [ ] **Step 5.7: `xcodegen generate` + Build**

```bash
cd /Users/dominik/Desktop/Developer/Dispo/apps/atoll-ios
xcodegen generate
xcodebuild -project ATOLL.xcodeproj -scheme ATOLL -destination 'generic/platform=iOS Simulator' -configuration Debug clean build 2>&1 | tail -30
```

Erwartet: `BUILD SUCCEEDED`. Iterieren bei `cannot find` / `inaccessible due to internal`.

- [ ] **Step 5.8: Commit (Controller)**

```bash
git add swift-packages/AtollDesign/ apps/atoll-ios/
git commit -m "refactor(ios): Theme + Components nach AtollDesign (7 Files: BrandColors + 6 Components)"
```

---

## Task 6: Smoke-Test der migrierten ATOLL-iOS-App

Diese Aufgabe schreibt keinen Code — sie verifiziert die Foundation gegen die Akzeptanzkriterien.

- [ ] **Step 6.1: Simulator-Smoke-Test**

User auf seinem Mac:

1. `cd /Users/dominik/Desktop/Developer/Dispo/apps/atoll-ios && xcodegen generate`
2. `open ATOLL.xcodeproj`
3. iPhone-Simulator wählen, ⌘B, ⌘R
4. App startet → Login-Screen erscheint → Email eintragen → Magic-Link erhalten → tappen → App öffnet sich, signed in
5. **Today-Screen:** zeigt heutige Einsätze (oder „keine Einsätze")
6. **Profile-Screen:** Name, Email, Logout-Button
7. **Students-Tab** (falls aktiviert): Liste lädt
8. **Skill-Check** auf einem Kurs: Matrix öffnet sich
9. Logout funktioniert, Login-Screen erscheint

- [ ] **Step 6.2: Vergleich gegen Production-App**

Wenn ein Tester ein TestFlight-Build der pre-Migration-Version installiert hat: parallel auf zwei Geräten dieselben Flows klicken. Erwartet: identisches Verhalten, identische Daten.

Falls kein TestFlight: Side-by-Side-Vergleich mit dem letzten Production-Commit per `git stash`-Tricks ist überkomplex — Smoke-Test alleine reicht für die Foundation-Validierung.

- [ ] **Step 6.3: Spec-Status aktualisieren**

In `docs/superpowers/specs/2026-05-14-atoll-suite-foundation-design.md`:

- Header-Status auf `Implementiert (YYYY-MM-DD mit heutigem Datum)` setzen
- Akzeptanzkriterien (Section 8) abhaken: alle `- [ ]` → `- [x]`

```bash
git add docs/superpowers/specs/2026-05-14-atoll-suite-foundation-design.md
git commit -m "docs(spec): Foundation — Status auf Implementiert + Akzeptanzkriterien abgehakt"
```

- [ ] **Step 6.4: README für `swift-packages/` anlegen**

`swift-packages/README.md`:

```markdown
# ATOLL Swift Packages

Geteilte Foundation-Module für die ATOLL App-Suite.

## Packages

- **AtollCore** — Auth, Supabase-Client, Models, Locale-Handling.
  Konsumiert von: `apps/atoll-ios`, AtollCal (geplant), AtollLog (geplant).
- **AtollDesign** — Brand-Tokens (Farben), wiederverwendbare SwiftUI-Components.
  Konsumiert von: dieselben Apps wie AtollCore.

## Hinzufügen zu einer neuen App

In `project.yml` der App:

```yaml
packages:
  AtollCore:
    path: ../../swift-packages/AtollCore
  AtollDesign:
    path: ../../swift-packages/AtollDesign

targets:
  YourApp:
    dependencies:
      - package: AtollCore
      - package: AtollDesign
```

Beim App-Start die Supabase-Config registrieren:

```swift
import AtollCore

@main
struct YourApp: App {
  private static let _configRegistered: Void = {
    AtollCoreConfig.register(YourAppSupabaseConfig())
  }()

  init() { _ = Self._configRegistered }
  ...
}
```
```

```bash
git add swift-packages/README.md
git commit -m "docs(packages): README für swift-packages/ mit Integration-Anleitung"
```

---

## Out of Scope für diesen Plan

- AtollCal-App (eigener Spec B + Plan, wird gegen diese Foundation gebaut)
- AtollLog-App (Future)
- Realtime-Subscription-Helper (`AtollRealtime`-Package — wenn erste App es braucht)
- Cross-App Single-Sign-On via App Group + Keychain Sharing (wenn 2+ Apps gleichzeitig installiert sind)
- Universal Links zwischen ATOLL-Apps
- macOS-Targets der existierenden Apps
- Snapshot-Tests für AtollDesign-Components
- Publishing der Packages auf Swift Package Index
- Branding-Refresh / neues Logo
