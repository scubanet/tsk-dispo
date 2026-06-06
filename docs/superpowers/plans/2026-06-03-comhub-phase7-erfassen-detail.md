# ComHub Phase 7 — Erfassen, Detail & Compose Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fünf Nutzer-Wünsche: (1) Adressliste nach **Nachname, Vorname** sortieren; (2) **neue Kombox-Nachricht** (Mail/WhatsApp) an einen wählbaren Kontakt; (3) **neue Todos** erfassen (Apple Erinnerungen); (4) **reichere Kontakt-Detailansicht** (alle sinnvollen Felder); (5) **Kontakt erfassen/ändern** — Ziel (Atoll-CRM **oder** Apple) wählbar.

**Architecture:** `UnifiedContact` (AtollHub) wird additiv um Rich-Felder erweitert (kind, Firma, Adressen, Geburtstag, Sprachen, Rollen, Tags, Notizen); `MergedContact` trägt `firstName`/`lastName` (für Sort) + aggregierte Rich-Felder. `ContactSections` sortiert nach `lastName,firstName`. `ContactsProvider` bekommt Schreib-Methoden (`createContact`/`updateContact`, Default wirft), implementiert in **AtollContactsAdapter** (Supabase `contacts`) und **AppleContactsAdapter** (`CNSaveRequest`). Der `Hub` routet: `createContact(_:source:)` ans gewählte Konto, `updateContact(id:with:)` per Id-Präfix, `createTask(...)` ans Apple-Todo-Konto. UI: reiches `ContactDetailPane`, `ContactEditSheet` (Quelle wählbar beim Erstellen), `TaskEditSheet` + „+" in Aufgaben, „Neue Nachricht" in Kombox (Kontakt-Picker → Kanal → senden via bestehendes `comms-outbound`).

**Tech Stack:** Swift 6 (strict concurrency complete), SwiftUI Multiplatform (iOS 26 / macOS 26), EventKit, `Contacts`/`CNContactStore` (write), supabase-swift 2.46 (PostgREST insert/update, JSONB), XCTest, XcodeGen. Reuse: `EventDraft`/`SourceID`/`CalendarFilter`/`ProviderWriteError`/`Hub`-Routing-Muster aus 5a; `CompactWidthReader` aus 6a; `comms-outbound` aus 3b.

---

## Scope-Grenzen (bewusst)

- **Kontakt schreiben:** Ziel **wählbar** (Atoll-CRM **oder** Apple). Bearbeiten editiert die Hälfte, die zur Quell-Id des gewählten Members passt; bei gemergten Kontakten mit beiden Hälften wird die **Atoll-Hälfte** bevorzugt (CRM-autoritativ), sonst Apple.
- **Todos erfassen:** nur **Apple Erinnerungen** (Atoll-Task-Erfassen braucht Listen-Schema — später).
- **Kombox neu:** Empfänger = **bestehender Kontakt** (comms-outbound braucht `contact_id`); keine freie Adresse.
- **Detail:** voll (alle sinnvollen Felder), read-only-Anzeige + Edit-Einstieg.
- Keine Kontakt-Löschung in dieser Phase (nur erstellen/ändern).

---

## File Structure

**AtollHub:**
- `Model/UnifiedModels.swift` — `UnifiedContact` +Rich-Felder; `PostalAddress`, `ContactKind`.
- `Contacts/MergedContact.swift` — +`firstName`/`lastName` + Rich-Aggregat.
- `Contacts/ContactMatcher.swift` — MergedContact-Bau um neue Felder ergänzen.
- `Contacts/ContactSections.swift` — Sort `lastName,firstName`.
- `Model/ContactDraft.swift` (neu) — Eingabemodell.
- `Capabilities/Providers.swift` — `ContactsProvider` Schreib-Methoden (Default wirft).
- `Hub/Hub.swift` — Routing `createContact`/`updateContact`/`createTask`.
- Tests: `ContactSectionsTests`, `ContactDraftTests`, `HubContactRoutingTests`.

**App:**
- `Adapters/AtollContactsAdapter.swift` — mehr SELECT-Spalten + Rich-Mapping + `createContact`/`updateContact` (Supabase).
- `Apple/AppleContactsAdapter.swift` — Rich-Mapping (read) + `createContact`/`updateContact` (`CNSaveRequest`) + Schreibrecht.
- `Contacts/ContactDetailPane.swift` — Rich-Anzeige + „Bearbeiten".
- `Contacts/ContactEditSheet.swift` (neu) — Erstellen/Bearbeiten.
- `Contacts/ContactsModuleView.swift` — „+"/Edit-Verdrahtung.
- `Tasks/TaskEditSheet.swift` (neu) + `Tasks/AufgabenStore.swift` + `Tasks/AufgabenModuleView.swift` — Todo erfassen.
- `Kombox/NewMessageSheet.swift` (neu) + `Kombox/KomboxModuleView.swift` + `Kombox/KomboxStore.swift` — neue Nachricht.

**Doku:** `apps/comhub-native/README.md`.

---

## Task 1: `UnifiedContact`/`MergedContact` Rich-Felder + `ContactDraft` (AtollHub, TDD)

**Files:** Modify `Model/UnifiedModels.swift`, `Contacts/MergedContact.swift`, `Contacts/ContactMatcher.swift`; Create `Model/ContactDraft.swift`; Test `Tests/AtollHubTests/ContactDraftTests.swift`.

- [ ] **Step 1: Rich-Typen + `UnifiedContact` erweitern (additiv)**

