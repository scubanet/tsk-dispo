# ComHub Design D1 — Design-System + Shell + Heute Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ComHub bekommt den **CoHub-Mockup-Look** (Apple/macOS-HIG, Light **und** Dark): eine ComHub-lokale Design-Schicht (Theme-Token + Primitive `CoCard`/`CoAvatar`/`CoChip`/`CoCountBadge`), eine **restylte Sidebar** (modul-farbige Icons, Count-Badge-Fähigkeit, Trenner vor Einstellungen, User-Footer) und ein **neu gebautes Heute-Modul** im Mockup-Layout (Begrüssung + „Heutiger Tagesablauf"-Karte + 3 Vorschau-Widgets Aufgaben/Kombox/CardInbox).

**Architecture:** Reine, testbare Helfer (`Initials`, `AvatarPalette`, `Greeting`) wandern nach `AtollHub` (TDD). Die SwiftUI-Design-Schicht liegt **ComHub-lokal** unter `ComHub/Design/` (NICHT in `AtollDesign` — das teilt AtollCal/AtollCard mit anderem Look): semantische Farben (Akzent via `AccentColor`-Asset light/dark; Grautöne via System-`.primary/.secondary/.tertiary`; Modul-Farben als `CoColor.module(_:)`), plus Primitive. Die Sidebar in `HubShell` wird neu gestylt; `CockpitView` (Heute) wird auf das Mockup-Layout umgebaut und nutzt die Primitive. Quelle der exakten Masse/Farben: `docs/superpowers/specs/2026-06-02-comhub-design-system.md`.

**Tech Stack:** Swift 6 (strict concurrency complete), SwiftUI Multiplatform (iOS 26 / macOS 26), XcodeGen, XCTest. Reuse: `ComHubModule`, `CockpitStore`, `UnifiedEvent`/`UnifiedTask`, `KomboxStore`/`KomboxMapper`/`KomboxDigest` (für das Kombox-Widget), `AuthState.currentUser` (Name/Begrüssung).

---

## Scope-Grenzen (bewusst)

- **D1 = Fundament + Heute.** Restyle von Kalender/Kombox/Kontakte folgt in D2; Aufgaben/CardInbox werden in Phase 4 direkt im neuen Look gebaut.
- **Kein Fake-Fenster-Chrome.** Traffic-Lights, Wallpaper, Titlebar-Leiste, „Tweaks"-Panel aus dem Prototyp werden **nicht** nachgebaut — ComHub ist ein echtes macOS/iOS-Fenster (native Chrome). Die `NavigationSplitView` liefert Sidebar-Toggle + Fenstertitel nativ.
- **Light + Dark** über System-`colorScheme` (Asset-Colorsets + semantische Farben), kein In-App-Umschalter. Dichte = „regular" fest (compact/comfy entfallen).
- **Sidebar-Badges:** Die Badge-**Darstellung** kommt jetzt; die **Werte** werden über einen injizierten `[ComHubModule: Int]`-Dictionary gespeist, der vorerst leer ist (echte Counts liefern die jeweiligen Phasen — Kombox/Aufgaben/CardInbox). Kein spekulatives Cross-Modul-Daten-Plumbing.
- **Heute-Widgets:** Termine + Aufgaben aus `CockpitStore` (live/verdrahtet). Kombox-Widget = jüngste Konversationen (neue Store-Methode). CardInbox-Widget = Empty-State (Phase 4). „ungelesene"-Zähler in der Begrüssung = Anzahl Kombox-Konversationen-Vorschau (kein echtes unread im Schema — Wortlaut „neue" statt „ungelesene").

---

## File Structure

**Geändertes Paket — `swift-packages/AtollHub/`:**
- `Sources/AtollHub/Design/Initials.swift` — `Initials.from(_:)`.
- `Sources/AtollHub/Design/AvatarPalette.swift` — `AvatarPalette.index(for:count:)`.
- `Sources/AtollHub/Design/Greeting.swift` — `Greeting.phrase(forHour:)`.
- `Tests/AtollHubTests/DesignHelpersTests.swift`.

**Neue App-Dateien — `apps/comhub-native/ComHub/Design/`:**
- `CoColor.swift` — Akzent, Modul-Farben, semantische Helfer.
- `CoTheme.swift` — Radii, Card-Shadow-Konstanten, Avatar-Palette-Hex.
- `CoCard.swift` — Karten-Container.
- `CoAvatar.swift` — Initialen-Avatar mit Gradient.
- `CoChip.swift` — `CoChip` (grau / farbiger Punkt) + `CoCountBadge`.

**Geänderte App-Dateien:**
- `ComHub/Assets.xcassets/AccentColor.colorset/Contents.json` — Akzent light `#007AFF` / dark `#0A84FF`.
- `ComHub/Shell/HubShell.swift` — Sidebar neu (Icons farbig, Badges, Footer).
- `ComHub/Cockpit/CockpitStore.swift` — jüngste Kombox-Konversationen ergänzen.
- `ComHub/Cockpit/CockpitView.swift` — Heute-Layout neu (Begrüssung + Agenda + Widgets).

