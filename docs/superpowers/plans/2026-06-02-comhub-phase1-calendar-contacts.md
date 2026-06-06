# ComHub Phase 1 — Kalender + Kontakte (lesen) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ComHub zeigt einen **gemergten, lese-only Kalender** (Tag/Woche/Monat) aus Apple/iCloud (EventKit) **und** Atoll-Events (`course_assignments`) sowie ein **kombiniertes Adressbuch** aus Apple-Kontakten (Contacts.framework) und Atoll-CRM-Kontakten (`contacts`), gematcht/dedupliziert über `ContactMatcher`.

**Architecture:** Vier konkrete Adapter im App-Target (`AppleCalendarAdapter`/`AppleContactsAdapter` über EventKit/Contacts; `AtollEventsAdapter`/`AtollContactsAdapter` über `supabase-swift`) erfüllen die in Phase 0 definierten `AtollHub`-Capability-Protokolle. Die Adapter sind dünn: sie holen Rohdaten und rufen **reine, unit-getestete Mapper** in `AtollHub` (`AppleEventMapper`, `AppleContactMapper`, `AtollEventMapper`, `AtollContactMapper`) auf, die quellneutrale `UnifiedEvent`/`UnifiedContact` erzeugen. Der `Hub`-Aggregator (Phase 0) merged über beide Konten; die Atoll-Adapter erfüllen `CalendarProvider`/`ContactsProvider`, sodass **kein Hub-Umbau** nötig ist. Die Kalender-Module-UI (Tag/Woche/Monat) wird **neu und schlank in ComHub** gebaut und rendert aus `[UnifiedEvent]` — die heikle Datums-Logik (Fenster, Tages-Buckets, Monatsraster) liegt als **reine, getestete Helfer** in `AtollHub` (`CalendarKind`, `CalendarWindow`, `CalendarLayout`).

**Tech Stack:** Swift 6 (strict concurrency complete), SwiftUI Multiplatform (iOS 26 / macOS 26), XcodeGen, XCTest, `supabase-swift` (über `AtollCore`: `SupabaseClient.shared`, Models `Assignment`/`Course`/`CourseDate`/`CourseModule`), EventKit, Contacts.

---

## Architektur-Entscheidung: AtollCal-Paketierung (vorab geklärt)

Der Phase-0-Plan und die Spec (§12) verlangen, **früh** zu entscheiden, ob AtollCals Kalender-Views in ein Paket `swift-packages/AtollCalKit` extrahiert oder **gezielt adaptiert** werden.

**Befund (aus Code-Sichtung):** `apps/atollcal-native/AtollCal/Views/{Day,Week,Month}View.swift` sind **app-gekoppelt** — sie besitzen ihre eigene Lade-Pipeline (`SystemCalendarStore` + `AtollEventLoader` via `@Environment`), lesen ≥ 4 `@AppStorage`-Schlüssel (`enabledCalendarIds`, `atollEnabled`, `sourceFilter`, `secondaryTimeZoneID`), und verdrahten die ATOLL-spezifische Expansion (`CalendarEvent.expandATOLL(assignment:)`, `Assignment`/`CourseModule`) fest in die Filter-Logik. Sauber separierbar sind nur `TimeAxisGrid`, `EventBar`, `AgendaList` (datengetrieben, ohne Environment).

**Entscheidung:** **Kein** `AtollCalKit` in Phase 1. ComHub baut **eigene, lese-only Tag/Woche/Monat-Views über `[UnifiedEvent]`**. Begründung: Eine Extraktion hieße, die Datenflüsse der **produktiven** AtollCal-App zu invertieren (großer, riskanter Diff) — für lese-only Views, die ComHub mit `UnifiedEvent` ohnehin anders modelliert (`CalendarEvent` ist ATOLL-spezifisch: `Assignment`/`CourseModule`/`anniversary`). Wir wiederverwenden die **Muster** (EventKit-`predicateForEvents`, der `course_assignments`-Select aus `AtollEventLoader`), nicht den Code. Die schwere Datums-Logik wandert als reine Helfer nach `AtollHub` und wird dort `swift test`-geprüft. `AtollCalKit` bleibt eine Option, falls Phase 5 (Schreiben) visuelle Parität mit AtollCal braucht.

---

## File Structure

**Geändertes Paket — `swift-packages/AtollHub/` (reine, getestete Mapper + Kalender-Logik):**
- `Sources/AtollHub/Mapping/AppleMappers.swift` — `AppleEventMapper`, `AppleContactMapper` (plain Felder → Unified; EventKit/Contacts-frei).
- `Sources/AtollHub/Mapping/AtollEventMapper.swift` — `Assignment` (aus AtollCore) → `[UnifiedEvent]`. **Importiert `AtollCore`** (neue Abhängigkeit des Pakets, nur für Model-Typen).
- `Sources/AtollHub/Mapping/AtollContactMapper.swift` — `AtollContactRow`/`AtollEmail`/`AtollPhone` (Decodable, Wire-Format) → `[UnifiedContact]`.
- `Sources/AtollHub/Contacts/MergedContact.swift` — `MergedContact` (View-Modell: eine Kontakt-Gruppe → Anzeigename, gesammelte E-Mails/Telefone, Quell-Typen).
- `Sources/AtollHub/Calendar/CalendarKind.swift` — `CalendarKind` (day/week/month).
- `Sources/AtollHub/Calendar/CalendarWindow.swift` — Lade-Fenster (`DateInterval`) pro Kind+Anker.
- `Sources/AtollHub/Calendar/CalendarLayout.swift` — `eventsByDay`, `weekDays`, `monthGrid`.
- `Package.swift` — Abhängigkeit auf lokales `AtollCore` ergänzen (für `AtollEventMapper`).
- `Tests/AtollHubTests/*` — je eine XCTest-Suite pro neuer Einheit.

**Neue App-Dateien — `apps/comhub-native/ComHub/` (dünne Adapter + Module-UI, build-verifiziert):**
- `Adapters/AppleCalendarAdapter.swift` — `CalendarProvider` über `EKEventStore`.
- `Adapters/AppleContactsAdapter.swift` — `ContactsProvider` über `CNContactStore`.
- `Adapters/AtollEventsAdapter.swift` — `CalendarProvider` über `course_assignments`.
- `Adapters/AtollContactsAdapter.swift` — `ContactsProvider` über `contacts`.
- `Hub/HubWiring.swift` — verbindet Apple- + Atoll-Konto in den `Hub` (nutzt `currentUser.legacyInstructorId`).
- `Calendar/CalendarStore.swift` — `@Observable` Store: Anker, Kind, `events`, `reload()` via `Hub`.
- `Calendar/CalendarModuleView.swift` — Kind-Umschalter + Vor/Zurück + Heute; hostet Day/Week/Month.
- `Calendar/DayColumnView.swift` — Tagesliste (lese-only).
- `Calendar/WeekGridView.swift` — 7-Spalten-Wochenraster (lese-only).
- `Calendar/MonthGridView.swift` — Monatsraster (lese-only).
- `Calendar/UnifiedEventRow.swift` — eine Event-Zeile (Titel, Zeit, Quell-Badge).
- `Contacts/ContactsStore.swift` — `@Observable` Store: lädt + matcht Kontakte via `Hub` + `ContactMatcher`.
- `Contacts/ContactsModuleView.swift` — kombinierte Liste + Detail (Quell-Tags).

**Geänderte App-Dateien:**
- `ComHub/Shell/HubShell.swift` — `.kalender` zeigt `CalendarModuleView`, `.kontakte` zeigt `ContactsModuleView` (statt Platzhalter).
- `ComHub/ComHubApp.swift` — beim Sign-in die Adapter in den `Hub` verdrahten (Aufruf `HubWiring`).

**Doku:**
- `apps/comhub-native/README.md` — Phase-1-Abschnitt ergänzen.

---

## Task 1: `AppleEventMapper` + `AppleContactMapper` (reine Apple-Mapper)

Reine Funktionen, die **plain Felder** (von EKEvent/CNContact extrahiert) in Unified-Modelle übersetzen. Kein `import EventKit/Contacts` — so im Paket testbar.

**Files:**
- Create: `swift-packages/AtollHub/Sources/AtollHub/Mapping/AppleMappers.swift`
- Test: `swift-packages/AtollHub/Tests/AtollHubTests/AppleMappersTests.swift`

- [ ] **Step 1: Failing Test schreiben**

`swift-packages/AtollHub/Tests/AtollHubTests/AppleMappersTests.swift`:

```swift
import XCTest
@testable import AtollHub

final class AppleMappersTests: XCTestCase {
  func test_event_mapsFieldsAndTagsAppleSource() {
    let start = Date(timeIntervalSince1970: 1_000)
    let end = Date(timeIntervalSince1970: 4_600)
    let e = AppleEventMapper.event(accountId: "icloud", identifier: "ek-1",
                                   title: "Tauchgang", start: start, end: end,
                                   isAllDay: false, location: "Hausriff")
    XCTAssertEqual(e.id, "apple:ek-1")
    XCTAssertEqual(e.source, AccountRef(accountId: "icloud", type: .apple))
    XCTAssertEqual(e.title, "Tauchgang")
    XCTAssertEqual(e.location, "Hausriff")
    XCTAssertFalse(e.isAllDay)
  }

  func test_event_fallsBackToPlaceholderTitleWhenEmpty() {
    let e = AppleEventMapper.event(accountId: "icloud", identifier: "x",
                                   title: "", start: Date(timeIntervalSince1970: 0),
                                   end: Date(timeIntervalSince1970: 1),
                                   isAllDay: true, location: nil)
    XCTAssertEqual(e.title, "(Ohne Titel)")
  }

  func test_contact_buildsUnifiedWithAppleSource() {
    let c = AppleContactMapper.contact(accountId: "icloud", identifier: "cn-9",
                                       givenName: "Anna", familyName: "Muster",
                                       emails: ["Anna@Example.com", ""],
                                       phones: ["+41 79 123 45 67"])
    XCTAssertEqual(c.id, "apple:cn-9")
    XCTAssertEqual(c.source.type, .apple)
    XCTAssertEqual(c.firstName, "Anna")
    XCTAssertEqual(c.lastName, "Muster")
    // Leere Strings werden gefiltert, Reihenfolge bleibt.
    XCTAssertEqual(c.emails, ["Anna@Example.com"])
    XCTAssertEqual(c.phones, ["+41 79 123 45 67"])
  }
}
```

- [ ] **Step 2: Test ausführen — soll fehlschlagen**

Run: `cd swift-packages/AtollHub && swift test --filter AppleMappersTests`
Expected: FAIL — `cannot find 'AppleEventMapper' in scope`.

- [ ] **Step 3: Mapper implementieren**

`swift-packages/AtollHub/Sources/AtollHub/Mapping/AppleMappers.swift`:

```swift
import Foundation

/// Übersetzt aus EventKit extrahierte Roh-Felder in `UnifiedEvent`.
/// Bewusst EventKit-frei (der App-Adapter zieht die Felder aus `EKEvent`),
/// damit die Mapping-Regeln im Paket unit-getestet werden können.
public enum AppleEventMapper {
  public static func event(accountId: String, identifier: String, title: String,
                           start: Date, end: Date, isAllDay: Bool,
                           location: String?) -> UnifiedEvent {
    let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    let loc = location?.trimmingCharacters(in: .whitespacesAndNewlines)
    return UnifiedEvent(
      id: "apple:\(identifier)",
      source: AccountRef(accountId: accountId, type: .apple),
      title: cleanTitle.isEmpty ? "(Ohne Titel)" : cleanTitle,
      start: start, end: end, isAllDay: isAllDay,
      location: (loc?.isEmpty ?? true) ? nil : loc
    )
  }
}

/// Übersetzt aus Contacts.framework extrahierte Roh-Felder in `UnifiedContact`.
public enum AppleContactMapper {
  public static func contact(accountId: String, identifier: String,
                             givenName: String, familyName: String,
                             emails: [String], phones: [String]) -> UnifiedContact {
    UnifiedContact(
      id: "apple:\(identifier)",
      source: AccountRef(accountId: accountId, type: .apple),
      firstName: givenName.trimmingCharacters(in: .whitespacesAndNewlines),
      lastName: familyName.trimmingCharacters(in: .whitespacesAndNewlines),
      emails: emails.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty },
      phones: phones.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    )
  }
}
```

- [ ] **Step 4: Test ausführen — soll grün sein**

Run: `cd swift-packages/AtollHub && swift test --filter AppleMappersTests`
Expected: PASS — 3 Tests grün.

- [ ] **Step 5: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add swift-packages/AtollHub/Sources/AtollHub/Mapping/AppleMappers.swift swift-packages/AtollHub/Tests/AtollHubTests/AppleMappersTests.swift
git commit -m "AtollHub: AppleEventMapper + AppleContactMapper (reine Apple-Mapper)"
```

---

## Task 2: `AtollHub` an `AtollCore` koppeln (für Atoll-Event-Mapping)

Der Atoll-Event-Mapper braucht die `Assignment`/`Course`/`CourseDate`/`CourseModule`-Typen aus `AtollCore`. Diese Typen sind `public Codable` in `AtollCore`. Wir fügen `AtollCore` als lokale Paket-Abhängigkeit zu `AtollHub` hinzu. (Die supabase-Abhängigkeit kommt damit **nicht** rein — `AtollCore` kapselt Supabase; `AtollHub` importiert nur die Model-Typen.)

**Files:**
- Modify: `swift-packages/AtollHub/Package.swift`

- [ ] **Step 1: `Package.swift` um die AtollCore-Abhängigkeit erweitern**

`swift-packages/AtollHub/Package.swift` (ganzen Inhalt ersetzen):

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "AtollHub",
  defaultLocalization: "de",
  platforms: [
    .iOS("26.0"),
    .macOS("26.0"),
  ],
  products: [
    .library(
      name: "AtollHub",
      targets: ["AtollHub"]
    ),
  ],
  dependencies: [
    .package(path: "../AtollCore"),
  ],
  targets: [
    .target(
      name: "AtollHub",
      dependencies: [
        .product(name: "AtollCore", package: "AtollCore"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    .testTarget(
      name: "AtollHubTests",
      dependencies: ["AtollHub"],
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
  ]
)
```

> Hinweis: Der `AtollCore`-Produktname muss exakt stimmen. Verifiziere mit
> `grep -n 'name:' swift-packages/AtollCore/Package.swift` — das Library-Produkt heißt `AtollCore`.

- [ ] **Step 2: Bestandstests müssen weiter grün sein (keine Regression durch die neue Abhängigkeit)**

Run: `cd swift-packages/AtollHub && swift build && swift test`
Expected: `Build complete!` und alle Phase-0-Suiten grün (Smoke, UnifiedModels, Account, Providers, Hub, ContactKey, ContactMatcher, ComHubModule, OTPCode) **plus** `AppleMappersTests`.

- [ ] **Step 3: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add swift-packages/AtollHub/Package.swift
git commit -m "AtollHub: AtollCore als Paket-Abhaengigkeit (Model-Typen fuer Atoll-Mapper)"
```

---

## Task 3: `AtollEventMapper` — `Assignment` → `[UnifiedEvent]`

Mappt geladene `course_assignments` (decodiert als `[Assignment]`) auf quellneutrale Events. Regel: pro `CourseDate` die `expandModules()` (timed, je Modul ein Event); hat ein Kurstag keine timed Module, ein **all-day** Fallback-Event pro Kurstag. Titel: `"<Kurs> — <Modul>"` (timed) bzw. `"<Kurs> (<Rolle>)"` (all-day). Abgesagte Kurse (`status == .cancelled`) fallen raus.

**Files:**
- Create: `swift-packages/AtollHub/Sources/AtollHub/Mapping/AtollEventMapper.swift`
- Test: `swift-packages/AtollHub/Tests/AtollHubTests/AtollEventMapperTests.swift`

- [ ] **Step 1: Failing Test schreiben**

`swift-packages/AtollHub/Tests/AtollHubTests/AtollEventMapperTests.swift`:

```swift
import XCTest
import AtollCore
@testable import AtollHub

final class AtollEventMapperTests: XCTestCase {
  // Baut ein Assignment aus dem Wire-JSON (so kommen die Daten aus PostgREST).
  private func assignment(_ json: String) throws -> Assignment {
    let decoder = JSONDecoder()
    return try decoder.decode(Assignment.self, from: Data(json.utf8))
  }

  func test_timedModule_becomesTimedEventWithModuleTitle() throws {
    let a = try assignment("""
    {
      "id": "11111111-1111-1111-1111-111111111111",
      "role": "haupt", "confirmed": true,
      "courses": {
        "id": "22222222-2222-2222-2222-222222222222",
        "title": "Open Water", "start_date": "2026-06-10",
        "status": "confirmed", "info": null, "notes": null,
        "location": "Zürich", "additional_dates": null,
        "course_types": null,
        "course_dates": [
          { "id": "33333333-3333-3333-3333-333333333333", "date": "2026-06-10",
            "has_theory": true, "has_pool": false, "has_lake": false,
            "theory_from": "18:00:00", "theory_to": "20:00:00",
            "pool_from": null, "pool_to": null, "lake_from": null, "lake_to": null,
            "pool_location": null, "pool_reserved": null, "note": null }
        ]
      }
    }
    """)
    let events = AtollEventMapper.events(from: [a], accountId: "atoll")
    XCTAssertEqual(events.count, 1)
    XCTAssertEqual(events[0].source, AccountRef(accountId: "atoll", type: .atoll))
    XCTAssertEqual(events[0].title, "Open Water — Theorie")
    XCTAssertFalse(events[0].isAllDay)
    XCTAssertEqual(events[0].location, "Zürich")
    XCTAssertTrue(events[0].id.hasPrefix("atoll:"))
  }

  func test_dayWithoutTimes_becomesAllDayEventWithRoleTitle() throws {
    let a = try assignment("""
    {
      "id": "11111111-1111-1111-1111-111111111111",
      "role": "assist", "confirmed": false,
      "courses": {
        "id": "22222222-2222-2222-2222-222222222222",
        "title": "Rescue", "start_date": "2026-06-12",
        "status": "tentative", "info": null, "notes": null,
        "location": null, "additional_dates": null, "course_types": null,
        "course_dates": [
          { "id": "44444444-4444-4444-4444-444444444444", "date": "2026-06-12",
            "has_theory": false, "has_pool": false, "has_lake": false,
            "theory_from": null, "theory_to": null,
            "pool_from": null, "pool_to": null, "lake_from": null, "lake_to": null,
            "pool_location": null, "pool_reserved": null, "note": null }
        ]
      }
    }
    """)
    let events = AtollEventMapper.events(from: [a], accountId: "atoll")
    XCTAssertEqual(events.count, 1)
    XCTAssertTrue(events[0].isAllDay)
    XCTAssertEqual(events[0].title, "Rescue (assist)")
  }

  func test_cancelledCourse_isSkipped() throws {
    let a = try assignment("""
    {
      "id": "11111111-1111-1111-1111-111111111111",
      "role": "haupt", "confirmed": true,
      "courses": {
        "id": "22222222-2222-2222-2222-222222222222",
        "title": "X", "start_date": "2026-06-10", "status": "cancelled",
        "info": null, "notes": null, "location": null, "additional_dates": null,
        "course_types": null, "course_dates": [] }
    }
    """)
    XCTAssertTrue(AtollEventMapper.events(from: [a], accountId: "atoll").isEmpty)
  }

  func test_poolModuleUsesPoolLocation() throws {
    let a = try assignment("""
    {
      "id": "11111111-1111-1111-1111-111111111111",
      "role": "haupt", "confirmed": true,
      "courses": {
        "id": "22222222-2222-2222-2222-222222222222",
        "title": "AOWD", "start_date": "2026-06-11", "status": "confirmed",
        "info": null, "notes": null, "location": "Zürich", "additional_dates": null,
        "course_types": null,
        "course_dates": [
          { "id": "55555555-5555-5555-5555-555555555555", "date": "2026-06-11",
            "has_theory": false, "has_pool": true, "has_lake": false,
            "theory_from": null, "theory_to": null,
            "pool_from": "09:00:00", "pool_to": "11:00:00",
            "lake_from": null, "lake_to": null,
            "pool_location": "Mooesli", "pool_reserved": true, "note": null }
        ]
      }
    }
    """)
    let events = AtollEventMapper.events(from: [a], accountId: "atoll")
    XCTAssertEqual(events.count, 1)
    XCTAssertEqual(events[0].title, "AOWD — Pool")
    XCTAssertEqual(events[0].location, "Mooesli")
  }
}
```

- [ ] **Step 2: Test ausführen — soll fehlschlagen**

Run: `cd swift-packages/AtollHub && swift test --filter AtollEventMapperTests`
Expected: FAIL — `cannot find 'AtollEventMapper' in scope`.

- [ ] **Step 3: Mapper implementieren**

`swift-packages/AtollHub/Sources/AtollHub/Mapping/AtollEventMapper.swift`:

```swift
import Foundation
import AtollCore

