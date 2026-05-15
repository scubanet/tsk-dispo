# AtollCal v1 Phase 1 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Native iOS+macOS-Kalender-App `AtollCal` mit Tag/Woche/Monat-Views, EventKit-Integration für System-Kalender und ATOLL-Daten als overlaid Quelle. Read + Event-Erstellung in System-Kalendern, ATOLL ist read-only. Erste Auslieferung an User + Test-Team.

**Architecture:** Neuer Xcode-Target unter `apps/atollcal-native/` parallel zu `atoll-ios`. SwiftUI Multiplatform (iOS 17+ / macOS 14+) mit `#if`-Adaptionen. Konsumiert `AtollCore` (Auth, Models, Supabase) + `AtollDesign` (Brand, Components) als Local-Path-Swift-Packages. Custom SwiftUI Kalender-Views (kein UICalendarView, keine Drittanbieter-Library). `CalendarEvent`-Enum vereint EventKit-Events + ATOLL-Assignments für die Layout-Engine.

**Tech Stack:** Swift 5.9+ · SwiftUI Multiplatform · EventKit + EventKitUI · Supabase Swift SDK 2.x (via AtollCore) · XcodeGen für `.xcodeproj`-Generierung · iOS 17 / macOS 14 minimum.

**Quellspec:** `docs/superpowers/specs/2026-05-15-atollcal-v1-phase1-design.md`

**Wichtige Constraints:**
- Sandbox kann KEIN `xcodebuild` ausführen — Build-Verifikation immer beim User auf seinem Mac.
- Pro Task: User muss `xcodegen generate` + `xcodebuild` (oder ⌘B in Xcode) laufen lassen, danach commit durch Controller.
- AtollCore-Auth-Init-Pattern (Config-Registration vor `State(initialValue: AuthState())`) MUSS exakt befolgt werden — siehe Foundation-Hotfix `af83a1e`.
- Bundle-ID `swiss.atoll.cal` (NICHT `swiss.atoll.app` — das gehört zu atoll-ios).

**Milestones (innere Struktur):**
- **M1 — Scaffolding + Auth (Tasks 1–4):** App startet, Login funktioniert, leerer Kalender-Screen
- **M2 — Daten-Layer (Tasks 5–7):** SystemCalendarStore + AtollEventLoader liefern CalendarEvents
- **M3 — Kalender-Views (Tasks 8–14):** Day/Week/Month mit Custom SwiftUI
- **M4 — Detail + Settings + Polish (Tasks 15–19):** EventDetailSheet, SettingsView, Pull-Refresh, macOS-Adaption, Smoke

---

## Pre-Flight

- [ ] **Step P.1: Bundle-ID + URL-Scheme noch frei?**

User checkt im Apple Developer Portal:
- Bundle-ID `swiss.atoll.cal` ist nicht schon registriert (sonst Konflikt mit atoll-ios oder anderem)
- URL-Scheme `atollcal://` kollidiert nicht mit anderer App auf dem Test-Gerät

Falls registriert/konfliktbehaftet: alternativen Namen wählen, Spec entsprechend updaten BEVOR wir starten.

- [ ] **Step P.2: Working-Tree clean**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git status --short
```
Muss leer sein.

- [ ] **Step P.3: Foundation-Packages funktionieren in atoll-ios**

```bash
cd /Users/dominik/Desktop/Developer/Dispo/apps/atoll-ios
xcodegen generate
xcodebuild -project ATOLL.xcodeproj -scheme ATOLL \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build 2>&1 | tail -5
```
Erwartet: `BUILD SUCCEEDED` — bestätigt dass die Foundation-Packages funktionieren bevor wir die zweite App drauf aufsetzen.

---

## M1 — Scaffolding + Auth

### Task 1: Xcode-Target-Skeleton via XcodeGen

**Files:**
- Create: `apps/atollcal-native/project.yml`
- Create: `apps/atollcal-native/AtollCal/AtollCalApp.swift` (placeholder)
- Create: `apps/atollcal-native/AtollCal/Info.plist` (oder via project.yml inline)
- Create: `apps/atollcal-native/AtollCal/ATOLL.entitlements`
- Create: `apps/atollcal-native/AtollCal/Assets.xcassets/AppIcon.appiconset/Contents.json` (placeholder)
- Create: `apps/atollcal-native/AtollCal/Assets.xcassets/Contents.json`
- Create: `apps/atollcal-native/.gitignore`
- Create: `apps/atollcal-native/README.md`

- [ ] **Step 1.1: Verzeichnis-Skeleton anlegen**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
mkdir -p apps/atollcal-native/AtollCal/Assets.xcassets/AppIcon.appiconset
```

- [ ] **Step 1.2: project.yml schreiben**

`apps/atollcal-native/project.yml`:

```yaml
name: AtollCal
options:
  bundleIdPrefix: swiss.atoll
  deploymentTarget:
    iOS: "17.0"
    macOS: "14.0"
  developmentLanguage: de

settings:
  base:
    SWIFT_VERSION: "5.9"
    MARKETING_VERSION: "0.1.0"
    CURRENT_PROJECT_VERSION: "1"
    DEVELOPMENT_TEAM: ""
    SUPPORTS_MACCATALYST: NO
    SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD: NO

packages:
  AtollCore:
    path: ../../swift-packages/AtollCore
  AtollDesign:
    path: ../../swift-packages/AtollDesign

targets:
  AtollCal:
    type: application
    platform: [iOS, macOS]
    sources:
      - path: AtollCal
    resources:
      - path: AtollCal/Assets.xcassets
    dependencies:
      - package: AtollCore
      - package: AtollDesign
      - sdk: EventKit.framework
      - sdk: EventKitUI.framework
    info:
      path: AtollCal/Info.plist
      properties:
        CFBundleDisplayName: AtollCal
        CFBundleShortVersionString: $(MARKETING_VERSION)
        CFBundleVersion: $(CURRENT_PROJECT_VERSION)
        UILaunchScreen:
          UIColorName: AccentColor
        UISupportedInterfaceOrientations:
          - UIInterfaceOrientationPortrait
          - UIInterfaceOrientationLandscapeLeft
          - UIInterfaceOrientationLandscapeRight
        ITSAppUsesNonExemptEncryption: false
        NSCalendarsFullAccessUsageDescription: "AtollCal zeigt deine Termine aus iCloud, Google und anderen Kalendern an."
        CFBundleURLTypes:
          - CFBundleURLName: swiss.atoll.cal
            CFBundleURLSchemes:
              - atollcal
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: swiss.atoll.cal
        INFOPLIST_KEY_NSCalendarsFullAccessUsageDescription: "AtollCal zeigt deine Termine aus iCloud, Google und anderen Kalendern an."
```

- [ ] **Step 1.3: AtollCalApp.swift Placeholder**

`apps/atollcal-native/AtollCal/AtollCalApp.swift`:

```swift
import SwiftUI

@main
struct AtollCalApp: App {
  var body: some Scene {
    WindowGroup {
      Text("AtollCal — wird in Task 2 implementiert")
        .padding()
    }
  }
}
```

- [ ] **Step 1.4: ATOLL.entitlements**

`apps/atollcal-native/AtollCal/ATOLL.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.app-sandbox</key>
  <true/>
  <key>com.apple.security.network.client</key>
  <true/>
  <key>com.apple.security.personal-information.calendars</key>
  <true/>
</dict>
</plist>
```

- [ ] **Step 1.5: Assets-Catalog-Placeholder**

`apps/atollcal-native/AtollCal/Assets.xcassets/Contents.json`:

```json
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

`apps/atollcal-native/AtollCal/Assets.xcassets/AppIcon.appiconset/Contents.json`:

```json
{
  "images" : [
    {
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

(Echtes App-Icon kommt in Task 19 oder als Side-Quest.)

- [ ] **Step 1.6: .gitignore + README**

`apps/atollcal-native/.gitignore`:

```
*.xcodeproj
.swiftpm/
.DS_Store
xcuserdata/
```

`apps/atollcal-native/README.md`:

```markdown
# AtollCal — Native iOS+macOS Kalender

Native SwiftUI-App, baut auf den ATOLL-Foundation-Packages (`AtollCore`, `AtollDesign`) auf.
Bundle-ID: `swiss.atoll.cal`. URL-Scheme: `atollcal://`.

## Setup

```bash
cd apps/atollcal-native
xcodegen generate
open AtollCal.xcodeproj
```

`AtollCal.xcodeproj` ist gitignored — wird aus `project.yml` regeneriert.

## Konfiguration

`AtollCal/Config.swift` (nach Task 2) enthält Supabase-URL + Anon-Key. Nicht commiten falls Production-Secrets.
```

- [ ] **Step 1.7: Build verifizieren (User)**

```bash
cd /Users/dominik/Desktop/Developer/Dispo/apps/atollcal-native
xcodegen generate
xcodebuild -project AtollCal.xcodeproj -scheme AtollCal \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build 2>&1 | tail -10
```
Erwartet: `BUILD SUCCEEDED` (mit Placeholder-Text-View).

- [ ] **Step 1.8: Commit (Controller)**

```bash
git add apps/atollcal-native/
git commit -m "feat(atollcal): Xcode-Target-Skeleton via XcodeGen mit AtollCore + AtollDesign Dependencies"
```

---

### Task 2: Auth + Config — App startet mit Sign-In

**Files:**
- Create: `apps/atollcal-native/AtollCal/Config.swift`
- Replace: `apps/atollcal-native/AtollCal/AtollCalApp.swift`
- Create: `apps/atollcal-native/AtollCal/Views/RootView.swift`
- Create: `apps/atollcal-native/AtollCal/Views/SignInView.swift`

- [ ] **Step 2.1: Config.swift mit Supabase-Secrets**

`apps/atollcal-native/AtollCal/Config.swift`:

```swift
import Foundation
import AtollCore

enum Config {
  // Production-Werte — gleicher Supabase-Projekt wie atoll-ios + Web
  static let supabaseURL     = URL(string: "https://axnrilhdokkfujzjifhj.supabase.co")!
  static let supabaseAnonKey = "<COPY-FROM-atoll-ios/ATOLL/Config.swift>"
  static let authRedirectURL = URL(string: "atollcal://auth/callback")!
  static let appName         = "AtollCal"
  static let tenantName      = "TSK Zürich"
}

/// AtollCore-Konformität — verbindet Config mit dem geteilten Supabase-Client.
struct AppSupabaseConfig: SupabaseConfig {
  var supabaseURL: URL        { Config.supabaseURL }
  var supabaseAnonKey: String { Config.supabaseAnonKey }
  var authRedirectURL: URL    { Config.authRedirectURL }
}
```

User trägt den Anon-Key aus `apps/atoll-ios/ATOLL/Config.swift` ein (Spalte `supabaseAnonKey`).

- [ ] **Step 2.2: AtollCalApp.swift komplett ersetzen**

```swift
import SwiftUI
import AtollCore

@main
struct AtollCalApp: App {
  @State private var auth: AuthState
  @State private var localeStore: LocaleStore

  init() {
    // MUSS vor State(initialValue: AuthState()) — AuthState.init() greift sofort
    // auf SupabaseClient.shared zu, der die registrierte Config braucht.
    AtollCoreConfig.register(AppSupabaseConfig())
    _auth = State(initialValue: AuthState())
    _localeStore = State(initialValue: LocaleStore())
  }

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(auth)
        .environment(localeStore)
        .environment(\.locale, localeStore.locale)
        .onOpenURL { url in
          guard url.scheme == "atollcal" else { return }
          Task { try? await auth.handleAuthCallback(url: url) }
        }
        .preferredColorScheme(nil)
    }
  }
}
```

- [ ] **Step 2.3: RootView.swift**

```swift
import SwiftUI
import AtollCore

struct RootView: View {
  @Environment(AuthState.self) var auth

  var body: some View {
    switch auth.status {
    case .loading:
      ProgressView()
    case .signedOut:
      SignInView()
    case .signedIn:
      // Kommt in Task 3 — vorerst Placeholder
      Text("Logged in — CalendarRoot kommt in Task 3")
        .padding()
    }
  }
}
```

- [ ] **Step 2.4: SignInView.swift**

`apps/atollcal-native/AtollCal/Views/SignInView.swift`:

```swift
import SwiftUI
import AtollCore
import AtollDesign

struct SignInView: View {
  @Environment(AuthState.self) var auth
  @State private var email: String = ""
  @State private var sendStatus: SendStatus = .idle

  enum SendStatus: Equatable {
    case idle
    case sending
    case sent
    case error(String)
  }

  var body: some View {
    VStack(spacing: 24) {
      Spacer()

      // Brand-Header aus AtollDesign
      BrandHeader(appName: Config.appName, tenantName: Config.tenantName)

      VStack(spacing: 12) {
        TextField("Email-Adresse", text: $email)
          .textFieldStyle(.roundedBorder)
          .keyboardType(.emailAddress)
          .textContentType(.emailAddress)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .padding(.horizontal)

        Button(action: sendLink) {
          Text(sendStatus == .sending ? "Sende..." : "Magic-Link senden")
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .disabled(email.isEmpty || sendStatus == .sending)
        .padding(.horizontal)

        switch sendStatus {
        case .sent:
          Text("Link gesendet — bitte Mail-App öffnen")
            .foregroundColor(.secondary)
            .font(.caption)
        case .error(let msg):
          Text(msg).foregroundColor(.red).font(.caption)
        default:
          EmptyView()
        }
      }

      Spacer()
    }
    .padding()
  }

  private func sendLink() {
    sendStatus = .sending
    Task {
      do {
        try await auth.sendMagicLink(to: email)
        await MainActor.run { sendStatus = .sent }
      } catch {
        await MainActor.run { sendStatus = .error(error.localizedDescription) }
      }
    }
  }
}
```

- [ ] **Step 2.5: Build + manueller Login-Smoke-Test (User)**

```bash
cd /Users/dominik/Desktop/Developer/Dispo/apps/atollcal-native
xcodegen generate
open AtollCal.xcodeproj
```

In Xcode: iPhone-Simulator wählen, ⌘R. Erwartet:
1. App startet ohne Crash → SignInView
2. Email eingeben → „Magic-Link senden" → „Link gesendet" erscheint
3. Mail-App öffnen, Magic-Link tippen → System fragt nach „In AtollCal öffnen?" → bestätigen
4. AtollCal öffnet wieder → State wechselt auf `.signedIn` → Placeholder „Logged in — CalendarRoot kommt in Task 3" erscheint

- [ ] **Step 2.6: Commit (Controller)**

```bash
git add apps/atollcal-native/
git commit -m "feat(atollcal): Auth + Config — App startet mit SignInView, Magic-Link via atollcal:// funktioniert"
```

---

### Task 3: CalendarRoot Skeleton + View-Switcher

**Files:**
- Create: `apps/atollcal-native/AtollCal/Models/CalendarViewKind.swift`
- Create: `apps/atollcal-native/AtollCal/Views/CalendarRoot.swift`
- Create: `apps/atollcal-native/AtollCal/Views/DayView.swift` (Placeholder)
- Create: `apps/atollcal-native/AtollCal/Views/WeekView.swift` (Placeholder)
- Create: `apps/atollcal-native/AtollCal/Views/MonthView.swift` (Placeholder)
- Modify: `apps/atollcal-native/AtollCal/Views/RootView.swift` (auf CalendarRoot routen)

- [ ] **Step 3.1: CalendarViewKind enum**

`Models/CalendarViewKind.swift`:

```swift
import Foundation

enum CalendarViewKind: String, CaseIterable, Identifiable {
  case day, week, month

  var id: String { rawValue }

  var label: String {
    switch self {
    case .day:   "Tag"
    case .week:  "Woche"
    case .month: "Monat"
    }
  }

  var systemImage: String {
    switch self {
    case .day:   "calendar.day.timeline.left"
    case .week:  "calendar"
    case .month: "calendar"
    }
  }
}
```

- [ ] **Step 3.2: CalendarRoot.swift mit Plattform-Adaption**

```swift
import SwiftUI
import AtollCore

struct CalendarRoot: View {
  @State private var selectedView: CalendarViewKind = .week
  @State private var focusedDate: Date = Date()

  var body: some View {
    #if os(iOS)
    NavigationStack {
      content
        .navigationTitle(formattedTitle)
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            Button("Heute") { focusedDate = Date() }
          }
          ToolbarItem(placement: .topBarTrailing) {
            Picker("Ansicht", selection: $selectedView) {
              ForEach(CalendarViewKind.allCases) { kind in
                Text(kind.label).tag(kind)
              }
            }
            .pickerStyle(.segmented)
          }
        }
    }
    #else
    NavigationSplitView {
      List(CalendarViewKind.allCases, selection: $selectedView) { kind in
        Label(kind.label, systemImage: kind.systemImage).tag(kind)
      }
      .navigationTitle("AtollCal")
    } detail: {
      content
        .navigationTitle(formattedTitle)
        .toolbar {
          ToolbarItem {
            Button("Heute") { focusedDate = Date() }
          }
        }
    }
    #endif
  }

  @ViewBuilder
  private var content: some View {
    switch selectedView {
    case .day:   DayView(date: $focusedDate)
    case .week:  WeekView(anchor: $focusedDate)
    case .month: MonthView(anchor: $focusedDate)
    }
  }

  private var formattedTitle: String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "de_CH")
    switch selectedView {
    case .day:
      formatter.dateFormat = "EEEE, d. MMMM yyyy"
      return formatter.string(from: focusedDate)
    case .week:
      formatter.dateFormat = "'KW' w yyyy"
      return formatter.string(from: focusedDate)
    case .month:
      formatter.dateFormat = "MMMM yyyy"
      return formatter.string(from: focusedDate)
    }
  }
}
```

- [ ] **Step 3.3: Placeholder-Views (kommen in M3 voll)**

`Views/DayView.swift`:
```swift
import SwiftUI

struct DayView: View {
  @Binding var date: Date
  var body: some View {
    VStack {
      Text("DayView — Implementation in Task 8–9")
      Text(date, style: .date).font(.caption).foregroundColor(.secondary)
    }
  }
}
```

`Views/WeekView.swift`:
```swift
import SwiftUI

struct WeekView: View {
  @Binding var anchor: Date
  var body: some View {
    VStack {
      Text("WeekView — Implementation in Task 10–11")
      Text(anchor, style: .date).font(.caption).foregroundColor(.secondary)
    }
  }
}
```

`Views/MonthView.swift`:
```swift
import SwiftUI

struct MonthView: View {
  @Binding var anchor: Date
  var body: some View {
    VStack {
      Text("MonthView — Implementation in Task 12–13")
      Text(anchor, style: .date).font(.caption).foregroundColor(.secondary)
    }
  }
}
```

- [ ] **Step 3.4: RootView auf CalendarRoot routen**

In `Views/RootView.swift` den `Text("Logged in...")`-Placeholder ersetzen mit `CalendarRoot()`.

- [ ] **Step 3.5: Build + Smoke (User)**

```bash
cd /Users/dominik/Desktop/Developer/Dispo/apps/atollcal-native
xcodegen generate
xcodebuild -project AtollCal.xcodeproj -scheme AtollCal \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build 2>&1 | grep -E "error:" | head -10
```
Erwartet: keine Errors. ⌘R im Xcode → nach Login: View-Switcher Tag/Woche/Monat oben rechts, „Heute"-Button oben links, Title je nach View formatiert.

- [ ] **Step 3.6: Commit (Controller)**

```bash
git add apps/atollcal-native/
git commit -m "feat(atollcal): CalendarRoot mit Tag/Woche/Monat-Switcher + Heute-Button (iOS+macOS-Adaption)"
```

---

### Task 4: EventKit-Permission-Request

**Files:**
- Create: `apps/atollcal-native/AtollCal/Services/SystemCalendarStore.swift`
- Modify: `apps/atollcal-native/AtollCal/AtollCalApp.swift` (Store als Environment hinzufügen)
- Modify: `apps/atollcal-native/AtollCal/Views/CalendarRoot.swift` (Permission-Banner)

- [ ] **Step 4.1: SystemCalendarStore Skeleton (nur Permission, Events kommen in Task 5)**

`Services/SystemCalendarStore.swift`:

```swift
import Foundation
import EventKit
import Observation