In `UnifiedModels.swift` ergänzen (vor `UnifiedContact`):
```swift
public enum ContactKind: String, Sendable, Codable, Equatable { case person, organization }

public struct PostalAddress: Sendable, Equatable, Hashable, Codable {
  public var street: String?
  public var postalCode: String?
  public var city: String?
  public var region: String?
  public var country: String?
  public var label: String?
  public init(street: String? = nil, postalCode: String? = nil, city: String? = nil,
              region: String? = nil, country: String? = nil, label: String? = nil) {
    self.street = street; self.postalCode = postalCode; self.city = city
    self.region = region; self.country = country; self.label = label
  }
  public var oneLine: String {
    [street, [postalCode, city].compactMap { $0 }.joined(separator: " "), country]
      .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
  }
}
```
READ die aktuelle `UnifiedContact`-Struct (Felder: id, source, firstName, lastName, emails, phones) und erweitere sie **additiv** (neue Felder mit Defaults; bestehender Init bleibt gültig — neue Parameter ans Ende mit Defaults):
```swift
  public var kind: ContactKind
  public var organizationName: String?
  public var addresses: [PostalAddress]
  public var birthday: Date?
  public var languages: [String]
  public var roles: [String]
  public var tags: [String]
  public var notes: String?
```
Init: bestehende Pflichtparameter unverändert, neue als `kind: ContactKind = .person, organizationName: String? = nil, addresses: [PostalAddress] = [], birthday: Date? = nil, languages: [String] = [], roles: [String] = [], tags: [String] = [], notes: String? = nil`. So bleiben alle bestehenden Call-Sites (Apple/Atoll-Mapper, Tests) gültig.

- [ ] **Step 2: `MergedContact` + Aggregat**

READ `MergedContact.swift` (Felder: id, displayName, emails, phones, sources, members). Ergänze:
```swift
  public var firstName: String?
  public var lastName: String?
  public var kind: ContactKind
  public var organizationName: String?
  public var addresses: [PostalAddress]
  public var birthday: Date?
  public var languages: [String]
  public var roles: [String]
  public var tags: [String]
  public var notes: String?
```
Init additiv mit Defaults (nil/[]/.person). `firstName`/`lastName` werden in `ContactMatcher` gesetzt.

- [ ] **Step 3: `ContactMatcher` füllt die neuen Felder**

READ `ContactMatcher.group(...)`. Wo es `MergedContact(...)` baut, leite die neuen Felder aus den `members` ab: bevorzuge den ersten Member mit nicht-leerem Wert (Atoll vor Apple, falls erkennbar — sonst Reihenfolge). Konkret:
```swift
    let primary = members.first { $0.source.type == .atoll } ?? members.first
    let firstName = members.compactMap { $0.firstName.isEmpty ? nil : $0.firstName }.first
    let lastName = members.compactMap { $0.lastName.isEmpty ? nil : $0.lastName }.first
    let kind = primary?.kind ?? .person
    let organizationName = members.compactMap { $0.organizationName }.first
    let addresses = members.flatMap { $0.addresses }
    let birthday = members.compactMap { $0.birthday }.first
    let languages = Array(Set(members.flatMap { $0.languages })).sorted()
    let roles = Array(Set(members.flatMap { $0.roles })).sorted()
    let tags = Array(Set(members.flatMap { $0.tags })).sorted()
    let notes = members.compactMap { $0.notes?.isEmpty == false ? $0.notes : nil }.first
```
und an den `MergedContact(...)`-Init durchreichen. **Passe `firstName`/`lastName`-Optionalität an die reale `UnifiedContact`-API an** (falls dort nicht-optionale `String` mit ""-Default — dann `.isEmpty`-Check wie oben).

- [ ] **Step 4: `ContactDraft` (neu)**

`Model/ContactDraft.swift`:
```swift
import Foundation

/// Quellneutrale Eingabe zum Erstellen/Bearbeiten eines Kontakts.
public struct ContactDraft: Sendable, Equatable {
  public var kind: ContactKind
  public var firstName: String
  public var lastName: String
  public var organizationName: String
  public var emails: [String]
  public var phones: [String]
  public var addresses: [PostalAddress]
  public var birthday: Date?
  public var languages: [String]
  public var roles: [String]
  public var tags: [String]
  public var notes: String

  public init(kind: ContactKind = .person, firstName: String = "", lastName: String = "",
              organizationName: String = "", emails: [String] = [], phones: [String] = [],
              addresses: [PostalAddress] = [], birthday: Date? = nil, languages: [String] = [],
              roles: [String] = [], tags: [String] = [], notes: String = "") {
    self.kind = kind; self.firstName = firstName; self.lastName = lastName
    self.organizationName = organizationName; self.emails = emails; self.phones = phones
    self.addresses = addresses; self.birthday = birthday; self.languages = languages
    self.roles = roles; self.tags = tags; self.notes = notes
  }

  /// Person: first+last Pflicht; Firma: organizationName Pflicht.
  public var isValid: Bool {
    switch kind {
    case .person: return !firstName.trimmingCharacters(in: .whitespaces).isEmpty
                      && !lastName.trimmingCharacters(in: .whitespaces).isEmpty
    case .organization: return !organizationName.trimmingCharacters(in: .whitespaces).isEmpty
    }
  }
}
```

- [ ] **Step 5: Test für `ContactDraft.isValid` (TDD)**

`Tests/AtollHubTests/ContactDraftTests.swift`:
```swift
import XCTest
@testable import AtollHub

final class ContactDraftTests: XCTestCase {
  func test_person_requiresFirstAndLast() {
    XCTAssertFalse(ContactDraft(kind: .person, firstName: "A", lastName: " ").isValid)
    XCTAssertTrue(ContactDraft(kind: .person, firstName: "A", lastName: "B").isValid)
  }
  func test_org_requiresName() {
    XCTAssertFalse(ContactDraft(kind: .organization, organizationName: "").isValid)
    XCTAssertTrue(ContactDraft(kind: .organization, organizationName: "TSK").isValid)
  }
}
```

