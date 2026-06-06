# ComHub Phase 6a — iOS-Feinschliff (iPhone/iPad) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Die macOS-first gebaute ComHub-App sauber auf iPhone + iPad bringen: erst **iOS überhaupt zum Bauen** kriegen (heute scheitert es), dann die **fix-breiten Multi-Pane-Module** (Kombox 3-Pane, Kontakte 2-Pane, Aufgaben 2-Pane) auf schmalen Screens adaptiv machen (Liste → Tap → Push), plus Shell-Navigation, Filter-Popover und Touch-Feinschliff.

**Architecture:** Ein `@Environment(\.horizontalSizeClass)`-basierter `isCompact`-Helfer (iOS) / `false` (macOS) entscheidet pro Multi-Pane-Modul zwischen **Wide-Layout** (bestehender `HStack` mit festen Breiten, unverändert für macOS/iPad-regular) und **Compact-Layout** (`NavigationStack` mit Master-Liste → `NavigationLink`/Push zum Detail). Die Shell wird cross-platform: `List`-Selection auf optionale Bindung umgestellt (iOS-Pflicht), Content-Spalte in `NavigationStack`, `.navigationSplitViewStyle(.balanced)`. Verifikation: **iOS-Simulator-Build** (`iPhone 17 Pro, OS 26.2`) UND der bestehende macOS-Build — beide müssen grün sein.

**Tech Stack:** Swift 6 (strict concurrency complete), SwiftUI Multiplatform (iOS 26 / macOS 26), `horizontalSizeClass`, `NavigationStack`/`NavigationSplitView`, XcodeGen. iOS-Simulatoren iOS 26.2 sind installiert (iPhone 17 Pro u. a.).

---

## Scope-Grenzen (bewusst)

- **6a = iPhone/iPad-Lauffähigkeit + adaptive Layouts.** Keine neuen Features, keine neuen Konten (Google/MS = 6b).
- **Verifikation = Build (iOS-Sim + macOS).** Echte Geräte-Smoke-Tests macht der User (EventKit-Rechte, Realtime, WebView-QR-Login lassen sich am besten am Gerät prüfen).
- **Wide-Layout bleibt unangetastet** (macOS + iPad-regular sehen aus wie bisher). Nur ein **zusätzlicher** Compact-Pfad kommt dazu.
- **Shell:** `NavigationSplitView` bleibt (kein TabView-Umbau) — minimal-invasiv, nur cross-platform-tauglich gemacht.
- WhatsApp-WebView ist bereits dual (`NSViewRepresentable`/`UIViewRepresentable`) — nichts zu tun außer Build-Check.

---

## File Structure

**Neu (App):**
- `apps/comhub-native/ComHub/Shell/SizeClass.swift` — `View`-Helfer/Environment für `isCompact` (cross-platform).

**Geändert (App):**
- `Shell/HubShell.swift` — `List`-Selection optional, Content in `NavigationStack`, `.balanced`, iOS-Build-Fix.
- `Contacts/ContactsModuleView.swift` — Compact-Pfad (Liste → Push Detail).
- `Tasks/AufgabenModuleView.swift` — Compact-Pfad (Filter als Menü/Toolbar + Liste).
- `Kombox/KomboxModuleView.swift` — Compact-Pfad (Kanal-Menü + Konversationsliste → Push Thread).
- `Calendar/CalendarModuleView.swift` — Popover→Compact-Sheet-Adaption, Header-Touch.
- ggf. weitere Dateien, die der iOS-Build als Fehler wirft (Task 1 iteriert bis grün).

**Doku:** `apps/comhub-native/README.md` — Phase-6a-Zeile.

---

## Task 1: iOS-Build grün + `isCompact`-Helfer + Shell cross-platform

**Files:**
- Create: `apps/comhub-native/ComHub/Shell/SizeClass.swift`
- Modify: `apps/comhub-native/ComHub/Shell/HubShell.swift`
- (iterativ) weitere Dateien mit iOS-Fehlern

**Bekannter erster Fehler:** `HubShell.swift:16` — `List(selection: $selectedModule)` mit **nicht-optionaler** `Binding<ComHubModule>` ist macOS-only; iOS verlangt `Binding<ComHubModule?>`.

