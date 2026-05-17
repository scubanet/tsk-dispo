# AtollCal v1 Phase 1 — Calendar-Basis + ATOLL-Integration

**Status:** Implementiert (2026-05-15)
**Date:** 2026-05-15
**Author:** Dominik Weckherlin (with Claude)
**Spec Owner:** Dominik
**Target Release:** AtollCal v0.1 (erste persönliche Nutzung + Test-Team)

---

## 1. Kontext & Vision

### Was AtollCal werden soll

AtollCal ist eine native iOS+macOS-Kalender-App, langfristig (6–9 Monate
Marathon-Projekt) ein Fantastical-Clone. ATOLL ist eine von mehreren
Datenquellen — alongside iCloud, Google, Exchange (alle via System-Settings
in EventKit gepflegt).

AtollCal ist Teil der ATOLL App-Suite und nutzt die Foundation-Packages
`AtollCore` (Auth, Supabase, Models) + `AtollDesign` (Brand-Tokens,
Components), die in der Foundation-Spec vom 2026-05-14 angelegt wurden.

### Phasen-Plan

- **Phase 1 (4–6 Wochen, dieser Spec):** Calendar-Basis + ATOLL-Integration
  — funktionierende Kalender-App mit Tag/Woche/Monat-Views, EventKit für
  System-Kalender, ATOLL als overlaid Quelle, Event-Erstellung in
  System-Kalendern via Standard-Form. Du nutzt sie selber + Test-Team.
- **Phase 2 (eigene Specs später):** Natural-Language-Input, Weather, Reminders,
  ATOLL-Verfügbarkeit-Eintragung, Drag-to-Create.
- **Phase 3 (eigene Specs später):** Calendar Sets, Templates, Maps,
  Conference-Detection, Widgets, Mac Menu Bar.

### Pain-Points die Phase 1 adressiert

1. ATOLL-Einsätze sind nur in der ATOLL-Web-App + ATOLL-iOS-App sichtbar —
   Konflikte mit privaten Terminen muss der User in zwei Apps abgleichen.
2. Apple Calendar zeigt zwar System-Kalender, aber AtollCal ist visuell
   schöner geplant und integriert ATOLL-Daten ohne Subscription-Setup.
3. Eigene App = volle Kontrolle über Differenziatoren in späteren Phasen
   (NLP, Calendar Sets, ATOLL-spezifische Features).

## 2. Architektur-Überblick

### Repo-Position

Neuer Xcode-Projekt-Target unter `apps/atollcal-native/` parallel zu
`apps/atoll-ios/`. Selbes XcodeGen-Setup-Pattern.

```
apps/atollcal-native/
├── AtollCal/
│   ├── AtollCalApp.swift       (App-Entry, registriert AtollCoreConfig)
│   ├── Config.swift            (Supabase-Secrets + AppSupabaseConfig-Konformität)
│   ├── Info.plist
│   ├── ATOLL.entitlements
│   ├── Assets.xcassets
│   ├── Localizable.xcstrings
│   ├── Models/                 (AtollCal-spezifische Models — z.B. CalendarEvent enum)
│   ├── Services/               (SystemCalendarStore, AtollEventLoader, CalendarSourceStore)
│   ├── Views/
│   │   ├── RootView.swift
│   │   ├── SignInView.swift
│   │   ├── CalendarRoot.swift
│   │   ├── DayView.swift       (Custom SwiftUI Tagesansicht)
│   │   ├── WeekView.swift      (Custom SwiftUI Wochenansicht)
│   │   ├── MonthView.swift     (Custom SwiftUI Monatsansicht)
│   │   ├── EventDetailSheet.swift
│   │   ├── SettingsView.swift
│   │   └── Components/         (CalendarGrid, EventBar, NowIndicator, etc.)
│   └── Resources/
├── project.yml                 (XcodeGen)
└── README.md
```

### Tech-Stack

- Swift 5.9+, SwiftUI Multiplatform (iOS 17+ und macOS 14+ als ein gemeinsamer
  Target mit `#if os(iOS)`/`#if os(macOS)` für Adaptionen)
- `AtollCore` (local path Swift Package) — Auth, Supabase, Models
- `AtollDesign` (local path Swift Package) — Brand-Tokens, Components
- Apples `EventKit` + `EventKitUI` (System-Frameworks)
- XcodeGen für `.xcodeproj`-Generierung (gleicher Workflow wie atoll-ios)

### Bundle + URL-Scheme

