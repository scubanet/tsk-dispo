# ComHub Phase 3b — Kombox schreiben + 3-Pane-Restyle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Die **Kombox** als vollwertige 3-Pane-Mailbox im CoHub-Look: **Kanal-Rail** (Alle/WhatsApp/Mail) + **Thread-Liste** (Suche, restylte Zeilen) + **Reader** (Kopf, Tages-Verlauf, **Composer** zum Senden via `comms-outbound`, Nachricht **löschen**). Baut auf der lese-only Phase 3a (Realtime, `KomboxStore`) auf.

**Architecture:** Reine Filter-Logik (`KomboxFilter`) wandert nach `AtollHub` (TDD). Der `KomboxStore` (3a) wird erweitert um Filter/Suche-State, **Senden** (`functions.invoke("comms-outbound")` mit Encodable-Body) und **Löschen** (`contact_events.delete()`), beides gefolgt von Refetch (Realtime bringt eingehende Bestätigung). Die UI wird auf 3-Pane gebracht: `KomboxRailView` (Filter), restylte `ConversationRow`/-liste, restylter Reader (`KomboxThreadView` mit Kopf + Tages-Sektionen + Composer), `KomboxComposer` (Kanal-Switch WhatsApp/Mail, Betreff, Eingabe, Senden). Nutzt D1-Primitive (`CoAvatar`, `CoColor`). Backend-Vertrag aus der Investigation: `comms-outbound` `{contact_id, channel, body, subject?}` → `{ok, provider_message_id}`; Löschen `contact_events.delete().eq("id")`.

**Tech Stack:** Swift 6 (strict concurrency complete), SwiftUI Multiplatform (iOS 26 / macOS 26), XcodeGen, XCTest, `supabase-swift` 2.46 (`functions.invoke` + `FunctionInvokeOptions(body:)`, PostgREST `.delete()`). Reuse: 3a `KomboxStore`/`KomboxEvent`/`KomboxConversation`/`KomboxMapper`/`KomboxDigest`, Realtime; `CoAvatar`/`CoColor`.

---

## Scope-Grenzen (bewusst)

