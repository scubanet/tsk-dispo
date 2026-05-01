# TSK ZRH Dispo-App — Design-Spezifikation

**Status**: Design freigegeben (in Arbeit), Implementierung nicht begonnen
**Erstellt**: 30. April 2026
**Autor**: Dominik Weckherlin (Course Director, TSK ZRH) zusammen mit Claude
**Codename**: TSK Dispo
**Pitch-Domain**: `https://dispo.course-director.ch`

---

## 1. Executive Summary

Eine Cross-Plattform-App (iOS, Mac, Web) ersetzt die heutige Excel-Datei
`2026 TL_DM Abrechnung TSK ZRH 2026.xlsx` als zentrale Wahrheitsquelle für
Kursplanung, Instructor-Dispo, Skill-Matrix und Vergütungsabrechnung der
Tauchsport Käge Zürich (TSK ZRH).

Die App wird als **Pitch-Prototyp** für den TSK-Inhaber gebaut — Ziel ist nicht
eine produktiv-skalierende Plattform am Tag 1, sondern eine **demo-fähige, real
verwendete Version** mit 3–5 ausgewählten Test-Loginern (Soft-Live), die TSK
nach Vorlage davon überzeugt, das Tool zu adoptieren.

Visuelle Sprache: **Apple-Style Liquid Glass**, übernommen aus dem bereits
existierenden Blue-Horizon-CRM-Mockup (Claude Design Bundle).

**Kern-Features in v1:**
- Dispatcher-Sicht: Kursplanung 2026 mit Konflikt-Erkennung, Skill-Match-Vorschlägen, Pool-Belegung
- Instructor-Sicht: Eigene Einsätze, Live-Saldo mit Bewegungs-Journal, Verfügbarkeit eintragen
- Vergütungs-Engine: Automatische Stunden- und Saldo-Berechnung pro Kursart × Rolle, transparent dokumentiert
- Excel-Import: 4-stufiger interaktiver Wizard für einmaliges Onboarding
- WhatsApp-Integration (leichtgewichtig): Deep-Links zur bestehenden Gruppe, vorgefüllte Nachrichten
- Wöchentlicher Excel-Export als Backup und Buchhaltungs-Brücke

**Timeline**: 6 Wochen + 1 Woche Puffer bis Pitch-fähig.

**Kosten v1**: ~CHF 1.25/Monat (nur Domain). Free-Tiers von Vercel, Supabase, Resend reichen.

---

## 2. Kontext & Ziele

### 2.1 Ausgangslage

TSK ZRH pflegt heute alle Dispo- und Abrechnungsdaten in einer einzelnen
Excel-Datei mit folgender Struktur:

| Sheet | Zweck | Größe |
|---|---|---|
| 1 Kursplanung | Alle Kurse 2026 mit Datum, Typ, Instructor, Notizen | ~215 Zeilen |
| 2 Hallenbad | Pool-Belegungs-Kalender Möösli + Langnau | 403 Spalten |
| 3 (Kurs-)Entschädigungen | Vergütungssätze pro Kursart × Rolle | ~25 Zeilen |
| 4 SkillMatrix | Personen × Skills (35 Specialties) | ~75 × 35 |
| 5 Ratios | PADI-Verhältnisse pro Kursart | klein |
| 6 Kontakte | Email/Telefon der Instructors | ~70 |
| 7 Einkaufskonditionen | Shop-Konditionen | klein |
| 8 Zusammenfassung | Saldo-Übersicht aller Personen | ~75 |
| 9 Einstellungen | Stundensätze, Kurstyp-Liste | klein |
| 75× Personen-Sheets | Persönliches Konto mit Lauf-Saldo pro TL/DM | je ~60 Zeilen |

**Schmerzpunkte**:
- Pflege-Aufwand: ~75 individuelle Personen-Sheets, manuell synchron zu halten
- Kein Mobile-Zugriff für Instructors — Updates kommen via WhatsApp und Email
- Keine Konflikt-Erkennung (Doppelbuchungen passieren manuell)
- Kein Skill-Filter beim Planen (manuelle Suche in Matrix)
- Saldo-Berechnung durch Excel-Formeln, schwer auditierbar
- Pool-Belegung in einem unhandlichen Format (403 Spalten)

### 2.2 Ziele

**Primärziel**: Glaubwürdiger Pitch an TSK-Inhaber, der zur Adoption führt.

**Sekundärziel**: Persönliches produktives Tool für Dominik, das die App auch
ohne TSK-Adoption sinnvoll macht (Fall 2 in Sektion 13).

**Nicht-Ziel v1**: Volle Multi-Mandanten-Plattform, App-Store-Präsenz, native
iOS/Mac-Apps, Buchhaltungs-Vollintegration.

### 2.3 Erfolgskriterien

- Dispatcher (Dominik) kann einen Kurs anlegen, einen TL/DM zuweisen, der TL/DM
  bekommt automatisch eine Email-Notification und sieht den Einsatz in seiner App.
- Saldo-Validierung nach Excel-Import: Differenz zur Excel-Realität < CHF 50
  pro Person für mind. 90% der Instructors.
- Pitch-Demo dauert 10–15 Minuten und zeigt alle Kern-Features ohne Bugs.
- Mind. 3 Test-Instructors haben sich eingeloggt und die App produktiv für
  ≥ 2 Wochen verwendet, bevor der Pitch stattfindet.

---

## 3. Architektur

### 3.1 Stack-Übersicht