- Bundle-ID: `swiss.atoll.cal`
- Display-Name: `AtollCal`
- URL-Scheme: `atollcal://auth/callback` (separat von ATOLL-iOS, damit kein
  Konflikt wenn beide Apps installiert sind)

### Calendar-UI-Tech: Custom SwiftUI from scratch

Nicht UICalendarView (kann keine Multi-Day-Event-Bars), nicht Drittanbieter-
Library (Limits + Sackgasse für Marathon-Vision). Tag/Woche/Monat-Grid wird
komplett selbst gebaut. Aufwand: ~2–3 Wochen für gutes Grid-Layout, danach
volle Kontrolle für alle späteren Fantastical-Features.

## 3. Auth + Config

Selbes Pattern wie ATOLL-iOS nach Foundation-Migration:

```swift
// Config.swift
import Foundation
import AtollCore

enum Config {
  static let supabaseURL       = URL(string: "https://...supabase.co")!
  static let supabaseAnonKey   = "..."
  static let authRedirectURL   = URL(string: "atollcal://auth/callback")!
  static let appName           = "AtollCal"
  static let tenantName        = "TSK Zürich"
}

struct AppSupabaseConfig: SupabaseConfig {
  var supabaseURL: URL        { Config.supabaseURL }
  var supabaseAnonKey: String { Config.supabaseAnonKey }
  var authRedirectURL: URL    { Config.authRedirectURL }
}
```

```swift
// AtollCalApp.swift
import SwiftUI
import AtollCore

@main
struct AtollCalApp: App {
  @State private var auth: AuthState
  @State private var localeStore: LocaleStore

  init() {
    AtollCoreConfig.register(AppSupabaseConfig())
    _auth = State(initialValue: AuthState())
    _localeStore = State(initialValue: LocaleStore())
  }

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(auth)
        .environment(localeStore)
        .onOpenURL { url in
          guard url.scheme == "atollcal" else { return }
          Task { try? await auth.handleAuthCallback(url: url) }
        }
    }
  }
}
```

**Sign-In:** Identisch zu ATOLL-iOS. Email-Input → Supabase verschickt Magic-
Link → User tippt Link in Mail-App → System öffnet AtollCal → Token wird
verarbeitet, signed in. RLS gibt automatisch nur die eigenen Assignments frei.

**Account-Sharing-Promise:** v1 hat keine Single-Sign-On mit ATOLL-iOS. Wer
beide Apps installiert hat, loggt sich in beiden separat ein. App Group +
Keychain Sharing kommen erst in einer eigenen Foundation-Etappe.

## 4. Daten-Layer

Zwei unabhängige Quellen, eine gemeinsame Abstraktion.

### EventKit-Integration

```swift
// Services/SystemCalendarStore.swift
import EventKit

@Observable
final class SystemCalendarStore {
  private let store = EKEventStore()
  private(set) var authorizationStatus: EKAuthorizationStatus = .notDetermined
  private(set) var calendars: [EKCalendar] = []

  func requestAccess() async {
    do {
      try await store.requestFullAccessToEvents()
      authorizationStatus = EKEventStore.authorizationStatus(for: .event)
      calendars = store.calendars(for: .event)
    } catch {
      authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }
  }

  func events(in range: DateInterval, calendarIds: Set<String>) -> [EKEvent] {
    let cals = calendars.filter { calendarIds.contains($0.calendarIdentifier) }
    let pred = store.predicateForEvents(withStart: range.start, end: range.end, calendars: cals)
    return store.events(matching: pred)
  }
}
```

User-Permission via `NSCalendarsFullAccessUsageDescription` in Info.plist.
Beim ersten App-Start fragt das System nach Zugriff.

EventKit-Performance bei großen Kalendern: Predicates immer mit Date-Range
filtern, nie alle Events laden. Beim View-Wechsel wird die relevante Range
neu berechnet.

### ATOLL-Integration

```swift
// Services/AtollEventLoader.swift
import AtollCore

@Observable
final class AtollEventLoader {
  private(set) var assignments: [Assignment] = []
  private(set) var courses: [UUID: Course] = [:]
  private(set) var courseDates: [UUID: [CourseDate]] = [:]

  func reload(for instructorId: UUID, range: DateInterval) async throws {
    // Query analog zu apps/web/src/lib/queries.ts:fetchCourseAssignments,
    // mit Date-Range-Filter und JOIN auf courses + course_types
    // Detail-Code im Plan, hier nur die Service-Schnittstelle.
  }
}
```

### Unified Event-Abstraktion