- [ ] **Step 6: Volle Suite + Commit**

Run: `cd swift-packages/AtollHub && swift test` — Expected: alle grün (112 + neue; additive Erweiterung bricht keine Mapper/Section-Tests). Capture „Executed N tests".
```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add swift-packages/AtollHub/Sources/AtollHub swift-packages/AtollHub/Tests/AtollHubTests/ContactDraftTests.swift
git commit -m "AtollHub: UnifiedContact/MergedContact Rich-Felder + ContactDraft (additiv, getestet)"
```

---

## Task 2: `ContactSections` Sort nach Nachname, Vorname (AtollHub, TDD)

**Files:** Modify `Contacts/ContactSections.swift`; Modify `Tests/AtollHubTests/ContactSectionsTests.swift`.

- [ ] **Step 1: Tests anpassen/ergänzen (TDD)**

READ `ContactSectionsTests.swift` + `ContactSections.swift`. Heute: Sektion = erster Buchstabe `displayName`, Member alphabetisch `displayName`. Ziel: Sortierschlüssel = `lastName` dann `firstName` (Fallback `displayName`), Sektionsbuchstabe = erster Buchstabe `lastName` (Fallback displayName). Ergänze einen Test, der zeigt: „Anna Zürcher" vor „Bob Aebi"? Nein — nach Nachname: Aebi (A) vor Zürcher (Z). Konkreter Test:
```swift
  func test_sortsByLastNameThenFirstName() {
    let c1 = merged(id: "1", first: "Anna", last: "Zueable", display: "Anna Zueable")
    let c2 = merged(id: "2", first: "Bob",  last: "Aebi",   display: "Bob Aebi")
    let c3 = merged(id: "3", first: "Zora", last: "Aebi",   display: "Zora Aebi")
    let sections = ContactSections.byLetter([c1, c2, c3])
    let flat = sections.flatMap { $0.contacts }   // realen Sektions-Typ/Property pruefen
    XCTAssertEqual(flat.map(\.id), ["2", "3", "1"])  // Aebi Bob, Aebi Zora, Zueable Anna
    XCTAssertEqual(sections.first?.letter, "A")       // Sektion nach Nachname
  }
```
> Schreibe einen `merged(...)`-Helfer passend zur realen `MergedContact`-Init (mit den neuen `firstName`/`lastName`). Passe die Sektions-Typnamen (`.contacts`/`.letter`) an die reale `ContactSections`-API an (READ sie).

- [ ] **Step 2: Test rot** — `swift test --filter ContactSectionsTests` → erwartete Reihenfolge schlägt fehl (noch displayName-Sort).

- [ ] **Step 3: Sort umstellen**

In `ContactSections.swift`: Sortierschlüssel je Kontakt =
```swift
  private static func sortKey(_ c: MergedContact) -> String {
    let last = (c.lastName?.isEmpty == false ? c.lastName! : c.displayName)
    let first = c.firstName ?? ""
    return "\(last) \(first)".localizedLowercase
  }
  private static func sectionLetter(_ c: MergedContact) -> String {
    let base = (c.lastName?.isEmpty == false ? c.lastName! : c.displayName)
    guard let ch = base.trimmingCharacters(in: .whitespaces).first else { return "#" }
    return ch.isLetter ? String(ch).uppercased() : "#"
  }
```
und Member je Sektion mit `localizedCaseInsensitiveCompare`/`sortKey` sortieren, Sektionen nach Buchstabe. Behalte das bestehende „#"-Bucket für Nicht-Buchstaben.

- [ ] **Step 4: Grün + volle Suite + Commit**

Run: `cd swift-packages/AtollHub && swift test` — alle grün.
```bash
git add swift-packages/AtollHub/Sources/AtollHub/Contacts/ContactSections.swift swift-packages/AtollHub/Tests/AtollHubTests/ContactSectionsTests.swift
git commit -m "AtollHub: Adressliste sortiert nach Nachname, Vorname"
```

---

## Task 3: `ContactsProvider`-Schreiben + Hub-Routing (AtollHub, TDD)

**Files:** Modify `Capabilities/Providers.swift`, `Hub/Hub.swift`; Test `Tests/AtollHubTests/HubContactRoutingTests.swift`.

- [ ] **Step 1: `ContactsProvider` Schreib-Methoden (Default wirft) als Requirements**

In `Providers.swift` das `ContactsProvider`-Protokoll erweitern (Methoden als **Requirements**, Defaults in Extension — wie bei Todo/Calendar in 5a; sonst greift bei Existentials der Default statt der Konkret-Impl):
```swift
public protocol ContactsProvider: Sendable {
  func contacts() async throws -> [UnifiedContact]
  func createContact(_ draft: ContactDraft) async throws -> UnifiedContact
  func updateContact(id: String, with draft: ContactDraft) async throws -> UnifiedContact
}
public extension ContactsProvider {
  func createContact(_ draft: ContactDraft) async throws -> UnifiedContact { throw ProviderWriteError.unsupported }
  func updateContact(id: String, with draft: ContactDraft) async throws -> UnifiedContact { throw ProviderWriteError.unsupported }
}
```
> Bestehende read-only Conformer (AtollContactsAdapter/AppleContactsAdapter, ContactMatcher-Fakes in Tests) kompilieren weiter über die Defaults.

- [ ] **Step 2: Hub-Routing**