@MainActor
@Observable
public final class SystemCalendarStore {
  private let store = EKEventStore()

  private(set) var authorizationStatus: EKAuthorizationStatus = .notDetermined
  private(set) var calendars: [EKCalendar] = []

  public init() {
    refreshAuthStatus()
  }

  func refreshAuthStatus() {
    authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    if authorizationStatus == .fullAccess {
      calendars = store.calendars(for: .event)
    }
  }

  func requestAccess() async {
    do {
      try await store.requestFullAccessToEvents()
    } catch {
      // status auf denied gesetzt vom System
    }
    refreshAuthStatus()
  }
}
```

- [ ] **Step 4.2: Store als Environment-Object in AtollCalApp**

In `AtollCalApp.swift` ergänzen:

```swift
@State private var auth: AuthState
@State private var localeStore: LocaleStore
@State private var calendarStore: SystemCalendarStore  // NEU

init() {
  AtollCoreConfig.register(AppSupabaseConfig())
  _auth = State(initialValue: AuthState())
  _localeStore = State(initialValue: LocaleStore())
  _calendarStore = State(initialValue: SystemCalendarStore())  // NEU
}
```

Im `WindowGroup`-Body ergänzen:
```swift
.environment(calendarStore)  // NEU, neben den anderen .environment-Aufrufen
```

- [ ] **Step 4.3: Permission-Banner in CalendarRoot**

In `CalendarRoot.swift` oberhalb von `content` einen Banner einbauen:

```swift
@Environment(SystemCalendarStore.self) var calendarStore

// Im body, wrap content in VStack:
VStack(spacing: 0) {
  if calendarStore.authorizationStatus != .fullAccess {
    PermissionBanner(store: calendarStore)
  }
  content
}
```

Plus eine kleine Sub-View `PermissionBanner` am Ende der Datei:

```swift
private struct PermissionBanner: View {
  let store: SystemCalendarStore

  var body: some View {
    VStack(spacing: 8) {
      Text("Kalender-Zugriff erforderlich")
        .font(.headline)
      Text("AtollCal braucht Zugriff auf deine System-Kalender (iCloud, Google etc.).")
        .font(.caption)
        .multilineTextAlignment(.center)
      Button("Zugriff erlauben") {
        Task { await store.requestAccess() }
      }
      .buttonStyle(.borderedProminent)
    }
    .padding()
    .frame(maxWidth: .infinity)
    .background(Color.yellow.opacity(0.15))
  }
}
```

- [ ] **Step 4.4: Build + Permission-Test (User)**

```bash
xcodegen generate && open AtollCal.xcodeproj
```
⌘R. Erwartet: Permission-Banner erscheint oben → „Zugriff erlauben" → System-Dialog → bestätigen → Banner verschwindet.

- [ ] **Step 4.5: Commit (Controller)**

```bash
git add apps/atollcal-native/
git commit -m "feat(atollcal): SystemCalendarStore + EventKit-Permission-Request mit Banner-UI"
```

**Milestone M1 erreicht:** App startet, Login funktioniert, Kalender-Permission ist erteilt, View-Switcher zeigt 3 Placeholder-Views.

---

## M2 — Daten-Layer

### Task 5: SystemCalendarStore — Events laden

**Files:**
- Modify: `apps/atollcal-native/AtollCal/Services/SystemCalendarStore.swift`

- [ ] **Step 5.1: events(in:calendarIds:) Methode**

In `SystemCalendarStore` ergänzen:

```swift
/// Liefert alle EKEvents im Range, gefiltert nach den angegebenen Calendar-Ids.
/// Wenn calendarIds leer ist: ALLE Events aus erlaubten Kalendern.
func events(in range: DateInterval, calendarIds: Set<String>? = nil) -> [EKEvent] {
  guard authorizationStatus == .fullAccess else { return [] }
  let cals: [EKCalendar]
  if let ids = calendarIds, !ids.isEmpty {
    cals = calendars.filter { ids.contains($0.calendarIdentifier) }
  } else {
    cals = calendars
  }
  guard !cals.isEmpty else { return [] }
  let pred = store.predicateForEvents(withStart: range.start, end: range.end, calendars: cals)
  return store.events(matching: pred)
}

/// Subscribe für externe EKEvent-Änderungen — z.B. wenn iCloud syncted.
func observeChanges(handler: @escaping () -> Void) -> NSObjectProtocol {
  NotificationCenter.default.addObserver(
    forName: .EKEventStoreChanged,
    object: store,
    queue: .main,
    using: { _ in handler() }
  )
}
```

- [ ] **Step 5.2: Build (User)**

```bash
xcodegen generate && xcodebuild ... | grep error: | head -5
```
Erwartet: keine Errors. (Funktion ist noch nicht aufgerufen — Build-Check reicht.)

- [ ] **Step 5.3: Commit (Controller)**

```bash
git add apps/atollcal-native/AtollCal/Services/SystemCalendarStore.swift
git commit -m "feat(atollcal): SystemCalendarStore — events(in:calendarIds:) + EKEventStoreChanged-Observer"
```

---

### Task 6: AtollEventLoader — Supabase-Query für Assignments

**Files:**
- Create: `apps/atollcal-native/AtollCal/Services/AtollEventLoader.swift`
- Modify: `apps/atollcal-native/AtollCal/AtollCalApp.swift` (Loader als Environment)

- [ ] **Step 6.1: AtollEventLoader Service**

`Services/AtollEventLoader.swift`:

```swift
import Foundation
import AtollCore
import Supabase
import Observation

@MainActor
@Observable
public final class AtollEventLoader {
  private(set) var assignments: [Assignment] = []
  private(set) var coursesById: [UUID: Course] = [:]
  private(set) var courseDatesByCourseId: [UUID: [CourseDate]] = [:]
  private(set) var lastError: Error?
  private(set) var loading: Bool = false

  private let supabase = SupabaseClient.shared

  public init() {}

  /// Lädt alle Assignments + Courses + Course-Dates für den Instructor im Date-Range.
  func reload(for instructorId: UUID, range: DateInterval) async {
    loading = true
    lastError = nil
    do {
      // 1. Assignments für den Instructor im Range — JOIN auf courses.start_date für Filter.
      // PostgREST-Embed nutzt course_assignments.course_id → courses(id).
      struct AssignmentJoinRow: Decodable {
        let id: UUID
        let role: String
        let confirmed: Bool
        let assigned_for_dates: [String]
        let courses: CourseInner
        struct CourseInner: Decodable {
          let id: UUID
          let title: String
          let status: String
          let start_date: String
          let additional_dates: [String]
          let location: String?
        }
      }

      let startStr = ISO8601DateFormatter.dateOnly.string(from: range.start)
      let endStr   = ISO8601DateFormatter.dateOnly.string(from: range.end)

      let resp: [AssignmentJoinRow] = try await supabase
        .from("course_assignments")
        .select("""
          id, role, confirmed, assigned_for_dates,
          courses!inner(id, title, status, start_date, additional_dates, location)
        """)
        .eq("instructor_id", value: instructorId)
        .gte("courses.start_date", value: startStr)
        .lte("courses.start_date", value: endStr)
        .neq("courses.status", value: "cancelled")
        .execute()
        .value

      // 2. Map zu Assignment + Course (model-Konvertierung)
      var assignmentsBuf: [Assignment] = []
      var coursesBuf: [UUID: Course] = [:]
      for row in resp {
        // Assignment-Mapping (Felder müssen mit AtollCore.Assignment matchen — ggf. anpassen)
        let assignment = Assignment(
          id: row.id,
          role: AssignmentRole(rawValue: row.role) ?? .co,
          confirmed: row.confirmed,
          assignedForDates: row.assigned_for_dates.compactMap(AppDate.parseISODate)
        )
        assignmentsBuf.append(assignment)

        // Course-Mapping
        if coursesBuf[row.courses.id] == nil {
          // Course-Konvertierung — Felder je nach AtollCore.Course-Definition anpassen.
          // Falls Course init-Signatur abweicht, hier inline mappen.
          let courseStartDate = AppDate.parseISODate(row.courses.start_date) ?? Date()
          let course = Course(
            id: row.courses.id,
            title: row.courses.title,
            status: CourseStatus(rawValue: row.courses.status) ?? .tentative,
            startDate: courseStartDate,
            additionalDates: row.courses.additional_dates.compactMap(AppDate.parseISODate),
            location: row.courses.location
          )
          coursesBuf[row.courses.id] = course
        }
      }

      // 3. course_dates für Zeitslots laden
      let courseIds = Array(coursesBuf.keys)
      var courseDatesBuf: [UUID: [CourseDate]] = [:]
      if !courseIds.isEmpty {
        struct CourseDateRow: Decodable {
          let course_id: UUID
          let date: String
          let time_from: String?
          let time_to: String?
        }
        let dateRows: [CourseDateRow] = try await supabase
          .from("course_dates")
          .select("course_id, date, time_from, time_to")
          .in("course_id", values: courseIds)
          .execute()
          .value
        for cd in dateRows {
          let courseDate = CourseDate(
            courseId: cd.course_id,
            date: AppDate.parseISODate(cd.date) ?? Date(),
            timeFrom: cd.time_from,
            timeTo: cd.time_to
          )
          courseDatesBuf[cd.course_id, default: []].append(courseDate)
        }
      }

      // 4. State publishen
      assignments = assignmentsBuf
      coursesById = coursesBuf
      courseDatesByCourseId = courseDatesBuf
    } catch {
      lastError = error
      print("[AtollEventLoader] reload failed: \(error)")
    }
    loading = false
  }
}

