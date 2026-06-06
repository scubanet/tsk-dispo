# ComHub Design D2a — Kontakte-Restyle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Das **Kontakte-Modul** im CoHub-Mockup-Look: 2-Pane (links A-Z-gruppierte Kontaktliste mit Suche, Avatar, Quell-Chips, E-Mail; rechts Detail mit grossem Avatar, Aktions-Buttons, Detail-Zeilen). Reiner Restyle der bestehenden Funktion (Apple+Atoll-Adressbuch via `MergedContact`) — keine neuen Daten/Features.

**Architecture:** Reine A-Z-Gruppierung (`ContactSections.byLetter`) wandert nach `AtollHub` (TDD). Die SwiftUI-UI wird ComHub-lokal neu gebaut: `ContactListPane` (Header + Suche + sticky Buchstaben-Sektionen + `ContactRow`) und `ContactDetailPane` (zentrierter `CoAvatar`, Aktions-Buttons Mail/Anruf via `openURL` mailto/tel, Detail-Zeilen), zusammengesetzt in `ContactsModuleView` als 2-Pane-`HStack`. Nutzt die D1-Primitive (`CoAvatar`, `CoChip`, `CoColor`). Die alte `NavigationStack { ContactsModuleView }`-Verdrahtung in der Shell entfällt (das neue Modul rendert Liste+Detail selbst). Exakte Masse: `docs/superpowers/specs/2026-06-02-comhub-design-system.md` (Abschnitt Kontakte) + `view-kontakte.jsx`.

**Tech Stack:** Swift 6 (strict concurrency complete), SwiftUI Multiplatform (iOS 26 / macOS 26), XcodeGen, XCTest. Reuse: `MergedContact` (`.id`, `.displayName`, `.emails`, `.phones`, `.sources: [AccountType]`), `ContactsStore` (`.merged`, `.filtered`, `.search`, `.reload(using:)`), `CoAvatar`/`CoChip`/`CoColor`, `Hub`.

---

## Scope-Grenzen (bewusst)

- **Nur Restyle** der bestehenden Kontakte-Funktion. Keine neuen Felder (Mockup zeigt Funktion/Firma — `MergedContact` hat die nicht; entfallen). Keine Schreib-Aktionen.
- **Aktions-Buttons:** Mockup zeigt 4 (Nachricht/Anruf/Video/Mail). Mit den vorhandenen Daten sinnvoll: **Mail** (`mailto:` erste E-Mail) und **Anruf** (`tel:` erste Telefonnummer) via `openURL`. Nachricht/Video entfallen (keine Datenbasis). Buttons ohne Ziel werden nicht gezeigt.
- **Quell-Chips** = `MergedContact.sources` (Apple/Atoll) statt der Mockup-„Accounts".
- **Gruppierung** nach erstem Buchstaben des `displayName` (MergedContact hat keinen getrennten Nachnamen). Nicht-Buchstabe → „#".

---

## File Structure

**Geändertes Paket — `swift-packages/AtollHub/`:**
- `Sources/AtollHub/Contacts/ContactSections.swift` — `ContactLetterSection`, `ContactSections.byLetter(_:)`.
- `Tests/AtollHubTests/ContactSectionsTests.swift`.

**Neue/geänderte App-Dateien — `apps/comhub-native/ComHub/Contacts/`:**
- `ContactRow.swift` — eine Listen-Zeile (Avatar + Name + Quell-Chips + E-Mail).
- `ContactListPane.swift` — Header + Suche + A-Z-Sektionen + Auswahl.
- `ContactDetailPane.swift` — Avatar + Aktionen + Detail-Zeilen.
- `ContactsModuleView.swift` — 2-Pane-Zusammenbau (ersetzt die Phase-1-Version).

**Geänderte App-Datei:**
- `ComHub/Shell/HubShell.swift` — `.kontakte` ohne `NavigationStack`-Wrapper.

**Doku:**
- `apps/comhub-native/README.md` — D2a-Zeile.

---