**Doku:**
- `apps/comhub-native/README.md` — Design-D1-Zeile.

---

## Task 1: Reine Design-Helfer (AtollHub, TDD)

**Files:**
- Create: `swift-packages/AtollHub/Sources/AtollHub/Design/Initials.swift`
- Create: `swift-packages/AtollHub/Sources/AtollHub/Design/AvatarPalette.swift`
- Create: `swift-packages/AtollHub/Sources/AtollHub/Design/Greeting.swift`
- Test: `swift-packages/AtollHub/Tests/AtollHubTests/DesignHelpersTests.swift`

- [ ] **Step 1: Failing Test schreiben**

`swift-packages/AtollHub/Tests/AtollHubTests/DesignHelpersTests.swift`:

```swift
import XCTest
@testable import AtollHub

final class DesignHelpersTests: XCTestCase {
  func test_initials_firstAndLast() {
    XCTAssertEqual(Initials.from("Anna Muster"), "AM")
  }
  func test_initials_singleWordTakesTwoLetters() {
    XCTAssertEqual(Initials.from("Lumen"), "LU")
  }
  func test_initials_stripsNonLettersAndEmptyIsQuestion() {
    XCTAssertEqual(Initials.from("  "), "?")
    XCTAssertEqual(Initials.from("Tauchschule Z (GmbH)"), "TZ")
  }

  func test_avatarPalette_isDeterministicAndInRange() {
    let a = AvatarPalette.index(for: "Anna Muster", count: 10)
    let b = AvatarPalette.index(for: "Anna Muster", count: 10)
    XCTAssertEqual(a, b)
    XCTAssertTrue((0..<10).contains(a))
  }
  func test_avatarPalette_differsByName() {
    // Nicht garantiert verschieden, aber fuer diese zwei Namen erwartet.
    XCTAssertNotEqual(AvatarPalette.index(for: "Anna", count: 10),
                      AvatarPalette.index(for: "Ben", count: 10))
  }

  func test_greeting_byHour() {
    XCTAssertEqual(Greeting.phrase(forHour: 7), "Guten Morgen")
    XCTAssertEqual(Greeting.phrase(forHour: 13), "Guten Tag")
    XCTAssertEqual(Greeting.phrase(forHour: 20), "Guten Abend")
  }
}
```

- [ ] **Step 2: Test ausführen — soll fehlschlagen**

Run: `cd swift-packages/AtollHub && swift test --filter DesignHelpersTests`
Expected: FAIL — `cannot find 'Initials' in scope`.

- [ ] **Step 3: Implementieren**

`swift-packages/AtollHub/Sources/AtollHub/Design/Initials.swift`:

```swift
import Foundation

/// Initialen aus einem Namen: erster + letzter Buchstabe; ein Wort → erste zwei;
/// leer/ohne Buchstaben → „?". Nicht-Buchstaben werden ignoriert.
public enum Initials {
  public static func from(_ name: String) -> String {
    let parts = name
      .components(separatedBy: CharacterSet.letters.inverted)
      .filter { !$0.isEmpty }
    guard let first = parts.first else { return "?" }
    if parts.count == 1 {
      return String(first.prefix(2)).uppercased()
    }
    let last = parts[parts.count - 1]
    return (String(first.prefix(1)) + String(last.prefix(1))).uppercased()
  }
}
```

`swift-packages/AtollHub/Sources/AtollHub/Design/AvatarPalette.swift`:

```swift
import Foundation

/// Deterministischer Palettenindex aus einem Namen (gleicher String → gleicher
/// Index). Spiegelt die Hash-Logik des Mockups (`h = h*31 + char`).
public enum AvatarPalette {
  public static func index(for name: String, count: Int) -> Int {
    guard count > 0 else { return 0 }
    var h: UInt32 = 0
    for scalar in name.unicodeScalars {
      h = h &* 31 &+ scalar.value
    }
    return Int(h % UInt32(count))
  }
}
```

`swift-packages/AtollHub/Sources/AtollHub/Design/Greeting.swift`:

```swift
import Foundation

/// Tageszeit-Begrüssung. < 11 Morgen, < 17 Tag, sonst Abend.
public enum Greeting {
  public static func phrase(forHour hour: Int) -> String {
    if hour < 11 { return "Guten Morgen" }
    if hour < 17 { return "Guten Tag" }
    return "Guten Abend"
  }
}
```

- [ ] **Step 4: Test ausführen — soll grün sein**

Run: `cd swift-packages/AtollHub && swift test --filter DesignHelpersTests`
Expected: PASS — 6 Tests grün.

- [ ] **Step 5: Volle Paket-Suite + Commit**

