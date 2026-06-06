# ComHub Design D3 — Einstellungen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Das **Einstellungen**-Modul (`.einstellungen`) im CoHub-Look mit **echtem** Inhalt: Konto-Kopf, **Abmelden** (schliesst die Logout-Lücke), Apple-Berechtigungs-Status (Kalender/Erinnerungen/Kontakte) mit „Erneut anfragen" + „Systemeinstellungen öffnen", Atoll-Konto-Info, Darstellungs-Hinweis (folgt System) und Versions-Fusszeile.

**Architecture:** Reine App-UI über bestehende Dienste — `AuthState` (`.status`/`.signOut()`/`CurrentUser`) und `AppleAuthorizationService` (`.calendars`/`.reminders`/`.contacts: CapabilityAuthorization`, `.requestAll()`, `.refreshStatus()`), beide schon via `@Environment` injiziert (Phase 0). Gruppen-Karten (`SettingsGroup`/`SettingsRow`) im Mockup-Stil (`view-einstellungen.jsx`), `CoAvatar`/`CoColor`-Reuse. **Keine** neue AtollHub-Logik, kein Backend — daher build-/smoke-verifiziert (keine TDD-Task). Mockup-Gruppen „Kombox-Kanäle"/„CardInbox-Visitenkarte" sind bewusst weggelassen (bräuchten `messaging_accounts`/Card-Daten).

**Tech Stack:** Swift 6 (strict concurrency complete), SwiftUI Multiplatform (iOS 26 / macOS 26), XcodeGen. Reuse: `AuthState`, `AppleAuthorizationService`, `CurrentUser`, `ComHubModule.einstellungen`, `CoAvatar`/`CoColor`/`CoTheme`, `Config.appName`.

---

## Scope-Grenzen (bewusst)

- **Echte, vorhandene Funktion:** Abmelden, Apple-Permission-Status + Anfragen + Systemeinstellungen-Deeplink, Atoll-Konto-Anzeige, Theme-folgt-System-Hinweis, App-Version.
- **Weggelassen (Mockup, aber ohne Datenbasis):** „Kombox-Kanäle" (Mail/iMessage/WhatsApp-Status → bräuchte `messaging_accounts`-Query, Phase 5), „CardInbox-Visitenkarte/Auto-Import" (Phase 4), „Profil bearbeiten" (kein Schreiben aufs Profil).
- **Push-Schalter** → Phase 5. **Google/Microsoft-Konten hinzufügen** → Phase 6. (Hier nur Platz-Hinweis, kein UI.)
- **Theme/Dichte-Umschalter:** ComHub folgt dem System-`colorScheme`; kein In-App-Umschalter (D1-Entscheidung) — nur ein Hinweis-Row.

---

## File Structure

**Neue App-Dateien — `apps/comhub-native/ComHub/Settings/`:**
- `SettingsGroup.swift` — Gruppen-Karte (`SettingsGroup` + `SettingsRow`).
- `SettingsModuleView.swift` — die Einstellungen-Seite.

**Geänderte App-Datei:**
- `ComHub/Shell/HubShell.swift` — `.einstellungen` rendert `SettingsModuleView` (statt Platzhalter).

**Doku:**
- `apps/comhub-native/README.md` — D3-Zeile.

---

## Task 1: `SettingsGroup`/`SettingsRow` + `SettingsModuleView` (ComHub)

**Files:**
- Create: `apps/comhub-native/ComHub/Settings/SettingsGroup.swift`
- Create: `apps/comhub-native/ComHub/Settings/SettingsModuleView.swift`

- [ ] **Step 1: `SettingsGroup` + `SettingsRow` schreiben**

`apps/comhub-native/ComHub/Settings/SettingsGroup.swift`:

```swift
import SwiftUI

/// Eine Einstellungs-Gruppe: Uppercase-Titel + gerahmte Karte mit Zeilen.
struct SettingsGroup<Content: View>: View {
  let title: String
  @ViewBuilder var content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      Text(title.uppercased())
        .font(.system(size: 11.5, weight: .bold)).foregroundStyle(.tertiary)
        .padding(.horizontal, 4)
      VStack(spacing: 0) { content() }
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(CoTheme.separator, lineWidth: 1))
    }
  }
}

/// Eine Einstellungs-Zeile: farbiges Icon + Titel/Untertitel + optionales Rechts-Element.
struct SettingsRow<Right: View>: View {
  let icon: String
  let iconColor: Color
  let title: String
  var subtitle: String? = nil
  var showDivider: Bool = true
  @ViewBuilder var right: () -> Right

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 12) {
        Image(systemName: icon).font(.system(size: 14)).foregroundStyle(.white)
          .frame(width: 28, height: 28).background(iconColor, in: RoundedRectangle(cornerRadius: 7))
        VStack(alignment: .leading, spacing: 1) {
          Text(title).font(.system(size: 13.5, weight: .medium))
          if let subtitle { Text(subtitle).font(.system(size: 11.5)).foregroundStyle(.tertiary) }
        }
        Spacer(minLength: 0)
        right()
      }
      .padding(.horizontal, 16).padding(.vertical, 11)
      if showDivider { Divider().padding(.leading, 16) }
    }
  }
}

/// Grün/grauer Status-Punkt mit Label.
struct SettingsStatusDot: View {
  let on: Bool
  var onLabel = "Erlaubt"
  var offLabel = "Nicht erlaubt"
  var body: some View {
    HStack(spacing: 6) {
      Circle().fill(on ? Color(red: 0.20, green: 0.78, blue: 0.35) : Color.secondary)
        .frame(width: 8, height: 8)
      Text(on ? onLabel : offLabel).font(.system(size: 12)).foregroundStyle(.secondary)
    }
  }
}
```

- [ ] **Step 2: `SettingsModuleView` schreiben**

`apps/comhub-native/ComHub/Settings/SettingsModuleView.swift`:

```swift
import SwiftUI
import AtollCore

/// Einstellungen: Konto-Kopf, Abmelden, Apple-Berechtigungen, Atoll-Konto,
/// Darstellung, Version.
struct SettingsModuleView: View {
  @Environment(AuthState.self) private var auth
  @Environment(AppleAuthorizationService.self) private var appleAuth
  @Environment(\.openURL) private var openURL

  private var user: CurrentUser? {
    if case .signedIn(let u) = auth.status { return u }
    return nil
  }
  private var appVersion: String {
    let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    return "\(Config.appName) \(v) (\(b))"
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        header
        accountGroup
        permissionsGroup
        appearanceGroup
        Text(appVersion).font(.system(size: 11.5)).foregroundStyle(.tertiary)
          .frame(maxWidth: .infinity, alignment: .center)
      }
      .padding(.horizontal, 30).padding(.vertical, 26)
      .frame(maxWidth: 620, alignment: .leading)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .onAppear { appleAuth.refreshStatus() }
  }

  private var header: some View {
    HStack(spacing: 16) {
      CoAvatar(name: user?.name ?? "ComHub", size: 64)
      VStack(alignment: .leading, spacing: 2) {
        Text(user?.name ?? "—").font(.system(size: 21, weight: .bold))
        Text("\(user?.email ?? "—") · ComHub Konto").font(.system(size: 13)).foregroundStyle(.tertiary)
      }
      Spacer()
    }
  }

  private var accountGroup: some View {
    SettingsGroup(title: "Konto") {
      SettingsRow(icon: "person.crop.circle", iconColor: CoColor.accent,
                  title: "Atoll-Konto", subtitle: user.map { $0.role.displayName } ?? "Angemeldet") {
        SettingsStatusDot(on: true, onLabel: "Verbunden", offLabel: "Getrennt")
      }
      SettingsRow(icon: "rectangle.portrait.and.arrow.right", iconColor: Color(red: 1, green: 0.27, blue: 0.23),
                  title: "Abmelden", showDivider: false) {
        Button("Abmelden", role: .destructive) { Task { await auth.signOut() } }
          .buttonStyle(.borderless)
      }
    }
  }

  private var permissionsGroup: some View {
    SettingsGroup(title: "Apple-Berechtigungen") {
      SettingsRow(icon: "calendar", iconColor: Color(red: 1, green: 0.27, blue: 0.23),
                  title: "Kalender") { SettingsStatusDot(on: appleAuth.calendars == .authorized) }
      SettingsRow(icon: "checklist", iconColor: Color(red: 1, green: 0.62, blue: 0.04),
                  title: "Erinnerungen") { SettingsStatusDot(on: appleAuth.reminders == .authorized) }
      SettingsRow(icon: "person.2", iconColor: Color(red: 0.56, green: 0.56, blue: 0.58),
                  title: "Kontakte") { SettingsStatusDot(on: appleAuth.contacts == .authorized) }
      SettingsRow(icon: "gearshape", iconColor: .secondary, title: "Berechtigungen verwalten",
                  subtitle: "Erneut anfragen oder in den Systemeinstellungen", showDivider: false) {
        HStack(spacing: 8) {
          Button("Anfragen") { Task { await appleAuth.requestAll() } }.buttonStyle(.borderless)
          Button("System") { openSystemPrivacy() }.buttonStyle(.borderless)
        }
      }
    }
  }

  private var appearanceGroup: some View {
    SettingsGroup(title: "Darstellung") {
      SettingsRow(icon: "circle.lefthalf.filled", iconColor: Color(red: 1, green: 0.62, blue: 0.04),
                  title: "Erscheinungsbild", subtitle: "Folgt den Systemeinstellungen (Hell/Dunkel)",
                  showDivider: false) { EmptyView() }
    }
  }

  private func openSystemPrivacy() {
    #if os(macOS)
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
      openURL(url)
    }
    #else
    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    #endif
  }
}
```