// Helper für ISO-Date-Formatting (YYYY-MM-DD)
extension ISO8601DateFormatter {
  static let dateOnly: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.timeZone = TimeZone(identifier: "Europe/Zurich")
    return f
  }()
}
```

**Wichtig:** Die `Course` und `Assignment` Konstruktor-Signaturen + `CourseDate`-Definition müssen mit `AtollCore`'s Models matchen. Wenn der Subagent beim Build merkt dass z.B. `CourseDate` in AtollCore nicht existiert: dann muss er das Model in AtollCore ergänzen. Je nach Foundation-Stand kann das nötig sein — vor Implementierung des Loaders kurz prüfen.

- [ ] **Step 6.2: Loader als Environment in AtollCalApp**

In `AtollCalApp.swift`:

```swift
@State private var atollLoader: AtollEventLoader

init() {
  AtollCoreConfig.register(AppSupabaseConfig())
  _auth = State(initialValue: AuthState())
  _localeStore = State(initialValue: LocaleStore())
  _calendarStore = State(initialValue: SystemCalendarStore())
  _atollLoader = State(initialValue: AtollEventLoader())
}
```

Im body:
```swift
.environment(atollLoader)
```

- [ ] **Step 6.3: Build (User)**

Erwartet: keine Errors. Falls `Course`-Init-Signatur nicht passt, Fehler weiterleiten an Subagent (oder Controller patcht inline).

- [ ] **Step 6.4: Commit (Controller)**

```bash
git add apps/atollcal-native/
git commit -m "feat(atollcal): AtollEventLoader — Assignments + Courses + CourseDates via Supabase im Date-Range"
```

---

### Task 7: CalendarEvent Unified Abstraction

**Files:**
- Create: `apps/atollcal-native/AtollCal/Models/CalendarEvent.swift`

- [ ] **Step 7.1: CalendarEvent enum**

`Models/CalendarEvent.swift`:

```swift
import Foundation
import EventKit
import SwiftUI
import AtollCore

/// Unifizierte Repräsentation für Calendar-Events aus System (EventKit) + ATOLL.
/// Wird von Calendar-Views konsumiert ohne Wissen über die Quelle.
enum CalendarEvent: Identifiable, Hashable {
  case system(EKEvent)
  case atoll(assignment: Assignment, course: Course, dates: [CourseDate])

  var id: String {
    switch self {
    case .system(let e):
      return "ek-\(e.eventIdentifier ?? "unknown-\(e.startDate.timeIntervalSince1970)")"
    case .atoll(let a, _, _):
      return "atoll-\(a.id)"
    }
  }

  var title: String {
    switch self {
    case .system(let e): return e.title ?? ""
    case .atoll(let a, let c, _):
      return "\(c.title) (\(a.role.rawValue))"
    }
  }

  /// Start-Date als Datum (ohne Zeit-Component, falls all-day; sonst mit Zeit).
  var startDate: Date {
    switch self {
    case .system(let e): return e.startDate
    case .atoll(_, let c, let dates):
      // Wenn Zeitslot in dates definiert: kombiniere mit Datum. Sonst: course.startDate.
      if let firstWithTime = dates.first(where: { $0.timeFrom != nil }) {
        return Self.combineDateTime(date: firstWithTime.date, time: firstWithTime.timeFrom)
      }
      return c.startDate
    }
  }

  var endDate: Date {
    switch self {
    case .system(let e): return e.endDate
    case .atoll(_, let c, let dates):
      if let firstWithTime = dates.first(where: { $0.timeTo != nil }) {
        return Self.combineDateTime(date: firstWithTime.date, time: firstWithTime.timeTo)
      }
      // Bei all-day: end = start + 1 Tag
      return Calendar.current.date(byAdding: .day, value: 1, to: c.startDate) ?? c.startDate
    }
  }

  var isAllDay: Bool {
    switch self {
    case .system(let e): return e.isAllDay
    case .atoll(_, _, let dates):
      return !dates.contains(where: { $0.timeFrom != nil })
    }
  }

  var location: String? {
    switch self {
    case .system(let e): return e.location
    case .atoll(_, let c, _): return c.location
    }
  }

  /// Color für Event-Bar. Brand-Color für ATOLL, Calendar-Color für System.
  var color: Color {
    switch self {
    case .system(let e):
      if let cgColor = e.calendar?.cgColor {
        return Color(cgColor: cgColor)
      }
      return .gray
    case .atoll:
      return .brandBlue  // aus AtollDesign
    }
  }

  var isATOLL: Bool {
    if case .atoll = self { return true }
    return false
  }

  // MARK: - Helper

  private static func combineDateTime(date: Date, time: String?) -> Date {
    guard let time = time else { return date }
    let parts = time.split(separator: ":").compactMap { Int($0) }
    guard parts.count >= 2 else { return date }
    var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
    components.hour = parts[0]
    components.minute = parts[1]
    components.second = parts.count > 2 ? parts[2] : 0
    return Calendar.current.date(from: components) ?? date
  }

  // MARK: - Hashable
  func hash(into hasher: inout Hasher) { hasher.combine(id) }
  static func == (lhs: CalendarEvent, rhs: CalendarEvent) -> Bool { lhs.id == rhs.id }
}
```

**Hinweis:** `Color.brandBlue` kommt aus `AtollDesign` (Foundation). Wenn der Foundation-Stand Blue nicht als `Color` (sondern via Hex-Helper) anbietet, hier inline `Color(hex: 0x185FA5)` notieren oder Helper aus AtollDesign nutzen.

- [ ] **Step 7.2: Build + minimaler Konsum-Test (User)**

Build muss durch sein. Echte Verwendung kommt in M3.

- [ ] **Step 7.3: Commit (Controller)**

```bash
git add apps/atollcal-native/AtollCal/Models/CalendarEvent.swift
git commit -m "feat(atollcal): CalendarEvent unified abstraction (system EKEvent + atoll Assignment)"
```

**Milestone M2 erreicht:** Daten-Quellen funktionieren — sowohl EventKit als auch ATOLL liefern Events, die in `CalendarEvent` einheitlich repräsentiert sind.

---

## M3 — Kalender-Views

### Task 8: TimeAxisGrid Component (Day/Week shared)

**Files:**
- Create: `apps/atollcal-native/AtollCal/Views/Components/TimeAxisGrid.swift`
- Create: `apps/atollcal-native/AtollCal/Views/Components/NowIndicator.swift`

- [ ] **Step 8.1: TimeAxisGrid**

`Views/Components/TimeAxisGrid.swift`:

```swift
import SwiftUI

/// Vertikale 24-Stunden-Achse mit Stunden-Labels links und horizontalen Grid-Linien.
/// Kinder werden als overlay auf das Grid gelegt — der Caller positioniert Events
/// per absolute coordinates (y = hour * hourHeight).
struct TimeAxisGrid<Content: View>: View {
  let hourHeight: CGFloat
  @ViewBuilder let content: () -> Content

  init(hourHeight: CGFloat = 60, @ViewBuilder content: @escaping () -> Content) {
    self.hourHeight = hourHeight
    self.content = content
  }

  private let hourLabelWidth: CGFloat = 50

  var body: some View {
    ScrollView {
      ZStack(alignment: .topLeading) {
        // Hour labels + grid lines
        VStack(spacing: 0) {
          ForEach(0..<24, id: \.self) { hour in
            HStack(alignment: .top, spacing: 0) {
              Text(String(format: "%02d:00", hour))
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: hourLabelWidth, alignment: .trailing)
                .padding(.trailing, 6)
                .padding(.top, -6)  // visuell mit Linie ausrichten
              Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 0.5)
                .padding(.top, 0)
              Spacer(minLength: 0)
            }
            .frame(height: hourHeight, alignment: .top)
          }
        }

        // Caller content (events)
        HStack(spacing: 0) {
          Spacer().frame(width: hourLabelWidth + 6)  // Hour-label gutter
          content()
        }
      }
    }
  }
}
```

- [ ] **Step 8.2: NowIndicator**

`Views/Components/NowIndicator.swift`:

```swift
import SwiftUI

/// Rote Linie für die aktuelle Zeit. Caller positioniert sie auf der Y-Achse
/// basierend auf der Stunde.
struct NowIndicator: View {
  let hourHeight: CGFloat

  var body: some View {
    let now = Date()
    let cal = Calendar.current
    let hour = cal.component(.hour, from: now)
    let minute = cal.component(.minute, from: now)
    let yOffset = (Double(hour) + Double(minute) / 60.0) * Double(hourHeight)

    HStack(spacing: 0) {
      Circle()
        .fill(Color.red)
        .frame(width: 8, height: 8)
      Rectangle()
        .fill(Color.red)
        .frame(height: 1.5)
    }
    .offset(y: yOffset)
  }
}
```

- [ ] **Step 8.3: Build (User)**

Build-only-Check. Components werden in Task 9 verwendet.

- [ ] **Step 8.4: Commit (Controller)**

```bash
git add apps/atollcal-native/AtollCal/Views/Components/
git commit -m "feat(atollcal): TimeAxisGrid + NowIndicator components für Day/Week-Views"
```

---

### Task 9: DayView — funktional mit Event-Bars

**Files:**
- Create: `apps/atollcal-native/AtollCal/Views/Components/EventBar.swift`
- Replace: `apps/atollcal-native/AtollCal/Views/DayView.swift`

- [ ] **Step 9.1: EventBar Component**

`Views/Components/EventBar.swift`:

```swift
import SwiftUI

/// Visuelle Repräsentation eines CalendarEvent als bar/card auf der Zeitachse.
/// Width + Height + Position werden vom Caller berechnet.
struct EventBar: View {
  let event: CalendarEvent
  var compact: Bool = false  // für WeekView/MonthView dichteres Layout