```
┌──────────────────────────────────────────────────────────┐
│   FRONTEND (PWA)                                         │
│   React 18 + Vite + reines CSS (Blue-Horizon-Stil)       │
│   Hosting: Vercel EU-Edge                                │
│   Custom Domain: dispo.course-director.ch                │
│                                                          │
│   Geteilte Routen (Inhalt rolle-abhängig gefiltert):     │
│   /heute       Dashboard (Dispatcher: alles · TL/DM: meins) │
│   /kalender    Wochen/Monatsansicht                      │
│                                                          │
│   Nur Dispatcher:                                        │
│   /kurse       Kursliste 2026 (Master-Detail)            │
│   /tldm        TL/DM-Liste + Detail                      │
│   /skills      Skill-Matrix                              │
│   /pool        Hallenbad Möösli/Langnau                  │
│   /saldi       Übersicht aller Saldi                     │
│   /einstellungen  Vergütungssätze, Import, User          │
│                                                          │
│   Nur Instructor:                                        │
│   /einsaetze   Meine Einsätze 2026                       │
│   /saldo       Mein Saldo + Journal                      │
│   /profil      Mein Profil + Verfügbarkeit               │
└──────────────────────┬───────────────────────────────────┘
                       │   HTTPS / WebSocket
┌──────────────────────┴───────────────────────────────────┐
│   SUPABASE MANAGED (EU-Frankfurt)                        │
│   Bestehendes Projekt: axnrilhdokkfujzjifhj.supabase.co  │
│                                                          │
│   ┌──────────────┐  ┌─────────────┐  ┌───────────────┐   │
│   │   Postgres   │  │    Auth     │  │   Realtime    │   │
│   │  (11 Tabellen│  │ (MagicLink) │  │ (WebSocket)   │   │
│   │   + RLS)     │  │             │  │               │   │
│   └──────────────┘  └─────────────┘  └───────────────┘   │
│                                                          │
│   ┌────────────────────┐  ┌──────────────────────────┐   │
│   │  Edge Functions    │  │   Storage                │   │
│   │  - excel-import    │  │  - Excel-Backups         │   │
│   │  - weekly-export   │  │  - Avatare               │   │
│   │  - email-notif     │  │                          │   │
│   └────────────────────┘  └──────────────────────────┘   │
└──────────────────────────────────────────────────────────┘
                       │
┌──────────────────────┴───────────────────────────────────┐
│   EMAIL (Resend, EU-Region)                              │
│   Sender: no-reply@course-director.ch                    │
│   3.000 Emails/Monat free, mehr als ausreichend          │
└──────────────────────────────────────────────────────────┘

                       Migrationspfad v3 (falls TSK kauft):
                       ↓
                       Self-hosted Supabase auf Schweizer
                       Hoster (z.B. Hostinger VPS mit
                       Docker-Compose, oder Infomaniak)
```

### 3.2 Rollen

| Rolle | Sieht | Kann ändern |
|---|---|---|
| **Dispatcher** (Dominik) | Alles | Alles |
| **Instructor** (TL/DM) | Alle Kurse + alle Profile (Name/Level/Avatar) + eigenen Saldo | Eigene Verfügbarkeit, eigenes Profil |
| **Owner/Buchhaltung** | (v2) Alles read-only | Nichts |

Rollen-Detection: nach Magic-Link-Login wird `auth.uid()` über
`instructors.auth_user_id` einer Instructor-Zeile zugeordnet. Das Feld
`instructors.role` (`'dispatcher' | 'instructor'`) bestimmt die Navigation.

### 3.3 Datenachsen

Drei logische Module:
- **People-Achse**: instructors, skills, instructor_skills, availability
- **Dispo-Achse**: course_types, courses, course_assignments, pool_bookings
- **Finanz-Achse**: comp_rates, comp_units, account_movements

---

## 4. Datenmodell

### 4.1 Entitäten und Beziehungen

```
auth.users  ←──┐  (Supabase managed)
               │
            instructors  (1:N → course_assignments, account_movements,
                              instructor_skills, availability)
               ├─ id, name, padi_nr, padi_level, email, color, active
               ├─ opening_balance_chf (Übertrag aus 2025)
               ├─ auth_user_id (NULL bis Login eingerichtet)
               └─ role ('dispatcher' | 'instructor' | 'owner')

skills        (M:N via instructor_skills)
   └─ id, code, label, category

instructor_skills
   └─ instructor_id × skill_id  (PK composite)

availability  (Verfügbarkeit/Abwesenheit)
   └─ id, instructor_id, from_date, to_date, type, note

course_types  (Lookup)
   ├─ id, code, label
   ├─ theory_units, pool_units, lake_units
   ├─ ratio_pool, ratio_lake
   └─ has_elearning, notes

courses
   ├─ id, type_id → course_types
   ├─ title, status (sicher/evtl/cxl)
   ├─ start_date, additional_dates[] (jsonb)
   ├─ num_participants, location, info, notes
   ├─ created_by → instructors
   └─ created_at, updated_at

course_assignments
   ├─ id
   ├─ course_id × instructor_id
   ├─ role ('haupt' | 'assist' | 'dmt')
   ├─ confirmed (boolean)
   ├─ assigned_for_dates[] (jsonb — welche Daten ist die Person dabei?)
   └─ created_at, updated_at

pool_bookings
   ├─ id, date, time_from, time_to
   ├─ location ('mooesli' | 'langnau')
   └─ course_id → courses (NULL = blockiert)

comp_rates
   └─ id, padi_level, hourly_rate_chf, valid_from, valid_to

comp_units
   ├─ id, course_type_id × role
   └─ theory_h, pool_h, lake_h, total_h

account_movements   (immutables Journal — Saldo = SUM dieser Tabelle)
   ├─ id, instructor_id, date, amount_chf
   ├─ kind ('vergütung' | 'übertrag' | 'korrektur')
   ├─ ref_assignment_id (NULL erlaubt)
   ├─ description
   ├─ breakdown_json (Audit-Spur, siehe Sektion 8)
   ├─ rate_version
   └─ created_at, created_by → instructors

import_logs
   ├─ id, source_filename, started_at, finished_at, status
   └─ summary_json (was wurde geschrieben, was übersprungen)
```

### 4.2 Wichtige Design-Entscheidungen

#### 4.2.1 Saldo als immutables Ledger
Der Saldo wird **nicht als Feld am Instructor gespeichert** und überschrieben.
Stattdessen wird jede Bewegung als eigene Zeile in `account_movements` geschrieben,
der Saldo wird zur Laufzeit als `SUM(amount_chf)` berechnet. Vorteile:
- Buchhaltungs-Standard (Audit-Spur jeder Veränderung)
- Korrekturen sind transparent (eigene Zeile mit Begründung)
- Performance unkritisch bei TSK-Volumen (~75 × ~30 Bewegungen/Jahr = ~2k Zeilen)

#### 4.2.2 `comp_units` als Tabelle, nicht als Code
Die Stunden pro Kursart × Rolle (z.B. AOWD haupt: 14.5h, AOWD assist: 14.5h)
liegen als Datenbank-Zeilen, nicht als Hardcoded-Logik. Ändert TSK den
Zuschnitt, klickt das Dominik in den Einstellungen, ohne dass Code-Releases nötig sind.