Run: `cd swift-packages/AtollHub && swift test`
Expected: PASS — alle Suiten grün.

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add swift-packages/AtollHub/Sources/AtollHub/Design swift-packages/AtollHub/Tests/AtollHubTests/DesignHelpersTests.swift
git commit -m "AtollHub: Design-Helfer (Initials, AvatarPalette, Greeting) rein/getestet"
```

---

## Task 2: Akzent-Asset + `CoColor` + `CoTheme` (ComHub)

**Files:**
- Modify: `apps/comhub-native/ComHub/Assets.xcassets/AccentColor.colorset/Contents.json`
- Create: `apps/comhub-native/ComHub/Design/CoColor.swift`
- Create: `apps/comhub-native/ComHub/Design/CoTheme.swift`

- [ ] **Step 1: AccentColor-Asset auf Systemblau (light/dark) setzen**

`apps/comhub-native/ComHub/Assets.xcassets/AccentColor.colorset/Contents.json` (ganzen Inhalt ersetzen):

```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : { "red" : "0x00", "green" : "0x7A", "blue" : "0xFF", "alpha" : "1.000" }
      },
      "idiom" : "universal"
    },
    {
      "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ],
      "color" : {
        "color-space" : "srgb",
        "components" : { "red" : "0x0A", "green" : "0x84", "blue" : "0xFF", "alpha" : "1.000" }
      },
      "idiom" : "universal"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

- [ ] **Step 2: `CoColor` schreiben** — Modul-Farben + semantische Helfer

`apps/comhub-native/ComHub/Design/CoColor.swift`:

```swift
import SwiftUI
import AtollHub

/// Farb-Palette von ComHub (CoHub-Mockup). Akzent kommt aus dem
/// `AccentColor`-Asset (light/dark). Grautöne nutzen System-Semantik
/// (`.primary/.secondary/.tertiary`), die sich automatisch an Light/Dark
/// anpassen. Modul-Icons tragen je eine eigene Tönung.
enum CoColor {
  static let accent = Color.accentColor

  /// Modul-Akzentfarbe (Sidebar-Icon + Heute-Widget-Header).
  static func module(_ module: ComHubModule) -> Color {
    switch module {
    case .heute:         return Color(red: 1.00, green: 0.62, blue: 0.04) // #FF9F0A
    case .kalender:      return Color(red: 1.00, green: 0.27, blue: 0.23) // #FF453A
    case .kombox:        return Color(red: 0.20, green: 0.78, blue: 0.35) // #34C759
    case .kontakte:      return Color(red: 0.56, green: 0.56, blue: 0.58) // #8E8E93
    case .tasks:         return Color(red: 1.00, green: 0.62, blue: 0.04) // #FF9F0A
    case .cardInbox:     return Color(red: 0.75, green: 0.35, blue: 0.95) // #BF5AF2
    case .einstellungen: return Color(red: 0.56, green: 0.56, blue: 0.58) // #8E8E93
    }
  }

  /// 10-Farb-Avatar-Palette (Mockup `window.AV`).
  static let avatar: [Color] = [
    Color(red: 0.37, green: 0.61, blue: 1.00), // #5E9CFF
    Color(red: 1.00, green: 0.42, blue: 0.42), // #FF6B6B
    Color(red: 0.20, green: 0.78, blue: 0.35), // #34C759
    Color(red: 1.00, green: 0.62, blue: 0.04), // #FF9F0A
    Color(red: 0.75, green: 0.35, blue: 0.95), // #BF5AF2
    Color(red: 0.04, green: 0.52, blue: 1.00), // #0A84FF
    Color(red: 1.00, green: 0.27, blue: 0.23), // #FF453A
    Color(red: 0.19, green: 0.84, blue: 0.78), // #30D5C8
    Color(red: 1.00, green: 0.45, blue: 0.66), // #FF73A8
    Color(red: 0.64, green: 0.52, blue: 0.37), // #A3845E
  ]

  /// Deterministische Avatar-Farbe für einen Namen.
  static func avatarColor(for name: String) -> Color {
    avatar[AvatarPalette.index(for: name, count: avatar.count)]
  }
}
```

> Hinweis: Die Hex-Werte der Avatar-Palette sind Platzhalter nach dem Mockup-Charakter
> (10 kräftige Töne). Falls die Design-Spec `docs/superpowers/specs/2026-06-02-comhub-design-system.md`
> exakte `window.AV`-Werte nennt, diese übernehmen.

- [ ] **Step 3: `CoTheme` schreiben** — Masse + Schatten

`apps/comhub-native/ComHub/Design/CoTheme.swift`:

```swift
import SwiftUI

/// Layout-Konstanten (Mockup-Token). Grautöne/Hintergründe via System-Semantik.
enum CoTheme {
  static let cardRadius: CGFloat = 16
  static let controlRadius: CGFloat = 8
  static let cardShadowColor = Color.black.opacity(0.06)
  static let cardShadowRadius: CGFloat = 10
  static let cardShadowY: CGFloat = 4
  static let separator = Color.primary.opacity(0.08)
}
```

- [ ] **Step 4: Build verifizieren**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Assets.xcassets/AccentColor.colorset/Contents.json apps/comhub-native/ComHub/Design/CoColor.swift apps/comhub-native/ComHub/Design/CoTheme.swift
git commit -m "ComHub: Design-Tokens (Systemblau-Akzent light/dark, Modul-/Avatar-Farben, CoTheme)"
```

---

## Task 3: Design-Primitive `CoCard` / `CoAvatar` / `CoChip` / `CoCountBadge` (ComHub)

**Files:**
- Create: `apps/comhub-native/ComHub/Design/CoCard.swift`
- Create: `apps/comhub-native/ComHub/Design/CoAvatar.swift`
- Create: `apps/comhub-native/ComHub/Design/CoChip.swift`

- [ ] **Step 1: `CoCard` schreiben**

`apps/comhub-native/ComHub/Design/CoCard.swift`:

```swift
import SwiftUI

/// Karten-Container im Mockup-Stil: content-bg, Hairline-Rahmen, weicher Schatten.
struct CoCard<Content: View>: View {
  @ViewBuilder var content: () -> Content
  var body: some View {
    content()
      .background(.background, in: RoundedRectangle(cornerRadius: CoTheme.cardRadius))
      .overlay(
        RoundedRectangle(cornerRadius: CoTheme.cardRadius)
          .strokeBorder(CoTheme.separator, lineWidth: 1)
      )
      .shadow(color: CoTheme.cardShadowColor, radius: CoTheme.cardShadowRadius,
              x: 0, y: CoTheme.cardShadowY)
  }
}
```

- [ ] **Step 2: `CoAvatar` schreiben**

`apps/comhub-native/ComHub/Design/CoAvatar.swift`:

```swift
import SwiftUI
import AtollHub

/// Runder Initialen-Avatar mit Farb-Gradient (deterministisch aus dem Namen).
struct CoAvatar: View {
  let name: String
  var size: CGFloat = 34
  var color: Color? = nil

  var body: some View {
    let base = color ?? CoColor.avatarColor(for: name)
    Circle()
      .fill(LinearGradient(colors: [base, base.opacity(0.78)],
                           startPoint: .topLeading, endPoint: .bottomTrailing))
      .frame(width: size, height: size)
      .overlay(
        Text(Initials.from(name))
          .font(.system(size: size * 0.4, weight: .semibold))
          .foregroundStyle(.white)
      )
  }
}
```

- [ ] **Step 3: `CoChip` + `CoCountBadge` schreiben**

`apps/comhub-native/ComHub/Design/CoChip.swift`:

```swift
import SwiftUI

/// Kleines Label: grau (Default) oder mit farbigem Punkt + Tönung.
struct CoChip: View {
  let text: String
  var color: Color? = nil

  var body: some View {
    HStack(spacing: 5) {
      if let color {
        Circle().fill(color).frame(width: 6, height: 6)
      }
      Text(text)
        .font(.system(size: 11, weight: .medium))
    }
    .padding(.horizontal, 7)
    .frame(height: 18)
    .foregroundStyle(color ?? .secondary)
    .background(color == nil ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear),
                in: RoundedRectangle(cornerRadius: 6))
    .overlay(
      RoundedRectangle(cornerRadius: 6)
        .strokeBorder(color?.opacity(0.33) ?? .clear, lineWidth: color == nil ? 0 : 1)
    )
  }
}