  var body: some View {
    HStack(alignment: .top, spacing: 6) {
      Rectangle()
        .fill(event.color)
        .frame(width: 3)

      VStack(alignment: .leading, spacing: 2) {
        Text(event.title)
          .font(compact ? .caption2 : .caption)
          .lineLimit(compact ? 1 : 2)
        if !compact, let loc = event.location, !loc.isEmpty {
          Text(loc)
            .font(.caption2)
            .foregroundColor(.secondary)
            .lineLimit(1)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.vertical, 3)
    .padding(.horizontal, 4)
    .background(event.color.opacity(0.15))
    .cornerRadius(4)
  }
}
```

- [ ] **Step 9.2: DayView — Event-Loading + Layout**

Komplett ersetzen `Views/DayView.swift`:

```swift
import SwiftUI
import AtollCore
import AtollDesign

struct DayView: View {
  @Binding var date: Date
  @Environment(SystemCalendarStore.self) var calendarStore
  @Environment(AtollEventLoader.self) var atollLoader
  @Environment(AuthState.self) var auth
  @AppStorage("enabledCalendarIds") private var enabledCalendarIdsJSON: String = "[]"
  @AppStorage("atollEnabled") private var atollEnabled: Bool = true

  @State private var events: [CalendarEvent] = []

  private let hourHeight: CGFloat = 60

  var body: some View {
    TimeAxisGrid(hourHeight: hourHeight) {
      ZStack(alignment: .topLeading) {
        // Event-Bars positionieren
        ForEach(events) { ev in
          eventLayout(for: ev)
        }
        if Calendar.current.isDateInToday(date) {
          NowIndicator(hourHeight: hourHeight)
        }
      }
    }
    .refreshable { await loadAll() }
    .task(id: date) { await loadAll() }
    .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
      Task { await loadAll() }
    }
  }

  private func eventLayout(for ev: CalendarEvent) -> some View {
    let cal = Calendar.current
    let dayStart = cal.startOfDay(for: date)
    let evStart = max(ev.startDate, dayStart)
    let evEnd = min(ev.endDate, cal.date(byAdding: .day, value: 1, to: dayStart)!)
    let startMinutes = evStart.timeIntervalSince(dayStart) / 60
    let durationMinutes = evEnd.timeIntervalSince(evStart) / 60
    let yOffset = startMinutes / 60.0 * Double(hourHeight)
    let height = max(20, durationMinutes / 60.0 * Double(hourHeight))

    return EventBar(event: ev)
      .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
      .offset(y: yOffset)
  }

  private func enabledCalendarIds() -> Set<String> {
    if let data = enabledCalendarIdsJSON.data(using: .utf8),
       let arr = try? JSONDecoder().decode([String].self, from: data) {
      return Set(arr)
    }
    // Default: alle erlaubten Kalender (leer = alle)
    return []
  }

  private func loadAll() async {
    let cal = Calendar.current
    let dayStart = cal.startOfDay(for: date)
    let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!
    let range = DateInterval(start: dayStart, end: dayEnd)

    var combined: [CalendarEvent] = []

    // System
    let sysEvents = calendarStore.events(in: range, calendarIds: enabledCalendarIds().isEmpty ? nil : enabledCalendarIds())
    combined.append(contentsOf: sysEvents.map { .system($0) })

    // ATOLL
    if atollEnabled,
       case .signedIn(let user) = auth.status,
       let instructorId = user.legacyInstructorId {
      await atollLoader.reload(for: instructorId, range: DateInterval(
        start: cal.date(byAdding: .month, value: -1, to: range.start)!,
        end:   cal.date(byAdding: .month, value: 1, to: range.end)!
      ))
      // Filter Assignments deren Datum im aktuellen Day-Range liegt
      for assignment in atollLoader.assignments {
        guard let course = atollLoader.coursesById[assignment.courseId] else { continue }
        let courseDates = atollLoader.courseDatesByCourseId[course.id] ?? []
        let assignmentDates: [Date]
        if assignment.assignedForDates.isEmpty {
          assignmentDates = [course.startDate] + course.additionalDates
        } else {
          assignmentDates = assignment.assignedForDates
        }
        if assignmentDates.contains(where: { cal.isDate($0, inSameDayAs: date) }) {
          combined.append(.atoll(assignment: assignment, course: course, dates: courseDates.filter {
            cal.isDate($0.date, inSameDayAs: date)
          }))
        }
      }
    }

    events = combined.sorted(by: { $0.startDate < $1.startDate })
  }
}
```

**Hinweis Subagent:** Die `assignment.courseId`-Verbindung erfordert eine `courseId`-Property in `Assignment`. Falls AtollCore.Assignment das nicht hat (war im Foundation-Stand vermutlich da), Modell entsprechend ergänzen.

- [ ] **Step 9.3: Build + Smoke (User)**

```bash
xcodegen generate && open AtollCal.xcodeproj
```
⌘R, App starten, einloggen. Erwartet:
- DayView zeigt Events des heutigen Tages aus iCloud/Google + ATOLL-Einsätze (falls vorhanden) auf der Zeitachse
- Now-Indikator (rote Linie) zeigt aktuelle Zeit
- Pull-Down-Refresh funktioniert

Falls keine Events sichtbar: Datum auf einen Tag mit bekannten Events ändern (wir bauen Datum-Picker erst in Task 10 — vorerst manuell `focusedDate` patchen oder in Code Default ändern).

- [ ] **Step 9.4: Commit (Controller)**

```bash
git add apps/atollcal-native/
git commit -m "feat(atollcal): DayView funktional — Event-Bars + Now-Indicator + Pull-to-Refresh"
```

---

### Task 10: Datum-Picker (Toolbar) für Day/Week/Month

**Files:**
- Modify: `apps/atollcal-native/AtollCal/Views/CalendarRoot.swift`

- [ ] **Step 10.1: Datum-Picker als Popover-Button im Toolbar**

In `CalendarRoot.swift` den Title-Bereich klickbar machen:

Im iOS-Branch des body, nach dem ToolbarItem `.topBarLeading` einfügen:

```swift
ToolbarItem(placement: .principal) {
  Button {
    showingDatePicker = true
  } label: {
    Text(formattedTitle)
      .font(.headline)
  }
  .popover(isPresented: $showingDatePicker) {
    DatePicker("Datum", selection: $focusedDate, displayedComponents: .date)
      .datePickerStyle(.graphical)
      .padding()
      .presentationCompactAdaptation(.popover)
  }
}
```

Plus oben in den `@State`-Properties:
```swift
@State private var showingDatePicker = false
```

Für macOS analog im detail-Toolbar einen Datum-Button.

- [ ] **Step 10.2: Build + Smoke (User)**

Datum-Picker öffnet sich via Tap auf Title. Tag wechseln → DayView refresht.

- [ ] **Step 10.3: Commit (Controller)**

```bash
git add apps/atollcal-native/AtollCal/Views/CalendarRoot.swift
git commit -m "feat(atollcal): Datum-Picker via Popover auf Title-Tap"
```

---

### Task 11: WeekView — 7 Spalten

**Files:**
- Replace: `apps/atollcal-native/AtollCal/Views/WeekView.swift`

- [ ] **Step 11.1: WeekView mit 7-Spalten-Grid**

Komplett ersetzen `Views/WeekView.swift`:

```swift
import SwiftUI
import AtollCore
import AtollDesign

struct WeekView: View {
  @Binding var anchor: Date
  @Environment(SystemCalendarStore.self) var calendarStore
  @Environment(AtollEventLoader.self) var atollLoader
  @Environment(AuthState.self) var auth
  @AppStorage("enabledCalendarIds") private var enabledCalendarIdsJSON: String = "[]"
  @AppStorage("atollEnabled") private var atollEnabled: Bool = true

  @State private var eventsByDay: [Date: [CalendarEvent]] = [:]

  private let hourHeight: CGFloat = 60