In `Hub.swift` ergänzen:
```swift
  /// Erstellt einen Kontakt im gewählten Konto (Apple oder Atoll).
  @discardableResult
  public func createContact(_ draft: ContactDraft, source: AccountType) async throws -> UnifiedContact {
    guard let prov = connections.first(where: { $0.account.type == source && $0.contacts != nil })?.contacts else {
      throw ProviderWriteError.notFound
    }
    return try await prov.createContact(draft)
  }
  /// Aktualisiert einen Kontakt (per UnifiedContact.id-Präfix apple:/atoll:).
  @discardableResult
  public func updateContact(id: String, with draft: ContactDraft) async throws -> UnifiedContact {
    let type: AccountType = id.hasPrefix("apple:") ? .apple : .atoll
    guard let prov = connections.first(where: { $0.account.type == type && $0.contacts != nil })?.contacts else {
      throw ProviderWriteError.notFound
    }
    return try await prov.updateContact(id: id, with: draft)
  }
  /// Erstellt eine Aufgabe im ersten schreibfähigen Apple-Todo-Konto.
  public func createTask(title: String, due: Date?, listId: String?) async throws {
    guard let todo = connections.first(where: { $0.account.type == .apple && $0.todo != nil })?.todo else {
      throw ProviderWriteError.notFound
    }
    try await todo.createTask(title: title, due: due, listId: listId)
  }
```

- [ ] **Step 3: TDD mit Fakes**

`Tests/AtollHubTests/HubContactRoutingTests.swift` — Fake `ContactsProvider` (records createContact + returns a stub) + Fake `TodoProvider` (records createTask). Teste:
- `createContact(draft, source: .atoll)` ruft nur den Atoll-Contacts-Provider.
- `updateContact(id: "apple:1", ...)` routet ans Apple-Konto.
- `createTask(...)` routet ans Apple-Todo-Konto.
- jeweils `ProviderWriteError.notFound`, wenn kein passendes Konto.
```swift
import XCTest
@testable import AtollHub

@MainActor
final class HubContactRoutingTests: XCTestCase {
  final class FakeContacts: ContactsProvider {
    var created: [ContactDraft] = []; var updated: [(String, ContactDraft)] = []
    let stub: UnifiedContact
    init(stub: UnifiedContact) { self.stub = stub }
    func contacts() async throws -> [UnifiedContact] { [] }
    func createContact(_ d: ContactDraft) async throws -> UnifiedContact { created.append(d); return stub }
    func updateContact(id: String, with d: ContactDraft) async throws -> UnifiedContact { updated.append((id, d)); return stub }
  }
  final class FakeTodo: TodoProvider {
    var created: [String] = []
    func tasks() async throws -> [UnifiedTask] { [] }
    func createTask(title: String, due: Date?, listId: String?) async throws { created.append(title) }
  }
  private func acct(_ id: String, _ t: AccountType) -> Account {
    Account(id: id, type: t, displayName: id, capabilities: [.contacts, .todo])
  }
  private var stub: UnifiedContact {
    UnifiedContact(id: "atoll:new", source: AccountRef(accountId: "atoll", type: .atoll),
                   firstName: "A", lastName: "B", emails: [], phones: [])
  }

  func test_createContact_routesToChosenSource() async throws {
    let apple = FakeContacts(stub: stub), atoll = FakeContacts(stub: stub)
    let hub = Hub()
    hub.connect(AccountConnection(account: acct("apple", .apple), contacts: apple))
    hub.connect(AccountConnection(account: acct("atoll", .atoll), contacts: atoll))
    _ = try await hub.createContact(ContactDraft(firstName: "X", lastName: "Y"), source: .atoll)
    XCTAssertEqual(atoll.created.count, 1); XCTAssertTrue(apple.created.isEmpty)
  }
  func test_updateContact_routesByIdPrefix() async throws {
    let apple = FakeContacts(stub: stub)
    let hub = Hub(); hub.connect(AccountConnection(account: acct("apple", .apple), contacts: apple))
    _ = try await hub.updateContact(id: "apple:1", with: ContactDraft(firstName: "X", lastName: "Y"))
    XCTAssertEqual(apple.updated.first?.0, "apple:1")
  }
  func test_createTask_routesToApple() async throws {
    let todo = FakeTodo()
    let hub = Hub(); hub.connect(AccountConnection(account: acct("apple", .apple), todo: todo))
    try await hub.createTask(title: "T", due: nil, listId: nil)
    XCTAssertEqual(todo.created, ["T"])
  }
}
```
> READ die realen `Account(...)`/`UnifiedContact(...)`/`AccountConnection(...)`-Inits und passe an. Beachte: `AccountConnection.init` braucht ggf. das `contacts:`-Label.

- [ ] **Step 4: Rot→Grün, volle Suite, Commit**

Run: `swift test --filter HubContactRoutingTests` (rot → grün), dann `swift test` (alle grün).
```bash
git add swift-packages/AtollHub/Sources/AtollHub/Capabilities/Providers.swift swift-packages/AtollHub/Sources/AtollHub/Hub/Hub.swift swift-packages/AtollHub/Tests/AtollHubTests/HubContactRoutingTests.swift
git commit -m "AtollHub: ContactsProvider-Schreiben + Hub routet createContact/updateContact/createTask"
```

---

## Task 4: Atoll-Kontakte reich lesen (ComHub)

**Files:** Modify `Adapters/AtollContactsAdapter.swift` (+ ggf. `AtollContactMapper` in AtollHub).

- [ ] **Step 1: Mehr Spalten lesen + reich mappen**

READ `AtollContactsAdapter.swift`. Erweitere das `select(...)` um: `birth_date, gender, addresses, languages, roles, tags, notes` (zusätzlich zu den bestehenden `id, kind, first_name, last_name, trading_name, legal_name, primary_email, emails, phones`). Erweitere die `Decodable`-Row + das Mapping (in `AtollContactMapper` falls dort, sonst inline) so, dass die neuen `UnifiedContact`-Felder gefüllt werden:
- `kind`: "organization"/"company" → `.organization`, sonst `.person`.
- `organizationName`: `trading_name ?? legal_name`.
- `addresses`: JSONB `[{street,zip/postal_code,city,region,country,label}]` → `[PostalAddress]` (Decodable-Struct; tolerant gegen fehlende Keys).
- `birthday`: `birth_date` (yyyy-MM-dd) parsen.
- `languages`/`roles`/`tags`: `TEXT[]` → `[String]`.
- `notes`: `notes`.
> Das JSONB-Adressformat (Keys) ggf. an die reale Spalte anpassen — orientiere dich an `supabase/migrations/0079_contacts_schema.sql` und der Web-`addresses`-Form. Tolerant decodieren (`try?`/optional Keys), damit fehlende Felder nicht die ganze Liste killen.