/// Übersetzt geladene Atoll-`Assignment`s (course_assignments → courses →
/// course_dates) in quellneutrale `UnifiedEvent`s. Reine Funktion — die
/// Netzwerk-/Decoding-Arbeit erledigt der App-Adapter (`AtollEventsAdapter`).
public enum AtollEventMapper {
  public static func events(from assignments: [Assignment],
                            accountId: String) -> [UnifiedEvent] {
    let ref = AccountRef(accountId: accountId, type: .atoll)
    var out: [UnifiedEvent] = []

    for a in assignments {
      guard let course = a.course, course.status != .cancelled else { continue }

      for day in course.courseDates ?? [] {
        guard let dayDate = day.dayDate else { continue }
        let modules = day.expandModules()

        if modules.isEmpty {
          // All-day Fallback: leerer Kurstag oder has_*-ohne-Zeit.
          let dayStamp = Int(startOfDay(dayDate).timeIntervalSince1970)
          out.append(UnifiedEvent(
            id: "atoll:\(a.id.uuidString):\(dayStamp)",
            source: ref,
            title: "\(course.title) (\(a.role.rawValue))",
            start: startOfDay(dayDate),
            end: nextDay(dayDate),
            isAllDay: true,
            location: course.location
          ))
        } else {
          for m in modules {
            out.append(UnifiedEvent(
              id: "atoll:\(a.id.uuidString):\(day.id.uuidString):\(m.type.rawValue)",
              source: ref,
              title: "\(course.title) — \(m.type.label)",
              start: m.start,
              end: m.end,
              isAllDay: false,
              location: (m.location?.isEmpty == false) ? m.location : course.location
            ))
          }
        }
      }
    }

    return out.sorted { $0.start < $1.start }
  }

  // Zürich-Wall-Clock-Tagesgrenzen (wie der Rest der Atoll-Datumslogik).
  private static var zurichCalendar: Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
    return cal
  }
  private static func startOfDay(_ d: Date) -> Date { zurichCalendar.startOfDay(for: d) }
  private static func nextDay(_ d: Date) -> Date {
    let s = startOfDay(d)
    return zurichCalendar.date(byAdding: .day, value: 1, to: s) ?? s
  }
}
```

- [ ] **Step 4: Test ausführen — soll grün sein**

Run: `cd swift-packages/AtollHub && swift test --filter AtollEventMapperTests`
Expected: PASS — 4 Tests grün.

- [ ] **Step 5: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add swift-packages/AtollHub/Sources/AtollHub/Mapping/AtollEventMapper.swift swift-packages/AtollHub/Tests/AtollHubTests/AtollEventMapperTests.swift
git commit -m "AtollHub: AtollEventMapper (Assignment/course_dates -> UnifiedEvent)"
```

---

## Task 4: `AtollContactMapper` — `contacts`-Rows → `[UnifiedContact]`

Die `contacts`-Tabelle liefert `emails`/`phones` als **JSONB-Arrays** (`{label, email, primary?}` bzw. `{label, e164, whatsapp?, primary?}`). Wir definieren Wire-Decodables und mappen auf `UnifiedContact`. Reine Funktion, unit-getestet aus JSON.

**Files:**
- Create: `swift-packages/AtollHub/Sources/AtollHub/Mapping/AtollContactMapper.swift`
- Test: `swift-packages/AtollHub/Tests/AtollHubTests/AtollContactMapperTests.swift`

- [ ] **Step 1: Failing Test schreiben**

`swift-packages/AtollHub/Tests/AtollHubTests/AtollContactMapperTests.swift`:

```swift
import XCTest
@testable import AtollHub

final class AtollContactMapperTests: XCTestCase {
  private func rows(_ json: String) throws -> [AtollContactRow] {
    try JSONDecoder().decode([AtollContactRow].self, from: Data(json.utf8))
  }

  func test_mapsPersonWithEmailsAndPhones() throws {
    let r = try rows("""
    [{
      "id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
      "kind": "person", "first_name": "Anna", "last_name": "Muster",
      "primary_email": "anna@example.com",
      "emails": [{"label":"work","email":"anna@example.com","primary":true},
                 {"label":"home","email":"a.muster@gmx.ch"}],
      "phones": [{"label":"mobile","e164":"+41791234567","whatsapp":true}]
    }]
    """)
    let contacts = AtollContactMapper.contacts(from: r, accountId: "atoll")
    XCTAssertEqual(contacts.count, 1)
    let c = contacts[0]
    XCTAssertEqual(c.id, "atoll:aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")
    XCTAssertEqual(c.source.type, .atoll)
    XCTAssertEqual(c.firstName, "Anna")
    XCTAssertEqual(c.lastName, "Muster")
    XCTAssertEqual(c.emails, ["anna@example.com", "a.muster@gmx.ch"])
    XCTAssertEqual(c.phones, ["+41791234567"])
  }

  func test_organizationUsesTradingNameAsFirstNameFallback() throws {
    let r = try rows("""
    [{
      "id": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
      "kind": "organization", "first_name": null, "last_name": null,
      "trading_name": "Tauchschule Z", "legal_name": "Tauchschule Z GmbH",
      "primary_email": "info@tsz.ch", "emails": null, "phones": null
    }]
    """)
    let c = AtollContactMapper.contacts(from: r, accountId: "atoll")[0]
    // Org: firstName leer, lastName trägt den Anzeigenamen.
    XCTAssertEqual(c.firstName, "")
    XCTAssertEqual(c.lastName, "Tauchschule Z")
    // primary_email fließt ein, auch wenn emails[] fehlt.
    XCTAssertEqual(c.emails, ["info@tsz.ch"])
  }

  func test_deduplicatesPrimaryEmailAlreadyInArray() throws {
    let r = try rows("""
    [{
      "id": "cccccccc-cccc-cccc-cccc-cccccccccccc",
      "kind": "person", "first_name": "Ben", "last_name": "B",
      "primary_email": "ben@x.ch",
      "emails": [{"label":"work","email":"ben@x.ch"}],
      "phones": null
    }]
    """)
    let c = AtollContactMapper.contacts(from: r, accountId: "atoll")[0]
    XCTAssertEqual(c.emails, ["ben@x.ch"]) // nicht doppelt
  }
}
```

- [ ] **Step 2: Test ausführen — soll fehlschlagen**

Run: `cd swift-packages/AtollHub && swift test --filter AtollContactMapperTests`
Expected: FAIL — `cannot find 'AtollContactRow' in scope`.

- [ ] **Step 3: Wire-Decodables + Mapper implementieren**

`swift-packages/AtollHub/Sources/AtollHub/Mapping/AtollContactMapper.swift`:

```swift
import Foundation

/// Ein JSONB-E-Mail-Eintrag aus `contacts.emails`.
public struct AtollEmail: Decodable, Sendable {
  public let email: String?
}

/// Ein JSONB-Telefon-Eintrag aus `contacts.phones`.
public struct AtollPhone: Decodable, Sendable {
  public let e164: String?
}

/// Wire-Format einer `contacts`-Row (Subset, das ComHub Phase 1 liest).
public struct AtollContactRow: Decodable, Sendable {
  public let id: String
  public let kind: String?
  public let firstName: String?
  public let lastName: String?
  public let tradingName: String?
  public let legalName: String?
  public let primaryEmail: String?
  public let emails: [AtollEmail]?
  public let phones: [AtollPhone]?

  enum CodingKeys: String, CodingKey {
    case id, kind, emails, phones
    case firstName = "first_name"
    case lastName = "last_name"
    case tradingName = "trading_name"
    case legalName = "legal_name"
    case primaryEmail = "primary_email"
  }
}

/// Übersetzt `contacts`-Rows in quellneutrale `UnifiedContact`s.
public enum AtollContactMapper {
  public static func contacts(from rows: [AtollContactRow],
                              accountId: String) -> [UnifiedContact] {
    let ref = AccountRef(accountId: accountId, type: .atoll)
    return rows.map { row in
      // Namens-Auflösung: Organisationen tragen den Anzeigenamen im lastName-Slot.
      let first: String
      let last: String
      if row.kind == "organization" {
        first = ""
        last = (row.tradingName ?? row.legalName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      } else {
        first = (row.firstName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        last = (row.lastName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      }

      // E-Mails: primary_email zuerst, dann Array — dedup unter Erhalt der Reihenfolge.
      var emails: [String] = []
      var seenEmail = Set<String>()
      func addEmail(_ raw: String?) {
        let v = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !v.isEmpty, !seenEmail.contains(v.lowercased()) else { return }
        seenEmail.insert(v.lowercased()); emails.append(v)
      }
      addEmail(row.primaryEmail)
      (row.emails ?? []).forEach { addEmail($0.email) }

      var phones: [String] = []
      var seenPhone = Set<String>()
      func addPhone(_ raw: String?) {
        let v = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !v.isEmpty, !seenPhone.contains(v) else { return }
        seenPhone.insert(v); phones.append(v)
      }
      (row.phones ?? []).forEach { addPhone($0.e164) }

      return UnifiedContact(
        id: "atoll:\(row.id)", source: ref,
        firstName: first, lastName: last, emails: emails, phones: phones
      )
    }
  }
}
```

- [ ] **Step 4: Test ausführen — soll grün sein**

Run: `cd swift-packages/AtollHub && swift test --filter AtollContactMapperTests`
Expected: PASS — 3 Tests grün.

- [ ] **Step 5: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add swift-packages/AtollHub/Sources/AtollHub/Mapping/AtollContactMapper.swift swift-packages/AtollHub/Tests/AtollHubTests/AtollContactMapperTests.swift
git commit -m "AtollHub: AtollContactMapper (contacts-Rows -> UnifiedContact)"
```

---

## Task 5: `MergedContact` — Kontakt-Gruppe als Anzeige-Modell

`ContactMatcher.group(_:)` (Phase 0) liefert `[[UnifiedContact]]`. Fürs kombinierte Adressbuch fassen wir jede Gruppe zu **einem** `MergedContact` zusammen: bester Anzeigename, vereinigte E-Mails/Telefone (dedup), und die beteiligten Quell-Typen (für Quell-Tags).

**Files:**
- Create: `swift-packages/AtollHub/Sources/AtollHub/Contacts/MergedContact.swift`
- Test: `swift-packages/AtollHub/Tests/AtollHubTests/MergedContactTests.swift`

- [ ] **Step 1: Failing Test schreiben**

`swift-packages/AtollHub/Tests/AtollHubTests/MergedContactTests.swift`:

```swift
import XCTest
@testable import AtollHub

final class MergedContactTests: XCTestCase {
  private func c(_ id: String, type: AccountType, first: String, last: String,
                emails: [String] = [], phones: [String] = []) -> UnifiedContact {
    UnifiedContact(id: id, source: AccountRef(accountId: type.rawValue, type: type),
                   firstName: first, lastName: last, emails: emails, phones: phones)
  }

  func test_mergesGroupUnionsContactsAndSources() {
    let group = [
      c("atoll:1", type: .atoll, first: "Anna", last: "Muster",
        emails: ["anna@example.com"], phones: ["+41791234567"]),
      c("apple:9", type: .apple, first: "Anna", last: "Muster",
        emails: ["anna@example.com"], phones: ["+41 79 123 45 67"]),
    ]
    let merged = MergedContact(group: group)
    XCTAssertEqual(merged.displayName, "Anna Muster")
    XCTAssertEqual(merged.sources, [.apple, .atoll]) // sortiert, dedupliziert
    XCTAssertEqual(merged.emails, ["anna@example.com"]) // dedup case-insensitiv
    XCTAssertEqual(merged.phones.count, 2) // unterschiedliche Roh-Strings bleiben
    XCTAssertEqual(merged.id, "apple:9") // stabile id = lexikographisch kleinste Mitglieds-id
  }