  var body: some View {
    GeometryReader { geo in
      let dayWidth = (geo.size.width - 56) / 7  // 50 hour-label + 6 gutter
      ScrollView {
        VStack(spacing: 0) {
          // Day-Header
          HStack(spacing: 0) {
            Spacer().frame(width: 56)
            ForEach(daysOfWeek, id: \.self) { day in
              VStack(spacing: 2) {
                Text(weekdayLabel(day))
                  .font(.caption)
                  .foregroundColor(Calendar.current.isDateInToday(day) ? .accentColor : .secondary)
                Text("\(Calendar.current.component(.day, from: day))")
                  .font(.headline)
                  .foregroundColor(Calendar.current.isDateInToday(day) ? .accentColor : .primary)
              }
              .frame(width: dayWidth)
            }
          }
          .padding(.vertical, 6)
          .background(Color.secondary.opacity(0.05))

          // Time-axis grid + columns
          ZStack(alignment: .topLeading) {
            // Hour labels + grid lines
            VStack(spacing: 0) {
              ForEach(0..<24, id: \.self) { hour in
                HStack(spacing: 0) {
                  Text(String(format: "%02d:00", hour))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .trailing)
                    .padding(.trailing, 6)
                    .padding(.top, -6)
                  Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 0.5)
                  Spacer(minLength: 0)
                }
                .frame(height: hourHeight, alignment: .top)
              }
            }

            // Day columns mit Events
            HStack(spacing: 0) {
              Spacer().frame(width: 56)
              ForEach(daysOfWeek, id: \.self) { day in
                ZStack(alignment: .topLeading) {
                  ForEach(eventsByDay[Calendar.current.startOfDay(for: day)] ?? []) { ev in
                    eventLayout(for: ev, dayStart: Calendar.current.startOfDay(for: day))
                  }
                  if Calendar.current.isDateInToday(day) {
                    NowIndicator(hourHeight: hourHeight)
                  }
                }
                .frame(width: dayWidth, alignment: .top)
                .border(Color.secondary.opacity(0.1), width: 0.5)
              }
            }
          }
        }
      }
    }
    .gesture(
      DragGesture(minimumDistance: 50)
        .onEnded { value in
          if value.translation.width < -50 {
            anchor = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: anchor)!
          } else if value.translation.width > 50 {
            anchor = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: anchor)!
          }
        }
    )
    .refreshable { await loadAll() }
    .task(id: anchor) { await loadAll() }
    .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
      Task { await loadAll() }
    }
  }

  private var daysOfWeek: [Date] {
    let cal = Calendar(identifier: .iso8601)  // Mo–So
    let weekday = cal.component(.weekday, from: anchor)
    let monday = cal.date(byAdding: .day, value: -(weekday - 2 + 7) % 7, to: anchor)!
    return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: monday) }
  }

  private func weekdayLabel(_ d: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "de_CH")
    f.dateFormat = "EE"
    return f.string(from: d)
  }

  private func eventLayout(for ev: CalendarEvent, dayStart: Date) -> some View {
    let cal = Calendar.current
    let evStart = max(ev.startDate, dayStart)
    let evEnd = min(ev.endDate, cal.date(byAdding: .day, value: 1, to: dayStart)!)
    let startMinutes = evStart.timeIntervalSince(dayStart) / 60
    let durationMinutes = evEnd.timeIntervalSince(evStart) / 60
    let yOffset = startMinutes / 60.0 * Double(hourHeight)
    let height = max(20, durationMinutes / 60.0 * Double(hourHeight))

    return EventBar(event: ev, compact: true)
      .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
      .offset(y: yOffset)
      .padding(.horizontal, 2)
  }

  private func enabledCalendarIds() -> Set<String> {
    if let data = enabledCalendarIdsJSON.data(using: .utf8),
       let arr = try? JSONDecoder().decode([String].self, from: data) {
      return Set(arr)
    }
    return []
  }

  private func loadAll() async {
    let cal = Calendar.current
    let weekStart = cal.startOfDay(for: daysOfWeek.first!)
    let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart)!
    let range = DateInterval(start: weekStart, end: weekEnd)

    let sysEvents = calendarStore.events(in: range, calendarIds: enabledCalendarIds().isEmpty ? nil : enabledCalendarIds())

    var byDay: [Date: [CalendarEvent]] = [:]
    for ev in sysEvents {
      let dayStart = cal.startOfDay(for: ev.startDate)
      byDay[dayStart, default: []].append(.system(ev))
    }

    if atollEnabled,
       case .signedIn(let user) = auth.status,
       let instructorId = user.legacyInstructorId {
      await atollLoader.reload(for: instructorId, range: DateInterval(
        start: cal.date(byAdding: .month, value: -1, to: range.start)!,
        end:   cal.date(byAdding: .month, value: 1, to: range.end)!
      ))
      for assignment in atollLoader.assignments {
        guard let course = atollLoader.coursesById[assignment.courseId] else { continue }
        let courseDates = atollLoader.courseDatesByCourseId[course.id] ?? []
        let assignmentDates: [Date]
        if assignment.assignedForDates.isEmpty {
          assignmentDates = [course.startDate] + course.additionalDates
        } else {
          assignmentDates = assignment.assignedForDates
        }
        for d in assignmentDates {
          let dayStart = cal.startOfDay(for: d)
          if dayStart >= weekStart && dayStart < weekEnd {
            byDay[dayStart, default: []].append(.atoll(
              assignment: assignment, course: course,
              dates: courseDates.filter { cal.isDate($0.date, inSameDayAs: d) }
            ))
          }
        }
      }
    }

    eventsByDay = byDay.mapValues { $0.sorted(by: { $0.startDate < $1.startDate }) }
  }
}
```

- [ ] **Step 11.2: Build + Smoke (User)**

WeekView zeigt 7 Spalten mit Events. Swipe horizontal: vorige/nächste Woche.

- [ ] **Step 11.3: Commit (Controller)**

```bash
git add apps/atollcal-native/AtollCal/Views/WeekView.swift
git commit -m "feat(atollcal): WeekView mit 7-Spalten-Grid + Swipe-Navigation"
```

---

### Task 12: MonthView — 7×6 Grid mit Event-Indikatoren

**Files:**
- Replace: `apps/atollcal-native/AtollCal/Views/MonthView.swift`

- [ ] **Step 12.1: MonthView mit Cell-Grid**

Komplett ersetzen `Views/MonthView.swift`:

```swift
import SwiftUI
import AtollCore
import AtollDesign

struct MonthView: View {
  @Binding var anchor: Date
  @Environment(SystemCalendarStore.self) var calendarStore
  @Environment(AtollEventLoader.self) var atollLoader
  @Environment(AuthState.self) var auth
  @AppStorage("enabledCalendarIds") private var enabledCalendarIdsJSON: String = "[]"
  @AppStorage("atollEnabled") private var atollEnabled: Bool = true

  @State private var eventsByDay: [Date: [CalendarEvent]] = [:]

  var body: some View {
    VStack(spacing: 0) {
      // Weekday-Header
      HStack(spacing: 0) {
        ForEach(["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"], id: \.self) { lbl in
          Text(lbl)
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
        }
      }
      .padding(.vertical, 6)
      .background(Color.secondary.opacity(0.05))

      // Grid 6 Wochen × 7 Tage
      let weeks = monthWeeks
      VStack(spacing: 0) {
        ForEach(weeks, id: \.first) { week in
          HStack(spacing: 0) {
            ForEach(week, id: \.self) { day in
              dayCell(day)
            }
          }
        }
      }
    }
    .task(id: anchor) { await loadAll() }
    .refreshable { await loadAll() }
    .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
      Task { await loadAll() }
    }
    .gesture(
      DragGesture(minimumDistance: 50)
        .onEnded { value in
          if value.translation.width < -50 {
            anchor = Calendar.current.date(byAdding: .month, value: 1, to: anchor)!
          } else if value.translation.width > 50 {
            anchor = Calendar.current.date(byAdding: .month, value: -1, to: anchor)!
          }
        }
    )
  }

  private var monthWeeks: [[Date]] {
    let cal = Calendar(identifier: .iso8601)
    let comps = cal.dateComponents([.year, .month], from: anchor)
    let monthStart = cal.date(from: comps)!
    let weekday = cal.component(.weekday, from: monthStart)
    let firstMonday = cal.date(byAdding: .day, value: -(weekday - 2 + 7) % 7, to: monthStart)!
    return (0..<6).map { weekIdx in
      (0..<7).compactMap { cal.date(byAdding: .day, value: weekIdx * 7 + $0, to: firstMonday) }
    }
  }

  private func dayCell(_ day: Date) -> some View {
    let cal = Calendar.current
    let isCurrentMonth = cal.isDate(day, equalTo: anchor, toGranularity: .month)
    let isToday = cal.isDateInToday(day)
    let dayEvents = eventsByDay[cal.startOfDay(for: day)] ?? []

    return VStack(alignment: .leading, spacing: 2) {
      Text("\(cal.component(.day, from: day))")
        .font(.caption)
        .foregroundColor(isToday ? .accentColor : (isCurrentMonth ? .primary : .secondary.opacity(0.5)))
        .padding(.horizontal, 4)
        .padding(.top, 4)

      VStack(spacing: 1) {
        ForEach(dayEvents.prefix(3)) { ev in
          HStack(spacing: 3) {
            Rectangle()
              .fill(ev.color)
              .frame(width: 2, height: 10)
            Text(ev.title)
              .font(.system(size: 9))
              .lineLimit(1)
              .foregroundColor(isCurrentMonth ? .primary : .secondary)
          }
          .padding(.horizontal, 2)
        }
        if dayEvents.count > 3 {
          Text("+\(dayEvents.count - 3) more")
            .font(.system(size: 8))
            .foregroundColor(.secondary)
            .padding(.horizontal, 2)
        }
      }

      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, minHeight: 70, alignment: .topLeading)
    .background(isToday ? Color.accentColor.opacity(0.1) : Color.clear)
    .border(Color.secondary.opacity(0.1), width: 0.5)
  }

  private func enabledCalendarIds() -> Set<String> {
    if let data = enabledCalendarIdsJSON.data(using: .utf8),
       let arr = try? JSONDecoder().decode([String].self, from: data) {
      return Set(arr)
    }
    return []
  }

  private func loadAll() async {
    let cal = Calendar.current
    let weeks = monthWeeks
    let rangeStart = cal.startOfDay(for: weeks.first!.first!)
    let rangeEnd = cal.date(byAdding: .day, value: 1, to: weeks.last!.last!)!
    let range = DateInterval(start: rangeStart, end: rangeEnd)

    let sysEvents = calendarStore.events(in: range, calendarIds: enabledCalendarIds().isEmpty ? nil : enabledCalendarIds())
    var byDay: [Date: [CalendarEvent]] = [:]
    for ev in sysEvents {
      let dayStart = cal.startOfDay(for: ev.startDate)
      byDay[dayStart, default: []].append(.system(ev))
    }

    if atollEnabled,
       case .signedIn(let user) = auth.status,
       let instructorId = user.legacyInstructorId {
      await atollLoader.reload(for: instructorId, range: DateInterval(
        start: cal.date(byAdding: .month, value: -1, to: range.start)!,
        end:   cal.date(byAdding: .month, value: 1, to: range.end)!
      ))
      for assignment in atollLoader.assignments {
        guard let course = atollLoader.coursesById[assignment.courseId] else { continue }
        let courseDates = atollLoader.courseDatesByCourseId[course.id] ?? []
        let assignmentDates: [Date] = assignment.assignedForDates.isEmpty
          ? [course.startDate] + course.additionalDates
          : assignment.assignedForDates
        for d in assignmentDates {
          let dayStart = cal.startOfDay(for: d)
          if dayStart >= rangeStart && dayStart < rangeEnd {
            byDay[dayStart, default: []].append(.atoll(
              assignment: assignment, course: course,
              dates: courseDates.filter { cal.isDate($0.date, inSameDayAs: d) }
            ))
          }
        }
      }
    }

    eventsByDay = byDay.mapValues { $0.sorted(by: { $0.startDate < $1.startDate }) }
  }
}
```

- [ ] **Step 12.2: Build + Smoke (User)**

MonthView zeigt 7×6-Grid, Events als kleine Bars in Tag-Cells, „+N more" wenn >3, heutiger Tag highlighted.

- [ ] **Step 12.3: Commit (Controller)**

```bash
git add apps/atollcal-native/AtollCal/Views/MonthView.swift
git commit -m "feat(atollcal): MonthView mit 7×6-Grid + Event-Indikatoren + Swipe-Navigation"
```

---

### Task 13: Tap-on-Day in MonthView → DayView

**Files:**
- Modify: `apps/atollcal-native/AtollCal/Views/MonthView.swift`
- Modify: `apps/atollcal-native/AtollCal/Views/CalendarRoot.swift`

- [ ] **Step 13.1: MonthView Tap-Action**

In `MonthView.swift` `dayCell(_:)` ergänzen:

```swift
.onTapGesture {
  onDayTap(day)
}
```

Plus Property:
```swift
var onDayTap: (Date) -> Void = { _ in }
```

- [ ] **Step 13.2: CalendarRoot — onDayTap propagieren**

In `CalendarRoot.swift`:

```swift
case .month: MonthView(anchor: $focusedDate, onDayTap: { day in
  focusedDate = day
  selectedView = .day
})
```

- [ ] **Step 13.3: Build + Smoke (User)**

In MonthView Tap auf einen Tag → springt zu DayView dieses Tages.

- [ ] **Step 13.4: Commit (Controller)**

```bash
git add apps/atollcal-native/AtollCal/Views/
git commit -m "feat(atollcal): Tap-on-Day in MonthView → springt zu DayView dieses Tages"
```

---

### Task 14: Multi-Day-Event-Spans in MonthView (komplexer Layout-Helper)

**Files:**
- Modify: `apps/atollcal-native/AtollCal/Views/MonthView.swift`

Multi-Day-Events spannen über mehrere Cells, brechen am Wochenende ab und starten in der nächsten Woche neu. Komplex aber wichtig für visuelle Korrektheit.

- [ ] **Step 14.1: MultiDayEventSpan-Helper**

In `MonthView.swift` als private nested struct ergänzen:

```swift
private struct MultiDayEventSpan: Identifiable {
  let id: String
  let event: CalendarEvent
  let weekIndex: Int
  let startDayInWeek: Int  // 0–6
  let lengthInWeek: Int    // 1–7