- [ ] **Step 2: Build** (macOS + iOS) — `** BUILD SUCCEEDED **` beide.
- [ ] **Step 3: Commit** — `git commit -m "ComHub: Atoll-Kontakte reich lesen (Firma/Adressen/Geburtstag/Sprachen/Rollen/Tags/Notizen)"`.

---

## Task 5: Apple-Kontakte reich lesen (ComHub)

**Files:** Modify `Apple/AppleContactsAdapter.swift` (+ ggf. `AppleContactMapper`).

- [ ] **Step 1: Mehr CNContact-Keys laden + mappen**

READ `AppleContactsAdapter.swift`. Erweitere die `keysToFetch` um `CNContactOrganizationNameKey`, `CNContactPostalAddressesKey`, `CNContactBirthdayKey`, `CNContactNoteKey` (Note ggf. ohne Entitlement leer — dann weglassen/try). Mappe:
- `organizationName`: `contact.organizationName` (nicht leer).
- `kind`: `contact.contactType == .organization ? .organization : .person`.
- `addresses`: `contact.postalAddresses` → `PostalAddress(street:…, postalCode:…, city:…, region:…, country:…, label: CNLabeledValue.localizedString(forLabel:))`.
- `birthday`: `contact.birthday?.date`.
> `CNContactNoteKey` braucht eine spezielle Entitlement (`com.apple.developer.contacts.notes`) — wenn nicht vorhanden, Notiz NICHT anfragen (sonst Fetch-Fehler). Lass `notes` für Apple leer, wenn die Entitlement fehlt.

- [ ] **Step 2: Build (beide) + Commit** — `git commit -m "ComHub: Apple-Kontakte reich lesen (Firma/Adressen/Geburtstag)"`.

---

## Task 6: Reiche Kontakt-Detailansicht (ComHub)

**Files:** Modify `Contacts/ContactDetailPane.swift`.

- [ ] **Step 1: Rich-Felder rendern**

