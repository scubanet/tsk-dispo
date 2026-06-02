# AtollContacts — Kontakt-Pillar im ComHub mit Apple-Anreicherung

**Status:** Draft (User-Review pending)
**Date:** 2026-06-02
**Author:** Dominik Weckherlin (mit Larry / myPKA)
**Spec Owner:** Dominik
**Target:** ComHub Kontakt-Pillar (`apps/comhub-native`) + Foundation `AtollHub`
**Branch:** `comhub-phase0` → Folge-Branch `comhub-contacts`

---

## 1. Kontext & Problem

### Heutiger Zustand

Kontaktdaten leben im Atoll-OS heute an **drei Orten**:

- **Web-Addressbook** — die reifste Oberfläche: vereinte `contacts`-Tabelle, rollenbasierte Sidecars (`contact_instructor`, `contact_student`), `ContactDetailPanelV2` mit adaptiven Tabs, Merge, SavedViews, CardInbox.
- **ComHub Kontaktmodul** — im Plan vorgesehen (`docs/comhub-native-app-plan.md`), aber noch nicht gebaut (Phase 0 = nur Gerüst + `AtollHub`-Kern, macOS-Build grün).
- **AtollCard** — erzeugt Leads, die als CardInbox in den CRM-Fluss laufen.

Parallel dazu pflegt der Nutzer seine **gelebte Kontakt-Realität im Apple-Adressbuch** (macOS/iCloud) — getrennt von Atoll. Tauchspezifisches Wissen (Brevet, Anzahl Tauchgänge) ist nirgends sauber an diesen Kontakten verankert.

### Pain-Points

1. **Zwei Adressbücher:** Apple-Kontakte (privat/gelebt) und Atoll-CRM (geschäftlich) driften auseinander; keine gemeinsame Sicht.
2. **Kein Tauch-Kontext am Kontakt:** Brevet-Level, -Agentur, -Nr und Tauchgangszahl hängen nicht an der Person, mit der man tatsächlich kommuniziert.
3. **ComHub ohne Kontakt-Pillar:** Der Outlook-artige Hub kann Kombox + Kalender, aber das Kontakt-Modul fehlt — genau dort gehört die angereicherte Adressverwaltung hin.
4. **PADI-zentriert:** Bestehende Felder (`padi_level`) sind PADI-spezifisch; Multi-Agentur (SSI/CMAS/SDI/RAID) hat keine Heimat.

### Ziel

Eine **superstarke Adressverwaltung als Kontakt-Pillar im ComHub** (macOS zuerst), die das Apple-Adressbuch als Basis nimmt und mit Atoll-Tauchwissen anreichert — **alle Felder im Pillar editierbar**, Standardfelder werden **nach Apple zurückgeschrieben**, Tauchdaten leben strukturiert in Supabase und werden als sichtbarer Block in die Apple-Notiz gespiegelt.

### Nicht-Ziel (für diese Spec)

- Eigenständige Standalone-App (bewusst verworfen — keine 7. App, kein viertes Kontakt-Silo).
- Zwei-Wege-Sync der Tauchfelder als strukturierte Apple-Felder (Apple hat dafür keinen nativen Slot; nur Notiz-Spiegel).
- Google/Microsoft-Kontaktquellen (`ContactsProvider` ist anbieter-offen, aber Apple zuerst).
- iOS/iPadOS-Feinschliff (fällt aus demselben Target, eigener Politur-Pass).
- Marketing-/Newsletter-Workflows.

---

## 2. Architektur-Entscheidungen

Im Brainstorming-Dialog festgelegt:

| # | Frage | Gewählt | Begründung |
|---|-------|---------|------------|
| 1 | Form/Scope? | **ComHub-Pillar + `AtollContacts`-Fundament** | Ein Gehirn, viele Oberflächen; kein neues App-Silo |
| 2 | Apple-Verhältnis? | **Apple primär, Atoll als Overlay** | Apple bleibt kanonisch für Standard-PII |
| 3 | Editierbarkeit? | **Alle Felder im Pillar editierbar** | Der Pillar ist der eine Editor |
| 4 | Write-back Standardfelder? | **Ja, echt nach Apple (`CNSaveRequest`)** | Apple bleibt führend; kein PII-Doppelspeicher |
| 5 | Write-back Tauchfelder? | **Supabase = SSOT + Notiz-Block-Spiegel nach Apple** | Strukturiert auswertbar UND überall sichtbar |
| 6 | Tauchfelder (MVP)? | **Brevet-Level, -Agentur, -Nr, Anzahl Tauchgänge** | Schlanker, agentur-neutraler Kern |
| 7 | Join Apple ↔ Atoll? | **`ContactMatcher` über normalisierte Mail/Telefon** | Foundation existiert bereits |
| 8 | Erster Client? | **macOS zuerst** | Hauptgerät; iOS aus demselben Target |