- [ ] **Step 1: `isCompact`-Helfer (cross-platform)**

`apps/comhub-native/ComHub/Shell/SizeClass.swift`:

```swift
import SwiftUI

/// `true`, wenn die horizontale Größenklasse kompakt ist (iPhone Hochformat).
/// Auf macOS gibt es keine Größenklassen → immer `false` (Wide-Layout).
struct CompactKey: EnvironmentKey { static let defaultValue = false }

extension EnvironmentValues {
  var isCompactWidth: Bool {
    get { self[CompactKey.self] }
    set { self[CompactKey.self] = newValue }
  }
}

/// Stülpt die plattformkorrekte Kompakt-Erkennung über einen Teilbaum.
struct CompactWidthReader<Content: View>: View {
  @ViewBuilder let content: (Bool) -> Content
  #if os(iOS)
  @Environment(\.horizontalSizeClass) private var hSize
  private var compact: Bool { hSize == .compact }
  #else
  private var compact: Bool { false }
  #endif
  var body: some View { content(compact) }
}
```

- [ ] **Step 2: Shell cross-platform machen**

In `HubShell.swift`:
1. Selection optional:
```swift
  @State private var selectedModule: ComHubModule? = .heute
```
2. Der `List(selection: $selectedModule)` bleibt — mit optionaler Bindung ist `init(selection:content:)` auf iOS **und** macOS verfügbar. Die `ForEach`+`.tag(module)`+`Divider()`-Struktur bleibt.
3. Den `content:`-Switch gegen den optionalen Wert absichern — ganz am Anfang des `content:`-Closures:
```swift
    } content: {
      let module = selectedModule ?? .heute
      NavigationStack {
        moduleContent(module)
          .navigationTitle(module.title)
          #if os(iOS)
          .navigationBarTitleDisplayMode(.inline)
          #endif
      }
    } detail: {
      …  // bestehende Detail-Spalte unverändert (Color.clear / Placeholder)
    }
```
4. Den großen `switch selectedModule { … }` aus dem `content:`-Closure in eine `@ViewBuilder`-Methode auslagern (damit der `NavigationStack`-Wrap sauber bleibt):
```swift
  @ViewBuilder
  private func moduleContent(_ module: ComHubModule) -> some View {
    switch module {
    case .heute:    CockpitView(onOpenModule: { selectedModule = $0 })
    case .kalender: CalendarModuleView()
    case .kontakte: ContactsModuleView()
    case .kombox:   KomboxModuleView()
    case .whatsapp: WhatsAppModuleView()
    case .einstellungen: SettingsModuleView()
    case .tasks:    AufgabenModuleView()
    default:        ModulePlaceholder(module: module, pane: "Liste")
    }
  }
```
> Die bisherigen `#if os(macOS) .frame(minWidth:) #endif` pro Modul gehen dabei verloren — das ist ok, denn die Mindestbreiten waren nur macOS-Kosmetik; auf macOS sorgt die `NavigationSplitView` weiter für sinnvolle Spaltenbreiten. Falls du die macOS-Mindestbreiten erhalten willst, häng sie in `moduleContent` per `#if os(macOS)`-`.frame(minWidth:)` an die jeweiligen Module (optional, nicht erforderlich).
5. `.navigationSplitViewStyle(.balanced)` an die `NavigationSplitView` hängen (nach dem schließenden `}` des `detail:`-Closures), damit iPad/iPhone vernünftig auflösen.
6. Die Sidebar-`#if os(macOS) .frame(minWidth: 220) #endif` bleibt.

- [ ] **Step 3: iOS-Build iterieren bis grün**