## Task 1: `ContactSections.byLetter` (AtollHub, TDD)

**Files:**
- Create: `swift-packages/AtollHub/Sources/AtollHub/Contacts/ContactSections.swift`
- Test: `swift-packages/AtollHub/Tests/AtollHubTests/ContactSectionsTests.swift`

- [ ] **Step 1: Failing Test schreiben**

`swift-packages/AtollHub/Tests/AtollHubTests/ContactSectionsTests.swift`:

```swift
import XCTest
@testable import AtollHub

final class ContactSectionsTests: XCTestCase {
  private func c(_ id: String, _ name: String) -> MergedContact {
    MergedContact(group: [UnifiedContact(
      id: id, source: AccountRef(accountId: "x", type: .apple),
      firstName: "", lastName: name, emails: [], phones: [])])
  }

  func test_groupsByFirstLetterSortedWithMembersSorted() {
    let input = [c("1","Muster"), c("2","Anna"), c("3","Albert"), c("4","Zorro")]
    let sections = ContactSections.byLetter(input)
    XCTAssertEqual(sections.map(\.letter), ["A", "M", "Z"])
    XCTAssertEqual(sections[0].contacts.map(\.displayName), ["Albert", "Anna"])
    XCTAssertEqual(sections[1].contacts.map(\.displayName), ["Muster"])
  }

  func test_nonLetterStartGroupsUnderHash() {
    let sections = ContactSections.byLetter([c("1","+41 79"), c("2","Ben")])
    XCTAssertEqual(Set(sections.map(\.letter)), ["#", "B"])
  }

  func test_emptyInputEmptyOutput() {
    XCTAssertTrue(ContactSections.byLetter([]).isEmpty)
  }
}
```

- [ ] **Step 2: Test ausführen — soll fehlschlagen**

Run: `cd swift-packages/AtollHub && swift test --filter ContactSectionsTests`
Expected: FAIL — `cannot find 'ContactSections' in scope`.

- [ ] **Step 3: Implementieren**

`swift-packages/AtollHub/Sources/AtollHub/Contacts/ContactSections.swift`:

```swift
import Foundation

/// Eine A-Z-Sektion der Kontaktliste.
public struct ContactLetterSection: Sendable, Identifiable, Equatable {
  public let id: String        // = letter
  public let letter: String
  public let contacts: [MergedContact]
  public init(letter: String, contacts: [MergedContact]) {
    self.id = letter; self.letter = letter; self.contacts = contacts
  }
}

/// Gruppiert `MergedContact`s nach dem ersten Buchstaben des Anzeigenamens
/// (Nicht-Buchstabe → „#"), Sektionen alphabetisch, Mitglieder nach Name.
public enum ContactSections {
  public static func byLetter(_ contacts: [MergedContact]) -> [ContactLetterSection] {
    var buckets: [String: [MergedContact]] = [:]
    for c in contacts {
      let first = c.displayName.trimmingCharacters(in: .whitespaces).first
      let key: String
      if let f = first, f.isLetter { key = String(f).uppercased() } else { key = "#" }
      buckets[key, default: []].append(c)
    }
    return buckets.keys.sorted { $0.localizedCompare($1) == .orderedAscending }.map { letter in
      let sorted = buckets[letter]!.sorted {
        $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
      }
      return ContactLetterSection(letter: letter, contacts: sorted)
    }
  }
}
```

- [ ] **Step 4: Test ausführen — soll grün sein**

Run: `cd swift-packages/AtollHub && swift test --filter ContactSectionsTests`
Expected: PASS — 3 Tests grün.

- [ ] **Step 5: Volle Paket-Suite + Commit**