#### 4.2.3 `additional_dates[]` als JSON-Array
Excel-Kurse haben oft 1–4 Termine (z.B. OWD über zwei Wochenenden).
Eine separate `course_dates`-Tabelle wäre normalisierter, aber für ~215
Kurse/Jahr Overkill. JSON-Array ist pragmatischer und SQL-abfragbar.

#### 4.2.4 Pool-Booking als eigene Entität
Pool-Slots können zu einem Kurs gehören oder unabhängig blockiert sein
(Vereinstauchen, Privattauchen). Daher eigene Tabelle mit optionalem
`course_id`-Foreign-Key.

#### 4.2.5 Skills als M:N-Tabelle, nicht als Spalten
Excel-SkillMatrix hat 35 Boolean-Spalten am Instructor. SQL-Anti-Pattern.
Wir normalisieren in `skills` × `instructor_skills`. Vorteile:
- Beliebige neue Skills hinzufügbar ohne Schema-Änderung
- Effiziente Abfragen ("Wer kann DRY und EAN?")
- Audit-Spur per Skill-Zuweisung möglich

#### 4.2.6 Saldo-Privatsphäre via RLS
Instructors sehen **nur eigene** `account_movements`, nicht die der Kollegen.
Aktueller Excel-Zustand (alle sehen alles) wird als historisch gewachsen,
nicht als Anforderung interpretiert.

### 4.3 Indizes (Performance-relevant)

```sql
CREATE INDEX idx_courses_start_date ON courses(start_date);
CREATE INDEX idx_courses_status ON courses(status);
CREATE INDEX idx_assignments_instructor ON course_assignments(instructor_id);
CREATE INDEX idx_assignments_course ON course_assignments(course_id);
CREATE INDEX idx_movements_instructor ON account_movements(instructor_id, date);
CREATE INDEX idx_pool_date_loc ON pool_bookings(date, location);
CREATE INDEX idx_instructor_skills_instr ON instructor_skills(instructor_id);
CREATE INDEX idx_instructor_skills_skill ON instructor_skills(skill_id);
```

---

## 5. App-Bereiche & Navigation

Eine Codebase, zwei Sichten — automatisch je nach Login-Rolle.

### 5.1 Navigation Dispatcher

| Icon | Titel | Inhalt | Status |
|---|---|---|---|
| 🏠 | Heute | Hero-Tile · KPI-Cards · Sessions-Timeline · "Aufmerksamkeit"-Rail | Übernommen aus Blue Horizon |
| 📅 | Kalender | Wochen-/Monatsansicht aller Kurse + Pool-Layer | NEU |
| 📘 | Kurse | Master-Liste 200+ Kurse 2026 → Detail (Tabs: Übersicht / Teilnehmer / Notizen / Vergütung) | Master-Detail wie Blue Horizon |
| 👥 | TL/DM | Master-Liste aller Instructors → Detail (Tabs: Übersicht / Skills / Einsätze / Saldo / Verfügbarkeit) | Master-Detail wie Blue Horizon |
| 🧩 | Skill-Matrix | Kreuztabelle Personen × Skills, filterbar, Bulk-Edit | NEU |
| 🌊 | Pool | Wochenkalender Möösli + Langnau als zwei Lanes | NEU |
| 💰 | Saldi | Liste aller Instructors mit Live-Saldo → Klick = Bewegungs-Journal | NEU |
| ⚙️ | Einstellungen | Vergütungssätze · Comp-Units · Excel-Import · User-Login einrichten · Akzent | NEU |

### 5.2 Navigation Instructor

| Icon | Titel | Inhalt |
|---|---|---|
| 🏠 | Heute | Mein heutiger/kommender Einsatz, Mini-Kalender, Saldo-Mini |
| 📋 | Meine Einsätze | Alle meine zugewiesenen Kurse 2026 als Liste + Kalender |
| 💰 | Mein Saldo | Live-CHF prominent oben, darunter Bewegungs-Journal mit Kurs-Verlinkung |
| 👤 | Mein Profil | Skills (read-only), Verfügbarkeit eintragen, Avatar/Mail |

### 5.3 Visuelle Sprache (übernommen aus Blue Horizon)