  func test_singletonKeepsSingleSource() {
    let merged = MergedContact(group: [c("apple:1", type: .apple, first: "Ben", last: "B")])
    XCTAssertEqual(merged.sources, [.apple])
    XCTAssertEqual(merged.displayName, "Ben B")
  }

  func test_displayNameFallsBackToEmailWhenNameEmpty() {
    let merged = MergedContact(group: [c("atoll:1", type: .atoll, first: "", last: "",
                                         emails: ["info@tsz.ch"])])
    XCTAssertEqual(merged.displayName, "info@tsz.ch")
  }
}
```

- [ ] **Step 2: Test ausführen — soll fehlschlagen**

Run: `cd swift-packages/AtollHub && swift test --filter MergedContactTests`
Expected: FAIL — `cannot find 'MergedContact' in scope`.

- [ ] **Step 3: Implementieren**

`swift-packages/AtollHub/Sources/AtollHub/Contacts/MergedContact.swift`:

```swift
import Foundation

/// Eine zusammengeführte Kontakt-Gruppe fürs kombinierte Adressbuch.
/// Aus `ContactMatcher.group(_:)`-Ausgabe gebaut: vereinigt Namen, E-Mails,
/// Telefone der Mitglieder und hält die beteiligten Quell-Typen für Tags.
public struct MergedContact: Identifiable, Equatable, Hashable, Sendable {
  /// Stabile id = lexikographisch kleinste Mitglieds-id (deterministisch).
  public let id: String
  public let displayName: String
  public let emails: [String]
  public let phones: [String]
  public let sources: [AccountType]
  /// Die Roh-Mitglieder (für die Detailansicht — pro Quelle aufschlüsselbar).
  public let members: [UnifiedContact]

  public init(group: [UnifiedContact]) {
    precondition(!group.isEmpty, "MergedContact braucht mindestens ein Mitglied")
    self.members = group
    self.id = group.map(\.id).min() ?? group[0].id

    // Anzeigename: erster nicht-leerer "First Last", sonst erste E-Mail, sonst id.
    let named = group.first { !($0.firstName + $0.lastName).trimmingCharacters(in: .whitespaces).isEmpty }
    if let n = named {
      self.displayName = "\(n.firstName) \(n.lastName)".trimmingCharacters(in: .whitespaces)
    } else if let mail = group.compactMap({ $0.emails.first }).first {
      self.displayName = mail
    } else {
      self.displayName = self.id
    }

    // E-Mails dedup (case-insensitiv), Reihenfolge erhalten.
    var emails: [String] = []; var seenE = Set<String>()
    for c in group { for e in c.emails where !seenE.contains(e.lowercased()) {
      seenE.insert(e.lowercased()); emails.append(e)
    } }
    self.emails = emails

    // Telefone dedup (exakt), Reihenfolge erhalten.
    var phones: [String] = []; var seenP = Set<String>()
    for c in group { for p in c.phones where !seenP.contains(p) {
      seenP.insert(p); phones.append(p)
    } }
    self.phones = phones

    self.sources = Array(Set(group.map { $0.source.type }))
      .sorted { $0.rawValue < $1.rawValue }
  }
}
```

- [ ] **Step 4: Test ausführen — soll grün sein**

Run: `cd swift-packages/AtollHub && swift test --filter MergedContactTests`
Expected: PASS — 3 Tests grün.

- [ ] **Step 5: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add swift-packages/AtollHub/Sources/AtollHub/Contacts/MergedContact.swift swift-packages/AtollHub/Tests/AtollHubTests/MergedContactTests.swift
git commit -m "AtollHub: MergedContact (Kontakt-Gruppe als Anzeige-Modell)"
```

---

## Task 6: `CalendarKind` + `CalendarWindow` (Lade-Fenster)

Reine Datums-Logik fürs Kalender-Modul: das Lade-Fenster (`DateInterval`), das der `Hub` pro Ansicht abfragt. Tag = der Tag; Woche = Mo–So der Ankerwoche; Monat = voller Kalender-Monat (ganze Wochen Mo–So, damit das Raster lückenlos ist).

**Files:**
- Create: `swift-packages/AtollHub/Sources/AtollHub/Calendar/CalendarKind.swift`
- Create: `swift-packages/AtollHub/Sources/AtollHub/Calendar/CalendarWindow.swift`
- Test: `swift-packages/AtollHub/Tests/AtollHubTests/CalendarWindowTests.swift`

- [ ] **Step 1: Failing Test schreiben**

`swift-packages/AtollHub/Tests/AtollHubTests/CalendarWindowTests.swift`:

```swift
import XCTest
@testable import AtollHub

final class CalendarWindowTests: XCTestCase {
  // Fester Kalender: Gregorian, Montag als Wochenstart, Zürich.
  private var cal: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Zurich")!
    c.firstWeekday = 2 // Montag
    return c
  }
  // 2026-06-10 ist ein Mittwoch.
  private func date(_ s: String) -> Date {
    let f = DateFormatter(); f.calendar = cal; f.timeZone = cal.timeZone
    f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX")
    return f.date(from: s)!
  }

  func test_day_spansExactlyOneDay() {
    let w = CalendarWindow.interval(for: date("2026-06-10"), kind: .day, calendar: cal)
    XCTAssertEqual(w.start, cal.startOfDay(for: date("2026-06-10")))
    XCTAssertEqual(w.end, cal.startOfDay(for: date("2026-06-11")))
  }

  func test_week_spansMondayToNextMonday() {
    // Mittwoch 2026-06-10 → Woche Mo 2026-06-08 .. Mo 2026-06-15.
    let w = CalendarWindow.interval(for: date("2026-06-10"), kind: .week, calendar: cal)
    XCTAssertEqual(w.start, cal.startOfDay(for: date("2026-06-08")))
    XCTAssertEqual(w.end, cal.startOfDay(for: date("2026-06-15")))
  }

  func test_month_coversWholeWeeksAroundMonth() {
    // Juni 2026: 1. = Montag, 30. = Dienstag. Raster Mo 2026-06-01 .. Mo 2026-07-06.
    let w = CalendarWindow.interval(for: date("2026-06-10"), kind: .month, calendar: cal)
    XCTAssertEqual(w.start, cal.startOfDay(for: date("2026-06-01")))
    XCTAssertEqual(w.end, cal.startOfDay(for: date("2026-07-06")))
  }
}
```

- [ ] **Step 2: Test ausführen — soll fehlschlagen**

Run: `cd swift-packages/AtollHub && swift test --filter CalendarWindowTests`
Expected: FAIL — `cannot find 'CalendarWindow' in scope`.

- [ ] **Step 3: Implementieren**

`swift-packages/AtollHub/Sources/AtollHub/Calendar/CalendarKind.swift`:

```swift
/// Die drei Kalender-Ansichten von ComHub Phase 1.
public enum CalendarKind: String, Sendable, CaseIterable, Identifiable {
  case day, week, month
  public var id: String { rawValue }

  public var title: String {
    switch self {
    case .day:   return "Tag"
    case .week:  return "Woche"
    case .month: return "Monat"
    }
  }
}
```

`swift-packages/AtollHub/Sources/AtollHub/Calendar/CalendarWindow.swift`:

```swift
import Foundation

/// Reine Logik: das `DateInterval`, das der Hub für eine Ansicht laden muss.
/// Monat = ganze Wochen (Mo–So), damit das Monatsraster lückenlos ist.
public enum CalendarWindow {
  public static func interval(for anchor: Date, kind: CalendarKind,
                              calendar: Calendar) -> DateInterval {
    let start = calendar.startOfDay(for: anchor)
    switch kind {
    case .day:
      let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
      return DateInterval(start: start, end: end)

    case .week:
      let weekStart = startOfWeek(for: anchor, calendar: calendar)
      let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
      return DateInterval(start: weekStart, end: weekEnd)

    case .month:
      let comps = calendar.dateComponents([.year, .month], from: anchor)
      let firstOfMonth = calendar.date(from: comps) ?? start
      // Letzter Tag des Monats:
      let nextMonth = calendar.date(byAdding: .month, value: 1, to: firstOfMonth) ?? firstOfMonth
      let lastOfMonth = calendar.date(byAdding: .day, value: -1, to: nextMonth) ?? firstOfMonth
      // Raster: Wochenstart vor dem 1. .. Wochenstart nach dem letzten.
      let gridStart = startOfWeek(for: firstOfMonth, calendar: calendar)
      let weekStartOfLast = startOfWeek(for: lastOfMonth, calendar: calendar)
      let gridEnd = calendar.date(byAdding: .day, value: 7, to: weekStartOfLast) ?? weekStartOfLast
      return DateInterval(start: gridStart, end: gridEnd)
    }
  }

  /// Start der Woche (00:00 des Wochenstart-Tages), respektiert `calendar.firstWeekday`.
  public static func startOfWeek(for date: Date, calendar: Calendar) -> Date {
    let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
    let weekStart = calendar.date(from: comps) ?? calendar.startOfDay(for: date)
    return calendar.startOfDay(for: weekStart)
  }
}
```

- [ ] **Step 4: Test ausführen — soll grün sein**

Run: `cd swift-packages/AtollHub && swift test --filter CalendarWindowTests`
Expected: PASS — 3 Tests grün.

- [ ] **Step 5: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add swift-packages/AtollHub/Sources/AtollHub/Calendar/CalendarKind.swift swift-packages/AtollHub/Sources/AtollHub/Calendar/CalendarWindow.swift swift-packages/AtollHub/Tests/AtollHubTests/CalendarWindowTests.swift
git commit -m "AtollHub: CalendarKind + CalendarWindow (Lade-Fenster pro Ansicht)"
```

---

## Task 7: `CalendarLayout` — Tages-Buckets, Wochentage, Monatsraster

Reine Logik, die die Views füttert: Events nach Tag bündeln, die Tage einer Woche, das Monatsraster (Wochen × 7 Tage). Timed-Events vor all-day, dann nach Startzeit sortiert.

**Files:**
- Create: `swift-packages/AtollHub/Sources/AtollHub/Calendar/CalendarLayout.swift`
- Test: `swift-packages/AtollHub/Tests/AtollHubTests/CalendarLayoutTests.swift`

- [ ] **Step 1: Failing Test schreiben**

`swift-packages/AtollHub/Tests/AtollHubTests/CalendarLayoutTests.swift`:

```swift
import XCTest
@testable import AtollHub