READ `ContactDetailPane.swift`. Es zeigt heute Avatar, Name, Quellen, Mail/Anruf, E-Mails, Telefone. Ergänze (jeweils nur wenn vorhanden):
- **Firma** (wenn `contact.organizationName != nil`) + `kind`-Chip (Person/Firma).
- **Adressen** (`contact.addresses`, je `oneLine`, mit „Karte"/Copy optional — nur Anzeige).
- **Geburtstag** (`contact.birthday`, formatiert `dd.MM.yyyy`).
- **Sprachen / Rollen / Tags** (als CoChip-Reihen, wenn nicht leer).
- **Notizen** (`contact.notes`, mehrzeilig).
Nutze die bestehenden Detail-Row-/Section-Bausteine + `CoChip`. Behalte das bestehende Layout/Styling (CoHub-Look).
Oben einen **„Bearbeiten"**-Button (Stift) — Aktion via Callback `onEdit: (() -> Void)?` (in Task 8 verdrahtet); jetzt als optionalen Parameter anlegen (Default nil), Button nur zeigen wenn gesetzt.

- [ ] **Step 2: Build (beide) + Commit** — `git commit -m "ComHub: Kontakt-Detail zeigt Firma/Adressen/Geburtstag/Sprachen/Rollen/Tags/Notizen + Bearbeiten-Einstieg"`.

---

## Task 7: Kontakt-Schreiben — Adapter (Atoll + Apple) (ComHub)

**Files:** Modify `Adapters/AtollContactsAdapter.swift`, `Apple/AppleContactsAdapter.swift`, `Apple/AppleAuthorizationService.swift` (Schreibrecht).

- [ ] **Step 1: Atoll `createContact`/`updateContact` (Supabase)**

In `AtollContactsAdapter` ergänzen (mirror dem Write-Muster aus `AtollTasksAdapter`):
```swift
  func createContact(_ draft: ContactDraft) async throws -> UnifiedContact {
    struct Insert: Encodable {
      let kind: String; let first_name: String?; let last_name: String?
      let legal_name: String?; let trading_name: String?
      let primary_email: String?; let emails: [[String: String]]; let phones: [[String: String]]
      let addresses: [AddrJSON]; let languages: [String]; let roles: [String]
      let tags: [String]; let notes: String?
    }
    let row = Insert(/* aus draft bauen; person→first/last, org→legal_name=organizationName;
                       emails als [{"email": x}], phones als [{"e164": x}] */)
    let created: [AtollContactRow] = try await supabase.from("contacts").insert(row).select(Self.selectColumns).execute().value
    guard let r = created.first else { throw ProviderWriteError.invalid("insert lieferte keine Zeile") }
    return AtollContactMapper.contact(from: r, accountId: accountId)   // reale Mapper-Signatur nutzen
  }

  func updateContact(id: String, with draft: ContactDraft) async throws -> UnifiedContact {
    let rowId = SourceID.raw(from: id)
    struct Patch: Encodable { /* gleiche Felder wie Insert, optional */ }
    let updated: [AtollContactRow] = try await supabase.from("contacts").update(Patch(/* aus draft */)).eq("id", value: rowId).select(Self.selectColumns).execute().value
    guard let r = updated.first else { throw ProviderWriteError.notFound }
    return AtollContactMapper.contact(from: r, accountId: accountId)
  }
```
Definiere eine `AddrJSON: Encodable` passend zur `addresses`-Spalte. Setze `kind` als String ("person"/"organization"). Lass `created_by`/`owner_id` weg (nullable/Default). Nutze die realen Select-Spalten + Mapper-Signatur (READ die Datei; ziehe ggf. die Spaltenliste in eine `static let selectColumns` zusammen). **Wenn supabase-swift das verschachtelte JSONB nicht sauber typt**, nutze `[String: AnyJSON]`/`[AnyJSON]` wie in 5a-T4 — bevorzuge typed Encodable-Structs, sonst AnyJSON.

- [ ] **Step 2: Apple `createContact`/`updateContact` (`CNSaveRequest`)**

In `AppleContactsAdapter` ergänzen. `@preconcurrency import Contacts`. Schreibstore: `CNContactStore`. 
```swift
  func createContact(_ draft: ContactDraft) async throws -> UnifiedContact {
    let c = CNMutableContact()
    apply(draft, to: c)
    let req = CNSaveRequest(); req.add(c, toContainerWithIdentifier: nil)
    try store.execute(req)               // CNContactStore
    return AppleContactMapper.contact(/* aus c, accountId */)   // reale Signatur
  }
  func updateContact(id: String, with draft: ContactDraft) async throws -> UnifiedContact {
    let identifier = SourceID.raw(from: id)
    let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactEmailAddressesKey,
                CNContactPhoneNumbersKey, CNContactPostalAddressesKey, CNContactOrganizationNameKey] as [CNKeyDescriptor]
    guard let existing = try? store.unifiedContact(withIdentifier: identifier, keysToFetch: keys),
          let mutable = existing.mutableCopy() as? CNMutableContact else { throw ProviderWriteError.notFound }
    apply(draft, to: mutable)
    let req = CNSaveRequest(); req.update(mutable); try store.execute(req)
    return AppleContactMapper.contact(/* aus mutable */)
  }
  private func apply(_ d: ContactDraft, to c: CNMutableContact) {
    c.contactType = d.kind == .organization ? .organization : .person
    c.givenName = d.firstName; c.familyName = d.lastName
    c.organizationName = d.organizationName
    c.emailAddresses = d.emails.map { CNLabeledValue(label: CNLabelOther, value: $0 as NSString) }
    c.phoneNumbers = d.phones.map { CNLabeledValue(label: CNLabelOther, value: CNPhoneNumber(string: $0)) }
    c.postalAddresses = d.addresses.map { a in
      let p = CNMutablePostalAddress()
      p.street = a.street ?? ""; p.postalCode = a.postalCode ?? ""; p.city = a.city ?? ""
      p.state = a.region ?? ""; p.country = a.country ?? ""
      return CNLabeledValue(label: CNLabelHome, value: p)
    }
  }
```
`CNContactStore` als `nonisolated(unsafe)` halten (analog EKEventStore). `CNMutableContact` verlässt die Methode nicht roh.

- [ ] **Step 3: Kontakte-Schreibrecht**

In `AppleAuthorizationService` (oder wo `requestAccess(for: .contacts)` läuft): sicherstellen, dass **Schreib**-Zugriff (CNContactStore `requestAccess(for: .contacts)`) angefragt wird (read+write ist derselbe Scope). Falls schon vorhanden — nichts zu tun; sonst ergänzen. Entitlement `com.apple.security.personal-information.addressbook` ist vorhanden.

- [ ] **Step 4: Build (beide) + Commit** — `git commit -m "ComHub: Kontakt-Schreiben Adapter (Atoll Supabase insert/update + Apple CNSaveRequest)"`.

---

## Task 8: `ContactEditSheet` + Verdrahtung (ComHub)

**Files:** Create `Contacts/ContactEditSheet.swift`; Modify `Contacts/ContactsModuleView.swift`, `Contacts/ContactDetailPane.swift` (Callback), `Contacts/ContactsStore.swift` (reload nach Schreiben).

- [ ] **Step 1: `ContactsStore` Schreib-Durchreichen**

In `ContactsStore` ergänzen (hält `hub`-Zugriff über Aufrufer; analog CalendarStore):
```swift
  func create(_ draft: ContactDraft, source: AccountType, using hub: Hub) async {
    do { _ = try await hub.createContact(draft, source: source); await reload(using: hub) }
    catch { errors.append("create: \(error)") }      // reale Fehler-Property
  }
  func update(id: String, with draft: ContactDraft, using hub: Hub) async {
    do { _ = try await hub.updateContact(id: id, with: draft); await reload(using: hub) }
    catch { errors.append("update: \(error)") }
  }
```
> Reale `reload(using:)`/Fehler-Property prüfen (READ ContactsStore).

- [ ] **Step 2: `ContactEditSheet`**

`Contacts/ContactEditSheet.swift` — Form mit: Quelle-Picker (nur bei Erstellen: Atoll/Apple), `kind`-Picker (Person/Firma), Vor-/Nachname (Person) bzw. Firmenname (Firma), dynamische E-Mail-/Telefon-Listen (hinzufügen/entfernen), eine Adresse (Straße/PLZ/Ort/Land), Geburtstag (optional DatePicker mit Toggle), Notizen. „Sichern" `.disabled(!draft.isValid)`. Liefert `(ContactDraft, AccountType)` an `onSave`. Vorbefüllen aus einem `MergedContact` beim Bearbeiten (Quelle = Member-Quelle, fix). Nutze `#if os(macOS) .frame(minWidth:480,minHeight:560) #endif`.
```swift
import SwiftUI
import AtollHub

struct ContactEditSheet: View {
  let existing: MergedContact?
  let onSave: (ContactDraft, AccountType) -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var draft = ContactDraft()
  @State private var source: AccountType = .atoll
  // … @State spiegel-Felder oder direkt $draft.* …
  // onAppear: existing → draft füllen (kind, names, emails, phones, address, birthday, notes)
  //           + source = bevorzugt Atoll-Member, sonst Apple.
}
```
Implementiere vollständig (Form-Sektionen, dynamische Listen via `ForEach($draft.emails.indices…)` o. Helfer, Toolbar Abbrechen/Sichern). Beim Bearbeiten ist die Quelle fix (kein Picker).

- [ ] **Step 3: `ContactDetailPane` „Bearbeiten" + `ContactsModuleView` „+"**

- `ContactDetailPane`: den `onEdit`-Callback (aus Task 6) auslösen.
- `ContactsModuleView`: `@State private var editing: MergedContact?` und `@State private var showCreate = false`. Ein „+" im Header/Toolbar (`showCreate = true`). `.sheet(isPresented: $showCreate) { ContactEditSheet(existing: nil) { draft, src in Task { await store.create(draft, source: src, using: hub) } } }` und `.sheet(item: $editing) { c in ContactEditSheet(existing: c) { draft, _ in Task { await store.update(id: <member-id>, with: draft, using: hub) } } }`. `onEdit` der Detail-Pane setzt `editing = <aktueller MergedContact>`.
> Für die Update-`id` die Id des passenden Members nehmen (Atoll-Member bevorzugt, sonst Apple) — diese Id wird auch zur Quellbestimmung in `Hub.updateContact` (Präfix) genutzt. `hub` = `@Environment(Hub.self)`.

- [ ] **Step 4: Build (beide) + manueller Smoke** (Mac): „+" → Person/Firma erfassen (Atoll **und** Apple testen) → erscheint in Liste/CRM bzw. Apple Kontakte; Detail „Bearbeiten" → ändern → übernommen.

- [ ] **Step 5: Commit** — `git commit -m "ComHub: Kontakt erfassen/bearbeiten (ContactEditSheet, Quelle waehlbar)"`.

---

## Task 9: Neue Todos erfassen (ComHub)

**Files:** Create `Tasks/TaskEditSheet.swift`; Modify `Tasks/AufgabenStore.swift`, `Tasks/AufgabenModuleView.swift`.

- [ ] **Step 1: `AufgabenStore.create`**

```swift
  func create(title: String, due: Date?, listId: String?, using hub: Hub) async {
    do { try await hub.createTask(title: title, due: due, listId: listId); await reload(using: hub) }
    catch { /* optional Fehlerfeld */ }
  }
```

- [ ] **Step 2: `TaskEditSheet`** — Form: Titel (Pflicht), Fälligkeit (optional DatePicker + Toggle), Liste (Picker über die Apple-Erinnerungslisten). Die Listen kommen aus den EKCalendars (`.reminder`). Hole sie über einen lokalen `EKEventStore().calendars(for: .reminder)` (id+title), Default = keine (Standardliste). Liefert `(title, due?, listId?)`.
```swift
import SwiftUI
import EventKit
struct TaskEditSheet: View {
  let onSave: (String, Date?, String?) -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var title = ""; @State private var hasDue = false
  @State private var due = Date(); @State private var listId: String?
  private let lists: [(id: String, title: String)] = {
    EKEventStore().calendars(for: .reminder).map { ($0.calendarIdentifier, $0.title) }
  }()
  // Form + Toolbar (Sichern disabled wenn Titel leer)
}
```
> `EKEventStore().calendars(for:.reminder)` liefert nur bei erteiltem Recht etwas — sonst leere Liste, dann schreibt `createTask` in die Standardliste. OK.

- [ ] **Step 3: „+" in `AufgabenModuleView`** — im Wide-`list`-Header **und** im Compact-Toolbar (6a) einen „+"-Button + `.sheet`:
```swift
  @State private var showNew = false
  // Button { showNew = true } label: { Image(systemName: "plus") }
  // .sheet(isPresented: $showNew) { TaskEditSheet { t, d, l in Task { await store.create(title: t, due: d, listId: l, using: hub) } } }
```
Platziere den Button konsistent (Wide: in der `list`-Headerzeile neben dem Titel; Compact: zweites `ToolbarItem`).

- [ ] **Step 4: Build (beide) + Smoke** (neue Aufgabe erscheint in Liste + Apple Erinnerungen) + Commit `git commit -m "ComHub: neue Todos erfassen (TaskEditSheet -> Apple Erinnerung)"`.

---

## Task 10: Neue Kombox-Nachricht (ComHub)

**Files:** Create `Kombox/NewMessageSheet.swift`; Modify `Kombox/KomboxStore.swift`, `Kombox/KomboxModuleView.swift`.

- [ ] **Step 1: `KomboxStore` Senden an beliebigen Kontakt**

READ `KomboxStore.send(channel:body:subject:)` — es nutzt die aktuell gewählte `selectedContactId`. Ergänze eine Variante, die explizit an einen Kontakt sendet:
```swift
  /// Sendet eine neue Nachricht an einen gewählten Kontakt (für „Neue Nachricht").
  @discardableResult
  func sendNew(contactId: String, channel: KomboxChannel, body: String, subject: String?) async -> Bool {
    // gleiche Edge-Function-Invoke wie send(...), aber mit übergebenem contactId.
    // Danach: optional selectContact(contactId) + reloadConversations(), damit die
    // neue Konversation sichtbar wird.
  }
```
> Extrahiere die Invoke-Logik aus `send` (DRY) oder dupliziere minimal. `contactId` ist die rohe Atoll-`contacts.id`. Beachte: comms-outbound erwartet `contact_id` (UUID) + `channel` ("email"/"whatsapp"). Mappe `KomboxChannel.mail → "email"`, `.whatsapp → "whatsapp"`.

- [ ] **Step 2: `NewMessageSheet`** — Kontakt-Picker (Suche über die Kontakte des Hubs; nutze `hub.allContacts()` oder den vorhandenen ContactsStore — wähle einen Kontakt mit E-Mail bzw. Telefon je nach Kanal), Kanal-Picker (WhatsApp/Mail), Betreff (nur Mail), Text, „Senden". Beim Senden `store.sendNew(contactId:channel:body:subject:)`. Der `contactId` muss die **Atoll-`contacts.id`** sein — wähle daher Kontakte, die einen Atoll-Member haben (comms-outbound schlägt sonst fehl). Filtere die Auswahl auf Kontakte mit Atoll-Quelle + passendem Empfänger (E-Mail für Mail, Telefon für WhatsApp); zeige sonst einen Hinweis.
```swift
import SwiftUI
import AtollHub
struct NewMessageSheet: View {
  let contacts: [MergedContact]
  let onSend: (_ atollContactId: String, _ channel: KomboxChannel, _ body: String, _ subject: String?) -> Void
  // Picker Kontakt (mit Suche) + Kanal + (Betreff) + Text; Senden disabled bis gueltig.
}
```
> Den `atollContactId` aus dem gewählten `MergedContact` ziehen: der Atoll-Member, `SourceID.raw(from: member.id)`.

- [ ] **Step 3: „Neue Nachricht"-Button in `KomboxModuleView`** — im Header/Rail (Wide) und im Compact-Toolbar ein „square.and.pencil"-Button → `.sheet` mit `NewMessageSheet(contacts: <hub contacts>)`. Lade die Kontakte (einmalig via `hub.allContacts()` in einem `@State`), oder reuse einen vorhandenen Store.

- [ ] **Step 4: Build (beide) + Smoke** (braucht `messaging_accounts`-Zeile): neue Mail/WhatsApp an Kontakt → erscheint als ausgehende Nachricht im Thread. Commit `git commit -m "ComHub: neue Kombox-Nachricht (Kontakt waehlen, Kanal, senden)"`.

---

## Task 11: Dokumentation (Phase 7)

**Files:** Modify `apps/comhub-native/README.md`.

- [ ] **Step 1: Phase-7-Zeile**

Nach `**Phase 6a** …`:
```markdown

**Phase 7** — **Erfassen, Detail & Compose**: Adressliste sortiert nach
**Nachname, Vorname**; **reiche Kontakt-Detailansicht** (Firma, Adressen,
Geburtstag, Sprachen, Rollen, Tags, Notizen); **Kontakt erfassen/bearbeiten**
mit wählbarer Quelle (Atoll-CRM via Supabase **oder** Apple via `CNSaveRequest`);
**neue Todos** (Apple Erinnerungen, Liste wählbar); **neue Kombox-Nachricht**
(Kontakt wählen → Mail/WhatsApp → `comms-outbound`). Reine Logik getestet in
`AtollHub` (`ContactDraft`, `ContactSections`-Sort, Hub-Contact/Task-Routing).
```

- [ ] **Step 2: Commit** — `git commit -m "Docs: ComHub-README Phase 7 (Erfassen, Detail & Compose)"`.

---

## Self-Review (durchgeführt)

**1. Abdeckung der 5 Wünsche:**
- Sort Nachname,Vorname → Task 2 (+ Task 1 für `firstName`/`lastName` im Modell). ✔
- Neue Kombox-Nachricht → Task 10 (+ comms-outbound bestehend). ✔
- Neue Todos → Task 9 (+ Task 3 Hub.createTask). ✔
- Reiche Detailansicht → Tasks 1/4/5 (Daten) + Task 6 (UI). ✔
- Kontakt erfassen/ändern (Quelle wählbar) → Tasks 3 (Protokoll/Routing) + 7 (Adapter Apple+Atoll) + 8 (UI). ✔

**2. Platzhalter-Scan:** Reference-Code je Schritt + „READ + an reale Namen anpassen"-Hinweise (bewährtes Muster aus 5a/6a). Zwei dokumentierte Implementierungs-Weichen (JSONB typed vs. AnyJSON in Task 7; Apple-Note-Entitlement in Task 5). Keine „TBD".

**3. Typ-Konsistenz:**
- `ContactDraft`/`PostalAddress`/`ContactKind` (T1) ↔ Provider-Schreiben (T3/T7) ↔ `ContactEditSheet` (T8). ✔
- `UnifiedContact`/`MergedContact` Rich-Felder (T1) ↔ Mapper (T4/T5) ↔ Detail (T6). ✔
- `Hub.createContact(_:source:)`/`updateContact(id:with:)`/`createTask(...)` (T3) ↔ Stores (T8/T9) ↔ comms-outbound channel-Mapping (T10). ✔
- `SourceID.raw` (5a) für Id-Präfix-Routing wiederverwendet. ✔

**4. Verifikations-Disziplin:** Tasks 1–3 echte TDD (`swift test`, Rückwärtskompatibilität der Bestands-Tests). Tasks 4–10 build-verifiziert (macOS **und** iOS), Tasks 8/9/10 zusätzlich manueller Smoke. Konform zu superpowers:verification-before-completion.

**Offene Hinweise:** comms-outbound braucht eine `messaging_accounts`-Zeile (Senden); Apple-Note-Feld evtl. ohne Sonder-Entitlement leer; Atoll-Task-Erfassen bewusst nicht enthalten (nur Apple).

---

## Execution Handoff

**Plan gespeichert unter `docs/superpowers/plans/2026-06-03-comhub-phase7-erfassen-detail.md`. Zwei Optionen: 1. Subagent-Driven (empfohlen). 2. Inline. Welcher Ansatz?**