- **Kanäle Alle/WhatsApp/Mail** (kein iMessage; kein „Markiert"/Flag — `contact_events` hat kein Flag).
- **Senden** über `comms-outbound` (WhatsApp via 360dialog, Mail via Resend — serverseitig). **Voraussetzung:** der eingeloggte User braucht eine `messaging_accounts`-Zeile für den Kanal; sonst antwortet die Function mit Fehler → die App zeigt eine Fehlermeldung (kein Absturz).
- **Aktionen:** **Löschen** einer Nachricht (`contact_events.delete`, RLS = Owner). **Antworten** = Composer mit passendem Kanal fokussieren. **Status** (resolved/archived), Quick-Log, Anhänge, Mail-Reader-Vollansicht = **out of scope** (später).
- **Senden ist real** (echte WhatsApp/Mail an reale Kontakte). Kein Bestätigungsdialog (wie Web-Mailbox) — Smoke-Test nur mit Test-Kontakt.
- **Privat-WhatsApp-WebView** bleibt Phase 3c.

---

## File Structure

**Geändertes Paket — `swift-packages/AtollHub/`:**
- `Sources/AtollHub/Kombox/KomboxFilter.swift` — `KomboxChannel`, `KomboxFilter.apply(_:channel:search:)`.
- `Tests/AtollHubTests/KomboxFilterTests.swift`.

**Neue/geänderte App-Dateien — `apps/comhub-native/ComHub/Kombox/`:**
- `KomboxStore.swift` — **erweitern**: Filter/Suche, `send`, `deleteEvent`.
- `KomboxRailView.swift` — Kanal-Rail (Alle/WhatsApp/Mail).
- `ConversationListView.swift` — **restyle** (Kopf + Suche + Zeilen mit Avatar+Kanal-Dot).
- `KomboxComposer.swift` — Kanal-Switch + Betreff + Eingabe + Senden.
- `ThreadView.swift` — **restyle**: Kopf (`HeaderBar`) + Tages-Verlauf + Composer; per-Nachricht Löschen.
- `KomboxModuleView.swift` — **3-Pane** (Rail · Liste · Reader).

**Doku:**
- `apps/comhub-native/README.md` — Phase-3b-Zeile.

---

## Task 1: `KomboxFilter` (AtollHub, TDD)

**Files:**
- Create: `swift-packages/AtollHub/Sources/AtollHub/Kombox/KomboxFilter.swift`
- Test: `swift-packages/AtollHub/Tests/AtollHubTests/KomboxFilterTests.swift`

- [ ] **Step 1: Failing Test schreiben**

`swift-packages/AtollHub/Tests/AtollHubTests/KomboxFilterTests.swift`:

```swift
import XCTest
@testable import AtollHub

final class KomboxFilterTests: XCTestCase {
  private func conv(_ id: String, name: String, kind: KomboxKind, preview: String) -> KomboxConversation {
    let e = KomboxEvent(id: id, contactId: id, contactName: name, kind: kind,
                        direction: .inbound, summary: preview, body: preview, subject: nil,
                        timestamp: Date(timeIntervalSince1970: 1), status: "open")
    return KomboxConversation(id: id, contactName: name, lastEvent: e)
  }

  func test_channelAllKeepsEverything() {
    let cs = [conv("1", name: "Anna", kind: .whatsapp, preview: "hi"),
              conv("2", name: "Ben", kind: .email, preview: "re"),
              conv("3", name: "C", kind: .system, preview: "note")]
    XCTAssertEqual(KomboxFilter.apply(cs, channel: .all, search: "").count, 3)
  }

  func test_channelWhatsappOnly() {
    let cs = [conv("1", name: "Anna", kind: .whatsapp, preview: "hi"),
              conv("2", name: "Ben", kind: .email, preview: "re")]
    let out = KomboxFilter.apply(cs, channel: .whatsapp, search: "")
    XCTAssertEqual(out.map(\.id), ["1"])
  }

  func test_searchMatchesNameOrPreviewCaseInsensitive() {
    let cs = [conv("1", name: "Anna Muster", kind: .whatsapp, preview: "Tauchgang"),
              conv("2", name: "Ben", kind: .whatsapp, preview: "hallo")]
    XCTAssertEqual(KomboxFilter.apply(cs, channel: .all, search: "muster").map(\.id), ["1"])
    XCTAssertEqual(KomboxFilter.apply(cs, channel: .all, search: "HALLO").map(\.id), ["2"])
  }
}
```

- [ ] **Step 2: Test ausführen — soll fehlschlagen**

Run: `cd swift-packages/AtollHub && swift test --filter KomboxFilterTests`
Expected: FAIL — `cannot find 'KomboxFilter' in scope`.

- [ ] **Step 3: Implementieren**

`swift-packages/AtollHub/Sources/AtollHub/Kombox/KomboxFilter.swift`:

```swift
import Foundation

/// Kanal-Filter der Kombox-Kontaktliste.
public enum KomboxChannel: String, Sendable, CaseIterable, Identifiable {
  case all, whatsapp, mail
  public var id: String { rawValue }
  public var title: String {
    switch self { case .all: return "Alle"; case .whatsapp: return "WhatsApp"; case .mail: return "Mail" }
  }
}

/// Reine Filter-Logik: Kanal (nach letztem Event) + Volltextsuche (Name/Vorschau).
public enum KomboxFilter {
  public static func apply(_ conversations: [KomboxConversation],
                           channel: KomboxChannel, search: String) -> [KomboxConversation] {
    let q = search.trimmingCharacters(in: .whitespaces).lowercased()
    return conversations.filter { c in
      switch channel {
      case .all:      break
      case .whatsapp: if c.lastEvent.kind != .whatsapp { return false }
      case .mail:     if c.lastEvent.kind != .email { return false }
      }
      guard !q.isEmpty else { return true }
      let hay = (c.contactName + " " + (c.lastEvent.subject ?? "")
                 + " " + (c.lastEvent.body ?? c.lastEvent.summary)).lowercased()
      return hay.contains(q)
    }
  }
}
```

- [ ] **Step 4: Test ausführen — soll grün sein**

Run: `cd swift-packages/AtollHub && swift test --filter KomboxFilterTests`
Expected: PASS — 3 Tests grün.

- [ ] **Step 5: Volle Paket-Suite + Commit**

Run: `cd swift-packages/AtollHub && swift test`
Expected: PASS — alle Suiten grün.

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add swift-packages/AtollHub/Sources/AtollHub/Kombox/KomboxFilter.swift swift-packages/AtollHub/Tests/AtollHubTests/KomboxFilterTests.swift
git commit -m "AtollHub: KomboxFilter (Kanal + Suche, rein/getestet)"
```

---

## Task 2: `KomboxStore` erweitern — Filter/Suche + Senden + Löschen (ComHub)

**Files:**
- Modify: `apps/comhub-native/ComHub/Kombox/KomboxStore.swift`

- [ ] **Step 1: Store erweitern**

In `apps/comhub-native/ComHub/Kombox/KomboxStore.swift`:

1. Sicherstellen, dass `import Supabase` und `import AtollHub` oben stehen (sind sie aus 3a). Falls `FunctionInvokeOptions` nicht auflöst, `import Functions` ergänzen.

2. Neue Properties neben den bestehenden `private(set)`-Feldern:

```swift
  var channel: KomboxChannel = .all
  var search: String = ""
  private(set) var sending = false
  private(set) var actionError: String?

  /// Gefilterte Konversationen (Kanal + Suche) — die Liste rendert diese.
  var visibleConversations: [KomboxConversation] {
    KomboxFilter.apply(conversations, channel: channel, search: search)
  }
```

3. Encodable/Decodable-Hilfstypen + `send`/`deleteEvent`-Methoden (innerhalb der Klasse) ergänzen:

```swift
  private struct OutboundRequest: Encodable {
    let contactId: String
    let channel: String
    let body: String
    let subject: String?
    enum CodingKeys: String, CodingKey { case contactId = "contact_id"; case channel, body, subject }
  }
  private struct OutboundResponse: Decodable { let ok: Bool? }

  /// Sendet via Edge Function `comms-outbound`. `channel` = "whatsapp" | "email".
  /// Bei Erfolg bringt Realtime das Outbound-Event; zusätzlich Refetch.
  func send(channel: String, body: String, subject: String?) async -> Bool {
    guard let contactId = selectedContactId else { return false }
    let text = body.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return false }
    sending = true; actionError = nil
    defer { sending = false }
    do {
      let req = OutboundRequest(contactId: contactId, channel: channel, body: text,
                                subject: (channel == "email") ? subject : nil)
      let _: OutboundResponse = try await supabase.functions.invoke(
        "comms-outbound", options: FunctionInvokeOptions(body: req))
      await reloadThread(); await reloadConversations()
      return true
    } catch {
      logger.error("send failed: \(error.localizedDescription, privacy: .public)")
      actionError = "Senden fehlgeschlagen (Konto verbunden?)"
      return false
    }
  }

  /// Löscht eine Nachricht (RLS: nur Owner). DELETE ist nicht im Realtime —
  /// daher manueller Refetch.
  func deleteEvent(id: String) async {
    do {
      try await supabase.from("contact_events").delete().eq("id", value: id).execute()
      await reloadThread(); await reloadConversations()
    } catch {
      logger.error("delete failed: \(error.localizedDescription, privacy: .public)")
      actionError = "Loeschen fehlgeschlagen."
    }
  }
