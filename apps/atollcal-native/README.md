# AtollCal — Native iOS + macOS Kalender

Native SwiftUI-App auf iOS 26 / macOS 26, baut auf den ATOLL-Foundation-Packages
(`AtollCore`, `AtollDesign`) auf. Liquid Glass durchgehend, Swift 6 mit Strict
Concurrency Complete.

- Bundle-ID: `swiss.atoll.cal`
- URL-Scheme: `atollcal://`
- Single-Tenant: TSK Zürich

## Setup

```bash
cd apps/atollcal-native
xcodegen generate
open AtollCal.xcodeproj
```

`AtollCal.xcodeproj` ist gitignored — wird aus `project.yml` regeneriert.

## Build

```bash
# iOS Simulator
xcodebuild -scheme AtollCal -destination 'platform=iOS Simulator,name=iPhone 15' build

# macOS
xcodebuild -scheme AtollCal -destination 'platform=macOS,arch=arm64' build
```

## Konfiguration

`AtollCal/Config.swift` enthält Supabase-URL + Anon-Key. URL-Callback geht über
`atollcal://auth/callback` zurück in die App.

## Tastatur-Shortcuts

| Shortcut | Aktion |
|----------|--------|
| `⌘T`     | Springe zu heute |
| `⌘1`     | Tages-Ansicht |
| `⌘2`     | Wochen-Ansicht |
| `⌘3`     | Monats-Ansicht |
| `⌘N`     | Neuer Termin |
| `⌘,`     | Einstellungen |
| `← / →`  | Vorige / nächste Periode |

## QA-Pass — Manuelle Smoke-Test-Checkliste

Vor jedem Release durchspielen. Reihenfolge egal, aber jedes Häkchen
einzeln auf realer Hardware (oder Simulator) bestätigen.

### Build
- [ ] `xcodegen generate` läuft ohne Fehler
- [ ] iOS-Simulator-Build (iPhone 15): 0 Errors, 0 Warnings
- [ ] iOS-Simulator-Build (iPhone SE 3rd gen): 0 Errors, 0 Warnings
- [ ] iPad-Simulator-Build (iPad Pro 13"): 0 Errors, 0 Warnings
- [ ] macOS-Build (arm64): 0 Errors, 0 Warnings
- [ ] Snapshot-Tests laufen grün (`xcodebuild test`)

### Auth
- [ ] Sign-In: Magic-Link wird per Mail empfangen
- [ ] App-Open via `atollcal://` schaltet auf `signedIn`
- [ ] Abmelden in Settings → zurück auf SignInView

### Layout & Navigation
- [ ] iPhone SE: Day-, Week-, Month-Views ohne Überlappungen
- [ ] iPhone 15 Pro: Day-, Week-, Month-Views ohne Überlappungen
- [ ] iPad Pro: Day-, Week-, Month-Views ohne Überlappungen
- [ ] Mac (1024×768): identische Toolbar-Reihenfolge wie iOS
- [ ] Mac Fullscreen (3000×2000): keine gestreckten Elemente, EventBars max-width plausibel
- [ ] WeekView auf iPhone SE: Events als reine Farbstreifen (kein Titel-Text)
- [ ] MonthView: max 3 sichtbare Events pro Zelle, "+N weitere"-Label korrekt
- [ ] Multi-Day-Span überlappt MonthView-Wochen ohne Versatz

### Auto-Scroll
- [ ] DayView heute: aktuelle Uhrzeit ~1/3 von oben sichtbar
- [ ] DayView morgen: Scroll-Position auf 08:00
- [ ] WeekView mit „heute" drin: aktuelle Uhrzeit ~1/3 von oben
- [ ] WeekView ohne „heute": Scroll-Position auf 08:00
- [ ] „Heute"-Button setzt View zurück + scrollt zur Uhrzeit
- [ ] NowIndicator-Pill tickt jede Minute (Wartezeit beobachten)
- [ ] Manuelles Hochscrollen wird nicht durch NowIndicator-Tick gestört

### View-Persistence
- [ ] Selektierte View (`Day/Week/Month`) bleibt nach App-Restart erhalten
- [ ] Mac Multi-Window: jedes Fenster hat eigenes Datum (SceneStorage)
- [ ] iOS: App im Hintergrund / Foreground → Datum bleibt

### Event-CRUD
- [ ] Neuer Termin via `+` Button → in System-Kalender sichtbar
- [ ] EKEvent bearbeiten: Titel, Zeit, Location, Notiz änderbar
- [ ] EKEvent löschen aus EventDetailSheet
- [ ] Wiederholung daily/weekly/monthly/yearly speicherbar
- [ ] Alarm none/atStart/5min/15min/1h/1d speicherbar
- [ ] ATOLL-Event-Tap: EventEditorSheet zeigt „im Web verwalten" + Link
- [ ] Editor disabled wenn Titel leer / Ende < Start / kein Kalender gewählt

### Error & Empty States
- [ ] Kalender-Permission verweigert → PermissionBanner sichtbar, Button funktioniert
- [ ] Keine System-Kalender konfiguriert → Empty-State „Keine Kalender konfiguriert"
- [ ] Alle Toggles aus + ATOLL aus → Empty-State „Keine Quelle aktiv"
- [ ] Supabase offline → ATOLL-Error-Banner rot mit „Erneut versuchen"-Button
- [ ] Loading state: ProgressView in Toolbar während Supabase-Request

### Liquid Glass
- [ ] Toolbar mit Glass-Material auf beiden Plattformen
- [ ] Sheets (Settings, EventEditor, EventDetail) mit Glass-Background
- [ ] PermissionBanner ist Glass-Card mit Amber-Border
- [ ] NowIndicator-Pill ist Glass mit Time-Label
- [ ] EventBar ≥40pt Höhe nutzt Glass-Material
- [ ] WeekView EventBar-Group nutzt `GlassEffectContainer`
- [ ] Keine `.ultraThinMaterial`-Workarounds — alles geht über native `glassEffect(...)`

### Lokalisierung
- [ ] Datum-Formate respektieren System-Locale (nicht hardcoded de_CH)
- [ ] Wochentag-Header (Mo–So) aus Locale-Calendar
- [ ] „+N weitere" (nicht „+N more")