Run:
```bash
cd /Users/dominik/Desktop/Developer/Dispo/apps/comhub-native
rm -rf "ComHub 2.xcodeproj" 2>/dev/null; true
xcodegen generate
xcodebuild -scheme ComHub -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' build 2>&1 | grep -E "error:|BUILD" | head -40
```
Expected nach dem Shell-Fix: ggf. **weitere** iOS-Only-Fehler in anderen Dateien (z. B. macOS-spezifische APIs ohne `#if`-Gate). **Iteriere:** jeden `error:` lesen, plattformgerecht fixen (typische iOS-Fälle: `NSColor`/AppKit ohne Gate, `.frame(minWidth:)` auf Fenstern, `onHover`, `.help`, `List(selection:)`-Varianten, `.textSelection`, Tastatur-Modifier). NICHT die macOS-Logik kaputt machen — immer per `#if os(iOS)`/`#if os(macOS)` trennen, wenn eine API nur einseitig existiert. Wiederhole bis `** BUILD SUCCEEDED **`.

- [ ] **Step 4: macOS-Build weiterhin grün**

Run:
```bash
cd /Users/dominik/Desktop/Developer/Dispo/apps/comhub-native
xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build 2>&1 | tail -4
```
Expected: `** BUILD SUCCEEDED **` (die Shell-Umstellung darf macOS nicht brechen).

- [ ] **Step 5: AtollHub-Tests grün (falls dort etwas berührt wurde)**

Run: `cd /Users/dominik/Desktop/Developer/Dispo/swift-packages/AtollHub && swift test 2>&1 | tail -3`
Expected: alle grün (101 Tests). (Normalerweise hier nichts geändert — nur zur Sicherheit, falls ein Fix ins Paket rutschte.)

- [ ] **Step 6: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub
git commit -m "ComHub: iOS-Build gruen (Shell cross-platform, optionale List-Selection, NavigationStack) + isCompact-Helfer"
```
> Falls iOS-Fehler in weiteren Dateien gefixt wurden, diese mit committen. Commit-Message: keine Umlaute, kein `feat:`-Prefix.

---

## Task 2: Kontakte 2-Pane → Compact-Pfad (ComHub)

**Files:**
- Modify: `apps/comhub-native/ComHub/Contacts/ContactsModuleView.swift`

**Heute:** `HStack { ContactListPane.frame(width: 330) | Divider | ContactDetailPane }` — auf iPhone bricht die feste Breite.

- [ ] **Step 1: Compact- vs. Wide-Pfad**

READ die Datei. Sie hat (vermutlich) einen `@State` für den ausgewählten Kontakt (z. B. `selectedContact`/`selected`) und rendert links Liste, rechts Detail. Baue zwei Pfade:

```swift
  var body: some View {
    CompactWidthReader { compact in
      if compact { compactBody } else { wideBody }
    }
  }

  // Bestehendes 2-Pane unverändert:
  private var wideBody: some View {
    HStack(spacing: 0) {
      ContactListPane(/* … bestehende Parameter … */)
        #if os(macOS)
        .frame(width: 330)
        #else
        .frame(width: 330)
        #endif
      Divider()
      ContactDetailPane(/* … */)
    }
  }

  // iPhone: Liste, Tap pusht Detail.
  private var compactBody: some View {
    NavigationStack {
      ContactListPane(/* … selektion treibt Navigation … */)
        .navigationDestination(item: $selected) { contact in
          ContactDetailPane(contact: contact /* reale Signatur */)
        }
    }
  }