```

> Hinweis: `supabase`, `logger`, `selectedContactId`, `reloadThread`, `reloadConversations` existieren aus 3a. `KomboxChannel`/`KomboxFilter`/`KomboxConversation` aus `AtollHub`.

- [ ] **Step 2: Build verifizieren**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`. Beweist die `functions.invoke(_:options:)`-Signatur (generische Decodable-Rückgabe) + `FunctionInvokeOptions(body:)` + PostgREST `.delete().eq(_:value:).execute()`. **Falls `functions.invoke`/`FunctionInvokeOptions` nicht auflösen:** `import Functions` oben ergänzen; falls die Signatur abweicht, in der supabase-swift-2.46-Quelle (`apps/comhub-native/.build`/DerivedData `SourcePackages/checkouts/supabase-swift/Sources/Functions/FunctionsClient.swift`) prüfen und angleichen — melden.

- [ ] **Step 3: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Kombox/KomboxStore.swift
git commit -m "ComHub: KomboxStore Senden (comms-outbound) + Loeschen + Filter/Suche"
```

---

## Task 3: `KomboxRailView` + restylte Konversationsliste (ComHub)

**Files:**
- Create: `apps/comhub-native/ComHub/Kombox/KomboxRailView.swift`
- Modify: `apps/comhub-native/ComHub/Kombox/ConversationListView.swift` (ganzen Inhalt ersetzen)

- [ ] **Step 1: `KomboxRailView` schreiben**

`apps/comhub-native/ComHub/Kombox/KomboxRailView.swift`:

```swift
import SwiftUI
import AtollHub