final class CalendarLayoutTests: XCTestCase {
  private var cal: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Zurich")!
    c.firstWeekday = 2
    return c
  }
  private func date(_ s: String) -> Date {
    let f = DateFormatter(); f.calendar = cal; f.timeZone = cal.timeZone
    f.dateFormat = "yyyy-MM-dd HH:mm"; f.locale = Locale(identifier: "en_US_POSIX")
    return f.date(from: s)!
  }
  private func ev(_ id: String, _ start: String, allDay: Bool = false) -> UnifiedEvent {
    UnifiedEvent(id: id, source: AccountRef(accountId: "x", type: .apple),
                 title: id, start: date(start),
                 end: date(start).addingTimeInterval(3600),
                 isAllDay: allDay, location: nil)
  }

  func test_eventsByDay_groupsByLocalDay() {
    let events = [ev("a", "2026-06-10 09:00"), ev("b", "2026-06-10 14:00"),
                  ev("c", "2026-06-11 08:00")]
    let byDay = CalendarLayout.eventsByDay(events, calendar: cal)
    let d10 = cal.startOfDay(for: date("2026-06-10 00:00"))
    let d11 = cal.startOfDay(for: date("2026-06-11 00:00"))
    XCTAssertEqual(byDay[d10]?.map(\.id), ["a", "b"])
    XCTAssertEqual(byDay[d11]?.map(\.id), ["c"])
  }

  func test_eventsByDay_allDayBeforeTimed() {
    let events = [ev("timed", "2026-06-10 09:00"), ev("allday", "2026-06-10 00:00", allDay: true)]
    let byDay = CalendarLayout.eventsByDay(events, calendar: cal)
    let d10 = cal.startOfDay(for: date("2026-06-10 00:00"))
    XCTAssertEqual(byDay[d10]?.map(\.id), ["allday", "timed"])
  }

  func test_weekDays_sevenDaysFromMonday() {
    let days = CalendarLayout.weekDays(of: date("2026-06-10 12:00"), calendar: cal)
    XCTAssertEqual(days.count, 7)
    XCTAssertEqual(days.first, cal.startOfDay(for: date("2026-06-08 00:00")))
    XCTAssertEqual(days.last, cal.startOfDay(for: date("2026-06-14 00:00")))
  }

  func test_monthGrid_returnsWeeksOfSeven() {
    let grid = CalendarLayout.monthGrid(of: date("2026-06-10 12:00"), calendar: cal)
    XCTAssertTrue(grid.allSatisfy { $0.count == 7 })
    XCTAssertEqual(grid.first?.first, cal.startOfDay(for: date("2026-06-01 00:00")))
    // Juni 2026 erstreckt sich über 5 Rasterwochen (Mo 01.06 .. So 05.07).
    XCTAssertEqual(grid.count, 5)
  }
}
```

- [ ] **Step 2: Test ausführen — soll fehlschlagen**

Run: `cd swift-packages/AtollHub && swift test --filter CalendarLayoutTests`
Expected: FAIL — `cannot find 'CalendarLayout' in scope`.

- [ ] **Step 3: Implementieren**

`swift-packages/AtollHub/Sources/AtollHub/Calendar/CalendarLayout.swift`:

```swift
import Foundation

/// Reine Layout-Helfer fürs Kalender-Modul. Keine SwiftUI-Abhängigkeit —
/// die Views konsumieren diese Strukturen.
public enum CalendarLayout {
  /// Bündelt Events nach lokalem Tag (Schlüssel = `startOfDay`). Innerhalb
  /// eines Tages: all-day zuerst, dann timed nach Startzeit.
  public static func eventsByDay(_ events: [UnifiedEvent],
                                 calendar: Calendar) -> [Date: [UnifiedEvent]] {
    var buckets: [Date: [UnifiedEvent]] = [:]
    for e in events {
      let day = calendar.startOfDay(for: e.start)
      buckets[day, default: []].append(e)
    }
    for (day, list) in buckets {
      buckets[day] = list.sorted { lhs, rhs in
        if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay && !rhs.isAllDay }
        return lhs.start < rhs.start
      }
    }
    return buckets
  }

  /// Die sieben Tage (00:00) der Woche, die `date` enthält — Mo..So je nach
  /// `calendar.firstWeekday`.
  public static func weekDays(of date: Date, calendar: Calendar) -> [Date] {
    let start = CalendarWindow.startOfWeek(for: date, calendar: calendar)
    return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
  }

  /// Das Monatsraster als Wochen × 7 Tage (00:00), ganze Wochen Mo..So.
  public static func monthGrid(of date: Date, calendar: Calendar) -> [[Date]] {
    let window = CalendarWindow.interval(for: date, kind: .month, calendar: calendar)
    var weeks: [[Date]] = []
    var cursor = window.start
    while cursor < window.end {
      let week = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: cursor) }
      weeks.append(week)
      cursor = calendar.date(byAdding: .day, value: 7, to: cursor) ?? window.end
    }
    return weeks
  }
}
```

- [ ] **Step 4: Test ausführen — soll grün sein**

Run: `cd swift-packages/AtollHub && swift test --filter CalendarLayoutTests`
Expected: PASS — 4 Tests grün.

- [ ] **Step 5: Volle Paket-Suite + Commit**

Run: `cd swift-packages/AtollHub && swift test`
Expected: PASS — alle Suiten grün (Phase 0 + AppleMappers, AtollEventMapper, AtollContactMapper, MergedContact, CalendarWindow, CalendarLayout).

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add swift-packages/AtollHub/Sources/AtollHub/Calendar/CalendarLayout.swift swift-packages/AtollHub/Tests/AtollHubTests/CalendarLayoutTests.swift
git commit -m "AtollHub: CalendarLayout (Tages-Buckets/Wochentage/Monatsraster) + Suite gruen"
```

---

## Task 8: `AppleCalendarAdapter` (EventKit → `CalendarProvider`)

Dünner App-Adapter: holt EKEvents im Fenster und mappt via `AppleEventMapper`. Build-verifiziert (EventKit lässt sich nicht sinnvoll im Paket testen).

**Files:**
- Create: `apps/comhub-native/ComHub/Adapters/AppleCalendarAdapter.swift`

- [ ] **Step 1: Adapter schreiben**

`apps/comhub-native/ComHub/Adapters/AppleCalendarAdapter.swift`:

```swift
import Foundation
import EventKit
import AtollHub

/// Erfüllt `CalendarProvider` über das System-`EKEventStore`. Liest nur
/// (Phase 1) — Schreiben kommt in Phase 5. Die Berechtigung wird vom
/// `AppleAuthorizationService` (Phase 0) angefragt; hier prüfen wir den Status
/// und liefern bei fehlendem Zugriff eine leere Liste statt zu werfen.
struct AppleCalendarAdapter: CalendarProvider {
  let accountId: String
  private let store: EKEventStore

  init(accountId: String = "apple", store: EKEventStore) {
    self.accountId = accountId
    self.store = store
  }

  func events(in interval: DateInterval) async throws -> [UnifiedEvent] {
    guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return [] }
    let cals = store.calendars(for: .event)
    guard !cals.isEmpty else { return [] }
    let pred = store.predicateForEvents(withStart: interval.start,
                                        end: interval.end, calendars: cals)
    let ekEvents = store.events(matching: pred)
    return ekEvents.map { e in
      AppleEventMapper.event(
        accountId: accountId,
        identifier: e.eventIdentifier ?? "ts-\(e.startDate.timeIntervalSince1970)",
        title: e.title ?? "",
        start: e.startDate, end: e.endDate,
        isAllDay: e.isAllDay, location: e.location
      )
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
git add apps/comhub-native/ComHub/Adapters/AppleCalendarAdapter.swift
git commit -m "ComHub: AppleCalendarAdapter (EventKit -> CalendarProvider, lesen)"
```

---

## Task 9: `AppleContactsAdapter` (Contacts → `ContactsProvider`)

Dünner App-Adapter: enumeriert Kontakte off-main (Muster aus `ContactsAnniversaryStore`) und mappt via `AppleContactMapper`. Build-verifiziert.

**Files:**
- Create: `apps/comhub-native/ComHub/Adapters/AppleContactsAdapter.swift`

- [ ] **Step 1: Adapter schreiben**

`apps/comhub-native/ComHub/Adapters/AppleContactsAdapter.swift`:

```swift
import Foundation
import Contacts
import AtollHub

/// Erfüllt `ContactsProvider` über `CNContactStore`. Liest Vor-/Nachname,
/// E-Mails und Telefonnummern; mappt via `AppleContactMapper`. Bei fehlender
/// Berechtigung leere Liste (kein Wurf), damit der Hub die anderen Quellen
/// weiter aggregiert.
struct AppleContactsAdapter: ContactsProvider {
  let accountId: String

  init(accountId: String = "apple") { self.accountId = accountId }

  func contacts() async throws -> [UnifiedContact] {
    guard CNContactStore.authorizationStatus(for: .contacts) == .authorized else { return [] }
    return await Task.detached(priority: .utility) { [accountId] in
      Self.fetch(accountId: accountId)
    }.value
  }

  private static func fetch(accountId: String) -> [UnifiedContact] {
    let keys: [CNKeyDescriptor] = [
      CNContactGivenNameKey as CNKeyDescriptor,
      CNContactFamilyNameKey as CNKeyDescriptor,
      CNContactEmailAddressesKey as CNKeyDescriptor,
      CNContactPhoneNumbersKey as CNKeyDescriptor,
      CNContactIdentifierKey as CNKeyDescriptor,
    ]
    let request = CNContactFetchRequest(keysToFetch: keys)
    let store = CNContactStore()
    var out: [UnifiedContact] = []
    do {
      try store.enumerateContacts(with: request) { c, _ in
        let emails = c.emailAddresses.map { $0.value as String }
        let phones = c.phoneNumbers.map { $0.value.stringValue }
        // Namenlose Kontakte ohne jede Kontaktinfo überspringen.
        let hasName = !(c.givenName + c.familyName).trimmingCharacters(in: .whitespaces).isEmpty
        guard hasName || !emails.isEmpty || !phones.isEmpty else { return }
        out.append(AppleContactMapper.contact(
          accountId: accountId, identifier: c.identifier,
          givenName: c.givenName, familyName: c.familyName,
          emails: emails, phones: phones
        ))
      }
    } catch {
      return out
    }
    return out
  }
}
```

- [ ] **Step 2: Build verifizieren**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Adapters/AppleContactsAdapter.swift
git commit -m "ComHub: AppleContactsAdapter (Contacts -> ContactsProvider, lesen)"
```

---

## Task 10: `AtollEventsAdapter` (`course_assignments` → `CalendarProvider`)

Dünner App-Adapter: lädt `course_assignments` für den eingeloggten Instructor im Fenster (Select-Muster aus `AtollEventLoader`), decodiert `[Assignment]`, mappt via `AtollEventMapper`. Build-verifiziert.

**Files:**
- Create: `apps/comhub-native/ComHub/Adapters/AtollEventsAdapter.swift`

- [ ] **Step 1: Adapter schreiben**

`apps/comhub-native/ComHub/Adapters/AtollEventsAdapter.swift`:

```swift
import Foundation
import AtollCore
import AtollHub
import Supabase

/// Erfüllt `CalendarProvider` über die Atoll-`course_assignments`. Der
/// Instructor (canonical/legacy id) wird beim Verdrahten injiziert. Select-
/// Spaltenliste gespiegelt von `AtollEventLoader` (AtollCal).
struct AtollEventsAdapter: CalendarProvider {
  let accountId: String
  let instructorId: UUID
  private let supabase = SupabaseClient.shared

