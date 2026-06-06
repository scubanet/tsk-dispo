# ComHub Phase 3c — Privat-WhatsApp (WebView-Tab) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ein eigenes **Privat-WhatsApp**-Modul in ComHub: WhatsApp Web (offizieller QR-Login) in einem `WKWebView`-Tab — **getrennt** von der Atoll-Kombox, nicht gemischt. Login überlebt App-Neustarts (persistenter Web-Datastore).

**Architecture:** Ein neues `ComHubModule.whatsapp` (AtollHub, UI-neutral) reiht sich in die Modul-Leiste. Im App-Target kapselt `WhatsAppWebView` (plattform-`Representable` um `WKWebView`) die offizielle WhatsApp-Web-Seite mit **Desktop-User-Agent** (sonst zeigt WhatsApp „Browser nicht unterstützt") und **persistentem `WKWebsiteDataStore.default()`** (Session/QR-Login bleibt erhalten). `WhatsAppModuleView` hostet den WebView plus eine kleine Toolbar (Neu laden). Verdrahtet in `HubShell` wie die übrigen Module. Kein Backend, keine Atoll-Daten — bewusst isoliert (Spec §7).

**Tech Stack:** Swift 6 (strict concurrency complete), SwiftUI Multiplatform (iOS 26 / macOS 26), WebKit (`WKWebView`/`WKWebViewConfiguration`/`WKWebsiteDataStore`), XcodeGen, XCTest. Reuse: `ComHubModule`, `HubShell`, `CoColor`. Entitlements: bestehende App-Sandbox + `network.client` reichen (kein Kamera-Zugriff — der QR wird vom **Handy** gescannt).

---

## Scope-Grenzen (bewusst)

- **Reiner WebView-Wrapper** um das offizielle `https://web.whatsapp.com` — kein reverse-engineered Client (Spec: ToS-konform, kein Sperr-Risiko).
- **Getrennt von der Kombox** — keine Aggregation ins Heute-Cockpit, keine gemeinsame Datenschicht.
- **macOS zuerst.** WhatsApp Web unterstützt mobile Browser offiziell nicht; auf iOS lädt der WebView mit Desktop-UA evtl. eingeschränkt — akzeptiert (Feinschliff später).
- **Keine Anruf-/Mediennutzung** im WebView (würde Kamera/Mikrofon-Entitlements + Usage-Strings brauchen) — out of scope.
- **Session-Persistenz** via `WKWebsiteDataStore.default()` (nicht ephemeral). Logout = in WhatsApp Web selbst abmelden.

---

## File Structure

**Geändertes Paket — `swift-packages/AtollHub/`:**
- `Sources/AtollHub/Navigation/ComHubModule.swift` — Case `.whatsapp` ergänzen (Titel + Symbol).
- `Tests/AtollHubTests/ComHubModuleTests.swift` — Tests an die neue Modul-Menge anpassen.

**Neue App-Dateien — `apps/comhub-native/ComHub/WhatsApp/`:**
- `WhatsAppWebView.swift` — plattform-`Representable` um `WKWebView` (Desktop-UA, persistenter Store).
- `WhatsAppModuleView.swift` — Host + Toolbar (Neu laden).

**Geänderte App-Dateien:**
- `ComHub/Design/CoColor.swift` — `module(_:)` um `.whatsapp` ergänzen (WhatsApp-Grün).
- `ComHub/Shell/HubShell.swift` — `.whatsapp` rendert `WhatsAppModuleView`.

**Doku:**
- `apps/comhub-native/README.md` — Phase-3c-Zeile.

---

## Task 1: `ComHubModule.whatsapp` ergänzen (AtollHub, TDD)

**Files:**
- Modify: `swift-packages/AtollHub/Sources/AtollHub/Navigation/ComHubModule.swift`
- Modify: `swift-packages/AtollHub/Tests/AtollHubTests/ComHubModuleTests.swift`

> `ComHubModule` ist `CaseIterable` — die Reihenfolge = Deklarationsreihenfolge. `.whatsapp` wird **vor** `.einstellungen` eingefügt, damit `.einstellungen` letztes Element bleibt (ein Bestandstest prüft das).

- [ ] **Step 1: Test anpassen (failing)**

Zuerst den bestehenden Test lesen: `swift-packages/AtollHub/Tests/AtollHubTests/ComHubModuleTests.swift`. Dann einen Test ergänzen, der die neue Modul-Menge fixiert. Füge folgende Test-Methode in die Klasse `ComHubModuleTests` ein:

```swift
  func test_whatsappModuleExistsBeforeEinstellungen() {
    XCTAssertTrue(ComHubModule.allCases.contains(.whatsapp))
    XCTAssertEqual(ComHubModule.allCases.last, .einstellungen)
    XCTAssertEqual(ComHubModule.whatsapp.title, "WhatsApp")
    XCTAssertFalse(ComHubModule.whatsapp.systemImage.isEmpty)
  }
```

Falls ein Bestandstest die **Anzahl** der Module hart prüft (z. B. `allCases.count == 7`), diese Zahl auf den neuen Wert (8) anpassen — sonst keine Bestandstests ändern.

- [ ] **Step 2: Test ausführen — soll fehlschlagen**

Run: `cd swift-packages/AtollHub && swift test --filter ComHubModuleTests`
Expected: FAIL — `type 'ComHubModule' has no member 'whatsapp'`.

- [ ] **Step 3: Case einfügen**

In `swift-packages/AtollHub/Sources/AtollHub/Navigation/ComHubModule.swift`:

1. Im `enum`-Block den Case `case whatsapp` **direkt vor** `case einstellungen` einfügen.
2. In `var title`: `case .whatsapp: return "WhatsApp"` (vor `.einstellungen`).
3. In `var systemImage`: `case .whatsapp: return "phone.bubble.fill"` (vor `.einstellungen`).

(Die genaue Syntax an die bestehende Datei anpassen — gleiche `switch`-Struktur.)

- [ ] **Step 4: Test ausführen — soll grün sein**

Run: `cd swift-packages/AtollHub && swift test --filter ComHubModuleTests`
Expected: PASS.

- [ ] **Step 5: Volle Paket-Suite + Commit**

Run: `cd swift-packages/AtollHub && swift test`
Expected: PASS — alle Suiten grün.

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add swift-packages/AtollHub/Sources/AtollHub/Navigation/ComHubModule.swift swift-packages/AtollHub/Tests/AtollHubTests/ComHubModuleTests.swift
git commit -m "AtollHub: ComHubModule.whatsapp (Privat-WhatsApp-Tab)"
```

---

## Task 2: `WhatsAppWebView` — WKWebView-Wrapper (ComHub)

**Files:**
- Create: `apps/comhub-native/ComHub/WhatsApp/WhatsAppWebView.swift`

- [ ] **Step 1: Wrapper schreiben**

`apps/comhub-native/ComHub/WhatsApp/WhatsAppWebView.swift`:

```swift
import SwiftUI
import WebKit

/// Plattform-Wrapper um `WKWebView`, der WhatsApp Web lädt. Setzt einen
/// Desktop-User-Agent (sonst lehnt WhatsApp den Browser ab) und nutzt den
/// **persistenten** Standard-Datastore, damit der QR-Login App-Neustarts
/// überlebt. Der QR-Code wird mit dem Handy gescannt — keine Kamera nötig.
struct WhatsAppWebView {
  /// Steuerung von aussen (Neu laden).
  final class Coordinator {
    weak var webView: WKWebView?
    func reload() { webView?.reload() }
  }
  let coordinator: Coordinator

  private static let desktopUA =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 " +
    "(KHTML, like Gecko) Version/17.0 Safari/605.1.15"
  private static let url = URL(string: "https://web.whatsapp.com")!

  private func makeWebView() -> WKWebView {
    let config = WKWebViewConfiguration()
    config.websiteDataStore = .default()   // persistent -> Session bleibt
    let webView = WKWebView(frame: .zero, configuration: config)
    webView.customUserAgent = Self.desktopUA
    webView.load(URLRequest(url: Self.url))
    coordinator.webView = webView
    return webView
  }
}

#if os(macOS)
import AppKit
extension WhatsAppWebView: NSViewRepresentable {
  func makeCoordinator() -> Coordinator { coordinator }
  func makeNSView(context: Context) -> WKWebView { makeWebView() }
  func updateNSView(_ nsView: WKWebView, context: Context) {}
}
#else
import UIKit
extension WhatsAppWebView: UIViewRepresentable {
  func makeCoordinator() -> Coordinator { coordinator }
  func makeUIView(context: Context) -> WKWebView { makeWebView() }
  func updateUIView(_ uiView: WKWebView, context: Context) {}
}
#endif
```

> Hinweis: `coordinator` wird im Host (`WhatsAppModuleView`) als `@State` gehalten, damit „Neu laden" den WebView erreicht. `makeCoordinator()` gibt genau diese Instanz zurück.

- [ ] **Step 2: Build verifizieren**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`. Beweist die `WKWebView`/`NSViewRepresentable`-Anbindung. **Falls** das `NSViewRepresentable`-Conformance-`extension`-Muster (mit eigener `Coordinator`-Klasse, die KEIN Bezug zur SwiftUI-Context-Coordinator ist) klemmt: alternativ den `Coordinator` als `final class Coordinator: NSObject` deklarieren und/oder das Representable als `struct` mit `typealias Coordinator` — die genaue Form, die kompiliert, wählen und melden. `WebKit` muss verfügbar sein (es ist ein System-Framework; kein SDK-Eintrag in `project.yml` nötig, `import WebKit` reicht).

- [ ] **Step 3: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/WhatsApp/WhatsAppWebView.swift
git commit -m "ComHub: WhatsAppWebView (WKWebView, Desktop-UA, persistenter Store)"
```

---

## Task 3: `WhatsAppModuleView` + Farbe + Shell-Verdrahtung (ComHub)

**Files:**
- Create: `apps/comhub-native/ComHub/WhatsApp/WhatsAppModuleView.swift`
- Modify: `apps/comhub-native/ComHub/Design/CoColor.swift` (`.whatsapp`-Farbe)
- Modify: `apps/comhub-native/ComHub/Shell/HubShell.swift` (`.whatsapp` rendern)

- [ ] **Step 1: `WhatsAppModuleView` schreiben**

`apps/comhub-native/ComHub/WhatsApp/WhatsAppModuleView.swift`:

```swift
import SwiftUI

/// Privat-WhatsApp: WhatsApp Web im WebView, getrennt von der Atoll-Kombox.
struct WhatsAppModuleView: View {
  @State private var coordinator = WhatsAppWebView.Coordinator()

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 10) {
        Image(systemName: "phone.bubble.fill").foregroundStyle(CoColor.module(.whatsapp))
        Text("WhatsApp").font(.system(size: 15, weight: .bold))
        Text("privat · WhatsApp Web").font(.caption).foregroundStyle(.secondary)
        Spacer()
        Button { coordinator.reload() } label: { Image(systemName: "arrow.clockwise") }
          .buttonStyle(.borderless)
      }
      .padding(.horizontal, 16).frame(height: 52)
      Divider()
      WhatsAppWebView(coordinator: coordinator)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
}
```

- [ ] **Step 2: `CoColor.module` um `.whatsapp` ergänzen**

In `apps/comhub-native/ComHub/Design/CoColor.swift` im `switch module`-Block von `module(_:)` einen Zweig **vor** `case .einstellungen` einfügen:

```swift
    case .whatsapp:      return Color(red: 0.15, green: 0.83, blue: 0.40) // #25D366 WhatsApp-Gruen