/// Zähl-Badge (Pille) für Sidebar/Widget-Header.
struct CoCountBadge: View {
  let count: Int
  var body: some View {
    Text("\(count)")
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(.secondary)
      .padding(.horizontal, 5)
      .frame(minWidth: 18, minHeight: 18)
      .background(.quaternary, in: Capsule())
  }
}
```

- [ ] **Step 4: Build verifizieren**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Design/CoCard.swift apps/comhub-native/ComHub/Design/CoAvatar.swift apps/comhub-native/ComHub/Design/CoChip.swift
git commit -m "ComHub: Design-Primitive (CoCard, CoAvatar, CoChip, CoCountBadge)"
```

---

## Task 4: Sidebar restylen — farbige Icons, Badges, Footer (ComHub)

**Files:**
- Modify: `apps/comhub-native/ComHub/Shell/HubShell.swift`

> Die Sidebar ist die `NavigationSplitView`-Seitenleiste. Wir ersetzen die einfache
> `List(ComHubModule.allCases)` durch farbige Modul-Zeilen mit optionalem Badge, einem
> Trenner vor `.einstellungen` und einem User-Footer. Badges kommen aus einem
> injizierten Dictionary (vorerst leer). Der Footer-Name kommt aus `AuthState`.

- [ ] **Step 1: `HubShell` Sidebar-Closure ersetzen**

In `apps/comhub-native/ComHub/Shell/HubShell.swift`:

1. Import + Environment ergänzen. Oben sicherstellen:

```swift
import SwiftUI
import AtollHub
import AtollCore
```

2. In `struct HubShell` über `var body` eine Auth-Environment-Property + Badge-Quelle ergänzen:

```swift
  @Environment(AuthState.self) private var auth
  /// Badge-Zahlen je Modul (von Phasen gespeist; vorerst leer).
  private let badges: [ComHubModule: Int] = [:]
```

3. Den `NavigationSplitView { … }`-Sidebar-Closure (die `List(ComHubModule.allCases, selection:) { … }.navigationTitle("ComHub") … `) ersetzen durch:

```swift
    NavigationSplitView {
      VStack(spacing: 0) {
        List(selection: $selectedModule) {
          ForEach(ComHubModule.allCases.filter { $0 != .einstellungen }) { module in
            sidebarRow(module).tag(module)
          }
          Divider().padding(.vertical, 4)
          sidebarRow(.einstellungen).tag(ComHubModule.einstellungen)
        }
        .listStyle(.sidebar)

        Spacer(minLength: 0)
        sidebarFooter
      }
      .navigationTitle("ComHub")
      #if os(macOS)
      .frame(minWidth: 220)
      #endif
    } content: {
```

(Der Rest — `content:`/`detail:` — bleibt unverändert.)

4. Zwei Helfer-Views + ein computed property innerhalb von `HubShell` (vor dem schliessenden `}` der struct, nach `body`) einfügen:

```swift
  @ViewBuilder
  private func sidebarRow(_ module: ComHubModule) -> some View {
    HStack(spacing: 10) {
      Image(systemName: module.systemImage)
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(CoColor.module(module))
        .frame(width: 20)
      Text(module.title)
      Spacer(minLength: 0)
      if let n = badges[module], n > 0 { CoCountBadge(count: n) }
    }
  }

  private var sidebarFooter: some View {
    HStack(spacing: 9) {
      CoAvatar(name: footerName, size: 28)
      VStack(alignment: .leading, spacing: 1) {
        Text(footerName).font(.system(size: 12.5, weight: .semibold)).lineLimit(1)
        Text("ComHub Konto").font(.system(size: 10.5)).foregroundStyle(.tertiary)
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 14).padding(.vertical, 10)
  }

  private var footerName: String {
    if case .signedIn(let user) = auth.status { return user.name }
    return "ComHub"
  }
```

- [ ] **Step 2: Build verifizieren**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`. (`AuthState.status` `.signedIn(currentUser:)` + `CurrentUser.name` existieren aus Phase 0/1.)

- [ ] **Step 3: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Shell/HubShell.swift
git commit -m "ComHub: Sidebar im CoHub-Look (farbige Icons, Badges, User-Footer)"
```

---

## Task 5: `CockpitStore` um jüngste Kombox-Konversationen erweitern (ComHub)

**Files:**
- Modify: `apps/comhub-native/ComHub/Cockpit/CockpitStore.swift`

> Das Heute-Kombox-Widget zeigt die jüngsten Konversationen. Wir laden sie im
> `CockpitStore` über dieselbe `contact_events`-Abfrage + `KomboxMapper/Digest`
> wie der `KomboxStore`.

- [ ] **Step 1: Import + Property + Lade-Code ergänzen**

In `apps/comhub-native/ComHub/Cockpit/CockpitStore.swift`:

1. Imports sicherstellen (oben): `import Supabase` zusätzlich zu den bestehenden (`Foundation`, `Observation`, `AtollHub`). Falls `AtollCore` nicht importiert ist und `SupabaseClient.shared` fehlt, `import AtollCore` ergänzen.

2. Neue Property neben den bestehenden `private(set)`-Feldern:

```swift
  private(set) var recentConversations: [KomboxConversation] = []
```

3. Eine Lade-Methode (innerhalb der Klasse) ergänzen:

```swift
  private static let komboxSelect =
    "id, contact_id, event_type, occurred_at, summary, body, payload, status, " +
    "contacts!inner(id, kind, first_name, last_name, trading_name, legal_name)"

  func reloadRecentConversations(using supabase: SupabaseClient = .shared) async {
    do {
      let rows: [KomboxEventRow] = try await supabase
        .from("contact_events")
        .select(Self.komboxSelect)
        .order("occurred_at", ascending: false)
        .limit(100)
        .execute()
        .value
      recentConversations = Array(
        KomboxDigest.conversations(from: KomboxMapper.events(from: rows)).prefix(3)
      )
    } catch {
      // leise — das Widget zeigt sonst Empty-State
    }
  }
```

4. Im bestehenden `reload(using hub:)` am Ende (vor `loading = false`) den Aufruf ergänzen:

```swift
    await reloadRecentConversations()
```

> Falls `SupabaseClient` `import AtollCore` braucht: ergänze den Import oben.
> `KomboxEventRow`/`KomboxMapper`/`KomboxDigest`/`KomboxConversation` stammen aus `AtollHub`.