  init(accountId: String = "atoll", instructorId: UUID) {
    self.accountId = accountId
    self.instructorId = instructorId
  }

  func events(in interval: DateInterval) async throws -> [UnifiedEvent] {
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd"
    df.timeZone = TimeZone(identifier: "Europe/Zurich")
    let startStr = df.string(from: interval.start)
    let endStr = df.string(from: interval.end)

    let assignments: [Assignment] = try await supabase
      .from("course_assignments")
      .select("""
        id, role, confirmed,
        courses!inner(
          id, title, status, info, notes, location, start_date, additional_dates,
          course_types(id, code, label),
          course_dates(
            id, date,
            has_theory, has_pool, has_lake,
            theory_from, theory_to,
            pool_from, pool_to,
            lake_from, lake_to,
            pool_location, pool_reserved, note
          )
        )
      """)
      .eq("instructor_id", value: instructorId)
      .gte("courses.start_date", value: startStr)
      .lte("courses.start_date", value: endStr)
      .neq("courses.status", value: "cancelled")
      .execute()
      .value

    return AtollEventMapper.events(from: assignments, accountId: accountId)
  }
}
```

> Hinweis: `instructor_id` referenziert `legacyInstructorId` (siehe Task 12).
> `courses.start_date` begrenzt grob auf das Fenster; mehrtägige Kurse, deren
> `start_date` davor liegt, deren `course_dates` aber ins Fenster fallen, sind
> ein bekannter Phase-1-Tradeoff (wie in AtollCal). Verfeinerung später.

- [ ] **Step 2: Build verifizieren**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`. (Compile beweist die `Assignment`-Decoding-Signatur + PostgREST-Kette.)

- [ ] **Step 3: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Adapters/AtollEventsAdapter.swift
git commit -m "ComHub: AtollEventsAdapter (course_assignments -> CalendarProvider)"
```

---

## Task 11: `AtollContactsAdapter` (`contacts` → `ContactsProvider`)

Dünner App-Adapter: lädt aktive `contacts` (nicht archiviert, nicht gemerged), decodiert `[AtollContactRow]`, mappt via `AtollContactMapper`. Build-verifiziert.

**Files:**
- Create: `apps/comhub-native/ComHub/Adapters/AtollContactsAdapter.swift`

- [ ] **Step 1: Adapter schreiben**

`apps/comhub-native/ComHub/Adapters/AtollContactsAdapter.swift`:

```swift
import Foundation
import AtollCore
import AtollHub
import Supabase

/// Erfüllt `ContactsProvider` über die Atoll-`contacts`-Tabelle. RLS ist für
/// `contacts` permissiv (alle authentifizierten Nutzer lesen alle Kontakte);
/// wir filtern auf aktive, nicht zusammengeführte Personen/Orgs. Spaltenliste
/// gespiegelt vom Web-`contactQueries.ts` (Subset).
struct AtollContactsAdapter: ContactsProvider {
  let accountId: String
  let pageSize: Int
  private let supabase = SupabaseClient.shared

  init(accountId: String = "atoll", pageSize: Int = 1000) {
    self.accountId = accountId
    self.pageSize = pageSize
  }

  func contacts() async throws -> [UnifiedContact] {
    let rows: [AtollContactRow] = try await supabase
      .from("contacts")
      .select("id, kind, first_name, last_name, trading_name, legal_name, primary_email, emails, phones")
      .is("archived_at", value: nil)
      .is("merged_into_id", value: nil)
      .order("last_name", ascending: true)
      .limit(pageSize)
      .execute()
      .value

    return AtollContactMapper.contacts(from: rows, accountId: accountId)
  }
}
```

- [ ] **Step 2: Build verifizieren**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`. (Compile beweist die `AtollContactRow`-Decoding-Signatur.)

- [ ] **Step 3: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Adapters/AtollContactsAdapter.swift
git commit -m "ComHub: AtollContactsAdapter (contacts -> ContactsProvider)"
```

---

## Task 12: `HubWiring` — Konten in den Hub verdrahten

Verbindet beim Sign-in das Apple-Konto (Kalender + Kontakte) und das Atoll-Konto (Events als Kalender + Kontakte) in den `Hub`. Idempotent (erst `reset()`). Apple-Adapter teilen sich **ein** `EKEventStore` (von außen gereicht, damit Berechtigungsstatus konsistent bleibt). Build-verifiziert.

**Files:**
- Create: `apps/comhub-native/ComHub/Hub/HubWiring.swift`

- [ ] **Step 1: Wiring schreiben**

`apps/comhub-native/ComHub/Hub/HubWiring.swift`:

```swift
import Foundation
import EventKit
import AtollCore
import AtollHub

/// Verdrahtet die konkreten Adapter in den `Hub`. Beim Sign-in aufgerufen mit
/// dem aktuellen User; Atoll-Events brauchen dessen Instructor-id.
enum HubWiring {
  /// Ein gemeinsamer Store für den Apple-Kalender-Adapter (Status-Konsistenz
  /// mit `AppleAuthorizationService`). Contacts nutzt einen eigenen Store.
  @MainActor
  static func connectAll(into hub: Hub, currentUser: CurrentUser,
                         eventStore: EKEventStore) {
    hub.reset()

    // Apple/iCloud: Kalender + Kontakte.
    let apple = Account(id: "apple", type: .apple, displayName: "iCloud",
                        capabilities: [.calendar, .contacts])
    hub.connect(AccountConnection(
      account: apple,
      calendar: AppleCalendarAdapter(store: eventStore),
      contacts: AppleContactsAdapter()
    ))

    // Atoll: Events (als CalendarProvider) + CRM-Kontakte.
    let atoll = Account(id: "atoll", type: .atoll, displayName: "Atoll",
                        capabilities: [.calendar, .contacts])
    hub.connect(AccountConnection(
      account: atoll,
      calendar: AtollEventsAdapter(instructorId: currentUser.legacyInstructorId),
      contacts: AtollContactsAdapter()
    ))
  }
}
```

- [ ] **Step 2: Build verifizieren**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Hub/HubWiring.swift
git commit -m "ComHub: HubWiring (Apple + Atoll Konten in den Hub)"
```

---

## Task 13: `CalendarStore` — Lade-Zustand fürs Kalender-Modul

`@Observable` Store: hält Anker, Kind, geladene Events und den `eventsByDay`-Cache; `reload()` ruft `hub.allEvents(in:)` mit dem `CalendarWindow`. Build-verifiziert.

**Files:**
- Create: `apps/comhub-native/ComHub/Calendar/CalendarStore.swift`

- [ ] **Step 1: Store schreiben**

`apps/comhub-native/ComHub/Calendar/CalendarStore.swift`:

```swift
import Foundation
import Observation
import AtollHub

/// Steuert das Kalender-Modul: aktuelle Ansicht (`kind`), Anker-Datum und die
/// geladenen, quellneutralen Events. Lädt über den `Hub` (Apple + Atoll).
@MainActor
@Observable
final class CalendarStore {
  var kind: CalendarKind = .week
  var anchor: Date = Date()
  private(set) var events: [UnifiedEvent] = []
  private(set) var eventsByDay: [Date: [UnifiedEvent]] = [:]
  private(set) var loading = false
  private(set) var errors: [String] = []

  /// Zürich-Kalender mit Montag als Wochenstart — konsistent mit den
  /// `AtollHub`-Datumshelfern.
  var calendar: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
    c.firstWeekday = 2
    return c
  }

  func reload(using hub: Hub) async {
    loading = true
    let window = CalendarWindow.interval(for: anchor, kind: kind, calendar: calendar)
    let merged = await hub.allEvents(in: window)
    events = merged
    eventsByDay = CalendarLayout.eventsByDay(merged, calendar: calendar)
    errors = hub.lastErrors
    loading = false
  }

  // MARK: – Navigation

  func goToToday() { anchor = Date() }

  func step(_ direction: Int) {
    let component: Calendar.Component
    switch kind {
    case .day:   component = .day
    case .week:  component = .weekOfYear
    case .month: component = .month
    }
    anchor = calendar.date(byAdding: component, value: direction, to: anchor) ?? anchor
  }
}
```

- [ ] **Step 2: Build verifizieren**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Calendar/CalendarStore.swift
git commit -m "ComHub: CalendarStore (Lade-Zustand, Navigation, Hub-Merge)"
```

---

## Task 14: Kalender-Views (Zeile, Tag, Woche, Monat)

Lese-only SwiftUI-Views, die aus `CalendarStore`/`CalendarLayout` rendern. Vier kleine Dateien. Build-verifiziert.

**Files:**
- Create: `apps/comhub-native/ComHub/Calendar/UnifiedEventRow.swift`
- Create: `apps/comhub-native/ComHub/Calendar/DayColumnView.swift`
- Create: `apps/comhub-native/ComHub/Calendar/WeekGridView.swift`
- Create: `apps/comhub-native/ComHub/Calendar/MonthGridView.swift`

- [ ] **Step 1: `UnifiedEventRow` schreiben** (eine Event-Zeile mit Quell-Badge)

`apps/comhub-native/ComHub/Calendar/UnifiedEventRow.swift`:

```swift
import SwiftUI
import AtollHub

/// Eine Event-Zeile: Zeit (oder „ganztägig"), Titel, Ort, Quell-Badge.
struct UnifiedEventRow: View {
  let event: UnifiedEvent

  private static let timeFormatter: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "HH:mm"
    f.timeZone = TimeZone(identifier: "Europe/Zurich"); return f
  }()

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      RoundedRectangle(cornerRadius: 2)
        .fill(event.source.type == .atoll ? Color.accentColor : Color.secondary)
        .frame(width: 4)
      VStack(alignment: .leading, spacing: 2) {
        Text(event.title).font(.callout.weight(.medium)).lineLimit(1)
        HStack(spacing: 6) {
          Text(event.isAllDay ? "ganztägig"
               : Self.timeFormatter.string(from: event.start))
            .font(.caption).foregroundStyle(.secondary)
          if let loc = event.location, !loc.isEmpty {
            Text(loc).font(.caption).foregroundStyle(.secondary).lineLimit(1)
          }
        }
      }
      Spacer(minLength: 0)
      Text(event.source.type == .atoll ? "Atoll" : "Apple")
        .font(.caption2).foregroundStyle(.secondary)
        .padding(.horizontal, 5).padding(.vertical, 1)
        .background(.quaternary, in: Capsule())
    }
    .padding(.vertical, 2)
  }
}
```

- [ ] **Step 2: `DayColumnView` schreiben**

`apps/comhub-native/ComHub/Calendar/DayColumnView.swift`:

```swift
import SwiftUI
import AtollHub

/// Tagesansicht: chronologische Liste der Events des Ankertags.
struct DayColumnView: View {
  let store: CalendarStore