```

- [ ] **Step 3: Shell — `.whatsapp` rendern**

In `apps/comhub-native/ComHub/Shell/HubShell.swift`:

1. Im `content:`-`switch selectedModule` **vor** `default:` einfügen:

```swift
      case .whatsapp:
        WhatsAppModuleView()
          #if os(macOS)
          .frame(minWidth: 480)
          #endif
```

2. Im `detail:`-`switch` den `.whatsapp`-Fall zu den selbst-rendernden Modulen ergänzen — den `case`-Ausdruck von:

```swift
      case .heute, .kalender, .kontakte, .kombox:
```

zu:

```swift
      case .heute, .kalender, .kontakte, .kombox, .whatsapp:
```

- [ ] **Step 4: Generieren + Build**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`. (Der `CoColor.module`-`switch` muss alle `ComHubModule`-Cases inkl. `.whatsapp` abdecken — sonst „switch must be exhaustive".)

- [ ] **Step 5: Manueller Smoke-Test** (echter Mac)

- [ ] Sidebar zeigt **WhatsApp** (grünes Icon) zwischen CardInbox und Einstellungen.
- [ ] Modul öffnen → WhatsApp-Web-Seite lädt (QR-Code erscheint, nicht „Browser nicht unterstützt").
- [ ] QR mit dem Handy (WhatsApp → Verknüpfte Geräte) scannen → Chats erscheinen.
- [ ] „Neu laden" lädt die Seite neu.
- [ ] App neu starten → Modul öffnen → **bleibt eingeloggt** (kein neuer QR).
- [ ] Bestätigen: **getrennt** von der Kombox (keine Vermischung).

- [ ] **Step 6: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/WhatsApp/WhatsAppModuleView.swift apps/comhub-native/ComHub/Design/CoColor.swift apps/comhub-native/ComHub/Shell/HubShell.swift
git commit -m "ComHub: Privat-WhatsApp-Modul in die Shell (WebView-Tab, gruenes Icon)"
```

---

## Task 4: Dokumentation (Phase 3c)

**Files:**
- Modify: `apps/comhub-native/README.md`

- [ ] **Step 1: Phase-3c-Zeile ergänzen**

In `apps/comhub-native/README.md` im Abschnitt `## Phasen-Stand` **nach** dem `**Phase 3b** …`-Absatz einfügen:

```markdown

**Phase 3c** — **Privat-WhatsApp** als eigener Tab: WhatsApp Web (offizieller
QR-Login) in einem `WKWebView` mit Desktop-User-Agent und persistentem Datastore
(Login bleibt erhalten). Bewusst **getrennt** von der Atoll-Kombox. Damit ist die
Kombox-Phase 3 abgeschlossen (lesen + senden + Privat-WhatsApp).
```

- [ ] **Step 2: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/README.md
git commit -m "Docs: ComHub-README Phase-3c (Privat-WhatsApp-WebView)"
```

---

## Self-Review (durchgeführt)

**1. Spec-Abdeckung (Spec §7 + §4.7, Slice 3c):**
- „Privat-WhatsApp als eigener WhatsApp-Web-WebView-Tab (offizieller QR), nicht in die Kombox gemischt" → Tasks 1 (Modul), 2 (`WhatsAppWebView` offizielle Seite + QR), 3 (eigenes Modul in der Shell, getrennt).
- „WebView-Wrapper, sicher, keine eigene Infrastruktur, kein ToS-Verstoss" → offizielle `web.whatsapp.com`, kein reverse-engineered Client.
- Bewusst out of scope: Aggregation/Cockpit, Anruf/Medien (Scope-Grenzen).

**2. Platzhalter-Scan:** Keine „TBD/TODO". Vollständiger Code je Schritt; Befehl + erwartete Ausgabe je Run. Der Smoke-Test (QR-Login) ist menschlich, klar aufgelistet.

**3. Typ-Konsistenz:**
- `ComHubModule.whatsapp` (`.title`/`.systemImage`, `.allCases` mit `.einstellungen` zuletzt) (Task 1) ↔ `CoColor.module(.whatsapp)` (Task 3) ↔ Shell-`switch` (Task 3) ↔ Sidebar (iteriert `allCases`, D1). ✔
- `WhatsAppWebView(coordinator:)` + `WhatsAppWebView.Coordinator` (`.reload()`) (Task 2) ↔ `WhatsAppModuleView` (`@State coordinator`) (Task 3). ✔
- `CoColor.module(_:)` muss nach Task 1 **alle** Cases abdecken (inkl. `.whatsapp`) — Task 3 Step 2 ergänzt das (sonst nicht-erschöpfender `switch` → Build-Fehler, der genau das erzwingt). ✔

**4. Verifikations-Disziplin:** Task 1 echte TDD (`swift test`). Tasks 2–3 build-verifiziert (`xcodegen generate` + `xcodebuild`); Task 3 schliesst mit manuellem Smoke-Test (QR-Login + Persistenz). Konform zu superpowers:verification-before-completion.

**Hinweis (nicht blockierend):** Falls WhatsApp Web im sandboxed WebView trotz Desktop-UA „nicht unterstützt" zeigt, prüfen: (a) Entitlement `com.apple.security.network.client` aktiv (ist es), (b) UA-String aktuell genug, (c) ggf. `WKWebpagePreferences`/JavaScript aktiviert (Default an). Diese Diagnose gehört in den Smoke-Test, nicht in den Plan.

---

## Execution Handoff

**Plan komplett und gespeichert unter `docs/superpowers/plans/2026-06-02-comhub-phase3c-privat-whatsapp.md`. Zwei Ausführungs-Optionen:**

**1. Subagent-Driven (empfohlen)** — frischer Subagent pro Task, Review zwischen den Tasks. (REQUIRED SUB-SKILL: superpowers:subagent-driven-development.)

**2. Inline-Ausführung** — Tasks in dieser Session, Batch mit Checkpoints. (REQUIRED SUB-SKILL: superpowers:executing-plans.)

**Welcher Ansatz?**