### SSOT-Regel (verbindlich)

- **Apple Kontakte** = kanonisch für Standardfelder (Name, Telefon, Mail, Adresse, Foto, Geburtstag, Notiz).
- **Supabase** = SSOT für das Dive-Profil (`contact_dive_profile`) und die Geschäfts-CRM-Daten (Rolle, Saldo, Comms, Kurse).
- **ComHub Kontakt-Pillar** = der eine Editor über beidem; hält selbst keine eigene Wahrheit, sondern schreibt in die jeweils kanonische Quelle.

---

## 3. Datenmodell

### 3.1 Neue Tabelle: `contact_dive_profile` (Sidecar)

Agentur-neutrales Tauchprofil, hängt 1:1 an einem `contacts`-Datensatz (gleiches Sidecar-Muster wie `contact_instructor`).

```sql
create table public.contact_dive_profile (
  contact_id    uuid primary key
                references public.contacts(id) on delete cascade,
  agency        text,         -- 'PADI' | 'SSI' | 'CMAS' | 'SDI' | 'RAID' | 'Andere'
  level         text,         -- agentur-neutral: 'OWD','AOWD','Rescue','DM','Instructor', ...
  cert_number   text,         -- Brevet-Nr
  total_dives   integer check (total_dives is null or total_dives >= 0),
  note_block_hash text,       -- Hash des zuletzt nach Apple geschriebenen Notiz-Blocks (Idempotenz)
  updated_at    timestamptz not null default now(),
  updated_by    uuid references auth.users(id)
);

alter table public.contact_dive_profile enable row level security;

-- Lese-/Schreibrecht wie die übrigen Kontakt-Sidecars (an contacts-Policy spiegeln)
create policy contact_dive_profile_rw on public.contact_dive_profile
  for all using ( /* gleiche Sichtbarkeit wie public.contacts */ true )
  with check ( true );
```

> Policy-Platzhalter `true` wird in der Implementierung an die bestehende `contacts`-RLS gekoppelt (gleiche Sichtbarkeit, kein eigenes Sichtbarkeitsmodell).

### 3.2 Per-Gerät-Link (optionaler Cache): `contact_apple_link`

`CNContact.identifier` ist **nicht gerätestabil**. Der `ContactMatcher` löst die Zuordnung primär über normalisierte Mail/Telefon. Dieser Cache vermeidet wiederholtes Matchen pro Gerät:

```sql
create table public.contact_apple_link (
  contact_id       uuid not null references public.contacts(id) on delete cascade,
  apple_identifier text not null,
  device_tag       text not null,   -- z.B. 'mac-studio', 'iphone-15'
  linked_at        timestamptz not null default now(),
  primary key (contact_id, apple_identifier, device_tag)
);
```

### 3.3 Level-Mapping (Folge-Migration, nicht blockierend)

Bestehende `padi_level`-Werte (`contact_instructor.padi_level`, `instructors.padi_level`) werden nach `contact_dive_profile` als `agency='PADI'` + agentur-neutrales `level` gemappt. Mapping-Tabelle (PADI → neutral) lebt in der Migration; Quelle bleibt vorerst unangetastet (Backfill, kein Drop).

---

## 4. Sync-Architektur

### 4.1 Lese-Pfad

1. ComHub liest die macOS-Kontakte über `Contacts.framework` (`CNContactStore`).
2. App-Adapter zieht Rohfelder aus `CNContact` und ruft `AppleContactMapper.contact(...)` → `UnifiedContact` (`id = "apple:<identifier>"`). **Existiert bereits** in `AtollHub/Mapping/AppleMappers.swift`.
3. `ContactMatcher` verknüpft `apple:<id>` mit einem `contacts`-Datensatz über `ContactKey` (normalisierte Mail/Telefon).
4. Supabase liefert für den Match das `contact_dive_profile` + CRM-Daten (PostgREST, RLS-konform); Comms live via Realtime (`contact_events`).
5. Der Pillar zeigt **eine verschmolzene Karte**: Apple-PII + Tauchprofil + CRM.

