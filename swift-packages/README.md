# ATOLL Swift Packages

Geteilte Foundation-Module für die ATOLL App-Suite.

## Packages

- **AtollCore** — Auth (Magic-Link), Supabase-Client, Models, Locale-Handling.
  Konsumiert von: `apps/atoll-ios`, AtollCal (geplant), AtollLog (geplant).
- **AtollDesign** — Brand-Tokens (Farben), wiederverwendbare SwiftUI-Components
  (AvatarView, BrandHeader, RoleBadge, SkillChip, StatusChip, AtollLogo).
  Hängt von AtollCore ab (RoleBadge nutzt `AssignmentRole`, StatusChip nutzt `CourseStatus`).
  Konsumiert von: dieselben Apps wie AtollCore.
- **AtollHub** — anbieter-offener Kern für ComHub: quellneutrale Modelle
  (`UnifiedEvent/Message/Task/Contact`, `Lead`), Capability-Protokolle
  (`CalendarProvider`/`MailProvider`/`TodoProvider`/`ContactsProvider` +
  Atoll-spezifisch `CommsProvider`/`EventsProvider`/`CardInboxProvider`),
  der `Hub`-Aggregator über `AccountConnection`, sowie reine Hilfen
  (`ContactKey`, `ContactMatcher`, `ComHubModule`, `OTPCode`).
  Dependency-leicht (keine Supabase-Abhängigkeit) — Adapter implementieren die
  Protokolle in den Apps. Konsumiert von: `apps/comhub-native`.
  Tests: `cd swift-packages/AtollHub && swift test`.

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

## App-spezifische SupabaseConfig

`AtollCore.SupabaseClient.shared` initialisiert sich aus der vom App registrierten
`SupabaseConfig`-Implementation. Jede App liefert ihre eigene Config:

```swift
import Foundation
import AtollCore

enum Config {
  static let supabaseURL = URL(string: "https://...")!
  static let supabaseAnonKey = "..."
  static let authRedirectURL = URL(string: "yourapp://auth/callback")!
}

struct AppSupabaseConfig: SupabaseConfig {
  var supabaseURL: URL        { Config.supabaseURL }
  var supabaseAnonKey: String { Config.supabaseAnonKey }
  var authRedirectURL: URL    { Config.authRedirectURL }
}
```

Beim App-Start die Config registrieren — **vor** jedem Zugriff auf
`SupabaseClient.shared` (also bevor `AuthState.init()` läuft):

```swift
import SwiftUI
import AtollCore

@main
struct YourApp: App {
  @State private var auth: AuthState
  @State private var localeStore: LocaleStore

  init() {
    // MUSS vor State(initialValue: AuthState()) passieren — AuthState.init()
    // greift sofort auf SupabaseClient.shared zu, das die Config braucht.
    AtollCoreConfig.register(AppSupabaseConfig())
    _auth = State(initialValue: AuthState())
    _localeStore = State(initialValue: LocaleStore())
  }

  var body: some Scene { ... }
}
```

**Wichtig:** Default-Werte direkt am `@State` (`@State private var auth = AuthState()`)
laufen VOR `init()` und feuern den Crash. Daher das Pattern oben mit
`State(initialValue:)` im `init()`.

## Neuer Component oder Model in der Foundation?

Faustregel:
- Type wird von ≥ 2 Apps genutzt → Foundation-Package
- Type ist nur für eine App relevant → bleibt in der App

Beim Verschieben darauf achten:
- Top-level Types + extern genutzte Properties auf `public` heben
- SwiftUI-Views: explizite `public init(...)` schreiben (Swift's auto-synth ist internal)
- Model-Structs die manuell konstruiert werden: explizite `public init(...)` (Codable's
  auto-synth `init(from:)` reicht nicht für `MyType(field: value)`-Aufrufe)

## Tests

`AtollCore` hat ein Test-Target (`AtollCoreTests`). Run via:

```bash
cd swift-packages/AtollCore
swift test
```

`AtollDesign` hat aktuell keine Tests (Visual-Components → Snapshot-Tests wären
sinnvoll, sind aber nicht aufgesetzt).