```
> **Passe an die reale API an:** Lies die echten Property-/Parameternamen von `ContactListPane`/`ContactDetailPane` und des Auswahl-State. Wenn die Liste die Auswahl über eine Bindung oder einen Callback meldet, nutze `navigationDestination(item:)` mit einem `Identifiable`-Kontakt-Typ (oder `navigationDestination(isPresented:)` + separater State). Ziel: auf iPhone zeigt sich erst die A-Z-Liste; Tippen auf einen Kontakt pusht das Detail; Zurück per Nav-Bar. Das Wide-Layout (macOS/iPad) bleibt exakt wie bisher.
>
> Falls `selected` heute kein `Identifiable`/optional ist, das für `navigationDestination(item:)` taugt, ergänze einen passenden optionalen State (z. B. `@State private var pushed: MergedContact?`) und setze ihn beim Tap.

- [ ] **Step 2: Beide Builds grün**

```bash
cd /Users/dominik/Desktop/Developer/Dispo/apps/comhub-native
rm -rf "ComHub 2.xcodeproj" 2>/dev/null; true; xcodegen generate
xcodebuild -scheme ComHub -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' build 2>&1 | grep -E "error:|BUILD" | tail -6
xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build 2>&1 | tail -3
```
Expected: beide `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Contacts/ContactsModuleView.swift
git commit -m "ComHub: Kontakte adaptiv (iPhone Liste->Push Detail, Wide-2-Pane unveraendert)"
```

---

## Task 3: Aufgaben 2-Pane → Compact-Pfad (ComHub)

**Files:**
- Modify: `apps/comhub-native/ComHub/Tasks/AufgabenModuleView.swift`

**Heute:** `HStack { rail.frame(width: 210) | Divider | list }` — Rail-Festbreite bricht auf iPhone.

- [ ] **Step 1: Compact- vs. Wide-Pfad**

READ die Datei (sie hat `rail(store:)` mit Smart-Filtern Alle/Heute/Markiert + „Meine Listen", und `list`). Baue:

```swift
  var body: some View {
    @Bindable var store = store
    CompactWidthReader { compact in
      if compact { compactBody(store) } else { wideBody(store) }
    }
    .task { await store.reload(using: hub) }
  }

  // Bestehendes 2-Pane:
  private func wideBody(_ store: AufgabenStore) -> some View {
    HStack(spacing: 0) {
      rail(store: store)
        #if os(macOS)
        .frame(width: 210)
        #else
        .frame(width: 210)
        #endif
      Divider()
      list
    }
  }

  // iPhone: Filter als Menü in der Toolbar, darunter die Liste.
  private func compactBody(_ store: AufgabenStore) -> some View {
    NavigationStack {
      list
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            Menu {
              ForEach(TaskSmartFilter.allCases) { f in
                Button { store.list = nil; store.smart = f } label: { Label(f.title, systemImage: icon(f)) }
              }
              if !store.lists.isEmpty {
                Divider()
                ForEach(store.lists) { l in
                  Button { store.list = l.name } label: { Text(l.name) }
                }
              }
            } label: { Image(systemName: "line.3.horizontal.decrease.circle") }
          }
        }
    }
  }
```
> Passe `TaskSmartFilter`/`icon(_:)`/`store.lists`/`store.list`/`store.smart` an die realen Namen an (alle existieren laut Datei). Das `.task { reload }` einmal am `body` belassen (nicht doppelt). Das Wide-Layout bleibt unverändert. Auf iPhone: oben links ein Filter-Menü, darunter die (bereits `maxWidth: 680`-begrenzte) Liste, die Checkboxen aus 5a funktionieren weiter.

- [ ] **Step 2: Beide Builds grün** (wie Task 2 Step 2)

- [ ] **Step 3: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Tasks/AufgabenModuleView.swift
git commit -m "ComHub: Aufgaben adaptiv (iPhone Filter-Menue + Liste, Wide-Rail unveraendert)"
```

---

## Task 4: Kombox 3-Pane → Compact-Pfad (ComHub)

**Files:**
- Modify: `apps/comhub-native/ComHub/Kombox/KomboxModuleView.swift`

**Heute:** `HStack { rail.frame(width: 180) | list.frame(width: 320) | reader }` — ~502px, bricht auf iPhone.

- [ ] **Step 1: Compact- vs. Wide-Pfad**

READ die Datei. Sie hat eine Kanal-Rail (Alle/WhatsApp/Mail), eine Konversationsliste (mit Suche) und einen Reader (Thread + Composer). Baue:

```swift
  var body: some View {
    CompactWidthReader { compact in
      if compact { compactBody } else { wideBody }
    }
    // bestehende .task/.onChange-Modifier unverändert anhängen
  }

  // Bestehendes 3-Pane:
  private var wideBody: some View {
    HStack(spacing: 0) {
      rail.frame(width: 180)
      Divider()
      conversationList.frame(width: 320)
      Divider()
      reader
    }
  }

  // iPhone: Kanal-Menü (Toolbar) + Konversationsliste; Tap pusht den Reader.
  private var compactBody: some View {
    NavigationStack {
      conversationList
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            Menu { /* Kanal-Auswahl Alle/WhatsApp/Mail → store.channel = … */ }
              label: { Image(systemName: "line.3.horizontal.decrease.circle") }
          }
        }
        .navigationDestination(item: $pushedConversation) { conv in
          reader   // Reader für die gewählte Konversation
        }
    }
  }
```
> **Passe an die reale API an:** Namen von Rail/Konversationsliste/Reader, den Kanal-Filter-State (z. B. `store.channel`/`KomboxFilter`), und wie die Konversationsauswahl heute funktioniert (vermutlich ein `@State selectedConversation`/`selectedContactId`). Für den Push brauchst du einen optionalen `Identifiable`-State (`@State private var pushedConversation: …?`), den der Listen-Tap setzt; `reader` muss aus diesem State seinen Inhalt ziehen (heute zieht er ihn vermutlich aus demselben Auswahl-State — dann genügt es, denselben State für `navigationDestination(item:)` zu verwenden). Realtime/Composer/Delete bleiben unangetastet. Wide-Layout bleibt exakt wie bisher.
>
> Wenn der Reader heute zwingend an den Auswahl-State gekoppelt ist und sich nicht leicht in eine Push-Destination heben lässt, ist als **Minimal-Variante** zulässig: auf compact die Rail in ein Toolbar-Menü zu verlagern und Liste + Reader **vertikal** zu stapeln (`VStack`) statt nebeneinander — Hauptsache keine festen Breiten mehr. Dokumentiere die gewählte Variante im Commit.

- [ ] **Step 2: Beide Builds grün** (wie Task 2 Step 2)

- [ ] **Step 3: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Kombox/KomboxModuleView.swift
git commit -m "ComHub: Kombox adaptiv (iPhone Kanal-Menue + Liste->Push Reader, Wide-3-Pane unveraendert)"
```

---

## Task 5: Kalender-Header + Filter-Popover auf iPhone (ComHub)

**Files:**
- Modify: `apps/comhub-native/ComHub/Calendar/CalendarModuleView.swift`

- [ ] **Step 1: Popover kompakt als Sheet/angepasst**

READ die Datei. Der D2c-Filter nutzt `.popover(isPresented: $showFilter) { … }`. Auf iPhone soll das Popover sich als angepasste Präsentation zeigen. Ergänze am Popover-Inhalt:
```swift
        .popover(isPresented: $showFilter) {
          if let sources { CalendarFilterPopover(store: sources) { applyFilter() } }
            #if os(iOS)
            .presentationCompactAdaptation(.popover)
            #endif
        }
```
> `presentationCompactAdaptation(.popover)` hält es auch auf iPhone als Popover (statt Vollbild-Sheet) — kompakt und konsistent. Falls der Inhalt dafür zu groß/unhandlich ist, alternativ `.sheet` für compact verwenden; entscheide nach Augenmaß und dokumentiere es.

- [ ] **Step 2: Header-Buttons Touch-tauglich**

Die Header-Buttons (`‹ Heute ›`, Filter, „+") sind `.buttonStyle(.bordered)` — auf iOS ok, aber stelle sicher, dass die Tap-Fläche ≥ ~30pt ist (Standard bei `.bordered` erfüllt). Falls der Header als enger `HStack` mit `.frame(height:)` gebaut ist, prüfe, dass er auf iPhone nicht abgeschnitten wird; bei Bedarf `.frame(maxWidth: .infinity)` für den Header und kleinere Schrift. KEINE großen Umbauten — nur wenn der iOS-Build/das Layout es erzwingt. (Dieser Step ist überwiegend ein Sicht-/Build-Check.)

- [ ] **Step 3: Beide Builds grün** (wie Task 2 Step 2)

- [ ] **Step 4: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Calendar/CalendarModuleView.swift
git commit -m "ComHub: Kalender-Filter-Popover iPhone-tauglich (compact adaptation)"
```

---

## Task 6: Dokumentation (Phase 6a)

**Files:**
- Modify: `apps/comhub-native/README.md`