Run: `cd swift-packages/AtollHub && swift test`
Expected: PASS — alle Suiten grün.

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add swift-packages/AtollHub/Sources/AtollHub/Contacts/ContactSections.swift swift-packages/AtollHub/Tests/AtollHubTests/ContactSectionsTests.swift
git commit -m "AtollHub: ContactSections.byLetter (A-Z-Gruppierung, rein/getestet)"
```

---

## Task 2: `ContactRow` + `ContactListPane` (ComHub)

**Files:**
- Create: `apps/comhub-native/ComHub/Contacts/ContactRow.swift`
- Create: `apps/comhub-native/ComHub/Contacts/ContactListPane.swift`

- [ ] **Step 1: `ContactRow` schreiben**

`apps/comhub-native/ComHub/Contacts/ContactRow.swift`:

```swift
import SwiftUI
import AtollHub

/// Eine Kontaktlisten-Zeile: Avatar + Name + Quell-Chips + erste E-Mail.
/// `selected` faerbt die Zeile im Akzent (weisser Text).
struct ContactRow: View {
  let contact: MergedContact
  let selected: Bool

  var body: some View {
    HStack(spacing: 11) {
      CoAvatar(name: contact.displayName, size: 32)
      VStack(alignment: .leading, spacing: 2) {
        Text(contact.displayName)
          .font(.system(size: 13.5, weight: .semibold))
          .foregroundStyle(selected ? .white : .primary)
          .lineLimit(1)
        HStack(spacing: 6) {
          ForEach(contact.sources, id: \.self) { src in
            Text(src == .atoll ? "Atoll" : "Apple")
              .font(.system(size: 10.5, weight: .medium))
              .padding(.horizontal, 6).padding(.vertical, 1)
              .foregroundStyle(selected ? .white : .secondary)
              .background(selected ? AnyShapeStyle(.white.opacity(0.22)) : AnyShapeStyle(.quaternary),
                          in: RoundedRectangle(cornerRadius: 5))
          }
          if let mail = contact.emails.first {
            Text(mail)
              .font(.system(size: 11.5))
              .foregroundStyle(selected ? .white.opacity(0.8) : .tertiary)
              .lineLimit(1)
          }
        }
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 14).padding(.vertical, 7)
    .background(selected ? CoColor.accent : .clear)
    .contentShape(Rectangle())
  }
}
```

- [ ] **Step 2: `ContactListPane` schreiben**

`apps/comhub-native/ComHub/Contacts/ContactListPane.swift`:

```swift
import SwiftUI
import AtollHub

/// Linke Spalte: Header („Kontakte" + Anzahl), Suchfeld, A-Z-Sektionen.
struct ContactListPane: View {
  let store: ContactsStore
  @Binding var selection: String?

  private var sections: [ContactLetterSection] {
    ContactSections.byLetter(store.filtered)
  }

  var body: some View {
    VStack(spacing: 0) {
      VStack(spacing: 10) {
        HStack {
          Text("Kontakte").font(.system(size: 17, weight: .bold))
          Spacer()
          Text("\(store.filtered.count)").font(.system(size: 12)).foregroundStyle(.tertiary)
        }
        searchField
      }
      .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 10)
      Divider()

      ScrollView {
        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
          ForEach(sections) { section in
            Section {
              ForEach(section.contacts) { contact in
                ContactRow(contact: contact, selected: selection == contact.id)
                  .onTapGesture { selection = contact.id }
                Divider()
              }
            } header: {
              Text(section.letter)
                .font(.system(size: 11, weight: .bold)).foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14).padding(.vertical, 3)
                .background(.bar)
            }
          }
        }
      }
    }
  }

  private var searchField: some View {
    HStack(spacing: 7) {
      Image(systemName: "magnifyingglass").font(.system(size: 13)).foregroundStyle(.tertiary)
      TextField("Kontakte suchen", text: Binding(
        get: { store.search }, set: { store.search = $0 }))
        .textFieldStyle(.plain)
        .font(.system(size: 13))
    }
    .padding(.horizontal, 10).frame(height: 30)
    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
  }
}
```

> Hinweis: `store.search` ist `var` (kein `private(set)`) im `ContactsStore` (Phase 1) — falls es `private(set)` ist, in `ContactsStore` zu `var search = ""` (schreibbar) ändern und das in Task 4 mit-committen.

- [ ] **Step 3: Build verifizieren**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`. (Falls `store.search` nicht beschreibbar: `ContactsStore.search` auf `var search = ""` setzen, im Build-Schritt verifizieren, in Task 4 committen.)