### 4.2 Schreib-Pfad — Standardfelder

- Edit im Pillar → mutable `CNMutableContact` → `CNSaveRequest`. Apple bleibt kanonisch.
- Kein Doppelspeichern der PII in Supabase; dort nur der Match-Schlüssel (+ optionaler Lese-Cache).
- Konflikt: Apple gewinnt beim nächsten Lesen (last-write-from-Apple). ComHub-Edits gehen ausschließlich nach Apple.

### 4.3 Schreib-Pfad — Tauchfelder

- Edit im Pillar → Upsert in `contact_dive_profile` (Supabase = SSOT).
- Zusätzlich: ComHub rendert eine kompakte Dive-Summary und schreibt sie **als markierten Block in die Apple-Notiz** (siehe §6). Nur dieser Block wird ersetzt; der restliche Notiztext bleibt unberührt.
- Der Notiz-Spiegel ist **write-only** (Atoll → Apple). Supabase bleibt führend; die Apple-Notiz wird nicht zurückgeparst (kein Round-trip-Risiko).

---

## 5. Matching & Merge

- **Schlüssel:** `ContactKey` (vorhanden) aus normalisierter Mail + Telefon (E.164).
- **Matcher:** `ContactMatcher` (vorhanden) liefert Kandidaten + Confidence.
- **Verschmolzene Karte:** Apple-PII (führend) + Atoll-Overlay; bei mehreren Treffern Auswahl-/Merge-Dialog.
- **Fallunterscheidung:**
  - *Nur in Apple:* Beim Erfassen eines Brevets wird ein schlanker `contacts`-Datensatz erzeugt + `contact_dive_profile` + `contact_apple_link`.
  - *Nur im CRM:* Optional „In Apple anlegen" → `CNSaveRequest` erzeugt den Apple-Kontakt, Link wird gesetzt.
  - *Beide:* Match, eine Karte.
- **Dedupe:** Bestehende Merge-Logik des Web-Addressbooks als Referenz; im Pillar leichtgewichtiger Merge-Vorschlag.

---

## 6. Notiz-Block-Format (Apple-Spiegel)

Idempotent, markiert, nur der eigene Block wird ersetzt:

```
— Atoll Dive —
Brevet: AOWD (PADI) · Nr 1234567
Tauchgänge: 142
Stand: 2026-06-02
— Ende Atoll Dive —
```

- Erkennung über die beiden Marker-Zeilen (regex-sicher).
- `note_block_hash` in `contact_dive_profile` verhindert unnötige Schreibvorgänge (nur schreiben, wenn sich der gerenderte Block ändert).
- Existiert kein Block, wird er am Ende der Notiz angehängt; existiert er, wird exakt der Bereich zwischen den Markern ersetzt.

---

## 7. Apple-Integration & Berechtigungen

- **Framework:** `Contacts` (`CNContactStore`, `CNContact`, `CNMutableContact`, `CNSaveRequest`).
- **Capability:** Der App-Adapter implementiert `ContactsProvider` aus `AtollHub` (Protokoll vorhanden; Paket bleibt Apple-frei, der Adapter kennt `CNContact`).
- **Entitlement (macOS):** `com.apple.security.personal-information.addressbook`.
- **Usage-String:** `NSContactsUsageDescription` (DE/EN) — erklärt Lese- und Schreibzugriff.
- **Auth:** `CNContactStore.requestAccess(for: .contacts)`; ohne Schreibrecht degradiert der Pillar auf read-only-Overlay (Tauchdaten nur in Supabase).

---

## 8. UI — Kontakt-Pillar im ComHub

- **Layout:** `NavigationSplitView` 3-spaltig (Modul-Sidebar | Kontaktliste | Detail), iOS kollabiert zu Stack. Konsistent mit Kombox/Kalender.
- **Liste:** Apple-Kontakte als Basis, Atoll-Badge (Brevet-Level/Agentur) wo gematcht; Suche, Filter „mit Tauchprofil / ohne".
- **Detail (verschmolzene Karte):**
  - Standardfelder editierbar (Inline-Edit → `CNSaveRequest`).
  - Sektion „Tauchen": Agentur, Level, Brevet-Nr, Anzahl Tauchgänge (Upsert → Supabase + Notiz-Spiegel).
  - CRM-Sektion (read-mostly): Rolle, Saldo, letzte Comms, Kurse — Tiefenlinks ins Web/andere Pillars.