- [ ] **Step 1: Phase-6a-Zeile + Build-Hinweis ergänzen**

Im Abschnitt `## Phasen-Stand` nach dem `**Phase 5a** …`-Absatz einfügen:

```markdown

**Phase 6a** — **iOS-Feinschliff**: dieselbe Codebasis läuft jetzt auf iPhone/iPad.
Shell cross-platform (optionale `List`-Selection, `NavigationStack`-Content,
`.balanced`-Split). Die Multi-Pane-Module sind **adaptiv**: auf iPhone (kompakte
Breite) wird aus dem festbreiten Neben­einander eine Master-Liste mit Push ins
Detail (Kontakte, Kombox) bzw. ein Filter-Menü + Liste (Aufgaben); auf macOS/iPad
bleibt das Wide-Layout. Kalender-Filter als kompaktes Popover. `CompactWidthReader`
(`horizontalSizeClass` auf iOS, `false` auf macOS) steuert die Umschaltung.
Google/Microsoft-Konten folgen in Phase 6b.
```

Und im `## Build & Test`-Abschnitt den iOS-Build ergänzen (nach dem macOS-Build-Block):
```markdown

# iOS-Simulator (Build verifizieren)
xcodebuild -scheme ComHub -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' build
```

- [ ] **Step 2: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/README.md
git commit -m "Docs: ComHub-README Phase 6a (iOS-Feinschliff)"
```

---

## Self-Review (durchgeführt)

**1. Abdeckung der iPhone-Breaker (aus dem Investigator-Bericht):**
- iOS baut nicht (`List`-Selection) → Task 1 (optionale Bindung + iterativer Build-Fix). ✔
- Kombox 3-Pane (180+320 fix) → Task 4. ✔
- Kontakte 2-Pane (330 fix) → Task 2. ✔
- Aufgaben 2-Pane (210 fix) → Task 3. ✔
- Shell-`NavigationSplitView`-Verhalten compact → Task 1 (`.balanced` + NavigationStack). ✔
- Filter-Popover auf iPhone → Task 5. ✔
- EventEditSheet `minWidth/minHeight` ist bereits `#if os(macOS)`-gated → kein Fix nötig (bewusst ausgelassen). ✔
- WhatsApp-WebView bereits dual-representable → nur Build-Check (Task 1). ✔

**2. Platzhalter-Scan:** Kein „TBD/TODO". Jeder Step hat konkreten Code/Edit + Befehl + erwartete Ausgabe. Zwei bewusste Implementierungs-Weichen (Kombox compact: Push vs. VStack; Popover vs. Sheet) mit Default-Empfehlung + Doku-Pflicht im Commit.

**3. Typ-Konsistenz:**
- `CompactWidthReader` (Task 1) ↔ genutzt in Tasks 2/3/4. ✔
- `selectedModule: ComHubModule?` (Task 1) ↔ `moduleContent(_:)`/`CockpitView(onOpenModule:)`. ✔
- Reale Pane-/Store-Namen werden per „READ + anpassen"-Hinweis verankert (wie in D2c/5a bewährt). ✔

**4. Verifikations-Disziplin:** Jede Task baut **iOS-Sim UND macOS** (Doppel-Gate), Task 1 iteriert bis grün, Task 1 prüft zusätzlich AtollHub-Tests. Geräte-Smoke (Touch, Realtime, WebView-Login) macht der User. Konform zu superpowers:verification-before-completion (Build ist hier das ehrliche, erreichbare Gate; Geräte-UX explizit dem User übergeben).

---

## Execution Handoff

**Plan komplett und gespeichert unter `docs/superpowers/plans/2026-06-03-comhub-phase6a-ios.md`. Zwei Ausführungs-Optionen:**

**1. Subagent-Driven (empfohlen)** — frischer Subagent pro Task, Review zwischen den Tasks. (REQUIRED SUB-SKILL: superpowers:subagent-driven-development.)

**2. Inline-Ausführung** — Tasks in dieser Session, Batch mit Checkpoints. (REQUIRED SUB-SKILL: superpowers:executing-plans.)

**Welcher Ansatz?**