- [ ] **Step 4: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Contacts/ContactRow.swift apps/comhub-native/ComHub/Contacts/ContactListPane.swift
git commit -m "ComHub: Kontakte-Liste im CoHub-Look (Zeile + A-Z-Pane mit Suche)"
```

---

## Task 3: `ContactDetailPane` (ComHub)

**Files:**
- Create: `apps/comhub-native/ComHub/Contacts/ContactDetailPane.swift`

- [ ] **Step 1: View schreiben**

`apps/comhub-native/ComHub/Contacts/ContactDetailPane.swift`:

```swift
import SwiftUI
import AtollHub

/// Rechte Spalte: grosser Avatar, Name, Quellen, Aktions-Buttons (Mail/Anruf),
/// Detail-Zeilen (E-Mail/Telefon/Quellen).
struct ContactDetailPane: View {
  let contact: MergedContact?
  @Environment(\.openURL) private var openURL

  var body: some View {
    if let contact {
      ScrollView {
        VStack(spacing: 0) {
          VStack(spacing: 0) {
            CoAvatar(name: contact.displayName, size: 92)
            Text(contact.displayName)
              .font(.system(size: 24, weight: .bold))
              .multilineTextAlignment(.center)
              .padding(.top, 16)
            Text(contact.sources.map { $0 == .atoll ? "Atoll" : "Apple" }.joined(separator: " · "))
              .font(.system(size: 14)).foregroundStyle(.secondary).padding(.top, 3)
            actions(contact).padding(.top, 20)
          }
          .padding(.horizontal, 30).padding(.top, 36).padding(.bottom, 22)
          Divider()
          VStack(spacing: 0) {
            detailRow("E-Mail", contact.emails, accent: true)
            detailRow("Telefon", contact.phones, accent: true)
            detailRow("Quellen", [contact.sources.map { $0 == .atoll ? "Atoll" : "Apple" }.joined(separator: ", ")], accent: false)
          }
          .padding(.horizontal, 30).padding(.vertical, 6)
          .frame(maxWidth: 520)
        }
        .frame(maxWidth: .infinity)
      }
    } else {
      ContentUnavailableView("Kein Kontakt ausgewählt", systemImage: "person.2",
                             description: Text("Wähle links einen Kontakt aus."))
    }
  }

  @ViewBuilder
  private func actions(_ contact: MergedContact) -> some View {
    HStack(spacing: 10) {
      if let mail = contact.emails.first, let url = URL(string: "mailto:\(mail)") {
        actionButton("Mail", "envelope") { openURL(url) }
      }
      if let phone = contact.phones.first,
         let url = URL(string: "tel:\(phone.filter { $0.isNumber || $0 == "+" })") {
        actionButton("Anruf", "phone") { openURL(url) }
      }
    }
  }

