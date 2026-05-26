# AtollCard Lock-Screen Widget

**Status:** Draft (User-Review pending)
**Date:** 2026-05-26
**Author:** Dominik Weckherlin (with Claude/Larry)
**Spec Owner:** Dominik
**Target Release:** Welle D — Sub-Projekt 5 von 9 (Lock-Screen Widget)

---

## 1. Kontext & Problem

### Heutiger Zustand

Um die Public-Card-URL via QR zu teilen, öffnet Dominik heute:
1. AtollCard auf dem iPhone
2. Wählt eine Karte (oder Default ist schon offen)
3. Tippt auf "QR" oder "Vollbild öffnen"
4. Fullscreen-QR erscheint (Brightness-Boost greift)

Das sind 3-4 Taps + Apps-Switch — bei einem schnellen Pool-Side-Moment ("Hier, scan mal") zu langsam.

### Pain-Points

1. **App muss erst geöffnet sein.** Aus dem Lock-Screen sind das mehrere Sekunden Friction.
2. **Karten-Auswahl-Schritt** auch dann nötig wenn 99% der Fälle die Default-Karte (CD) gewünscht ist.
3. **Keine Always-On-Sichtbarkeit.** Die Karte ist immer "irgendwo in der App".

### Zielbild

Lock-Screen-Widget zeigt dauerhaft die **Default-Karte** mit Titel + Badge. Ein Tap → AtollCard öffnet direkt im **Fullscreen-QR-Screen** für diese Karte. Insgesamt **~2 Sekunden vom Sperrbildschirm zum QR** statt heutiger 5-10s.

---

## 2. Architektur-Entscheidung

**Lock-Screen-Widget zeigt Karten-Info, NICHT den QR selber.**

Begründung: Lock-Screen-Widgets rendern in iOS-vibrancy/tinted-Mode — alle Farben werden durch einen System-Filter geschickt. QR-Codes brauchen scharfe schwarz-weiss-Module für zuverlässige Scan-Rate; nach dem Filter wird das unzuverlässig. Stattdessen:

- Widget = "Hier ist deine Karte, tap me"
- Tap → app öffnet, Fullscreen-QR mit Brightness-Boost ist sofort sichtbar
- Resultat: gleiche Geschwindigkeit, perfekte Scan-Rate

**Daten-Sharing via App Group, nicht via Repository-Calls aus dem Widget.**

Begründung: Widget-Extension hat begrenzte Laufzeit (max ~30s pro Refresh) und keine Netz-Garantie. Direkter Supabase-Call wäre fragile + langsam. Stattdessen: App schreibt ein kleines JSON in den shared App Group Container immer wenn die Default-Karte sich ändert. Widget liest aus diesem JSON — sub-Millisekunden, ohne Netz.

**Refresh: reload-on-write, nicht Polling.**

Begründung: Default-Karte ändert sich selten. Ein Timeline-Polling-Schedule (z.B. alle 4h) wäre Verschwendung. Stattdessen ruft die App `WidgetCenter.shared.reloadAllTimelines()` punktuell auf, wenn der App-Group-File aktualisiert wurde.

---

## 3. Widget-Inhalt + Layout

### 3.1 Rectangular Lock-Screen Widget

`supportedFamilies: [.accessoryRectangular]` — keine circular/inline, keine Home-Screen-Variante in dieser Spec.

Layout (~158×54pt, tinted):

```
┌─────────────────────────────────────┐
│ 🌊  PADI Course Director · PADI CD  │
│     Tippen → QR                     │
└─────────────────────────────────────┘
```

Komponenten:
- **Links:** ATOLL-Glyph-Icon (24×24pt, monochrome, vibrancy-friendly — am besten ein SF-Symbol-ähnlicher Vector statt PNG)
- **Oben rechts:** `<title> · <badge>` (single-line, truncated mit ellipsis bei overflow)
- **Unten rechts:** "Tippen → QR" als Hint in 70% Opazität

### 3.2 Fallback-States

| State | Anzeige |
|---|---|
| Keine Default-Karte gesetzt | Icon · "AtollCard" · "Karte einrichten" |
| User nicht eingeloggt | Icon · "AtollCard" · "Karte einrichten" |
| Widget-First-Install (placeholder) | Icon · "AtollCard" · "Tippen → QR" |

### 3.3 Lokalisierung