  private var dayEvents: [UnifiedEvent] {
    let day = store.calendar.startOfDay(for: store.anchor)
    return store.eventsByDay[day] ?? []
  }

  var body: some View {
    Group {
      if dayEvents.isEmpty {
        ContentUnavailableView("Keine Termine", systemImage: "calendar")
      } else {
        List(dayEvents) { UnifiedEventRow(event: $0) }
      }
    }
  }
}
```

- [ ] **Step 3: `WeekGridView` schreiben**

`apps/comhub-native/ComHub/Calendar/WeekGridView.swift`:

```swift
import SwiftUI
import AtollHub

/// Wochenansicht: sieben Tagesspalten (Mo–So) mit ihren Events.
struct WeekGridView: View {
  let store: CalendarStore

  private static let header: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "EE dd.MM"
    f.locale = Locale(identifier: "de_CH")
    f.timeZone = TimeZone(identifier: "Europe/Zurich"); return f
  }()

  private var days: [Date] {
    CalendarLayout.weekDays(of: store.anchor, calendar: store.calendar)
  }

  var body: some View {
    ScrollView(.horizontal) {
      HStack(alignment: .top, spacing: 0) {
        ForEach(days, id: \.self) { day in
          VStack(alignment: .leading, spacing: 4) {
            Text(Self.header.string(from: day))
              .font(.caption.weight(.semibold))
              .frame(maxWidth: .infinity, alignment: .leading)
            Divider()
            let events = store.eventsByDay[store.calendar.startOfDay(for: day)] ?? []
            if events.isEmpty {
              Text("—").font(.caption2).foregroundStyle(.tertiary)
            } else {
              ForEach(events) { UnifiedEventRow(event: $0) }
            }
            Spacer(minLength: 0)
          }
          .padding(8)
          .frame(width: 200, alignment: .topLeading)
          Divider()
        }
      }
    }
  }
}
```

- [ ] **Step 4: `MonthGridView` schreiben**

`apps/comhub-native/ComHub/Calendar/MonthGridView.swift`:

```swift
import SwiftUI
import AtollHub

/// Monatsansicht: Wochen × 7 Tage. Jede Zelle zeigt die Tageszahl und bis zu
/// drei Event-Titel (+ „n weitere").
struct MonthGridView: View {
  let store: CalendarStore

  private var weeks: [[Date]] {
    CalendarLayout.monthGrid(of: store.anchor, calendar: store.calendar)
  }
  private var anchorMonth: Int {
    store.calendar.component(.month, from: store.anchor)
  }

  var body: some View {
    VStack(spacing: 0) {
      ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
        HStack(spacing: 0) {
          ForEach(week, id: \.self) { day in
            cell(for: day)
            Divider()
          }
        }
        Divider()
      }
    }
  }

  @ViewBuilder
  private func cell(for day: Date) -> some View {
    let dayStart = store.calendar.startOfDay(for: day)
    let events = store.eventsByDay[dayStart] ?? []
    let inMonth = store.calendar.component(.month, from: day) == anchorMonth
    VStack(alignment: .leading, spacing: 2) {
      Text("\(store.calendar.component(.day, from: day))")
        .font(.caption.weight(.semibold))
        .foregroundStyle(inMonth ? .primary : .tertiary)
      ForEach(events.prefix(3)) { e in
        Text(e.title).font(.caption2).lineLimit(1)
          .foregroundStyle(e.source.type == .atoll ? Color.accentColor : .secondary)
      }
      if events.count > 3 {
        Text("+\(events.count - 3) weitere").font(.caption2).foregroundStyle(.tertiary)
      }
      Spacer(minLength: 0)
    }
    .padding(4)
    .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
  }
}
```

- [ ] **Step 5: Build verifizieren**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Calendar/UnifiedEventRow.swift apps/comhub-native/ComHub/Calendar/DayColumnView.swift apps/comhub-native/ComHub/Calendar/WeekGridView.swift apps/comhub-native/ComHub/Calendar/MonthGridView.swift
git commit -m "ComHub: Kalender-Views (Zeile/Tag/Woche/Monat, lese-only)"
```

---

## Task 15: `CalendarModuleView` — Umschalter + Navigation, lädt via Hub

Hostet die drei Ansichten, bietet Kind-Picker + Vor/Zurück/Heute, und lädt bei jeder Änderung von `kind`/`anchor` über den `Hub` (aus der Environment). Build-verifiziert.

**Files:**
- Create: `apps/comhub-native/ComHub/Calendar/CalendarModuleView.swift`

- [ ] **Step 1: View schreiben**

`apps/comhub-native/ComHub/Calendar/CalendarModuleView.swift`:

```swift
import SwiftUI
import AtollHub

/// Kalender-Modul: Tag/Woche/Monat über die gemergten Hub-Events.
struct CalendarModuleView: View {
  @Environment(Hub.self) private var hub
  @State private var store = CalendarStore()

  private static let title: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
    f.locale = Locale(identifier: "de_CH")
    f.timeZone = TimeZone(identifier: "Europe/Zurich"); return f
  }()

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      content
    }
    .task(id: reloadKey) { await store.reload(using: hub) }
  }

  // Lädt neu, wenn sich Ansicht oder Anker ändert.
  private var reloadKey: String {
    "\(store.kind.rawValue)-\(store.anchor.timeIntervalSince1970)"
  }

  private var header: some View {
    HStack(spacing: 12) {
      Picker("Ansicht", selection: $store.kind) {
        ForEach(CalendarKind.allCases) { Text($0.title).tag($0) }
      }
      .pickerStyle(.segmented)
      .frame(maxWidth: 240)

      Spacer()

      Text(Self.title.string(from: store.anchor))
        .font(.headline)

      Spacer()

      Button { store.step(-1) } label: { Image(systemName: "chevron.left") }
      Button("Heute") { store.goToToday() }
      Button { store.step(1) } label: { Image(systemName: "chevron.right") }
      if store.loading { ProgressView().controlSize(.small) }
    }
    .padding(8)
  }

  @ViewBuilder
  private var content: some View {
    switch store.kind {
    case .day:   DayColumnView(store: store)
    case .week:  WeekGridView(store: store)
    case .month: MonthGridView(store: store)
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
git add apps/comhub-native/ComHub/Calendar/CalendarModuleView.swift
git commit -m "ComHub: CalendarModuleView (Umschalter + Navigation, laedt via Hub)"
```

---

## Task 16: `ContactsStore` + `ContactsModuleView` — kombiniertes Adressbuch

Lädt alle Kontakte über den `Hub`, gruppiert via `ContactMatcher`, baut `MergedContact`s; zeigt Liste + Detail mit Quell-Tags. Build-verifiziert.

**Files:**
- Create: `apps/comhub-native/ComHub/Contacts/ContactsStore.swift`
- Create: `apps/comhub-native/ComHub/Contacts/ContactsModuleView.swift`

- [ ] **Step 1: `ContactsStore` schreiben**

`apps/comhub-native/ComHub/Contacts/ContactsStore.swift`:

```swift
import Foundation
import Observation
import AtollHub

/// Lädt + matcht das kombinierte Adressbuch (Apple + Atoll) über den Hub.
@MainActor
@Observable
final class ContactsStore {
  private(set) var merged: [MergedContact] = []
  private(set) var loading = false
  private(set) var errors: [String] = []
  var search = ""

  var filtered: [MergedContact] {
    let q = search.trimmingCharacters(in: .whitespaces).lowercased()
    guard !q.isEmpty else { return merged }
    return merged.filter { c in
      c.displayName.lowercased().contains(q)
        || c.emails.contains { $0.lowercased().contains(q) }
        || c.phones.contains { $0.contains(q) }
    }
  }

  func reload(using hub: Hub) async {
    loading = true
    let all = await hub.allContacts()
    let groups = ContactMatcher.group(all)
    merged = groups.map(MergedContact.init(group:))
      .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    errors = hub.lastErrors
    loading = false
  }
}
```

- [ ] **Step 2: `ContactsModuleView` schreiben**

`apps/comhub-native/ComHub/Contacts/ContactsModuleView.swift`:

```swift
import SwiftUI
import AtollHub

/// Kombiniertes Adressbuch: Liste (mit Suche) + Detail mit Quell-Tags.
struct ContactsModuleView: View {
  @Environment(Hub.self) private var hub
  @State private var store = ContactsStore()
  @State private var selection: MergedContact?

  var body: some View {
    List(store.filtered, selection: $selection) { contact in
      NavigationLink(value: contact) {
        VStack(alignment: .leading, spacing: 2) {
          Text(contact.displayName).font(.callout.weight(.medium))
          HStack(spacing: 4) {
            ForEach(contact.sources, id: \.self) { src in
              Text(src == .atoll ? "Atoll" : "Apple")
                .font(.caption2).foregroundStyle(.secondary)
                .padding(.horizontal, 5).padding(.vertical, 1)
                .background(.quaternary, in: Capsule())
            }
            if let mail = contact.emails.first {
              Text(mail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
          }
        }
      }
    }
    .searchable(text: $store.search, prompt: "Kontakte suchen")
    .overlay { if store.loading { ProgressView() } }
    .navigationDestination(for: MergedContact.self) { ContactDetailView(contact: $0) }
    .task { await store.reload(using: hub) }
  }
}

/// Detailansicht eines zusammengeführten Kontakts.
private struct ContactDetailView: View {
  let contact: MergedContact

  var body: some View {
    Form {
      Section {
        Text(contact.displayName).font(.title2.weight(.semibold))
        HStack(spacing: 6) {
          ForEach(contact.sources, id: \.self) { src in
            Label(src == .atoll ? "Atoll" : "Apple",
                  systemImage: src == .atoll ? "cloud" : "applelogo")
              .font(.caption)
          }
        }
      }
      if !contact.emails.isEmpty {
        Section("E-Mail") {
          ForEach(contact.emails, id: \.self) { Text($0).textSelection(.enabled) }
        }
      }
      if !contact.phones.isEmpty {
        Section("Telefon") {
          ForEach(contact.phones, id: \.self) { Text($0).textSelection(.enabled) }
        }
      }
    }
    .navigationTitle(contact.displayName)
  }
}
```