```swift
// Models/CalendarEvent.swift
enum CalendarEvent: Identifiable, Hashable {
  case system(EKEvent)
  case atoll(Assignment, Course, [CourseDate])

  var id: String {
    switch self {
    case .system(let e): return "ek-\(e.eventIdentifier ?? UUID().uuidString)"
    case .atoll(let a, _, _): return "atoll-\(a.id)"
    }
  }

  var startDate: Date { /* extract */ }
  var endDate: Date   { /* extract */ }
  var title: String   { /* extract */ }
  var color: Color    { /* extract: system → cgColor, atoll → brand */ }
  var isATOLL: Bool   { if case .atoll = self { true } else { false } }
}
```

Calendar-Views konsumieren `[CalendarEvent]` ohne zu wissen aus welcher
Quelle. Layout/Sortierung passiert in der Calendar-Layout-Engine.

### Refresh-Strategie

- App-Foreground (`scenePhase == .active`): beide Loader feuern
- Pull-to-Refresh in jeder Calendar-View
- Kein Realtime-Channel für v1 — Pull-Refresh reicht
- EventKit: `.EKEventStoreChanged`-Notification subscribed → bei Changes neu laden

## 5. UI-Architektur

### Plattform-Adaption

```swift
// Views/CalendarRoot.swift
struct CalendarRoot: View {
  @State private var selectedView: CalendarViewKind = .week
  @State private var focusedDate: Date = Date()

  var body: some View {
    #if os(iOS)
    NavigationStack {
      content.toolbar { viewSwitcherToolbar }
    }
    #else
    NavigationSplitView {
      Sidebar(selection: $selectedView)
    } detail: {
      content
    }
    #endif
  }
}
```

### Day-View

- Vertikale Zeitachse 0–24h, links Stunden-Labels rechts Event-Bars
- Now-Indikator (rote Linie) bei heute
- Multi-Day-Events oben in „all-day-Bar" gepinned
- Tap auf Event → EventDetailSheet
- Long-Press auf leere Fläche: in v1 disabled (Quick-Create kommt Phase 2)

### Week-View

- 7 Spalten (Mo–So), gleiche Zeitachse-Struktur wie Day-View aber kondensiert
- Heute-Spalte hervorgehoben
- Swipe horizontal: vorige/nächste Woche
- macOS: Pfeiltasten + Cmd-T für „Heute"

### Month-View

- 7×6-Grid, Wochen pro Reihe
- Pro Tag bis zu 3 Event-Indikatoren (farbige Bars mit Title), darunter „+N more"
- Tap auf Tag → Day-View dieses Tages
- Multi-Day-Events spannen über die Cells (komplexer Layout-Helper, ~2–3 Tage)

### EventDetailSheet (universal)

- Titel, Datum/Zeit (mit Zeitzone wenn nicht-lokal), Location
- ATOLL-Events: Rolle (Haupt/Co/etc.), Kurs-Status, andere TL/DM
- System-Events: Notes, Calendar-Source-Name, Attendees (read-only in v1)
- iOS: `.sheet`. macOS: Inspector oder Sheet je nach Window-Größe

### Toolbar

- View-Switcher: Day/Week/Month als Segmented-Control (iOS) oder Sidebar-Items (macOS)
- „Heute"-Button — springt zu heutigem Datum
- Datum-Picker: tap auf aktuelle Datum-Anzeige → kompakter DatePicker als Popover

## 6. Settings — Calendar-Sources

```
┌─ Settings ────────────────────────────────────────────────────┐
│  KALENDER-QUELLEN                                             │
│                                                               │
│  System-Kalender (via EventKit)                               │
│  ☑ Privat (iCloud)                                            │
│  ☑ Arbeit (Google)                                            │
│  ☐ Geburtstage (iCloud)                                       │
│  ☐ Schweizer Feiertage                                        │
│                                                               │
│  ATOLL                                                        │
│  ☑ Meine Tauchkurs-Einsätze                                   │
│                                                               │
│  KONTO                                                        │
│  Eingeloggt als: weckherlin@icloud.com                        │
│  [ Abmelden ]                                                 │
│                                                               │
│  ÜBER                                                         │
│  AtollCal v0.1 (Build 1)                                      │
│  Datenquelle: TSK Zürich                                      │
└───────────────────────────────────────────────────────────────┘
```

**Persistenz:** `@AppStorage("enabledCalendarIds")` für die System-Kalender-IDs
(Set\<String> als JSON), `@AppStorage("atollEnabled")` Boolean. Standard:
alle System-Kalender enabled, ATOLL enabled.