> Hinweis: `auth`/`appleAuth` sind in `ComHubApp` via `.environment(...)` injiziert (Phase 0). `Config.appName` aus `ComHub/Config.swift`. Nach `auth.signOut()` schaltet `RootView` automatisch auf `SignInView` (Status `.signedOut`).

- [ ] **Step 3: Build verifizieren**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`. Beweist `AuthState.signOut()`/`.status`/`CurrentUser.role.displayName`/`.email`/`.name`, `AppleAuthorizationService.calendars/reminders/contacts/requestAll/refreshStatus`, `@Environment(AppleAuthorizationService.self)`. **Falls** ein Symbol abweicht (z. B. `CurrentUser.role.displayName` heisst anders): die echten Properties in `swift-packages/AtollCore/Sources/AtollCore/Models/CurrentUser.swift` + `apps/comhub-native/ComHub/Apple/AppleAuthorizationService.swift` prüfen und angleichen — melden.

- [ ] **Step 4: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Settings/SettingsGroup.swift apps/comhub-native/ComHub/Settings/SettingsModuleView.swift
git commit -m "ComHub: SettingsModuleView (Konto/Abmelden, Apple-Berechtigungen, Version)"
```

---

## Task 2: `.einstellungen` in die Shell + Smoke (ComHub)

**Files:**
- Modify: `apps/comhub-native/ComHub/Shell/HubShell.swift`

- [ ] **Step 1: `.einstellungen` rendern**

In `apps/comhub-native/ComHub/Shell/HubShell.swift`:

1. Im `content:`-`switch selectedModule` **vor** `default:` einfügen:

```swift
      case .einstellungen:
        SettingsModuleView()
          #if os(macOS)
          .frame(minWidth: 480)
          #endif
```

2. Im `detail:`-`switch` den `.einstellungen`-Fall zu den selbst-rendernden Modulen ergänzen — den `case`-Ausdruck von:

```swift
      case .heute, .kalender, .kontakte, .kombox, .whatsapp:
```

zu:

```swift
      case .heute, .kalender, .kontakte, .kombox, .whatsapp, .einstellungen:
```

> Damit fällt `.einstellungen` nicht mehr in den `default`-`ModulePlaceholder`. (Da `.einstellungen` nun das einzige verbleibende `default`-Modul war neben `.tasks`/`.cardInbox`, bleibt der `ModulePlaceholder` nur noch für `.tasks`/`.cardInbox` — korrekt bis Phase 4.)

- [ ] **Step 2: Generieren + Build**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Manueller Smoke-Test** (echter Mac, Light + Dark)