/// Kanal-Rail: Posteingang-Filter Alle/WhatsApp/Mail.
struct KomboxRailView: View {
  @Binding var channel: KomboxChannel

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text("POSTEINGANG").font(.system(size: 11, weight: .bold)).foregroundStyle(.tertiary)
        .padding(.horizontal, 10).padding(.top, 4).padding(.bottom, 8)
      ForEach(KomboxChannel.allCases) { ch in
        Button { channel = ch } label: {
          HStack(spacing: 9) {
            Image(systemName: icon(ch))
              .font(.system(size: 14)).foregroundStyle(channel == ch ? .white : iconColor(ch))
              .frame(width: 18)
            Text(ch.title).font(.system(size: 13, weight: channel == ch ? .semibold : .medium))
              .foregroundStyle(channel == ch ? .white : .primary)
            Spacer(minLength: 0)
          }
          .padding(.horizontal, 10).frame(height: 32)
          .background(channel == ch ? CoColor.accent : .clear, in: RoundedRectangle(cornerRadius: 7))
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
      Spacer()
    }
    .padding(10)
  }

  private func icon(_ ch: KomboxChannel) -> String {
    switch ch { case .all: return "tray.full"; case .whatsapp: return "bubble.left.fill"; case .mail: return "envelope.fill" }
  }
  private func iconColor(_ ch: KomboxChannel) -> Color {
    switch ch { case .all: return .secondary; case .whatsapp: return CoColor.module(.kombox); case .mail: return CoColor.accent }
  }
}
```

- [ ] **Step 2: `ConversationListView` ersetzen**

`apps/comhub-native/ComHub/Kombox/ConversationListView.swift`:

```swift
import SwiftUI
import AtollHub

/// Thread-Liste: Kopf (Filter-Titel + Anzahl) + Suche + Konversations-Zeilen.
struct ConversationListView: View {
  let store: KomboxStore
  @Binding var selection: String?

  private static let time: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "dd.MM. HH:mm"
    f.locale = Locale(identifier: "de_CH")
    f.timeZone = TimeZone(identifier: "Europe/Zurich"); return f
  }()

  var body: some View {
    VStack(spacing: 0) {
      VStack(spacing: 10) {
        HStack {
          Text(store.channel.title).font(.system(size: 17, weight: .bold))
          Spacer()
          Text("\(store.visibleConversations.count)").font(.system(size: 12)).foregroundStyle(.tertiary)
        }
        searchField
      }
      .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 10)
      Divider()

      List(store.visibleConversations, selection: $selection) { conv in
        ConversationRow(conv: conv, timeText: Self.time.string(from: conv.lastEvent.timestamp))
          .tag(conv.id)
      }
      .overlay { if store.loadingConversations && store.conversations.isEmpty { ProgressView() } }
    }
  }

  private var searchField: some View {
    HStack(spacing: 7) {
      Image(systemName: "magnifyingglass").font(.system(size: 13)).foregroundStyle(.tertiary)
      TextField("Suchen", text: Binding(get: { store.search }, set: { store.search = $0 }))
        .textFieldStyle(.plain).font(.system(size: 13))
    }
    .padding(.horizontal, 10).frame(height: 30)
    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
  }
}