### Performance
- [ ] Schnelles Scrollen WeekView (10× hin/her): max 1 Supabase-Request alle 30s
- [ ] WeekView → DayView → MonthView Wechsel: Animation flüssig, kein Glitch
- [ ] EventStoreChanged-Notification reload alle Views

## Snapshot Tests

`swift-snapshot-testing` (pointfreeco) ist als Test-Dependency in `project.yml`
registriert. Snapshots werden in `AtollCalTests/__Snapshots__/` abgelegt.

### Erstes Aufnehmen

Vor dem ersten Test-Run muss `record: .all` (oder `isRecording = true` in
älteren Versionen) gesetzt sein, sonst schlagen alle Tests fehl mit
„No snapshot recorded". Danach mit `record: .missing` (Default) verifizieren.

### Tests laufen

```bash
xcodebuild test \
  -scheme AtollCal \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### Test-Matrix

| View       | Datenlage                    | Devices                          |
|------------|------------------------------|----------------------------------|
| EventBar   | Auto-Tier (15min/1h/3h)      | iPhone 15 Pro                    |
| DayView    | 0 / 3 / 10 Events            | iPhone SE, iPhone 15 Pro, iPad   |
| WeekView   | Multi-Day-Span 2 Wochen      | iPhone SE, iPhone 15 Pro, iPad   |
| MonthView  | 6 Wochen × Event-Mix         | iPhone 15 Pro, iPad, Mac 1024×768 |

DayView/WeekView/MonthView mit echten Events brauchen einen testbaren
Event-Store — derzeit liefern die Views Daten direkt aus dem
SystemCalendarStore. Für Phase-2 ist eine „Presentation-Layer"-Abspaltung
geplant, die `[CalendarEvent]` direkt akzeptiert; bis dahin testen wir die
EventBar-Komponente und die statischen Layout-Konstanten.

## Architektur

```
AtollCal/
├── AtollCalApp.swift               # @main, Environment-Wiring
├── Config.swift                    # Supabase-Credentials
├── Models/
│   ├── CalendarEvent.swift         # enum .system | .atoll
│   └── CalendarViewKind.swift      # enum .day | .week | .month
├── Services/
│   ├── SystemCalendarStore.swift   # EventKit-Wrapper + CRUD
│   └── AtollEventLoader.swift      # Supabase-Loader mit Debounce
├── Views/
│   ├── RootView.swift              # Auth-Router
│   ├── SignInView.swift            # Magic-Link Form
│   ├── CalendarRoot.swift          # Toolbar + View-Switching
│   ├── DayView.swift               # 24h-Timeline + All-day-Zone
│   ├── WeekView.swift              # 7-Tage-Grid + Multi-Day-Spans
│   ├── MonthView.swift             # 6×7-Grid + Multi-Day-Overlay
│   ├── EventDetailSheet.swift      # Read-only Detail + Edit/Delete
│   ├── EventEditorSheet.swift      # Create / Edit / ATOLL-Readonly
│   ├── SettingsView.swift          # Source-Toggles + Account
│   └── Components/
│       ├── EventBar.swift          # 3-Tier-Rendering (Glass/Flat/Compact)
│       ├── TimeAxisGrid.swift      # 24h-Achse mit scrollPosition(id:)
│       └── NowIndicator.swift      # Rote Linie + Glass-Time-Pill
```

Stores werden in `AtollCalApp` initialisiert und via `.environment(...)`
durchgereicht. Stateful Storage:

- `@AppStorage("calendarViewKind")` — Day/Week/Month, persistent
- `@AppStorage("enabledCalendarIds")` — JSON-Set, persistent
- `@AppStorage("atollEnabled")` — Bool, persistent
- `@SceneStorage("focusedDateInterval")` — pro Scene/Fenster eigenes Datum