- [ ] **Step 3: Build verifizieren**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Contacts/ContactsStore.swift apps/comhub-native/ComHub/Contacts/ContactsModuleView.swift
git commit -m "ComHub: kombiniertes Adressbuch (ContactsStore + ContactsModuleView)"
```

---

## Task 17: Module in die Shell hängen + Hub beim Sign-in verdrahten

`HubShell` zeigt für `.kalender`/`.kontakte` die echten Module; `ComHubApp` verdrahtet beim Sign-in die Adapter in den `Hub`. Build + Tests + manueller Smoke-Test.

**Files:**
- Modify: `apps/comhub-native/ComHub/Shell/HubShell.swift`
- Modify: `apps/comhub-native/ComHub/ComHubApp.swift`

- [ ] **Step 1: `HubShell` — echte Module statt Platzhalter für Kalender/Kontakte**

In `apps/comhub-native/ComHub/Shell/HubShell.swift` den `content`-Closure des `NavigationSplitView` ersetzen, sodass für `.kalender`/`.kontakte` die Module rendern (übrige Module behalten den `ModulePlaceholder`). Konkret den `content:`-Block so fassen:

```swift
    } content: {
      switch selectedModule {
      case .kalender:
        CalendarModuleView()
          #if os(macOS)
          .frame(minWidth: 480)
          #endif
      case .kontakte:
        ContactsModuleView()
          #if os(macOS)
          .frame(minWidth: 320)
          #endif
      default:
        ModulePlaceholder(module: selectedModule, pane: "Liste")
          #if os(macOS)
          .frame(minWidth: 280)
          #endif
      }
    } detail: {
      switch selectedModule {
      case .kalender, .kontakte:
        // Kalender/Kontakte rendern ihr Detail intern (NavigationSplitView-
        // Detailspalte bleibt für diese Module leer/kontextuell).
        Color.clear
      default:
        ModulePlaceholder(module: selectedModule, pane: "Detail")
      }
    }
```

> Der Rest von `HubShell.swift` (Sidebar-`List`, `ModulePlaceholder`-struct) bleibt
> unverändert.

- [ ] **Step 2: `ComHubApp` — Hub beim Sign-in verdrahten**

In `apps/comhub-native/ComHub/ComHubApp.swift` einen gemeinsamen `EKEventStore` als `@State` halten und beim Wechsel auf `.signedIn` `HubWiring.connectAll(...)` aufrufen. Konkret:

1. Import ergänzen (oben, nach den bestehenden Imports):

```swift
import EventKit
```

2. Neues `@State` neben den bestehenden Stores (in der Property-Liste):

```swift
  @State private var eventStore = EKEventStore()
```

3. Im `WindowGroup`-Body, am `RootView()` **nach** `.onChange(of: scenePhase...)` einen Auth-Beobachter ergänzen, der bei `.signedIn` verdrahtet:

```swift
        .onChange(of: authStatusKey) { _, _ in
          if case .signedIn(let user) = auth.status {
            HubWiring.connectAll(into: hub, currentUser: user, eventStore: eventStore)
          } else {
            hub.reset()
          }
        }
        .task(id: authStatusKey) {
          if case .signedIn(let user) = auth.status {
            HubWiring.connectAll(into: hub, currentUser: user, eventStore: eventStore)
          }
        }
```

4. Ein stabiler Schlüssel für den Auth-Status (am Ende des `ComHubApp`-structs, als computed property):

```swift
  /// Stabiler Schlüssel, der nur bei echtem Statuswechsel kippt (für `onChange`/`task(id:)`).
  private var authStatusKey: String {
    switch auth.status {
    case .loading:   return "loading"
    case .signedOut: return "signedOut"
    case .signedIn(let u): return "signedIn:\(u.id.uuidString)"
    }
  }
```

> Hinweis: `.task(id:)` verdrahtet beim ersten Erscheinen einer bereits
> bestehenden Session (App-Neustart, Session aus Keychain), `.onChange`
> bei einem Login/Logout zur Laufzeit. Beide rufen dieselbe idempotente
> `connectAll` (die intern `hub.reset()` macht).

- [ ] **Step 3: Generieren + voller Build + Tests**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`.

Run: `cd apps/comhub-native && xcodebuild test -scheme ComHub -destination 'platform=macOS,arch=arm64'`
Expected: `** TEST SUCCEEDED **` — `ComHubTests` (Phase-0-Smoke, 2 Tests) weiterhin grün.

- [ ] **Step 4: Manueller Smoke-Test** (echter Mac, nicht automatisierbar)

- [ ] App starten, anmelden (OTP) → Shell.
- [ ] Apple-Permissions akzeptieren (Kalender + Kontakte), falls noch nicht geschehen.
- [ ] Modul **Kalender**: Woche zeigt Apple- **und** Atoll-Events (Atoll mit Akzent-Badge); Tag/Monat umschalten; Vor/Zurück/Heute navigieren; Atoll-Kurstage erscheinen an den richtigen Daten.
- [ ] Modul **Kontakte**: Liste zeigt Apple- + Atoll-Kontakte; doppelte (gleiche E-Mail/Telefon) erscheinen **einmal** mit beiden Quell-Tags; Suche filtert; Detail zeigt E-Mails/Telefone + Quellen.

- [ ] **Step 5: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Shell/HubShell.swift apps/comhub-native/ComHub/ComHubApp.swift
git commit -m "ComHub: Kalender- + Kontakte-Modul in die Shell, Hub beim Sign-in verdrahtet"
```

---

## Task 18: Dokumentation (Phase 1)

**Files:**
- Modify: `apps/comhub-native/README.md`

- [ ] **Step 1: README-Phase-Abschnitt ersetzen**

In `apps/comhub-native/README.md` den `## Phase 0 (dieser Stand)`-Abschnitt durch folgenden ersetzen:

```markdown
## Phasen-Stand

**Phase 0** — OTP-Login, leere 3-Spalten-Shell, getesteter Provider-Kern (`AtollHub`).

**Phase 1** — Gemergter, lese-only **Kalender** (Tag/Woche/Monat) aus Apple/iCloud
(EventKit) + Atoll-Events (`course_assignments`) und ein **kombiniertes Adressbuch**
(Apple-Kontakte + Atoll-`contacts`, gematcht/dedupliziert über `ContactMatcher`).
Adapter im App-Target (`Adapters/`), reine Mapper/Layout-Logik getestet in `AtollHub`
(`AppleEventMapper`/`AppleContactMapper`/`AtollEventMapper`/`AtollContactMapper`,
`MergedContact`, `CalendarWindow`/`CalendarLayout`). Schreiben (EventKit/Reminders),
Kombox, Tasks, CardInbox, Push folgen in Phase 2+.
```

- [ ] **Step 2: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/README.md
git commit -m "Docs: ComHub-README Phase-1-Stand (Kalender + kombiniertes Adressbuch)"
```

---

## Self-Review (durchgeführt)

**1. Spec-Abdeckung (Phase 1 laut Spec §11 + Roadmap):**
- „AppleAdapter (EventKit, Contacts)" → Task 8 (`AppleCalendarAdapter`) + Task 9 (`AppleContactsAdapter`), reine Mapper Task 1.
- „AtollAdapter (Events via supabase-swift, `contacts`)" → Task 10 (`AtollEventsAdapter`) + Task 11 (`AtollContactsAdapter`), reine Mapper Tasks 3+4.
- „gemergter Kalender (Tag/Woche/Monat)" → Tasks 6–7 (Fenster/Layout, getestet) + Tasks 13–15 (Store, Views, Modul) + Hub-Merge via `AccountConnection.calendar` (kein Hub-Umbau).
- „kombiniertes Adressbuch (`ContactMatcher`)" → Task 5 (`MergedContact`) + Task 16 (Store/View), Matching aus Phase-0-`ContactMatcher`.
- „Voraussetzung früh klären: AtollCal-Paketierung" → oben entschieden (kein `AtollCalKit`; lese-only Views in ComHub über `UnifiedEvent`), mit Begründung.

**2. Platzhalter-Scan:** Keine „TBD/TODO/später ausfüllen"-Schritte. Jeder Code-Schritt zeigt vollständigen Code; jeder Run-Schritt nennt Befehl + erwartete Ausgabe. Bewusste Tradeoffs (mehrtägige Atoll-Kurse mit `start_date` vor Fenster) sind als bekannte Phase-1-Grenze markiert, nicht als Loch.

**3. Typ-Konsistenz** (über Tasks hinweg geprüft):
- `AppleEventMapper.event(accountId:identifier:title:start:end:isAllDay:location:)` (Task 1) ↔ Aufruf in `AppleCalendarAdapter` (Task 8). ✔
- `AppleContactMapper.contact(accountId:identifier:givenName:familyName:emails:phones:)` (Task 1) ↔ `AppleContactsAdapter` (Task 9). ✔
- `AtollEventMapper.events(from:accountId:)` (Task 3) ↔ `AtollEventsAdapter` (Task 10). ✔ — `Assignment`/`Course`/`CourseDate`/`CourseModule` aus AtollCore exakt (`course.courseDates`, `day.expandModules()`, `m.type.label`, `course.status != .cancelled`, `a.role.rawValue`).
- `AtollContactRow`/`AtollEmail`/`AtollPhone` + `AtollContactMapper.contacts(from:accountId:)` (Task 4) ↔ `AtollContactsAdapter` Select-Spalten (Task 11). ✔
- `MergedContact(group:)` mit `.displayName/.emails/.phones/.sources/.members/.id` (Task 5) ↔ `ContactsStore`/`ContactDetailView` (Task 16). ✔
- `CalendarKind` (.day/.week/.month, `.title`, `.allCases`) (Task 6) ↔ `CalendarStore`/`CalendarModuleView` (Tasks 13/15). ✔
- `CalendarWindow.interval(for:kind:calendar:)` + `startOfWeek(for:calendar:)` (Task 6) ↔ `CalendarLayout` (Task 7) + `CalendarStore.reload` (Task 13). ✔
- `CalendarLayout.eventsByDay(_:calendar:)/weekDays(of:calendar:)/monthGrid(of:calendar:)` (Task 7) ↔ Views (Task 14) + Store (Task 13). ✔
- Phase-0-APIs unverändert genutzt: `Hub.allEvents(in:)`/`allContacts()`/`connect(_:)`/`reset()`/`lastErrors`, `AccountConnection(account:calendar:contacts:)`, `Account(id:type:displayName:capabilities:)`, `ContactMatcher.group(_:)`, `AccountRef`, `UnifiedEvent`/`UnifiedContact`-Inits. ✔
- AtollCore: `SupabaseClient.shared` (public, verifiziert), `CurrentUser.legacyInstructorId`, `auth.status` `.signedIn(currentUser:)`. ✔

**4. Verifikations-Disziplin:** Pakettasks (1,3,4,5,6,7) sind echte TDD (failing test → impl → grün) via `swift test`. App-Tasks (8–17) sind build-/test-verifiziert via `xcodegen generate` + `xcodebuild`. Task 17 schließt mit `xcodebuild test` + manuellem Smoke-Test. Konform zu superpowers:verification-before-completion — kein „fertig" ohne grüne Ausgabe.

---

## Execution Handoff

**Plan komplett und gespeichert unter `docs/superpowers/plans/2026-06-02-comhub-phase1-calendar-contacts.md`. Zwei Ausführungs-Optionen:**

**1. Subagent-Driven (empfohlen)** — ich schicke pro Task einen frischen Subagenten los, prüfe zwischen den Tasks, schnelle Iteration. (REQUIRED SUB-SKILL: superpowers:subagent-driven-development.)

**2. Inline-Ausführung** — Tasks in dieser Session abarbeiten, Batch mit Checkpoints. (REQUIRED SUB-SKILL: superpowers:executing-plans.)

**Welcher Ansatz?**