/// Eine Konversations-Zeile: Avatar + Kanal-Dot, Name, Zeit, Vorschau.
private struct ConversationRow: View {
  let conv: KomboxConversation
  let timeText: String

  var body: some View {
    HStack(spacing: 10) {
      ZStack(alignment: .bottomTrailing) {
        CoAvatar(name: conv.contactName, size: 38)
        Image(systemName: channelIcon)
          .font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
          .frame(width: 15, height: 15).background(channelColor, in: Circle())
          .overlay(Circle().strokeBorder(.background, lineWidth: 1.5))
          .offset(x: 3, y: 3)
      }
      VStack(alignment: .leading, spacing: 1) {
        HStack {
          Text(conv.contactName).font(.system(size: 13.5, weight: .semibold)).lineLimit(1)
          Spacer(minLength: 0)
          Text(timeText).font(.system(size: 11)).foregroundStyle(.tertiary)
        }
        Text(preview).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
      }
    }
    .padding(.vertical, 3)
  }

  private var channelIcon: String {
    switch conv.lastEvent.kind { case .whatsapp: return "bubble.left.fill"; case .email: return "envelope.fill"; case .system: return "info" }
  }
  private var channelColor: Color {
    switch conv.lastEvent.kind { case .whatsapp: return CoColor.module(.kombox); case .email: return CoColor.accent; case .system: return .secondary }
  }
  private var preview: String {
    let e = conv.lastEvent
    let p = e.direction == .outbound ? "Du: " : ""
    return p + (e.kind == .email ? (e.subject ?? e.summary) : (e.body ?? e.summary))
  }
}
```

- [ ] **Step 3: Build verifizieren**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Kombox/KomboxRailView.swift apps/comhub-native/ComHub/Kombox/ConversationListView.swift
git commit -m "ComHub: Kombox Kanal-Rail + restylte Konversationsliste (Avatar, Kanal-Dot, Suche)"
```

---

## Task 4: `KomboxComposer` (ComHub)

**Files:**
- Create: `apps/comhub-native/ComHub/Kombox/KomboxComposer.swift`

- [ ] **Step 1: Composer schreiben**

`apps/comhub-native/ComHub/Kombox/KomboxComposer.swift`:

```swift
import SwiftUI
import AtollHub

/// Composer: Kanal-Switch (WhatsApp/Mail), Betreff (nur Mail), Eingabe, Senden.
struct KomboxComposer: View {
  let store: KomboxStore

  @State private var channel = "whatsapp"   // "whatsapp" | "email"
  @State private var subject = ""
  @State private var draft = ""

  var body: some View {
    VStack(spacing: 8) {
      if let err = store.actionError {
        Text(err).font(.caption).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading)
      }
      HStack(spacing: 8) {
        channelButton("WhatsApp", "whatsapp", CoColor.module(.kombox))
        channelButton("E-Mail", "email", CoColor.accent)
        Spacer()
      }
      if channel == "email" {
        TextField("Betreff", text: $subject)
          .textFieldStyle(.plain).font(.system(size: 13))
          .padding(.horizontal, 12).frame(height: 30)
          .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
      }
      HStack(spacing: 8) {
        TextField(channel == "email" ? "Antworten…" : "Nachricht…", text: $draft, axis: .vertical)
          .textFieldStyle(.plain).font(.system(size: 13.5)).lineLimit(1...4)
          .padding(.horizontal, 12).padding(.vertical, 7)
          .background(.quaternary, in: RoundedRectangle(cornerRadius: 18))
        Button(action: sendNow) {
          Image(systemName: "paperplane.fill").font(.system(size: 15)).foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(channel == "email" ? CoColor.accent : CoColor.module(.kombox), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(store.sending || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .opacity(store.sending ? 0.5 : 1)
      }
    }
    .padding(12)
  }

  private func channelButton(_ label: String, _ value: String, _ color: Color) -> some View {
    Button { channel = value } label: {
      Text(label).font(.system(size: 12.5, weight: .semibold))
        .foregroundStyle(channel == value ? .white : .secondary)
        .padding(.horizontal, 12).frame(height: 26)
        .background(channel == value ? color : AnyShapeStyle(.quaternary),
                    in: RoundedRectangle(cornerRadius: 7))
    }
    .buttonStyle(.plain)
  }

  private func sendNow() {
    let body = draft, subj = subject
    Task {
      let ok = await store.send(channel: channel, body: body, subject: subj)
      if ok { draft = ""; subject = "" }
    }
  }
}
```