MVP: deutsche Strings hardcoded. EN/FR kommt mit Welle E (Localization).

---

## 4. Daten-Sharing-Architektur

### 4.1 App Group

- Identifier: **`group.swiss.atoll.card`**
- Konfiguriert in Apple Developer Portal + beiden Bundle-IDs (`swiss.atoll.card` + `swiss.atoll.card.widget`)
- Entitlement-Eintrag in beiden `.entitlements`-Files:
  ```xml
  <key>com.apple.security.application-groups</key>
  <array>
    <string>group.swiss.atoll.card</string>
  </array>
  ```

### 4.2 Shared Snapshot Format

Datei: `<app-group-container>/default-card.json` (klein, ~300 Byte)

```typescript
struct SharedCardSnapshot: Codable, Sendable {
  let slug:           String      // "dominik-cd"
  let title:          String      // "PADI Course Director"
  let badge:          String?     // "PADI CD" — optional
  let personInitials: String      // "DW"
  let publicURL:      URL         // https://atoll-os.com/c/dominik-cd
  let updatedAt:      Date
}
```

`SharedCardSnapshot.swift` lebt in einem Code-File mit Target-Membership in BEIDEN Targets (App + Widget) — kein dupliziertes Modell, kein extra Swift Package nötig.

### 4.3 Write-Path (in der App)

Neues Service-File `apps/atollcard-native/AtollCard/Services/SharedCardSnapshotWriter.swift`:

```swift
import WidgetKit

enum SharedCardSnapshotWriter {
  static func write(_ snapshot: SharedCardSnapshot?) {
    let url = appGroupContainer().appendingPathComponent("default-card.json")
    if let snapshot {
      let data = try? JSONEncoder.iso8601.encode(snapshot)
      try? data?.write(to: url, options: .atomic)
    } else {
      try? FileManager.default.removeItem(at: url)
    }
    WidgetCenter.shared.reloadAllTimelines()
  }

  private static func appGroupContainer() -> URL {
    FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: Config.appGroupID)!
  }
}
```

### 4.4 Trigger-Points

Wann ruft die App `SharedCardSnapshotWriter.write(...)` auf:

| Stelle | Was wird geschrieben |
|---|---|
| `CardStore.refresh()` Ende | Default-Karte aus den geladenen Karten |
| `CardStore.upsert(card:)` | Wenn die geupsert-te Karte die Default ist |
| `CardStore.setDefault(cardId:)` | Die neue Default-Karte |
| `AtollCardApp .task` beim Launch | Initial-Fill |
| Logout / Account-Wechsel | `write(nil)` → File löschen, Widget-State zurück auf Fallback |

### 4.5 Read-Path (im Widget)

```swift
struct CardSnapshotProvider: TimelineProvider {
  func getTimeline(in context: Context, completion: @escaping (Timeline<CardSnapshotEntry>) -> Void) {
    let snapshot = loadFromAppGroup()
    let entry = CardSnapshotEntry(date: .now, snapshot: snapshot)
    completion(Timeline(entries: [entry], policy: .never))
  }

  private func loadFromAppGroup() -> SharedCardSnapshot? {
    let url = appGroupContainer().appendingPathComponent("default-card.json")
    guard let data = try? Data(contentsOf: url) else { return nil }
    return try? JSONDecoder.iso8601.decode(SharedCardSnapshot.self, from: data)
  }
}
```

---

## 5. Tap-Target + Deep-Link

Widget-View nutzt `Link(destination: ...)`:

```swift
struct LockScreenCardView: View {
  let entry: CardSnapshotEntry

  var body: some View {
    if let snapshot = entry.snapshot {
      Link(destination: URL(string: "atollcard://card/\(snapshot.slug)/qr")!) {
        widgetBody(snapshot)
      }
    } else {
      Link(destination: URL(string: "atollcard://")!) {
        fallbackBody
      }
    }
  }
  // widgetBody + fallbackBody unten
}
```

### 5.1 URL-Schema

Custom Scheme `atollcard://` ist schon in `Info.plist` registriert. Neu unterstützen:
- `atollcard://card/<slug>/qr` — Open Fullscreen-QR für diese Karte

### 5.2 Routing in AtollCardApp

`.onOpenURL` in `AtollCardApp.swift` existiert schon (Magic-Link-Auth-Callback). Erweitern:

```swift
.onOpenURL { url in
  // existing magic-link handling …
  if url.scheme == "atollcard",
     url.host == "card",
     let slug = url.pathComponents.dropFirst().first,
     url.pathComponents.last == "qr" {
    routeToFullscreenQR(slug: slug)
  }
}
```

`routeToFullscreenQR(slug:)` ist eine kleine Methode im AppRouter — findet die Karte via slug aus dem CardStore, setzt `presentingFullscreenQR = card` als State.

---

## 6. File-Inventar

### Neu

```
apps/atollcard-native/
├── AtollCardWidget/                                     NEU — Widget Extension Target
│   ├── AtollCardWidgetBundle.swift                      @main, registriert LockScreenCardWidget
│   ├── LockScreenCardWidget.swift                       Widget config + entry + provider + view
│   ├── Info.plist                                       NSExtension-Konfig
│   └── AtollCardWidget.entitlements                     App Group entitlement
├── AtollCard/
│   └── Services/
│       └── SharedCardSnapshotWriter.swift               write() + reloadAllTimelines()
└── AtollCardShared/                                     NEU — Cross-Target source folder
    └── SharedCardSnapshot.swift                         Codable struct, members both targets

docs/superpowers/runbooks/
└── 2026-05-26-atollcard-widget-welle-d-rollout.md       Schritt-für-Schritt Setup
```

### Geändert

```
apps/atollcard-native/
├── project.yml                                          + AtollCardWidget target, + AtollCardShared sources, + appGroupID build setting
├── AtollCard/
│   ├── AtollCard.entitlements                           + com.apple.security.application-groups
│   ├── Config.swift                                     + appGroupID constant
│   ├── AtollCardApp.swift                               + .onOpenURL atollcard://card/.../qr handling, + initial snapshot write in .task
│   ├── Repositories/CardStore.swift                     + writeSnapshot() calls in refresh/upsert/setDefault
│   └── Views/RootView.swift (or AppRouter)              + state for "show Fullscreen-QR for slug X"
└── CHANGELOG.md                                         + 0.11.0 Entry (Welle D Part 1)
```

### Test-Coverage

- `SharedCardSnapshotTests.swift` — Codable-Roundtrip (encode then decode produces identical struct, ISO-8601 dates preserved)
- `SharedCardSnapshotWriterTests.swift` — write+read against a tmpdir-mocked App-Group-Container; assert WidgetCenter.reloadAllTimelines() was called (via spy if testable, else just no-crash sanity)
- **Snapshot-Test** (Swift Snapshot Testing) — `LockScreenCardView` render-output für drei States (have-card, no-card, placeholder) bleibt visuell stabil
- **Manueller E2E** in Runbook: Widget aufs Lock-Screen, Default-Karte umschalten in App, sehe Widget-Update

---

## 7. Apple-Setup (einmalig, ~5 Min)

### 7.1 App Group registrieren