  var widthFraction: Double { Double(lengthInWeek) / 7.0 }
  var leftFraction: Double { Double(startDayInWeek) / 7.0 }
}

private func multiDayEventSpans(in weeks: [[Date]]) -> [MultiDayEventSpan] {
  var spans: [MultiDayEventSpan] = []
  let cal = Calendar.current
  for (weekIdx, week) in weeks.enumerated() {
    let weekStart = cal.startOfDay(for: week.first!)
    let weekEndExclusive = cal.date(byAdding: .day, value: 7, to: weekStart)!

    // Sammle alle distinct Multi-Day-Events die diese Woche überschneiden
    var seenIds = Set<String>()
    for day in week {
      let dayStart = cal.startOfDay(for: day)
      for ev in eventsByDay[dayStart] ?? [] {
        // Nur Multi-Day-Events (mehr als 1 Tag span)
        let evDayCount = max(1, Int(ev.endDate.timeIntervalSince(ev.startDate) / 86400))
        guard evDayCount > 1 else { continue }
        if seenIds.contains(ev.id) { continue }
        seenIds.insert(ev.id)

        let evStart = max(ev.startDate, weekStart)
        let evEnd = min(ev.endDate, weekEndExclusive)
        let startDayInWeek = cal.dateComponents([.day], from: weekStart, to: evStart).day ?? 0
        let lengthInWeek = max(1, cal.dateComponents([.day], from: evStart, to: evEnd).day ?? 1)
        spans.append(MultiDayEventSpan(
          id: "\(ev.id)-w\(weekIdx)",
          event: ev,
          weekIndex: weekIdx,
          startDayInWeek: startDayInWeek,
          lengthInWeek: min(7 - startDayInWeek, lengthInWeek)
        ))
      }
    }
  }
  return spans
}
```

- [ ] **Step 14.2: Layout-Overlay in MonthView body**

In `MonthView.body` die `VStack(spacing: 0)` mit weeks ersetzen mit:

```swift
GeometryReader { geo in
  let cellWidth = geo.size.width / 7
  let cellHeight: CGFloat = 70

  ZStack(alignment: .topLeading) {
    // Day-Cells (wie vorher)
    VStack(spacing: 0) {
      ForEach(weeks, id: \.first) { week in
        HStack(spacing: 0) {
          ForEach(week, id: \.self) { day in
            dayCell(day)
          }
        }
      }
    }

    // Multi-Day-Spans als overlay
    ForEach(multiDayEventSpans(in: weeks)) { span in
      let yOffset = CGFloat(span.weekIndex) * cellHeight + 22  // unter Day-Number
      let xOffset = CGFloat(span.startDayInWeek) * cellWidth
      let width = CGFloat(span.lengthInWeek) * cellWidth - 4

      HStack(spacing: 3) {
        Rectangle().fill(span.event.color).frame(width: 2)
        Text(span.event.title).font(.system(size: 9)).lineLimit(1)
        Spacer()
      }
      .padding(.horizontal, 2)
      .frame(width: width, height: 12)
      .background(span.event.color.opacity(0.15))
      .cornerRadius(2)
      .offset(x: xOffset + 2, y: yOffset)
    }
  }
}
.frame(minHeight: CGFloat(weeks.count) * 70)
```

(Wichtig: die single-day-Events in dayCell bleiben ergänzend zu den Multi-Day-Spans — die Spans sind Overlay, single-day Bars normal.)

- [ ] **Step 14.3: Build + Smoke (User)**

Multi-Day-Events spannen nun visuell über mehrere Cells. Editor Edge-Cases:
- Event von Mo–Mi: span Mo–Mi ✓
- Event von So–Mi: zwei Spans (So in Vorwoche, Mo–Mi in aktueller) ✓
- Event über Monatsgrenze: nur die im aktuellen Monat-Weeks-Range sichtbar ✓

- [ ] **Step 14.4: Commit (Controller)**

```bash
git add apps/atollcal-native/AtollCal/Views/MonthView.swift
git commit -m "feat(atollcal): Multi-Day-Event-Spans in MonthView (Span-Bars über Cells, week-clipped)"
```

**Milestone M3 erreicht:** Alle drei Calendar-Views funktional.

---

## M4 — Detail + Settings + Polish

### Task 15: EventDetailSheet

**Files:**
- Create: `apps/atollcal-native/AtollCal/Views/EventDetailSheet.swift`
- Modify: `apps/atollcal-native/AtollCal/Views/Components/EventBar.swift` (Tap-Action)
- Modify: `apps/atollcal-native/AtollCal/Views/DayView.swift`, `WeekView.swift`, `MonthView.swift` (Sheet-State)

- [ ] **Step 15.1: EventDetailSheet**

`Views/EventDetailSheet.swift`:

```swift
import SwiftUI
import EventKit
import AtollCore
import AtollDesign

struct EventDetailSheet: View {
  let event: CalendarEvent
  @Environment(\.dismiss) var dismiss

  var body: some View {
    NavigationStack {
      Form {
        Section {
          HStack {
            Rectangle().fill(event.color).frame(width: 4, height: 24)
            Text(event.title).font(.headline)
          }
          Text(formattedDateRange)
            .foregroundColor(.secondary)
            .font(.subheadline)
          if let loc = event.location, !loc.isEmpty {
            Label(loc, systemImage: "mappin.and.ellipse")
          }
        }

        switch event {
        case .system(let ek):
          Section("Kalender") {
            Text(ek.calendar?.title ?? "—")
          }
          if let notes = ek.notes, !notes.isEmpty {
            Section("Notizen") {
              Text(notes)
            }
          }
        case .atoll(let assignment, let course, _):
          Section("ATOLL — Tauchkurs") {
            Label("Rolle: \(assignment.role.rawValue)", systemImage: "person.badge.shield.checkmark")
            Label("Status: \(course.status.rawValue)", systemImage: "checkmark.seal")
          }
        }
      }
      .navigationTitle(event.title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Schließen") { dismiss() }
        }
      }
    }
  }

  private var formattedDateRange: String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "de_CH")
    f.dateStyle = .full
    f.timeStyle = event.isAllDay ? .none : .short
    if Calendar.current.isDate(event.startDate, inSameDayAs: event.endDate) {
      let dayStr = f.string(from: event.startDate)
      if event.isAllDay { return "\(dayStr) — ganztägig" }
      let timeF = DateFormatter()
      timeF.timeStyle = .short
      return "\(dayStr), \(timeF.string(from: event.startDate))–\(timeF.string(from: event.endDate))"
    } else {
      return "\(f.string(from: event.startDate)) — \(f.string(from: event.endDate))"
    }
  }
}
```

- [ ] **Step 15.2: EventBar tap-action**

In `EventBar.swift` `var onTap: () -> Void = {}` ergänzen, Body in `Button { onTap() }` wrappen oder `.onTapGesture { onTap() }`.

- [ ] **Step 15.3: DayView/WeekView/MonthView — selectedEvent + Sheet**

In jeder der drei Views ergänzen:
```swift
@State private var selectedEvent: CalendarEvent?
```

Bei jedem `EventBar(...)` ergänzen:
```swift
.onTapGesture { selectedEvent = ev }
```

Außerhalb des Bodies:
```swift
.sheet(item: $selectedEvent) { ev in
  EventDetailSheet(event: ev)
}
```

- [ ] **Step 15.4: Build + Smoke (User)**

Tap auf Event → Sheet öffnet, Details sichtbar.

- [ ] **Step 15.5: Commit (Controller)**

```bash
git add apps/atollcal-native/AtollCal/Views/
git commit -m "feat(atollcal): EventDetailSheet mit Kalender/Notizen für System + Rolle/Status für ATOLL"
```

---

### Task 16: SettingsView + Calendar-Source-Toggles

**Files:**
- Create: `apps/atollcal-native/AtollCal/Views/SettingsView.swift`
- Modify: `apps/atollcal-native/AtollCal/Views/CalendarRoot.swift` (Settings-Button)

- [ ] **Step 16.1: SettingsView**

`Views/SettingsView.swift`:

```swift
import SwiftUI
import EventKit
import AtollCore