**EventKit-Permission-Status:** Wenn nicht erteilt → großer Banner oben
„Kalender-Zugriff erforderlich" mit Button „In Einstellungen öffnen".

**ATOLL-Section:** Falls AuthState `.signedOut` → „ATOLL nicht verbunden"
mit Sign-In-Link. v1: nur eine ATOLL-Quelle. Multi-Tenant kommt später.

## 7. Out of Scope für v1

Bewusst nicht in Phase 1, kommen als eigene Specs/Pläne:

- Natural-Language-Input („Tomorrow 3pm dentist") — Phase 2
- Weather-Overlay (WeatherKit) — Phase 2
- Reminders-Integration (EKReminderStore) — Phase 2
- Calendar Sets (Gruppen von Kalendern) — Phase 3
- Event-Templates — Phase 3
- Map/Travel-Time in Event-Details — Phase 3
- iOS Widgets, Mac Menu Bar — Phase 3
- Conference-Detection (Zoom/Teams-Links als Quick-Action) — Phase 3
- ATOLL-Verfügbarkeit eintragen (TL/DM trägt Urlaub direkt im Kalender ein) — Phase 2
- Drag-to-Create / Drag-to-Reschedule — Phase 2
- Postgres-Realtime-Subscription für ATOLL — wenn Pull-Refresh nicht reicht
- Multi-Tenant (mehrere ATOLL-Centers in einer App) — irgendwann später
- Single-Sign-On mit ATOLL-iOS via App Group — eigene Foundation-Etappe
- Cross-Device-Calendar-Filter-Sync via iCloud — eher Phase 3

## 8. Risiken / Verifizieren vor Implementation

1. **EventKit-Performance bei vielen Events** — User mit großen Google-
   Kalendern (10+ Jahre History) kann Tausende Events haben. Predicates
   immer mit Date-Range filtern. Beim View-Wechsel: relevante Range neu
   berechnen.
2. **`EKEvent` ist NSObject und nicht value-Hashable** — beim SwiftUI-Diffing
   könnten wir falsch invalidieren. Mit `eventIdentifier` als Identity arbeiten.
3. **Multi-Day-Event-Layout in Month-View** — komplex (Events spannen mehrere
   Cells, brechen am Wochenende ab und starten neu). Eigener Layout-Helper,
   ~2–3 Tage.
4. **macOS-NavigationSplitView-Sidebar bei kleinen Fenstern** — collapsed
   Sidebar → Toolbar muss View-Switcher zeigen. Edge-Case-Test früh.
5. **Magic-Link auf macOS** — wenn der User den Link in Apple Mail auf dem
   Mac öffnet, kann das System AtollCal-iOS auf einem in der Nähe stehenden
   iPhone öffnen statt AtollCal-macOS. Bekannter Edge-Case oder später
   Universal Links aufsetzen.
6. **AtollCore.AuthState-Init-Race** — der Foundation-Fix von 2026-05-15
   (Config-Registration vor State-Init via `State(initialValue:)`) muss in
   AtollCalApp.swift exakt so übernommen werden. README in `swift-packages/`
   dokumentiert das Pattern.

## 9. Akzeptanzkriterien

- [x] App-Target `apps/atollcal-native/` existiert, baut auf iOS 17+ und macOS 14+
- [x] Magic-Link-Login mit `atollcal://` URL-Scheme funktioniert
- [x] EventKit-Permission wird beim ersten Start angefragt
- [x] Day-View zeigt Events des gewählten Tags aus System-Kalendern + ATOLL
      korrekt platziert auf der Zeitachse
- [x] Week-View zeigt 7 Tage mit horizontalem Swipe für Wochen-Wechsel
- [x] Month-View zeigt 7×6-Grid mit Event-Indikatoren pro Tag
- [x] „Heute"-Button springt in jeder View zum aktuellen Datum
- [x] Tap auf ein Event öffnet EventDetailSheet mit allen relevanten Infos
- [x] Settings: Calendar-Sources lassen sich an/abschalten und der Filter wird
      sofort wirksam
- [x] Pull-to-Refresh in jeder View triggert ATOLL-Reload (System-Events
      kommen via EKEventStoreChanged-Notification automatisch)
- [x] iOS und macOS sehen erkennbar verwandt aus, plattform-typische
      Patterns (TabView vs NavigationSplitView)
- [x] Bei Logout/Re-Login behält der User seine Calendar-Source-Selection
      (AppStorage)
- [x] Beide AtollCore + AtollDesign Packages werden importiert und genutzt
      (BrandHeader im SignIn, Brand-Colors in Event-Bars)