1. [developer.apple.com](https://developer.apple.com/account) → Identifiers → oben Dropdown auf **App Groups** → **+**
2. Description: `AtollCard shared container`
3. Identifier: `group.swiss.atoll.card`
4. Continue → Register

### 7.2 App Group beiden Bundle-IDs zuweisen

Bestehende `swiss.atoll.card` App-ID:
- Identifiers → klick auf `swiss.atoll.card` → Capabilities → **App Groups** anhaken → **Configure** → `group.swiss.atoll.card` ankreuzen → Save

Neue `swiss.atoll.card.widget` App-ID:
- Wenn Apple sie beim ersten Xcode-Build noch nicht automatisch angelegt hat: manuell registrieren (gleicher Flow). Dann App Groups → `group.swiss.atoll.card` ankreuzen.

### 7.3 Provisioning Profiles

Xcode refresht automatisch beim nächsten Build, wenn man eingeloggt ist im Apple ID des Developer Accounts.

---

## 8. Rollout-Plan

1. **Apple-Setup** (§7) — App Group registriert, beiden Bundle-IDs zugewiesen
2. **Code-Änderungen** in der App + neues Widget-Target via XcodeGen
3. **`xcodegen generate`** → öffnet Xcode mit neuem AtollCardWidget-Target
4. **Build aufs Real-Device** (Lock-Screen-Workflow nur auf Hardware testbar; Simulator zeigt Widget aber kein echter Lock-Screen)
5. **Widget zur Lock-Screen hinzufügen:** Long-Press auf Lock-Screen → **Anpassen** → **Sperrbildschirm** → unter der Uhr **+ Widget** → **AtollCard** → rectangular wählen
6. **End-to-End-Test:**
   - Default-Karte wird auf Lock-Screen-Widget sichtbar
   - Tap auf Widget → Phone unlocked → AtollCard öffnet → Fullscreen-QR ist offen
   - In App Default-Karte umschalten (Karten-Editor → Standard) → Widget zeigt innert ~1-2 Sekunden neue Karte

---

## 9. Out-of-Scope

- **Home-Screen Widget** (Frage 2 → nur Lock-Screen). Kommt separat wenn der Bedarf da ist.
- **Configuration-Intent** (Frage 4 → immer Default-Karte). Multi-Card-Selektion pro Widget-Instanz braucht ein eigenes Intent-Definition-File und ein Sub-Projekt
- **StandBy-Mode Widget** (das Quer-Display wenn iPhone horizontal lädt) — Nische, später
- **Live Activities / Dynamic Island** — keine Use Case für eine statische Karte
- **Widget-Lokalisierung EN/FR** — kommt mit Welle E
- **Push-based Widget-Refresh** (z.B. wenn Lead-Count steigt) — heute reload-on-write reicht; APNs-getriggertes Widget-Refresh wäre Phase 2

---

## 10. Open Risiken & Annahmen

1. **Vibrancy-Rendering des Glyph-Icons:** Auf Lock-Screen wird alles tinted. Das ATOLL-Glyph muss als reine Form (1 Farbe, hoher Kontrast) gestaltet sein. Wenn das aktuelle Logo zu grafisch ist, brauchen wir eine vereinfachte SF-Symbol-ähnliche Variante.
2. **App-Group-Identifier-Tippfehler:** klassischer Foot-Gun. Wenn der Identifier in einem der Targets falsch ist, schreibt die App ins App-Group aber Widget kann nicht lesen → Widget bleibt im Fallback-State ohne sichtbaren Fehler. Mitigation: Identifier als Konstante in `Config.swift`, in beiden Targets referenziert.
3. **WidgetCenter.reloadAllTimelines() Quota:** iOS drosselt Widget-Refreshes wenn zu häufig. Bei Default-Karten-Wechsel ist das selten — kein Problem für MVP. Falls später häufige Updates kommen (z.B. Lead-Count im Widget), `reloadTimelines(ofKind:)` mit selective Kind benutzen.
4. **Real-Device-Pflicht:** Echte Lock-Screen-Workflow ist nicht im Simulator nachstellbar. Tests im Simulator sind nur "rendert das Widget grundsätzlich".
5. **`AtollCardShared/` als Cross-Target-Source-Folder:** alternative wäre ein separates Swift Package `AtollCardShared`. Folder reicht für 1 File — wenn mehr Cross-Target-Code dazukommt, dann auf Package umstellen.

---

## 11. Akzeptanzkriterien

- [ ] AtollCardWidget Target baut sauber via `xcodegen generate` + `xcodebuild`
- [ ] Lock-Screen-Widget rectangular ist zur Lock-Screen hinzufügbar via Long-Press → +
- [ ] Widget zeigt aktuelle Default-Karten-Title + Badge
- [ ] Default-Karte in App umschalten → Widget zeigt innert ~2 Sekunden die neue Karte
- [ ] Widget-Tap unlockt iPhone + öffnet App + zeigt Fullscreen-QR der Default-Karte
- [ ] No-default-card State: Widget zeigt "AtollCard / Karte einrichten"
- [ ] Logout in App: Widget reset auf Fallback-State (File entfernt)
- [ ] Codable-Roundtrip Test grün
- [ ] Snapshot-Test für die 3 View-States grün

---

## 12. Referenzen

- [Apple WidgetKit Documentation](https://developer.apple.com/documentation/widgetkit)
- [Apple Lock Screen Widget Guidelines](https://developer.apple.com/design/human-interface-guidelines/widgets)
- [App Groups Documentation](https://developer.apple.com/documentation/xcode/configuring-app-groups)
- Bestehende `FullscreenQRView.swift` mit Brightness-Boost im AtollCard-Repo
- `AtollCardApp.swift` `.onOpenURL`-Handler (heute nur magic-link, wird erweitert)
- AtollCard CHANGELOG Architektur-Entscheid #7 (Custom-URL-Scheme statt Universal Links für jetzt)