- **Wallpaper** mit Radial-Gradient-Blobs in Akzentfarben
- **Statusbar** oben (echte Uhrzeit, Symbole)
- **Topbar** mit Title + Subtitle ("Heute · Donnerstag, 30. April · 12 Kurse diese Woche")
- **Tweak-Panel** (Schraubenschlüssel oben rechts): Dark/Light · Akzent · Sidebar↔Tabbar
- **Liquid Glass** durchgehend (`backdrop-filter: blur(36px) saturate(180%)`, Specular-Highlight, Hairlines)
- **Akzentfarben wählbar**: Ocean Blue (#0A84FF, default), Teal, Reef, Coral, Sunset
- **Typografie**: SF Pro System-Stack, Letter-Spacing -0.01em bis -0.025em
- **Form-Sprache**: Pill-Buttons, Card-Radius 14/20/26px, Avatare mit Gradient-Hintergrund
- **Komponenten-Bibliothek**: Avatar, StatusBar, Sidebar, Topbar, Sheet, Chips, Segmented Control, Progress, Timeline, Tile-Now

### 5.4 Was bewusst NICHT in v1 ist

- ❌ Kunden/Teilnehmer als eigene Entität (Slice D — v2)
- ❌ Guru-Bezüge / Shop-Verrechnung (Slice C — v2)
- ❌ Boote, Equipment, Tauchplätze als eigene Entitäten
- ❌ Push-Notifications via APN (Email reicht)
- ❌ Abrechnungsperioden / Monatsabschluss-Workflow
- ❌ Bilingual DE/EN (nur Deutsch)

---

## 6. Datenfluss & Berechtigungen

### 6.1 Login-Flow

```
1. User tippt Email auf /login
2. Supabase Auth schickt Magic-Link via Resend
3. User klickt Link → Session-Cookie gesetzt
4. App holt JWT, liest auth.uid()
5. Lookup: instructors.auth_user_id = uid
6. Role bestimmt (dispatcher / instructor)
7. Korrekte Navigation wird geladen
```

Beim **erstmaligen Login**: Dispatcher legt vorher in
**Einstellungen → User** fest, welche Email zu welchem Instructor gehört.
Beim ersten Klick wird die `auth_user_id` automatisch verknüpft.

### 6.2 Row-Level-Security (Übersicht)

| Tabelle | Dispatcher | Instructor |
|---|---|---|
| `courses` | r/w alle | r alle |
| `course_assignments` | r/w alle | r eigene + Kollegen auf demselben Kurs |
| `instructors` | r/w alle | r alle (Public-Felder) · w nur eigenes Profil |
| `skills`, `instructor_skills` | r/w alle | r alle |
| `availability` | r alle, w alle | r/w nur eigene Einträge |
| `account_movements` | r/w alle | r **nur eigene** |
| `comp_rates`, `comp_units` | r/w | r only |
| `pool_bookings` | r/w alle | r alle |

### 6.3 Schlüssel-Flows

#### Flow A — Dispatcher legt Kurs an

1. UI: Sheet öffnet, Kurstyp + Datum + Instructor wählen
2. Bei Instructor-Auswahl: App schlägt qualifizierte + freie Personen vor
   (Skill-Filter + Verfügbarkeits-Check + Konflikt-Erkennung)
3. Speichern → INSERT in `courses` + `course_assignments`
4. Postgres-Trigger berechnet Vergütung (siehe Sektion 8)
5. Realtime-Channel pingt App des betroffenen Instructors
6. Edge Function schickt Email-Notification

#### Flow B — Konflikt-Erkennung
Bei Zuweisung: SQL-Abfrage prüft, ob der Instructor an diesem Datum
bereits einem anderen Kurs zugewiesen ist. Wenn ja → **weiche Warnung**
(orange Banner), nicht hart blockieren. Manchmal ist eine Doppelbelegung
gewollt.

#### Flow C — Skill-Match-Vorschläge
Bei Anlegen eines Kurses Typ X:
```sql
SELECT i.* FROM instructors i
JOIN instructor_skills is ON is.instructor_id = i.id
WHERE is.skill_id IN (required_skills_for_X)
  AND i.padi_level IN (allowed_levels_for_X)
  AND NOT EXISTS (
    SELECT 1 FROM course_assignments ca
    JOIN courses c ON c.id = ca.course_id
    WHERE ca.instructor_id = i.id
      AND <overlap-check>
  )
ORDER BY i.last_assigned_date ASC  -- weniger belastete zuerst
LIMIT 5
```

#### Flow D — Saldo-Berechnung
View-basiert, immer aktuell:
```sql
CREATE VIEW v_instructor_balance AS
SELECT
  instructor_id,
  SUM(amount_chf) AS balance_chf,
  MAX(date) AS last_movement_date
FROM account_movements
GROUP BY instructor_id;
```

### 6.4 Realtime

Supabase pingt offene Apps via WebSocket bei Datenänderungen,
RLS-aware (nur sichtbare Änderungen). Kein manuelles F5 nötig.

### 6.5 Email-Benachrichtigungen v1

Drei Trigger:
- ✉️ Neuer Einsatz zugewiesen → Instructor (mit "In WhatsApp ankündigen"-Link für Dispatcher)
- ✉️ Einsatz storniert/verschoben → Instructor
- ✉️ Magic-Link-Login → User (Standard, von Supabase)

---

## 7. Excel-Import (4-stufiger Wizard)

### 7.1 Stufe 1 — Hochladen & Vorprüfung
Datei wird in Supabase Storage hochgeladen, Edge Function liest mit ExcelJS,
gibt Vorschau zurück:
```
✓ 84 Sheets erkannt
✓ 215 Kurszeilen gefunden in "1 Kursplanung"
✓ 75 Instructors gefunden in "8 Zusammenfassung"
⚠ 12 Status-Werte uneinheitlich
⚠ 8 Kurstyp-Codes uneinheitlich
⚠ ~23 unklare Instructor-Namen in Kursplanung
```

### 7.2 Stufe 2 — Mehrdeutigkeiten auflösen
Drei Sub-Schritte (interaktiv):
- **Kurstyp-Mapping** (Excel-Code → DB-course_type, Auto-Match wo möglich)
- **Instructor-Namens-Auflösung** (z.B. "DMT Diego" → Diego Stohrer / Daniele Toto Brocchi auswählen)
- **Status-Normalisierung** (sicher/evtl/cxl, automatisch trim+lowercase)

Mappings werden in `import_mappings`-Tabelle gespeichert für Re-Import.

### 7.3 Stufe 3 — Dry-Run-Vorschau
Zusammenfassung mit allen geplanten Schreib-Operationen + Liste der ignorierten
Zeilen mit Begründung. Letzte Möglichkeit zum Abbruch.

### 7.4 Stufe 4 — Import + Validierung
- Postgres-Transaktion: alles oder nichts
- Excel-Datei wird in Supabase Storage als Backup mit Zeitstempel archiviert
- Saldo-Vergleichs-Report (App ↔ Excel)
- `import_logs`-Eintrag mit `summary_json`

### 7.5 Was importiert wird

| Aus Excel | Wohin |
|---|---|
| 9 Einstellungen | `comp_rates` |
| 3 (Kurs-)Entschädigungen | `course_types` + `comp_units` |
| 8 Zusammenfassung | `instructors` + `account_movements` (Eröffnung) |
| 4 SkillMatrix | `skills` + `instructor_skills` |
| 6 Kontakte | Email/Telefon in `instructors` ergänzen |
| 1 Kursplanung | `courses` + `course_assignments` |

### 7.6 Was NICHT importiert wird

- ❌ Die 75 Personen-Sheets — abgeleitete Daten, werden durch Comp-Engine neu erzeugt
- ❌ Sheet "2 Hallenbad" (Pool startet **leer**, wird ab Go-Live frisch gepflegt)
- ❌ Sheet "5 Ratios" — nur informativ, gehört nicht in DB
- ❌ Sheet "7 Einkaufskonditionen" — gehört zu Slice C, v2

### 7.7 Soft-Validierung
Saldo-Differenzen App ↔ Excel sind **Hinweise**, keine Blocker. Differenzen
sind erwartet (manuelle Excel-Buchungen, die nicht aus Kursen stammen).

### 7.8 Idempotenz
Re-Import erkennt vorhandene Datensätze per natural key (Kurs: type+start_date+title)
und legt nur neue an. Edge-Cases werden im Wizard angezeigt.

### 7.9 Pre-Mapping vor Import (Optional, empfohlen)
Vor dem Import generiere ich (Claude) ein Mapping-Sheet mit allen unklaren
Instructor-Namens-Strings und Vorschlägen. Du gehst durch, ich nehme das fertige
Mapping als Seed in die Stufe-2-Auswahl.

---

## 8. Vergütungs-Engine

### 8.1 Grund-Formel

```
Vergütung = Σ (Stunden pro Einheit) × Stundensatz nach PADI-Level

  Stunden    = comp_units (theory_h + pool_h + lake_h) für Kursart × Rolle
  Stundensatz = comp_rates für PADI-Level
                (Instructor=28, DM=20, Shop Staff=20, Andere Funktion=1)
```

**Beispiel** (Excel "3 Entschädigungen", Zeile 8):
```
Divemaster-Kurs · Haupt-Instructor:
  Theorie  =  5 h
  Pool     = 12 h
  See      = 12 h
  Total    = 29 h × CHF 28 = CHF 812
```

### 8.2 Trigger-Lokalisierung

Die Berechnung läuft als **Postgres-Trigger** auf `course_assignments`,
nicht als App-Code. Garantiert Konsistenz, egal woher die Änderung kommt.

```
ON INSERT/UPDATE OF course_assignments:
  1. Lookup course_types via course_id
  2. Lookup comp_units WHERE course_type_id = ? AND role = ?
  3. Anteilige Verteilung über assigned_for_dates
  4. Lookup comp_rate WHERE padi_level = instructor.padi_level
  5. amount = total_hours × hourly_rate
  6. INSERT INTO account_movements (kind='vergütung', breakdown_json=...)

ON DELETE OF course_assignments:
  Lösche zugehörigen account_movement (oder negiere via gegenbuchung)
```

### 8.3 Audit-Spur via `breakdown_json`

Jede Bewegung trägt die komplette Berechnungs-Logik als JSON:
```json
{
  "course_type": "AOWD",
  "role": "haupt",
  "padi_level": "Instructor",
  "theory_h": 1.5,
  "pool_h": 0,
  "lake_h": 13,
  "total_h": 14.5,
  "hourly_rate": 28,
  "amount_chf": 406,
  "calculated_at": "2026-05-15T14:23:00Z",
  "rate_version": 1
}
```

In der UI klickt der Instructor auf eine Saldo-Bewegung → sieht genau, woher
die Zahl kommt.

### 8.4 Mehr-Tages-Kurse mit Teil-Zuweisungen

`course_assignments.assigned_for_dates[]` enthält die spezifischen Daten,
an denen die Person dabei ist. Anteilige Verteilung der Total-Stunden:

```
hours_for_this_assignment =
  total_hours_for_course_type × |assigned_for_dates| / |all_course_dates|
```

**Default**: Verteilung nach Anzahl Tagen.
**Override**: Manuell via Korrektur-Buchung möglich.

### 8.5 Manuelle Korrekturen

Dispatcher kann jederzeit ein `account_movement` mit `kind='korrektur'`
und freier Begründung einfügen. Beispiel: "Lukas krank Tag 2, Annick eingesprungen"
→ -98 CHF Lukas, +98 CHF Annick.

### 8.6 Rate-Versionierung

Bei Änderung von `comp_rates`:
- Neue Zeile in `comp_rates` mit neuer `valid_from`-Datum
- Alte Bewegungen behalten ihren `rate_version` und Wert
- **Keine rückwirkende Neuberechnung** (Buchhaltungs-Standard)
- UI-Warnung beim Ändern: "Wirkt sich nur auf zukünftige Einsätze aus"

### 8.7 E-Learning-Bonus & Sonderkurse

Als **explizite Kurstypen** in `course_types`, nicht als versteckte Logik:
- AOWD (Standard, 14.5 h)
- AOWD + Dry (mit Specialty-Dry-Aufschlag, 19.5 h)
- AOWD + DAD (mit Dive Against Debris)

Anzahl Varianten überschaubar (~5–8 Kombi-Kurse), einmalig in Einstellungen
angelegt. Beim Anlegen eines konkreten Kurses wählt Dispatcher die korrekte Variante.

### 8.8 Was die Engine NICHT macht in v1

- ❌ Auszahlung anstoßen (Banking — v3)
- ❌ Spesen automatisch (manuell als Korrektur)
- ❌ Vergütung an Externe
- ❌ Steuern/Sozialabgaben
- ❌ Mehrwährung (alles CHF)

### 8.9 Test-Anforderungen

Comp-Engine wird hart unit-getestet:
- Jede Kursart × Rolle (Test-Matrix-Coverage)
- Multi-Day-Verteilung (z.B. Marjanka 17.+18., Niggi 24.+25.)
- Rate-Versionierung
- Korrektur-Buchungen
- Saldo-Aggregation gegen Mock-Daten
- Excel-Validation: importiere echte Datei → Saldo-Diff < CHF 50/Person für ≥90% der Personen

Tests blockieren Deploy bei Rotbruch. Falsche Saldi sind das schlimmste mögliche Versagen.

---

## 9. WhatsApp-Integration (Tiefe 1)

### 9.1 Scope v1

**Tiefe 1 = Deep-Links + vorgefüllte Nachrichten**, keine Cloud-API,
keine Automatisierung, kein Empfang aus WhatsApp.

Begründung: Setup-Aufwand für die Cloud API (Meta-Business-Verifizierung
1–2 Wochen, Templates pre-approval) blockiert die 6-Wochen-Pitch-Timeline.
Deep-Links liefern 80% des Pitch-Werts mit ~3 Stunden Aufwand.

### 9.2 Konkrete Touchpoints

| Wo | Button | Resultat |
|---|---|---|
| Nach Kurs-Anlage | "📲 In Gruppe ankündigen" | Öffnet WhatsApp Web/App mit vorgefüllter Nachricht im Kurs-Style |
| Nach Stornierung | "📲 Storno posten" | Öffnet WA mit Storno-Text |
| Heute-Dashboard | "📲 Tagesdigest senden" | Öffnet WA mit Zusammenfassung der heutigen Sessions |
| Instructor-Detail | "📲 [Lukas] direkt anschreiben" | Öffnet WA-DM (`https://wa.me/<phone>?text=...`) |
| Email-Notification an Instructor | "Antworten in WhatsApp" | Öffnet WA-DM mit Dispatcher |

### 9.3 Templates (Emoji-Stil)

Beispiele für die Standard-Templates:

**Neuer Kurs:**
```
🆕 Neuer Kurs · DSD GK01
📅 11.01.2026 · 09:30
👤 Pan (Haupt)
🌊 Pool Kloten 10:45–12:00
👥 2 Teilnehmer
```

**Tagesdigest:**
```
☀️ TSK heute · Donnerstag 30.04.

🤿 09:00 OWD GK01 · Daniele · Wallensee
🤿 10:00 DSD VIP · Pan · Möösli
🤿 14:00 Refresher · Lukas · Langnau
🌊 Pool Möösli 10:45–12:00 (DSD)

✨ 4 Sessions · 12 Taucher
```

**Storno:**
```
❌ Storniert · Dry GK02
📅 War: 15.01.2026
ℹ️ Grund: Krankheit Instructor, wird verschoben
```

### 9.4 Konfigurations-Felder (in Einstellungen)

- `whatsapp_group_invite_url`: Einladungslink der zentralen TSK-Gruppe
  (NUR wenn alle Instructors in derselben Gruppe sind — das ist Anforderung)
- `template_style`: 'emoji' (default) | 'knapp' | 'ausführlich' — vorbereitet für später
- Templates können vom Dispatcher in Einstellungen angepasst werden (Mustache-Syntax `{{course.title}}`)

### 9.5 Migrationspfad zu Tiefe 2/3

In v2 (post-Pitch, falls TSK kauft):
- Tiefe 2: WhatsApp Cloud API für **automatisches** Senden in die Gruppe
  (Meta-Business-Approval erforderlich, ~2 Wochen Vorlauf)
- Tiefe 3: Bidirektionale Integration — TL/DM antwortet "👍/👎" in WhatsApp,
  App liest Webhook und aktualisiert `course_assignments.confirmed`

### 9.6 Pitch-Bonus (Woche 6, optional)

Für die Pitch-Demo richten wir einen **WhatsApp-Cloud-API-Sandbox**
mit Dominiks Test-Account und einer Mini-Test-Gruppe ein. Erlaubt eine
Live-Demo von Tiefe 2 ohne Meta-Approval. Beim Pitch:
> "Schaut, ich lege Kurs an → 2 Sek. später ist die Nachricht automatisch
> im Test-WA. So sähe es scharf aus, sobald TSK das offiziell schaltet."

---

## 10. Hosting & Deployment

### 10.1 Stack-Hosts

| Komponente | Host | Region | Plan |
|---|---|---|---|
| Frontend (PWA) | Vercel | EU-Edge | Free |
| Backend (DB+Auth+Storage+Realtime+Functions) | Supabase Managed | EU-Frankfurt | Free |
| Email | Resend | EU | Free (3.000 Mails/Monat) |
| Domain & DNS | Infomaniak | Schweiz (Genf) | bestehend (`course-director.ch`) |
| Monitoring | Vercel Analytics + Supabase Logs + Sentry | — | Free |
| Repo | GitHub privat | — | Free |

### 10.2 URL-Struktur

- App: `https://dispo.course-director.ch`
- Email-Sender: `no-reply@course-director.ch`

DNS-Setup bei Infomaniak (von Dominik freigegeben, von Claude eingerichtet):
- 1× CNAME `dispo` → Vercel
- 2–3× TXT-Records für Resend-SPF/DKIM-Verifizierung

### 10.3 CI/CD

- GitHub Actions: Lint + Build + Tests bei jedem Push
- Vercel: Auto-Deploy bei Push nach `main` (~30 Sek.)
- Preview-Deployments für Feature-Branches automatisch
- Supabase-Migrations versioniert in `supabase/migrations/`, automatisch beim Deploy ausgespielt

### 10.4 Umgebungen (v1)

Nur **eine** Umgebung — Production. Lokale Entwicklung gegen lokalen
Supabase-Container (Docker), seeded mit anonymisierten Daten.

v2 (post-Pitch): dev/staging/prod-Trennung.

### 10.5 Backups

- **Automatisch**: Supabase tägliche Snapshots, 7-Tage-Retention (Free-Tier)
- **Zusätzlich**: Wöchentlicher Excel-Export (Sonntag) als Edge Function,
  legt .xlsx-Datei in Supabase Storage ab. Vorteile:
  - TSK-Buchhaltung kann jederzeit "altes Format" abrufen
  - Disaster-Recovery (App unabhängig vom Service)
  - Pitch-Beruhigung: "Ihr seid zu keinem Zeitpunkt von uns abhängig"

### 10.6 DSG/DSGVO

**v1 (≤ 5 User, Pitch-Phase)**:
- Daten in Supabase EU-Frankfurt → GDPR-konform
- Daten in Resend EU → GDPR-konform
- Schweizer Daten in EU sind unter rev. DSG (Sept 2023) zulässig
- Personenbezogene Daten in v1: Name, Email, PADI-Nr, Saldo
- **Nicht in v1**: Adressen, Bankdaten, Geburtsdaten, Sozialversicherungs-Nr.
- AVV (Auftragsverarbeitungs-Vertrag) mit Supabase + Resend optional in v1, Pflicht in v2

**v2 (Production, 75+ User)**:
- AVVs unterzeichnen
- Datenschutzerklärung in der App
- Migrationspfad zu Schweizer Hoster vorbereiten (optional)

### 10.7 Kosten

| Phase | Was | Pro Monat |
|---|---|---|
| v1 Pitch (4–6 Wochen) | Domain CHF 15/Jahr | ~CHF 1.25 |
| v2 Soft-Production (3–10 User) | gleich, +AVVs | ~CHF 1.25 |
| v3 Full TSK Production (75 User) | Supabase Pro $25, evtl. Vercel Pro $20 | ~CHF 45 |

---

## 11. Roadmap

### Woche 1 — Fundament
- Supabase-Schema (alle 11 Tabellen + RLS-Policies + Trigger-Stubs)
- Vite + React + Blue-Horizon-CSS portiert
- Auth-Flow (Magic-Link → Session → Role-Detection)
- Domain + DNS (`dispo.course-director.ch` live, Hello-World)
- Repo + CI/CD eingerichtet

📍 **Meilenstein**: "Du kannst dich mit Email einloggen, leerer Bildschirm"

### Woche 2 — Datenmaschinerie
- Excel-Import-Wizard (alle 4 Stufen)
- Vergütungs-Engine (Trigger + breakdown_json)
- Saldo-View (SUM aus account_movements)
- Validierungs-Report (App ↔ Excel)

📍 **Meilenstein**: "Echtes Excel ist drin, Saldi stimmen ±5%"

### Woche 3 — Dispatcher Hauptansichten
- Heute-Dashboard
- Kurse (Master-Detail mit Tabs)
- TL/DM (Master-Detail mit Tabs)
- Konflikt-Erkennung beim Anlegen

📍 **Meilenstein**: "Du kannst neuen Kurs anlegen, Lukas zuweisen, Konflikt sehen"

### Woche 4 — Spezialansichten
- Kalender (Wochen-/Monatsansicht mit Pool-Layer)
- Skill-Matrix (Kreuztabelle, filterbar, Bulk-Edit)
- Saldi (Liste + Bewegungs-Journal pro Person)
- Pool (Möösli + Langnau Lanes)

📍 **Meilenstein**: "Volle Dispatcher-Sicht steht"

### Woche 5 — Instructor-Sicht & Polish
- Instructor-Navigation (Heute / Meine Einsätze / Saldo / Profil)
- Realtime-Updates (WebSocket-Subscriptions)
- Email-Notifications (Neuer Einsatz / Storniert)
- WhatsApp-Deep-Links + Templates (Tiefe 1)
- Tweak-Panel (Dark/Light · Akzent · Sidebar↔Tabbar)
- Wöchentlicher Excel-Export als Edge Function

📍 **Meilenstein**: "Lukas Bader bekommt Email, klickt Login, sieht Saldo"

### Woche 6 — Pitch-Vorbereitung
- Bug-Hunt + Performance-Check (echte 200+ Kurse geladen)
- Pitch-Skript & Demo-Walkthrough mit Dominik
- DSG-One-Pager
- Backup-Test (Restore aus Supabase-Snapshot in leeres Projekt → alle Tabellen + RLS funktionieren; Excel-Export-Funktion liefert valide .xlsx)
- WhatsApp-Cloud-API-Sandbox-Demo (Tiefe-2-Vorschau, optional)
- Pitch-Dry-Run

📍 **Meilenstein**: "Pitch-ready"

### Woche 7 — Puffer

### Gesamt
**6 Wochen + 1 Puffer**, realistisch.

---

## 12. Test-Strategie

### 12.1 Hart getestet (automatisch, jeder Push)

**Vergütungs-Engine** (Sektion 8.9 detailliert):
- Unit-Tests für Kursart × Rolle Matrix
- Multi-Day-Verteilung
- Rate-Versionierung
- Korrektur-Buchungen
- Saldo-Aggregation
- Excel-Validation (Saldo-Diff < CHF 50/Person für ≥90%)

**Schema/RLS-Tests** (Postgres):
- Instructor sieht nicht Annicks Saldo (negative Test)
- Instructor kann nicht fremdes Profil ändern (negative Test)
- Dispatcher sieht alles (positive Test)

### 12.2 Weich getestet (Smoke-E2E + manuell)

Mit Playwright als täglicher Smoke-Test:
- Login-Flow
- Kurs-Anlegen-Flow
- Konflikt-Warnung
- Realtime-Update zwischen zwei Browsern
- Excel-Import (Mini-Datei mit 5 Kursen)
- Pitch-Walkthrough (10-Klick-Demo)

### 12.3 Gating

- Comp-Engine-Test rot → Deploy blockiert
- Andere Tests rot → Warnung in Slack/Email, Deploy nicht blockiert
  (Pitch-Prototyp, kein Produktions-Härtungs-Niveau)

---

## 13. Risiken & Gegenmaßnahmen

| Risiko | Wahrscheinlichkeit | Gegenmaßnahme |
|---|---|---|
| Excel-Import scheitert an Edge-Cases | Mittel | Wizard mit interaktivem Override, Soft-Validierung, Pre-Mapping |
| Berechneter Saldo weicht stark vom Excel ab | Niedrig | Comp-Engine voll Unit-getestet, Differenz-Report transparent |
| TSK lehnt aus DSG-Gründen ab | Niedrig | One-Pager + Migrationspfad zu Self-Hosted dokumentiert |
| Liquid-Glass funktioniert nicht in altem iPad-OS | Niedrig | Modernes Browser-Baseline (Safari 16+), Fallback ohne Glass-Effekt |
| TSK lehnt ab, weil "wir wollen native Apps" | Mittel | Migrationspfad zu SwiftUI dokumentiert; PWA-Demo zeigt 95% Native-Feel |
| Performance bei 200+ Kursen lahm | Niedrig | Postgres-Indizes, Pagination, Virtualization wo nötig |
| Dominik wird krank, Claude kann nicht beliebig weiter | Niedrig | Standard-React + Standard-Supabase — jeder Web-Entwickler kann übernehmen |
| WhatsApp-Deep-Link funktioniert auf iOS nicht zuverlässig | Niedrig | Universal-Link-Format `https://wa.me/`; Fallback "in Zwischenablage kopieren" |
| Meta blockiert WhatsApp-Sandbox kurzfristig (für Tiefe-2-Demo) | Mittel | Tiefe-1 ist v1-Lösung, Sandbox-Demo nur Bonus |

---

## 14. Was passiert nach dem Pitch

### Fall 1 — TSK kauft
- v2 startet: Slice C (Guru/Buchhaltungs-Export) + Slice D (Teilnehmer-Tracking)
- Migration auf 3-Umgebungen-Setup (dev/staging/prod)
- AVVs unterzeichnen, DSG-Erklärung publizieren
- WhatsApp-Tiefe 2 oder 3
- Optional: Self-Hosted Supabase auf Schweizer Infrastruktur
- Optional: native iOS-App in SwiftUI als v3

### Fall 2 — TSK lehnt ab
- Dominik behält die App für **persönliche** Verwendung
- Code bleibt in seinem Repo, läuft auf seiner Domain, Kosten <CHF 2/Monat
- Lessons learned portierbar — z.B. Pitch bei anderer Tauchschule oder als
  Open-Source-Projekt für andere PADI Course Directors freigeben (Optional)

### Fall 3 — TSK sagt "ja, aber..."
- Anpassungs-Loop, ohne Druck. v1.5 statt v2.

---

## 15. Annahmen & Festlegungen

Festgelegt während des Brainstormings:
- ✅ Volle Multi-User-Plattform (Slice D), aber MVP nur für A+B (Dispo + Instructor-App)
- ✅ Excel komplett ablösen, nicht parallel betreiben (B)
- ✅ Soft-Live-Modus mit 3–5 echten Test-Loginern
- ✅ Pitch-Prototyp, kein Big-Bang Production
- ✅ Tech-Stack: PWA (React + Vite + CSS) + Supabase Managed
- ✅ Visual: Blue Horizon übernommen, Liquid Glass, Tweak-Panel
- ✅ 11 Tabellen, immutables Ledger, M:N für Skills
- ✅ Saldo-Privatsphäre via RLS (Instructor sieht nur eigenen)
- ✅ Konflikt-Erkennung weich (Warnung, kein Block)
- ✅ Email via Resend, Sender `no-reply@course-director.ch`
- ✅ Domain `dispo.course-director.ch` (Subdomain unter Infomaniak)
- ✅ Pool startet leer (Excel-Sheet 2 nicht importiert)
- ✅ Mappings vor Import gespeichert für Re-Import
- ✅ Anteilige Vergütungs-Verteilung nach Tagen (Default), Manual-Override möglich
- ✅ Rate-Versionierung ohne Rückwirkung
- ✅ Sonderkurse als explizite Varianten
- ✅ WhatsApp-Tiefe 1 (Deep-Links), eine zentrale Gruppe, Emoji-Stil
- ✅ Hartes Test-Gating für Comp-Engine
- ✅ GitHub als Repo
- ✅ Wöchentlicher Excel-Export

Offen / zu klären vor Implementierung:
- ⏳ Anon-Key + Service-Role-Key der bestehenden Supabase-Instanz übergeben
- ⏳ Domain-Zugriff auf Infomaniak (DNS-Modifikation) freigeben
- ⏳ Excel-Datei als verbindliche Quelle für Import
- ⏳ Liste der 3–5 Test-Instructors für Soft-Live (Namen + Mail)
- ⏳ TSK-Logo / Visual-Brand-Elemente, falls vorhanden
- ⏳ Konkreter Pitch-Termin (für Roadmap-Schluss)

---

## 16. Glossar

| Begriff | Bedeutung |
|---|---|
| TSK | Tauchsport Käge (Zürcher Tauchladen) |
| TL | Tauchlehrer / Instructor |
| DM | Divemaster |
| DMT | Divemaster Trainee |
| OWD | Open Water Diver |
| AOWD | Advanced Open Water Diver |
| DSD | Discover Scuba Diving |
| DLD | Discover Local Diving |
| DRY | Dry Suit Specialty |
| EAN | Enriched Air Nitrox |
| EFR | Emergency First Response |
| BFD | Basic Freediver |
| PADI | Professional Association of Diving Instructors |
| Saldo | Kontostand des Instructor (CHF) |
| RLS | Row-Level-Security (Postgres-Feature) |
| PWA | Progressive Web App |
| Comp-Engine | Vergütungs-Berechnung (Compensation Engine) |
| MAU | Monthly Active Users |
| AVV | Auftragsverarbeitungs-Vertrag (DSG/DSGVO) |

---

## Anhang A — Datenbeispiele aus aktueller Excel-Datei

Aus "1 Kursplanung", Zeile 24:
```
Titel:       OWD
Kurs:        OWD DRY GK01 DE / ENG
Status:      sicher
StartDatum:  2026-01-12
ZusatzD1:    17. + 18.01.26
ZusatzD2:    24. + 25.01.26
Info:        Theorie ab 18 Uhr / dann ab 09 Uhr (Mitfahrt Kaito)
HauptInstr:  Daniele
Assistenten: 17. + 18. Marjanka / 24. + 25. Niggi
TN:          4
Pool:        ja
Notiz:       Langnau ab 11 Uhr (6 PAX ok)
```

Wird in DB zu:
```
courses:
  type=OWD eLearning, title='OWD DRY GK01 DE / ENG',
  status='confirmed', start_date='2026-01-12',
  additional_dates=['2026-01-17','2026-01-18','2026-01-24','2026-01-25'],
  num_participants=4, info='...', notes='Langnau ab 11 Uhr (6 PAX ok)'

course_assignments:
  - instructor='Daniele Toto Brocchi', role='haupt',
    assigned_for_dates=ALL
  - instructor='Marjanka Aeschlimann', role='assist',
    assigned_for_dates=['2026-01-17','2026-01-18']
  - instructor='Niklaus Schaffner', role='assist',
    assigned_for_dates=['2026-01-24','2026-01-25']

pool_bookings:
  - date='2026-01-12', location='langnau', course_id=...
  (oder ähnlich, je nach Pool-Plan)

account_movements (auto vom Trigger):
  - Daniele: 22h × CHF 28 × (5/5) = CHF 616 (Vollumfang)
  - Marjanka: 22h × CHF 20 × (2/5) = CHF 176 (anteilig)
  - Niggi:    22h × CHF 20 × (2/5) = CHF 176 (anteilig)
```

---

## Anhang B — Verzeichnisstruktur (geplant)

```
Dispo/
├── docs/
│   └── superpowers/
│       └── specs/
│           └── 2026-04-30-tsk-dispo-app-design.md   (dies hier)
├── apps/
│   └── web/                    # PWA
│       ├── src/
│       │   ├── components/     # Avatar, Sheet, Topbar, etc.
│       │   ├── screens/        # TodayScreen, KalenderScreen, etc.
│       │   ├── lib/            # Supabase-Client, Utils
│       │   ├── styles/         # CSS aus Blue Horizon portiert
│       │   └── App.tsx
│       ├── index.html
│       ├── package.json
│       └── vite.config.ts
├── supabase/
│   ├── migrations/             # SQL-Migrations (versioniert)
│   ├── functions/              # Edge Functions
│   │   ├── excel-import/
│   │   ├── weekly-export/
│   │   └── send-notification/
│   └── config.toml
├── scripts/
│   └── pre-mapping.ts          # Pre-Import-Helper
├── tests/
│   ├── unit/                   # Comp-Engine-Tests
│   └── e2e/                    # Playwright
├── .github/
│   └── workflows/
│       └── ci.yml
├── .gitignore
├── README.md
└── package.json
```

---

**Ende des Design-Dokuments**

Nächster Schritt nach Freigabe durch Dominik: Aufruf des `superpowers:writing-plans`-Skills,
um diesen Spec in einen detaillierten Wochen-für-Wochen-Implementierungs-Plan zu übersetzen.