- [ ] **Einstellungen** öffnen → Kopf mit Avatar + Name + E-Mail.
- [ ] **Konto**: Atoll-Konto „Verbunden"; **Abmelden** → zurück zum Login (`SignInView`).
- [ ] **Apple-Berechtigungen**: Kalender/Erinnerungen/Kontakte zeigen korrekten Status (grün „Erlaubt" wenn gewährt); „Anfragen" zeigt System-Dialog (falls noch nicht entschieden); „System" öffnet die Systemeinstellungen → Datenschutz.
- [ ] **Darstellung**: Hinweis „Folgt den Systemeinstellungen".
- [ ] Versions-Fusszeile zeigt `ComHub <version> (<build>)`.
- [ ] Dark Mode lesbar.

- [ ] **Step 4: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Shell/HubShell.swift
git commit -m "ComHub: Einstellungen-Modul in die Shell (statt Platzhalter)"
```

---

## Task 3: Dokumentation (D3)

**Files:**
- Modify: `apps/comhub-native/README.md`

- [ ] **Step 1: D3-Zeile ergänzen**

In `apps/comhub-native/README.md` im Abschnitt `## Phasen-Stand` **nach** dem `**Design D2b** …`-Absatz (oder am Ende der Design-Einträge) einfügen:

```markdown

**Design D3** — **Einstellungen** (`.einstellungen`-Modul) im CoHub-Look: Konto-Kopf,
**Abmelden** (`auth.signOut`), Apple-Berechtigungs-Status (Kalender/Erinnerungen/
Kontakte) mit „Erneut anfragen" + Systemeinstellungen-Deeplink, Atoll-Konto, Hinweis
„Erscheinungsbild folgt System", Versions-Fusszeile. Push-Schalter folgt in Phase 5,
Google/Microsoft-Konten in Phase 6.
```

- [ ] **Step 2: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/README.md
git commit -m "Docs: ComHub-README Design-D3 (Einstellungen)"
```

---

## Self-Review (durchgeführt)

**1. Spec-Abdeckung (Mockup `view-einstellungen.jsx`, angepasst an echte Funktion):**
- Konto-Kopf (Avatar + Name + E-Mail) → Task 1 `header`.
- Verbundene Konten → „Konto"-Gruppe (Atoll + Abmelden) + „Apple-Berechtigungen"-Gruppe (3 Capabilities).
- Darstellung → „Darstellung"-Gruppe (folgt System).
- Version-Fusszeile → Task 1.
- **Abmelden** (im Mockup nicht explizit, real aber nötig) → ergänzt.
- Bewusst weg (Scope-Grenzen): Kombox-Kanäle, CardInbox-Visitenkarte/Toggle, Profil bearbeiten, Tweaks-Umschalter.

**2. Platzhalter-Scan:** Keine „TBD/TODO". Vollständiger Code je Schritt; Befehl + erwartete Ausgabe je Run. Empty-States (kein User) zeigen „—".

**3. Typ-Konsistenz:**
- `SettingsGroup(title:){...}`, `SettingsRow(icon:iconColor:title:subtitle?:showDivider?:){right}`, `SettingsStatusDot(on:onLabel?:offLabel?:)` (Task 1) ↔ `SettingsModuleView` (Task 1). ✔
- Reuse: `AuthState.status`/`.signOut()`, `CurrentUser.name`/`.email`/`.role.displayName`, `AppleAuthorizationService.calendars/reminders/contacts == .authorized`/`.requestAll()`/`.refreshStatus()`, `CoAvatar(name:size:)`, `CoColor.accent`, `CoTheme.separator`, `Config.appName`, `ComHubModule.einstellungen` — gegen Phase-0/1-Code geprüft (Task 1 Build verifiziert; Abweichung → angleichen).
- Shell: `.einstellungen`-Content statt `default`; `detail:` nimmt `.einstellungen` zu den `Color.clear`-Modulen. ✔

**4. Verifikations-Disziplin:** Kein AtollHub-Logik → keine TDD-Task (bewusst; die genutzten Dienste sind bereits getestet/etabliert). Tasks 1–2 build-verifiziert (`xcodegen generate` + `xcodebuild`); Task 2 schliesst mit manuellem Smoke-Test (Abmelden + Permissions + Dark Mode). Konform zu superpowers:verification-before-completion (Build grün + Smoke).

---

## Execution Handoff

**Plan komplett und gespeichert unter `docs/superpowers/plans/2026-06-02-comhub-designD3-einstellungen.md`. Zwei Ausführungs-Optionen:**

**1. Subagent-Driven (empfohlen)** — frischer Subagent pro Task, Review zwischen den Tasks. (REQUIRED SUB-SKILL: superpowers:subagent-driven-development.)

**2. Inline-Ausführung** — Tasks in dieser Session, Batch mit Checkpoints. (REQUIRED SUB-SKILL: superpowers:executing-plans.)

**Welcher Ansatz?**