> Hinweis zur Typ-Unifikation: `background(channel==value ? color : AnyShapeStyle(.quaternary), in:)` — falls der Compiler die Branches (`Color` vs `.quaternary`) nicht vereint, beide in `AnyShapeStyle(...)` wickeln.

- [ ] **Step 2: Build verifizieren**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`. (Falls die ShapeStyle-Ternary klemmt: beide Branches in `AnyShapeStyle` wickeln — melden.)

- [ ] **Step 3: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Kombox/KomboxComposer.swift
git commit -m "ComHub: KomboxComposer (Kanal-Switch, Betreff, Senden via comms-outbound)"
```

---

## Task 5: `ThreadView` restyle — Kopf + Verlauf + Composer + Löschen (ComHub)

**Files:**
- Modify: `apps/comhub-native/ComHub/Kombox/ThreadView.swift` (ganzen Inhalt ersetzen)

- [ ] **Step 1: `ThreadView` ersetzen**

`apps/comhub-native/ComHub/Kombox/ThreadView.swift`:

```swift
import SwiftUI
import AtollHub

/// Reader: Kopf (Kontakt) + Tages-Verlauf (Bubbles/Mail/System) + Composer.
/// Pro Nachricht „Löschen" via Kontextmenü.
struct ThreadView: View {
  let store: KomboxStore

  private static let dayLabel: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "EEEE, d. MMMM"
    f.locale = Locale(identifier: "de_CH")
    f.timeZone = TimeZone(identifier: "Europe/Zurich"); return f
  }()

  private var contactName: String {
    store.thread.flatMap(\.events).first?.contactName
      ?? store.conversations.first { $0.id == store.selectedContactId }?.contactName ?? ""
  }

  var body: some View {
    if store.selectedContactId == nil {
      ContentUnavailableView("Konversation wählen", systemImage: "bubble.left.and.bubble.right")
    } else {
      VStack(spacing: 0) {
        header
        Divider()
        messages
        Divider()
        KomboxComposer(store: store)
      }
    }
  }

  private var header: some View {
    HStack(spacing: 11) {
      CoAvatar(name: contactName, size: 30)
      Text(contactName).font(.system(size: 14, weight: .semibold)).lineLimit(1)
      Spacer()
    }
    .padding(.horizontal, 16).frame(height: 52)
  }

  @ViewBuilder
  private var messages: some View {
    if store.thread.isEmpty {
      ContentUnavailableView(store.loadingThread ? "Lädt…" : "Keine Nachrichten", systemImage: "bubble.left")
    } else {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 10) {
          ForEach(store.thread) { section in
            HStack {
              Spacer()
              Text(Self.dayLabel.string(from: section.day))
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(.quaternary.opacity(0.4), in: Capsule())
              Spacer()
            }
            .padding(.top, 6)
            ForEach(section.events) { event in
              KomboxRow(event: event)
                .contextMenu {
                  Button("Löschen", role: .destructive) {
                    Task { await store.deleteEvent(id: event.id) }
                  }
                }
            }
          }
        }
        .padding(12)
      }
    }
  }
}
```