- [ ] **Step 2: Build verifizieren**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Cockpit/CockpitStore.swift
git commit -m "ComHub: CockpitStore laedt juengste Kombox-Konversationen (Heute-Widget)"
```

---

## Task 6: Heute (`CockpitView`) im Mockup-Layout neu bauen (ComHub)

**Files:**
- Modify: `apps/comhub-native/ComHub/Cockpit/CockpitView.swift` (ganzen Inhalt ersetzen)

- [ ] **Step 1: `CockpitView` ersetzen**

`apps/comhub-native/ComHub/Cockpit/CockpitView.swift`:

```swift
import SwiftUI
import AtollCore
import AtollHub

/// Heute-Cockpit im CoHub-Look: Begrüssung + „Heutiger Tagesablauf"-Karte +
/// Vorschau-Widgets (Aufgaben/Kombox/CardInbox). Sektionen verlinken ins Modul.
struct CockpitView: View {
  @Environment(Hub.self) private var hub
  @Environment(AuthState.self) private var auth
  @State private var store = CockpitStore()

  let onOpenModule: (ComHubModule) -> Void

  private static let dateHeader: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "EEEE, d. MMMM yyyy"
    f.locale = Locale(identifier: "de_CH")
    f.timeZone = TimeZone(identifier: "Europe/Zurich"); return f
  }()
  private static let time: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "HH:mm"
    f.timeZone = TimeZone(identifier: "Europe/Zurich"); return f
  }()

  private var firstName: String {
    if case .signedIn(let u) = auth.status, !u.firstName.isEmpty { return u.firstName }
    return ""
  }
  private var greeting: String {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
    return Greeting.phrase(forHour: cal.component(.hour, from: Date()))
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        greetingBlock
        layout
      }
      .padding(.horizontal, 34).padding(.vertical, 30)
      .frame(maxWidth: 1080, alignment: .leading)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .task(id: reloadKey) { await store.reload(using: hub) }
  }

  private var reloadKey: String {
    if case .signedIn(let u) = auth.status { return "in:\(u.id.uuidString)" }
    return "out"
  }

  private var greetingBlock: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(Self.dateHeader.string(from: Date()).uppercased())
        .font(.system(size: 13, weight: .semibold)).foregroundStyle(CoColor.accent)
      Text(firstName.isEmpty ? "\(greeting)." : "\(greeting), \(firstName).")
        .font(.system(size: 30, weight: .heavy))
      summaryLine
    }
  }

  private var summaryLine: some View {
    let nEv = store.todayEvents.count
    let nTasks = store.openTasks.count
    let nMsg = store.recentConversations.count
    return (
      Text("Du hast ")
      + Text("\(nEv) Termine").bold()
      + Text(", ")
      + Text("\(nTasks) Aufgaben").bold()
      + Text(" und ")
      + Text("\(nMsg) neue").bold()
      + Text(" Nachrichten heute.")
    )
    .font(.system(size: 15)).foregroundStyle(.secondary)
  }

  private var layout: some View {
    HStack(alignment: .top, spacing: 18) {
      agendaCard.frame(maxWidth: .infinity)
      VStack(spacing: 18) {
        tasksWidget
        komboxWidget
        cardInboxWidget
      }
      .frame(width: 320)
    }
  }

  // MARK: – Agenda

  private var agendaCard: some View {
    CoCard {
      VStack(alignment: .leading, spacing: 0) {
        Button { onOpenModule(.kalender) } label: {
          HStack(spacing: 9) {
            Image(systemName: "calendar").foregroundStyle(CoColor.module(.kalender))
            Text("Heutiger Tagesablauf").font(.system(size: 15, weight: .bold))
            Spacer()
          }
          .padding(.horizontal, 18).padding(.top, 15).padding(.bottom, 12)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if store.todayEvents.isEmpty {
          Text("Keine Termine heute").font(.callout).foregroundStyle(.secondary)
            .padding(.horizontal, 18).padding(.bottom, 18)
        } else {
          VStack(spacing: 0) {
            ForEach(Array(store.todayEvents.enumerated()), id: \.element.id) { i, ev in
              agendaRow(ev, showDivider: i > 0)
            }
          }
          .padding(.horizontal, 18).padding(.bottom, 18)
        }
      }
    }
  }

  private func agendaRow(_ ev: UnifiedEvent, showDivider: Bool) -> some View {
    HStack(spacing: 14) {
      VStack(alignment: .trailing, spacing: 0) {
        Text(ev.isAllDay ? "—" : Self.time.string(from: ev.start))
          .font(.system(size: 13.5, weight: .bold)).foregroundStyle(.primary)
        if !ev.isAllDay {
          Text(Self.time.string(from: ev.end)).font(.system(size: 11)).foregroundStyle(.tertiary)
        }
      }
      .frame(width: 46, alignment: .trailing)
      RoundedRectangle(cornerRadius: 3)
        .fill(ev.source.type == .atoll ? CoColor.accent : Color.secondary)
        .frame(width: 4).frame(minHeight: 34)
      VStack(alignment: .leading, spacing: 1) {
        Text(ev.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
        if let loc = ev.location, !loc.isEmpty {
          Label(loc, systemImage: "mappin").font(.system(size: 12)).foregroundStyle(.tertiary)
        }
      }
      Spacer(minLength: 0)
    }
    .padding(.vertical, 10)
    .overlay(alignment: .top) {
      if showDivider { Divider() }
    }
  }

  // MARK: – Widgets

  private func widgetCard<Content: View>(_ module: ComHubModule, title: String, icon: String,
                                         count: Int, @ViewBuilder content: () -> Content) -> some View {
    CoCard {
      VStack(alignment: .leading, spacing: 0) {
        Button { onOpenModule(module) } label: {
          HStack(spacing: 9) {
            Image(systemName: icon).foregroundStyle(CoColor.module(module))
            Text(title).font(.system(size: 14, weight: .bold))
            Spacer()
            Text("\(count)").font(.system(size: 12, weight: .semibold)).foregroundStyle(.tertiary)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
          }
          .padding(.horizontal, 16).padding(.top, 13).padding(.bottom, 10)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        VStack(alignment: .leading, spacing: 0) { content() }
          .padding(.horizontal, 16).padding(.bottom, 14)
      }
    }
  }

  private var tasksWidget: some View {
    widgetCard(.tasks, title: "Aufgaben heute", icon: "checklist", count: store.openTasks.count) {
      if store.openTasks.isEmpty {
        Text("Keine Aufgaben fällig 🎉").font(.system(size: 12.5)).foregroundStyle(.tertiary).padding(.vertical, 4)
      } else {
        ForEach(store.openTasks.prefix(4)) { task in
          HStack(spacing: 9) {
            Circle().strokeBorder(.tertiary, lineWidth: 1.8).frame(width: 16, height: 16)
            Text(task.title).font(.system(size: 13)).lineLimit(1)
            Spacer(minLength: 0)
          }
          .padding(.vertical, 6)
        }
      }
    }
  }

  private var komboxWidget: some View {
    widgetCard(.kombox, title: "Kombox", icon: "bubble.left.and.bubble.right",
               count: store.recentConversations.count) {
      if store.recentConversations.isEmpty {
        Text("Keine neuen Nachrichten").font(.system(size: 12.5)).foregroundStyle(.tertiary).padding(.vertical, 4)
      } else {
        ForEach(store.recentConversations.prefix(3)) { conv in
          HStack(spacing: 10) {
            CoAvatar(name: conv.contactName, size: 30)
            VStack(alignment: .leading, spacing: 1) {
              Text(conv.contactName).font(.system(size: 13, weight: .semibold)).lineLimit(1)
              Text(conv.lastEvent.kind == .email ? (conv.lastEvent.subject ?? conv.lastEvent.summary)
                                                  : (conv.lastEvent.body ?? conv.lastEvent.summary))
                .font(.system(size: 12)).foregroundStyle(.tertiary).lineLimit(1)
            }
            Spacer(minLength: 0)
            Text(conv.lastEvent.kind == .email ? "Mail" : (conv.lastEvent.kind == .whatsapp ? "WhatsApp" : "Log"))
              .font(.system(size: 11, weight: .semibold))
              .foregroundStyle(conv.lastEvent.kind == .whatsapp ? CoColor.module(.kombox) : CoColor.accent)
          }
          .padding(.vertical, 7)
        }
      }
    }
  }

  private var cardInboxWidget: some View {
    widgetCard(.cardInbox, title: "CardInbox", icon: "tray.and.arrow.down", count: 0) {
      Text("Noch keine neuen Leads").font(.system(size: 12.5)).foregroundStyle(.tertiary).padding(.vertical, 4)
    }
  }
}
```

- [ ] **Step 2: Generieren + Build**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Manueller Smoke-Test** (echter Mac, Light + Dark)

- [ ] **Heute** zeigt: Datum (uppercase, blau) · „Guten {Tageszeit}, {Vorname}." · Summenzeile mit fetten Zahlen.
- [ ] Links Karte „Heutiger Tagesablauf" mit Zeit · Farbbalken · Titel · Ort; leer → „Keine Termine heute".
- [ ] Rechts 3 Karten: Aufgaben (oder „Keine Aufgaben fällig 🎉"), Kombox (jüngste Konversationen mit Avatar + Kanal-Label, oder Empty), CardInbox (Empty).
- [ ] Klick auf Karten-Kopf wechselt ins Modul.
- [ ] **Dark Mode** (System auf Dunkel): Karten/Text/Akzent passen sich an, lesbar.
- [ ] Sidebar: farbige Modul-Icons, Trenner vor Einstellungen, Footer mit Avatar + Name + „ComHub Konto".

- [ ] **Step 4: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Cockpit/CockpitView.swift
git commit -m "ComHub: Heute im CoHub-Look (Begruessung + Tagesablauf-Karte + Widgets)"
```

---

## Task 7: Dokumentation (Design D1)

**Files:**
- Modify: `apps/comhub-native/README.md`

- [ ] **Step 1: Design-Zeile ergänzen**

In `apps/comhub-native/README.md` im Abschnitt `## Phasen-Stand` **nach** dem `**Phase 3a** …`-Absatz einfügen:

```markdown

**Design D1** — CoHub-Mockup-Look: ComHub-lokale Design-Schicht (`ComHub/Design/`:
`CoColor`/`CoTheme`/`CoCard`/`CoAvatar`/`CoChip`), Systemblau-Akzent (light/dark),
restylte **Sidebar** (modul-farbige Icons, Count-Badges, User-Footer) und ein neu
gebautes **Heute** (Begrüssung + „Heutiger Tagesablauf"-Karte + Vorschau-Widgets).
Reine Helfer getestet in `AtollHub` (`Initials`/`AvatarPalette`/`Greeting`).
Referenz: `docs/superpowers/specs/2026-06-02-comhub-design-system.md`. Restyle
Kalender/Kombox/Kontakte folgt in D2; Aufgaben/CardInbox in Phase 4 direkt im Look.
```

- [ ] **Step 2: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/README.md
git commit -m "Docs: ComHub-README Design-D1 (System + Shell + Heute)"
```

---

## Self-Review (durchgeführt)

**1. Spec-Abdeckung (Design-Mockup, Slice D1 = System + Shell + Heute):**
- Tokens (Akzent light/dark, Modul-/Avatar-Farben, Card-Radius/Shadow) → Task 2 (`CoColor`/`CoTheme` + AccentColor-Asset).
- Primitive (Card, Avatar mit Initialen/Hash-Farbe, Chip, Count-Badge) → Task 1 (reine Logik) + Task 3 (SwiftUI).
- Shell (Sidebar: farbige Icons, Badges, Trenner, User-Footer) → Task 4.
- Heute (Begrüssung + Agenda-Karte + 3 Widgets) → Task 5 (Daten) + Task 6 (View).
- Light + Dark → System-`colorScheme` + Asset-Colorset (Task 2), Smoke-Test prüft Dark (Task 6).
- Bewusst D2/Phase 4: Restyle Kalender/Kombox/Kontakte, Module Aufgaben/CardInbox (Scope-Grenze).

**2. Platzhalter-Scan:** Keine „TBD/TODO". Vollständiger Code je Schritt; Befehl + erwartete Ausgabe je Run. Avatar-Palette-Hex als „nach Mockup, exakte Werte aus Spec übernehmen" markiert (kein Loch — funktioniert, nur Feinabgleich).

**3. Typ-Konsistenz:**
- `Initials.from(_:)`, `AvatarPalette.index(for:count:)`, `Greeting.phrase(forHour:)` (Task 1) ↔ `CoColor.avatarColor` (Task 2), `CoAvatar` (Task 3), `CockpitView.greeting` (Task 6). ✔
- `CoColor.module(_:)`/`.accent`/`.avatarColor`, `CoTheme.*` (Task 2) ↔ `CoCard`/`CoAvatar`/`CoChip` (Task 3), Sidebar (Task 4), Heute (Task 6). ✔
- `CockpitStore.recentConversations` + `reloadRecentConversations` (Task 5) ↔ `komboxWidget` (Task 6). ✔
- Reuse: `ComHubModule` (Cases + `.title`/`.systemImage`), `CockpitStore.todayEvents/openTasks`, `Hub`, `AuthState.status`/`CurrentUser.name`/`.firstName`/`.id`, `KomboxEventRow`/`KomboxMapper`/`KomboxDigest`/`KomboxConversation`, `UnifiedEvent` — alle gegen den echten Code geprüft. ✔

**4. Verifikations-Disziplin:** Task 1 echte TDD (`swift test`). Tasks 2–6 build-verifiziert (`xcodegen generate` + `xcodebuild`); Task 6 schliesst mit manuellem Smoke-Test inkl. Dark Mode. Konform zu superpowers:verification-before-completion.

---

## Execution Handoff

**Plan komplett und gespeichert unter `docs/superpowers/plans/2026-06-02-comhub-designD1-system-shell-heute.md`. Zwei Ausführungs-Optionen:**

**1. Subagent-Driven (empfohlen)** — frischer Subagent pro Task, Review zwischen den Tasks. (REQUIRED SUB-SKILL: superpowers:subagent-driven-development.)

**2. Inline-Ausführung** — Tasks in dieser Session, Batch mit Checkpoints. (REQUIRED SUB-SKILL: superpowers:executing-plans.)

**Welcher Ansatz?**