- **Neuer Kontakt:** im Pillar anlegen → schreibt nach Apple + (bei Tauchdaten) Supabase.
- **Design:** `AtollDesign` (Glass-Theme, BrandColors) — konsistent mit AtollCal/AtollCard.

---

## 9. Foundation-Wiederverwendung (`AtollHub`)

| Baustein | Status | Aktion |
|---|---|---|
| `UnifiedContact`, `ContactKey`, `ContactMatcher` | vorhanden | nutzen |
| `AppleContactMapper` | vorhanden | nutzen (ggf. Adresse/Foto ergänzen) |
| `ContactsProvider` (Capability) | Protokoll vorhanden | Apple-Adapter in der App implementieren |
| Dive-Profil-Typ (`DiveProfile`) | neu | in `AtollHub` als anbieter-neutraler Typ |
| Notiz-Block-Renderer/-Parser | neu | reine, unit-testbare Hilfe in `AtollHub` |

---

## 10. Phasen / Meilensteine

| Phase | Inhalt | Aufwand |
|---|---|---|
| **0 — Schema** | `contact_dive_profile` + `contact_apple_link` + RLS; `DiveProfile`-Typ in AtollHub | ~2–3 Tage |
| **1 — Lesen** | Contacts-Permission, Apple-Adapter (`ContactsProvider`), Liste + verschmolzene Detailkarte (read-only) | ~1 Woche |
| **2 — Standard-Write-back** | Inline-Edit der Standardfelder → `CNSaveRequest` | ~3–4 Tage |
| **3 — Tauchprofil** | Edit Agentur/Level/Nr/#TG → Supabase-Upsert + Notiz-Block-Spiegel | ~3–4 Tage |
| **4 — Matching/Merge** | Match-UI, nur-Apple/nur-CRM-Fälle, Dedupe-Vorschlag | ~1 Woche |
| **5 — Politur** | Filter, Suche, iOS-Feinschliff, `padi_level`-Backfill | laufend |

→ **MVP** (macOS · lesen + Standard-Write-back + Tauchprofil mit Notiz-Spiegel) realistisch in **~3 Wochen**.

---

## 11. Tests

- **AtollHub (rein, `swift test`):** `ContactMatcher` (Treffer/Confidence), `AppleContactMapper`-Round-trip, Notiz-Block-Renderer **idempotent** (zweimal schreiben = keine Änderung), Block-Ersatz erhält Fremdtext.
- **Integration:** `CNSaveRequest`-Write-back (Mock-Store), Supabase-Upsert + `note_block_hash`-Kurzschluss.
- **RLS:** `contact_dive_profile` nur sichtbar wie `contacts`.
- **Berechtigung:** Degradation auf read-only ohne Contacts-Schreibrecht.

---

## 12. Risiken / offene Fragen

- **Foto/Adresse im Mapper:** `AppleContactMapper` mappt heute Name/Mail/Telefon; Adresse + Foto für die Karte ergänzen (klein).
- **`padi_level`-Backfill:** Mapping-Tabelle PADI → neutral muss vollständig sein (Cleanup `0087` als Referenz).
- **Notiz-Hoheit:** Falls der Nutzer den Atoll-Block in Apple manuell editiert, gewinnt beim nächsten Schreiben Supabase (Block wird überschrieben) — bewusst so.
- **Multi-Device-Identifier:** `contact_apple_link` ist nur Cache; Wahrheit bleibt der Matcher.

---

## 13. Definition of Done (MVP)

- macOS-ComHub zeigt Apple-Kontakte als Pillar, gematcht mit Atoll.
- Standardfelder editierbar und nach Apple zurückgeschrieben.
- Tauchprofil (Agentur, Level, Nr, #TG) editierbar, in Supabase gespeichert, als Notiz-Block in Apple sichtbar.
- `swift test` grün (Matcher, Mapper, Notiz-Block idempotent).
- RLS verifiziert.