- [ ] **Step 2: Build verifizieren**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`. (`KomboxRow` aus 3a unverändert genutzt.)

- [ ] **Step 3: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Kombox/ThreadView.swift
git commit -m "ComHub: Kombox-Reader restyle (Kopf + Verlauf + Composer + Loeschen)"
```

---

## Task 6: `KomboxModuleView` 3-Pane + Realtime (ComHub)

**Files:**
- Modify: `apps/comhub-native/ComHub/Kombox/KomboxModuleView.swift` (ganzen Inhalt ersetzen)

- [ ] **Step 1: `KomboxModuleView` ersetzen**

`apps/comhub-native/ComHub/Kombox/KomboxModuleView.swift`:

```swift
import SwiftUI
import AtollHub

/// Kombox-Modul (3-Pane): Kanal-Rail · Konversationsliste · Reader. Lädt beim
/// Erscheinen und hält via Realtime aktuell.
struct KomboxModuleView: View {
  @State private var store = KomboxStore()
  @State private var selection: String?

  var body: some View {
    @Bindable var store = store
    HStack(spacing: 0) {
      KomboxRailView(channel: $store.channel)
        #if os(macOS)
        .frame(width: 180)
        #endif
      Divider()
      ConversationListView(store: store, selection: $selection)
        #if os(macOS)
        .frame(width: 320)
        #endif
      Divider()
      ThreadView(store: store)
        .frame(maxWidth: .infinity)
    }
    .task {
      await store.reloadConversations()
      store.startRealtime()
    }
    .onDisappear { store.stopRealtime() }
    .onChange(of: selection) { _, new in
      guard let new else { return }
      Task { await store.selectContact(new) }
    }
  }
}
```

- [ ] **Step 2: Generieren + Build**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`. (`.kombox` in `HubShell` ist seit 3a verdrahtet — keine Shell-Änderung nötig.)

- [ ] **Step 3: Manueller Smoke-Test** (echter Mac, **nur mit Test-Kontakt** — Senden ist real!)

- [ ] **Kombox** (3-Pane): links Rail Alle/WhatsApp/Mail (Auswahl im Akzent); Mitte Liste (Kopf=Filtername+Anzahl, Suche, Zeilen mit Avatar+Kanal-Dot+Name+Zeit+Vorschau); rechts Reader.
- [ ] Filter wechseln → Liste filtert nach Kanal; Suche filtert live.
- [ ] Konversation wählen → Reader: Kopf, Tages-Verlauf (Bubbles/Mail/System), Composer unten.
- [ ] **Senden** (Test-Kontakt!): WhatsApp/Mail-Switch, Betreff (Mail), Text, Senden → Nachricht erscheint im Verlauf (via Realtime/Refetch); Eingabe geleert. Ohne `messaging_accounts`-Konto: rote Fehlermeldung statt Absturz.
- [ ] **Löschen**: Rechtsklick auf Nachricht → „Löschen" → verschwindet (Refetch).
- [ ] **Realtime**: eingehende Nachricht (Web/Test-Insert) erscheint live.
- [ ] Dark Mode lesbar.

- [ ] **Step 4: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Kombox/KomboxModuleView.swift
git commit -m "ComHub: Kombox 3-Pane (Rail + Liste + Reader/Composer), Realtime"
```

---

## Task 7: Dokumentation (Phase 3b)

**Files:**
- Modify: `apps/comhub-native/README.md`

- [ ] **Step 1: Phase-3b-Zeile ergänzen**

In `apps/comhub-native/README.md` im Abschnitt `## Phasen-Stand` die `**Phase 3a**`-Zeile ergänzen/ersetzen — **nach** dem 3a-Absatz einfügen:

```markdown

**Phase 3b** — **Kombox schreiben + 3-Pane** (CoHub-Look): Kanal-Rail
(Alle/WhatsApp/Mail) · Konversationsliste mit Suche · Reader mit **Composer**
(Senden via Edge Function `comms-outbound`) und **Löschen** (`contact_events`).
Filter-Logik getestet in `AtollHub` (`KomboxFilter`). Senden braucht eine
`messaging_accounts`-Zeile des Users. Privat-WhatsApp-WebView folgt in 3c.
```

- [ ] **Step 2: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/README.md
git commit -m "Docs: ComHub-README Phase-3b (Kombox schreiben + 3-Pane)"
```

---

## Self-Review (durchgeführt)

**1. Spec-Abdeckung (Spec §4.3 „Kombox", Slice 3b + CoHub-Mockup):**
- Kontaktliste · Verlauf · Composer · Senden via `comms-outbound` · Antworten/Löschen · Filter Alle/WA/Mail · Suche → Tasks 1 (Filter), 2 (Senden/Löschen), 3 (Rail+Liste), 4 (Composer), 5 (Reader+Löschen), 6 (3-Pane).
- 3-Pane wie Web-Mailbox (Rail · Liste · Reader) → Tasks 3/5/6.
- Bewusst out of scope (Scope-Grenzen): Status/Quick-Log/Anhänge/„Markiert"/iMessage; Privat-WA (3c).

**2. Platzhalter-Scan:** Keine „TBD/TODO". Vollständiger Code je Schritt; Befehl + erwartete Ausgabe je Run. Fehlerpfade (Senden ohne Konto, Löschen-Fehler) zeigen `actionError`.

**3. Typ-Konsistenz:**
- `KomboxChannel`/`KomboxFilter.apply(_:channel:search:)` (Task 1) ↔ `KomboxStore.visibleConversations` (Task 2) ↔ `KomboxRailView`/`ConversationListView` (Task 3) ↔ `KomboxModuleView` (`$store.channel`) (Task 6). ✔
- `KomboxStore.send(channel:body:subject:)`/`deleteEvent(id:)`/`sending`/`actionError`/`channel`/`search`/`visibleConversations` (Task 2) ↔ Composer (Task 4)/Reader (Task 5)/Liste (Task 3). ✔
- 3a-Reuse: `KomboxStore` (`.conversations`/`.thread`/`.selectedContactId`/`.loadingThread`/`.loadingConversations`/`.reloadConversations`/`.reloadThread`/`.selectContact`/`.startRealtime`/`.stopRealtime`/`supabase`/`logger`), `KomboxConversation`/`KomboxEvent`/`KomboxRow`/`CoAvatar`/`CoColor` — gegen 3a-Code geprüft. ✔
- supabase-swift 2.46: `functions.invoke(_:options:) -> T` + `FunctionInvokeOptions(body:)`, `.from().delete().eq(_:value:).execute()` — gegen Investigation/SDK geprüft (Task 2 verifiziert per Build; Abweichung → SDK-Quelle angleichen). ✔

**4. Verifikations-Disziplin:** Task 1 echte TDD (`swift test`). Tasks 2–6 build-verifiziert (`xcodegen generate` + `xcodebuild`); Task 6 schliesst mit manuellem Smoke-Test (Senden **nur Test-Kontakt**, Löschen, Realtime, Dark Mode). Konform zu superpowers:verification-before-completion.

---

## Execution Handoff

**Plan komplett und gespeichert unter `docs/superpowers/plans/2026-06-02-comhub-phase3b-kombox-write.md`. Zwei Ausführungs-Optionen:**

**1. Subagent-Driven (empfohlen)** — frischer Subagent pro Task, Review zwischen den Tasks. (REQUIRED SUB-SKILL: superpowers:subagent-driven-development.)

**2. Inline-Ausführung** — Tasks in dieser Session, Batch mit Checkpoints. (REQUIRED SUB-SKILL: superpowers:executing-plans.)

**Welcher Ansatz?**