struct SettingsView: View {
  @Environment(SystemCalendarStore.self) var calendarStore
  @Environment(AuthState.self) var auth
  @Environment(\.dismiss) var dismiss

  @AppStorage("enabledCalendarIds") private var enabledCalendarIdsJSON: String = "[]"
  @AppStorage("atollEnabled") private var atollEnabled: Bool = true

  @State private var enabledIds: Set<String> = []

  var body: some View {
    NavigationStack {
      Form {
        Section("Kalender-Quellen") {
          if calendarStore.authorizationStatus != .fullAccess {
            VStack(alignment: .leading, spacing: 6) {
              Text("Kalender-Zugriff verweigert").bold()
              Text("Erlaube Zugriff in den System-Einstellungen, um deine Kalender zu nutzen.")
                .font(.caption).foregroundColor(.secondary)
            }
          } else {
            ForEach(calendarStore.calendars, id: \.calendarIdentifier) { cal in
              Toggle(isOn: Binding(
                get: { enabledIds.contains(cal.calendarIdentifier) },
                set: { newValue in
                  if newValue { enabledIds.insert(cal.calendarIdentifier) }
                  else { enabledIds.remove(cal.calendarIdentifier) }
                  persist()
                }
              )) {
                HStack {
                  Circle().fill(Color(cgColor: cal.cgColor)).frame(width: 10, height: 10)
                  Text(cal.title)
                  Spacer()
                  Text(cal.source.title).font(.caption).foregroundColor(.secondary)
                }
              }
            }
          }
        }

        Section("ATOLL") {
          Toggle("Meine Tauchkurs-Einsätze", isOn: $atollEnabled)
          if case .signedIn(let user) = auth.status {
            Text("Eingeloggt als: \(user.email ?? user.name)").font(.caption).foregroundColor(.secondary)
            Button("Abmelden", role: .destructive) {
              Task { try? await auth.signOut() }
            }
          }
        }

        Section("Über") {
          Text("AtollCal v0.1 (Build 1)")
          Text("Datenquelle: \(Config.tenantName)")
        }
      }
      .navigationTitle("Einstellungen")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Schließen") { dismiss() }
        }
      }
      .onAppear {
        // Lade aktuelle enabled-Set aus AppStorage
        if let data = enabledCalendarIdsJSON.data(using: .utf8),
           let arr = try? JSONDecoder().decode([String].self, from: data) {
          enabledIds = Set(arr)
        }
        // Default: ALLE enabled wenn AppStorage leer
        if enabledIds.isEmpty && !calendarStore.calendars.isEmpty {
          enabledIds = Set(calendarStore.calendars.map { $0.calendarIdentifier })
          persist()
        }
      }
    }
  }

  private func persist() {
    let arr = Array(enabledIds)
    if let data = try? JSONEncoder().encode(arr),
       let str = String(data: data, encoding: .utf8) {
      enabledCalendarIdsJSON = str
    }
  }
}
```

- [ ] **Step 16.2: Settings-Button in CalendarRoot-Toolbar**

In `CalendarRoot.swift` ToolbarItem ergänzen:
```swift
ToolbarItem(placement: .topBarTrailing) {
  Button(action: { showingSettings = true }) {
    Image(systemName: "gearshape")
  }
}
```
Plus `@State private var showingSettings = false` und `.sheet(isPresented: $showingSettings) { SettingsView() }`.

- [ ] **Step 16.3: Build + Smoke (User)**

Settings öffnet sich. Calendar-Toggles wirken sofort (Day/Week/Month-Views filtern). ATOLL-Toggle versteckt ATOLL-Events. Logout funktioniert.

- [ ] **Step 16.4: Commit (Controller)**

```bash
git add apps/atollcal-native/
git commit -m "feat(atollcal): SettingsView mit Calendar-Source-Toggles + ATOLL-Switch + Logout"
```

---

### Task 17: scenePhase-basierter Refresh

**Files:**
- Modify: `apps/atollcal-native/AtollCal/AtollCalApp.swift`

- [ ] **Step 17.1: ScenePhase-Listener**

In `AtollCalApp.swift` body ergänzen:

```swift
.onChange(of: scenePhase) { _, newPhase in
  if newPhase == .active {
    // Loader feuert, alle Views holen sich frische Daten via .task
    calendarStore.refreshAuthStatus()
    NotificationCenter.default.post(name: .EKEventStoreChanged, object: nil)
  }
}
```

Plus `@Environment(\.scenePhase) var scenePhase` in der struct.

- [ ] **Step 17.2: Build + Smoke (User)**

App in Background, neuer ATOLL-Eintrag in Web → App wieder Vordergrund → DayView refresht automatisch.

- [ ] **Step 17.3: Commit (Controller)**

```bash
git add apps/atollcal-native/AtollCal/AtollCalApp.swift
git commit -m "feat(atollcal): scenePhase=active triggert Auth-Refresh + EKChanged-Broadcast"
```

---

### Task 18: macOS-spezifische Anpassungen

**Files:**
- Modify: `apps/atollcal-native/AtollCal/Views/CalendarRoot.swift`
- Modify: `apps/atollcal-native/AtollCal/Views/DayView.swift`, `WeekView.swift`, `MonthView.swift` (Keyboard-Shortcuts)

- [ ] **Step 18.1: Keyboard-Shortcuts**

In `CalendarRoot.swift`:

```swift
.keyboardShortcut("t", modifiers: [.command])  // am "Heute"-Button
```

Plus in DayView/WeekView/MonthView die ←/→-Pfeil-Navigation:

```swift
.focusable()
.onKeyPress(.leftArrow) { navigatePrevious(); return .handled }
.onKeyPress(.rightArrow) { navigateNext(); return .handled }
```

Mit `navigatePrevious()` / `navigateNext()` die je nach View Tag/Woche/Monat navigieren.

- [ ] **Step 18.2: macOS-Sidebar-Toolbar (View-Switcher auch in Toolbar wenn Sidebar collapsed)**

In `CalendarRoot.swift` macOS-Branch im detail-Toolbar:

```swift
ToolbarItem {
  Picker("Ansicht", selection: $selectedView) {
    ForEach(CalendarViewKind.allCases) { kind in
      Text(kind.label).tag(kind)
    }
  }
  .pickerStyle(.segmented)
}
```

- [ ] **Step 18.3: Build auf beiden Plattformen (User)**

```bash
# iOS
xcodebuild -project AtollCal.xcodeproj -scheme AtollCal \
  -destination 'generic/platform=iOS Simulator' build | tail -5

# macOS
xcodebuild -project AtollCal.xcodeproj -scheme AtollCal \
  -destination 'platform=macOS' build | tail -5
```

Beide müssen `BUILD SUCCEEDED` zeigen. Im Mac-App: Sidebar mit Day/Week/Month, Pfeiltasten navigieren, Cmd-T springt zu Heute.

- [ ] **Step 18.4: Commit (Controller)**

```bash
git add apps/atollcal-native/
git commit -m "feat(atollcal): macOS-Adaptionen — Keyboard-Shortcuts (←/→/⌘T) + View-Switcher in Toolbar"
```

---

### Task 19: e2e-Smoke + Spec-Status + Acceptance

Diese Aufgabe schreibt keinen Code — sie verifiziert das komplette System.

- [ ] **Step 19.1: iOS-Smoke-Test**

User auf iPhone-Simulator + echtem iPhone (falls möglich):
1. Login ✓
2. EventKit-Permission erteilt ✓
3. DayView: heutige System-Events + ATOLL-Einsatz korrekt ✓
4. WeekView: 7 Spalten, swipe ✓
5. MonthView: Grid + Multi-Day-Spans ✓
6. Tap auf Event → Detail-Sheet ✓
7. Settings: Calendar-Toggle wirkt sofort ✓
8. Logout/Re-Login: Calendar-Selection bleibt erhalten ✓

- [ ] **Step 19.2: macOS-Smoke-Test**

User auf macOS (run via Xcode → My Mac):
1. NavigationSplitView mit Sidebar ✓
2. Cmd-T springt zu Heute ✓
3. ←/→ navigiert ✓
4. Bei kleinen Fenstern: Sidebar collapses, View-Switcher in Toolbar ✓

- [ ] **Step 19.3: Spec-Status**

In `docs/superpowers/specs/2026-05-15-atollcal-v1-phase1-design.md`:
- Header `Status: Implementiert (YYYY-MM-DD)` mit heutigem Datum
- Akzeptanzkriterien Section 9: alle `- [ ]` → `- [x]`

- [ ] **Step 19.4: Commit (Controller)**

```bash
git add docs/superpowers/specs/2026-05-15-atollcal-v1-phase1-design.md
git commit -m "docs(spec): AtollCal v1 Phase 1 — Status auf Implementiert + Akzeptanzkriterien abgehakt"
```

---

## Out of Scope für diesen Plan

Bewusst nicht in Phase 1 — kommen als eigene Specs/Pläne in v2/v3:

- Natural-Language-Input
- Weather-Overlay (WeatherKit)
- Reminders-Integration
- Calendar Sets, Templates, Maps, Conference-Detection
- iOS Widgets, Mac Menu Bar
- ATOLL-Verfügbarkeit eintragen
- Drag-to-Create / Drag-to-Reschedule
- Postgres-Realtime-Subscription für ATOLL
- Multi-Tenant
- App Group + Single-Sign-On mit ATOLL-iOS
- App-Icon-Design (Placeholder bis dahin)
- App Store Connect Setup