  private func actionButton(_ label: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
    Button(action: action) {
      VStack(spacing: 5) {
        Image(systemName: icon).font(.system(size: 19)).foregroundStyle(CoColor.accent)
          .frame(width: 42, height: 42)
          .background(CoColor.accent.opacity(0.12), in: Circle())
        Text(label).font(.system(size: 11)).foregroundStyle(CoColor.accent)
      }
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder
  private func detailRow(_ label: String, _ values: [String], accent: Bool) -> some View {
    let shown = values.filter { !$0.isEmpty }
    if !shown.isEmpty {
      VStack(alignment: .leading, spacing: 1) {
        Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(.tertiary)
        ForEach(shown, id: \.self) { v in
          Text(v).font(.system(size: 13.5))
            .foregroundStyle(accent ? CoColor.accent : .primary)
            .textSelection(.enabled)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 9)
      .overlay(alignment: .bottom) { Divider() }
    }
  }
}
```

- [ ] **Step 2: Build verifizieren**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Contacts/ContactDetailPane.swift
git commit -m "ComHub: Kontakt-Detail im CoHub-Look (Avatar, Aktionen, Detail-Zeilen)"
```

---

## Task 4: `ContactsModuleView` 2-Pane + Shell entdrahten (ComHub)

**Files:**
- Modify: `apps/comhub-native/ComHub/Contacts/ContactsModuleView.swift` (ganzen Inhalt ersetzen)
- Modify: `apps/comhub-native/ComHub/Shell/HubShell.swift` (`.kontakte` ohne NavigationStack)
- (ggf.) Modify: `apps/comhub-native/ComHub/Contacts/ContactsStore.swift` (`search` beschreibbar)

- [ ] **Step 1: `ContactsModuleView` ersetzen**

`apps/comhub-native/ComHub/Contacts/ContactsModuleView.swift`:

```swift
import SwiftUI
import AtollHub

/// Kombiniertes Adressbuch im CoHub-Look: links A-Z-Liste, rechts Detail.
struct ContactsModuleView: View {
  @Environment(Hub.self) private var hub
  @State private var store = ContactsStore()
  @State private var selection: String?

  private var selectedContact: MergedContact? {
    store.merged.first { $0.id == selection }
  }

  var body: some View {
    HStack(spacing: 0) {
      ContactListPane(store: store, selection: $selection)
        #if os(macOS)
        .frame(width: 330)
        #endif
      Divider()
      ContactDetailPane(contact: selectedContact)
        .frame(maxWidth: .infinity)
    }
    .task {
      await store.reload(using: hub)
      if selection == nil { selection = ContactSections.byLetter(store.filtered).first?.contacts.first?.id }
    }
  }
}
```

- [ ] **Step 2: Falls nötig — `ContactsStore.search` beschreibbar machen**

`ContactsStore` aus Phase 1 prüfen: `var search = ""` muss öffentlich schreibbar sein (kein `private(set)`). Ist es bereits `var search = ""` (so im Phase-1-Plan) → nichts tun. Falls `private(set)`, das Schlüsselwort entfernen.

- [ ] **Step 3: Shell — `.kontakte` ohne `NavigationStack`**

In `apps/comhub-native/ComHub/Shell/HubShell.swift` den `.kontakte`-Content-Zweig ersetzen von:

```swift
      case .kontakte:
        // NavigationStack, damit NavigationLink/navigationDestination in der
        // Content-Spalte das Kontakt-Detail tatsaechlich pushen koennen.
        NavigationStack { ContactsModuleView() }
          #if os(macOS)
          .frame(minWidth: 320)
          #endif
```

zu:

```swift
      case .kontakte:
        ContactsModuleView()
          #if os(macOS)
          .frame(minWidth: 560)
          #endif
```

(Der `detail:`-Block bleibt — `.kontakte` ist dort weiterhin bei den `Color.clear`-Modulen.)

- [ ] **Step 4: Generieren + Build**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Manueller Smoke-Test** (echter Mac, Light + Dark)

- [ ] **Kontakte**: links Header „Kontakte" + Anzahl + Suchfeld; A-Z-Sektionen (sticky Buchstaben); Zeilen mit Avatar + Name + Quell-Chips (Apple/Atoll) + E-Mail.
- [ ] Klick auf Zeile → Akzent-Highlight, rechts Detail: grosser Avatar, Name, Quellen, Buttons (Mail/Anruf falls vorhanden), Detail-Zeilen E-Mail/Telefon/Quellen.
- [ ] Suche filtert die Liste live.
- [ ] „Mail"/„Anruf" öffnen Mail-Programm / Telefon-Prompt (falls Daten vorhanden).
- [ ] Dark Mode: alles lesbar, Akzent-Auswahl korrekt.

- [ ] **Step 6: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Contacts/ContactsModuleView.swift apps/comhub-native/ComHub/Shell/HubShell.swift apps/comhub-native/ComHub/Contacts/ContactsStore.swift
git commit -m "ComHub: Kontakte 2-Pane im CoHub-Look (Liste + Detail) + Shell entdrahtet"
```

---

## Task 5: Dokumentation (D2a)

**Files:**
- Modify: `apps/comhub-native/README.md`

- [ ] **Step 1: D2a-Zeile ergänzen**

In `apps/comhub-native/README.md` im Abschnitt `## Phasen-Stand` **nach** dem `**Design D1** …`-Absatz einfügen:

```markdown

**Design D2a** — **Kontakte** im CoHub-Look: 2-Pane (links A-Z-Liste mit Suche,
Avatar, Quell-Chips, E-Mail; rechts Detail mit grossem Avatar, Mail/Anruf-Aktionen,
Detail-Zeilen). A-Z-Gruppierung getestet in `AtollHub` (`ContactSections`).
Kalender-Rebuild folgt in D2b; Kombox-Restyle in Phase 3b.
```

- [ ] **Step 2: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/README.md
git commit -m "Docs: ComHub-README Design-D2a (Kontakte-Restyle)"
```

---

## Self-Review (durchgeführt)

**1. Spec-Abdeckung (Mockup `view-kontakte.jsx`, Slice D2a):**
- 2-Pane Liste (330) + Detail → Task 4 (`ContactsModuleView`).
- Liste: Header „Kontakte" + Anzahl + Suche, A-Z sticky Gruppen, Zeile Avatar+Name+Chips+Mail → Task 1 (Gruppierung) + Task 2 (`ContactRow`/`ContactListPane`).
- Detail: grosser Avatar + Name + (Quellen statt role·org) + Aktions-Buttons + Detail-Zeilen → Task 3 (`ContactDetailPane`).
- Bewusste Abweichungen (Scope-Grenzen): Funktion/Firma entfallen (keine Daten); Aktionen nur Mail/Anruf; „Accounts"→„Quellen" (Apple/Atoll).

**2. Platzhalter-Scan:** Keine „TBD/TODO". Vollständiger Code je Schritt; Befehl + erwartete Ausgabe je Run. Empty-State (`ContentUnavailableView`) vollständig.

**3. Typ-Konsistenz:**
- `ContactSections.byLetter(_:)` + `ContactLetterSection` (`.letter`/`.contacts`/`.id`) (Task 1) ↔ `ContactListPane` (Task 2) + `ContactsModuleView` (Task 4). ✔
- `MergedContact` (`.id`/`.displayName`/`.emails`/`.phones`/`.sources`) ↔ `ContactRow`/`ContactDetailPane`. ✔
- `ContactsStore` (`.merged`/`.filtered`/`.search`/`.reload(using:)`) ↔ Panes/Module. ✔ (Phase-1-Store; `search` muss `var` sein — Task 4 Step 2 stellt das sicher.)
- D1-Primitive `CoAvatar(name:size:)`/`CoColor.accent` ↔ Zeilen/Detail. ✔
- Shell: `.kontakte`-Content ohne `NavigationStack`; `detail:` unverändert (`.kontakte` bleibt `Color.clear`). ✔

**4. Verifikations-Disziplin:** Task 1 echte TDD (`swift test`). Tasks 2–4 build-verifiziert (`xcodegen generate` + `xcodebuild`); Task 4 schliesst mit manuellem Smoke-Test inkl. Dark Mode. Konform zu superpowers:verification-before-completion.

---

## Execution Handoff

**Plan komplett und gespeichert unter `docs/superpowers/plans/2026-06-02-comhub-designD2a-kontakte.md`. Zwei Ausführungs-Optionen:**

**1. Subagent-Driven (empfohlen)** — frischer Subagent pro Task, Review zwischen den Tasks. (REQUIRED SUB-SKILL: superpowers:subagent-driven-development.)

**2. Inline-Ausführung** — Tasks in dieser Session, Batch mit Checkpoints. (REQUIRED SUB-SKILL: superpowers:executing-plans.)

**Welcher Ansatz?**
