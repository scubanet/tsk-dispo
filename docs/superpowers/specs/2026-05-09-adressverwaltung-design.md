# Adressverwaltung Redesign — Unified Contacts CRM

**Status:** Draft (User-Review pending)
**Date:** 2026-05-09
**Author:** Dominik Weckherlin (with Claude)
**Spec Owner:** Dominik
**Target Release:** v5.0

---

## 1. Kontext & Problem

### Heutiger Zustand

Die Adressverwaltung in ATOLL ist auf **fünf getrennte Screens** verteilt:

- `StudentsScreen` (Schüler / Kandidaten / Org-Kontakte mit FilterTabBar)
- `InstructorsScreen` (Team — TL/DM/CD/Owner)
- `cd/CDOrganizationsScreen` (Tauchschulen / Partner / Verbände)
- `cd/CDPipelineScreen` (5-Spalten-Kanban: Lead → Qualified → Opportunity → Customer → Lost)
- `CommunicationHubScreen` (Touchpoint-Log)

Datenmässig liegen diese in **drei getrennten Tabellen**:

- `instructors` (Migration `0006_table_instructors.sql`) — Auth-verknüpft, mit
  `padi_pro_number`, `account_balance`, `active`, Skills, Verfügbarkeiten
- `people` (Migration `0069*` — umbenannt von `students`) — mit `is_student`,
  `is_candidate`, `pipeline_stage`, `intake_status`, externe Brevet-History
- `organizations` — Tauchschulen, Partner, Verbände

### Pain-Points

1. **Doppelerfassung:** TL/DM die selbst an einem Kurs teilnehmen (Crossover,
   Specialty-Instructor, EFRI Refresher) müssen als zweite Identität in `people`
   angelegt werden — die gemeinsame Historie bricht ab.
2. **Lifecycle-Bruch:** Beim IDC-Pass wird aus einem `people`-Eintrag (Kandidat)
   ein **neuer** `instructors`-Eintrag — alle bisherigen Kommunikations-Touchpoints,
   Notizen, Beziehungen werden im Adressbuch unauffindbar.
3. **Fünf mentale Modelle:** Ein:e Mitarbeiter:in muss wissen "wo schaue ich
   wenn ich X suche". Master-Detail-Logik, Detail-Panel-Aufbau und Edit-Flows
   sind pro Screen unterschiedlich.
4. **Voll-CRM-Bedarf nicht abgedeckt:** Lieferanten (Equipment, Gas), Behörden
   (Coast Guard, Immigration), Geschäftspartner (PADI-Reps, Versicherungen),
   Newsletter-Empfänger / Cold-Leads — heute keine saubere Heimat. Tendenz: in
   Zettel, Excel-Files, Email-Adressbüchern verstreut.
5. **EditSheet-Pattern wird unhandlich:** Jeder Datensatz-Typ hat sein eigenes
   `*EditSheet.tsx` — viel Code-Duplikation, inkonsistente UX.

### Ziel

Eine professionelle, zentrale Adressverwaltung als **eine Datenquelle** für
alle Personen und Organisationen, mit:

- **eine** vereinte Tabelle (`contacts`) für alle Personen-/Org-Datensätze
- **rollenbasierte** Sidecars für rollenspezifische Daten (Instructor, Student,
  Org)
- **n:m-Beziehungen** zwischen Contacts (Person ↔ Org, Familien, Empfehlungen)
- **ein** universeller `ContactDetailPanel` — adaptive Tabs nach Rollen,
  kontextueller Default-Tab, Inline-Edit überall
- **gemischte Navigation:** zentrales Adressbuch + spezialisierte
  Workflow-Screens (Pipeline, Communication Hub, Skill-Matrix, Verfügbarkeit)
- **GDPR-konform**, **Audit-fähig**, **Dedup-sicher**

### Nicht-Ziel (für diesen Spec)

- Marketing-Automation (Newsletter-Workflows, Drip-Campaigns) — separater Spec
- Mobile-App-Refresh — kann nach M3 separat angegangen werden
- Migration der bestehenden iOS-App auf das neue Schema — separater Spec

---

## 2. Architektur-Entscheidungen

Sechs Fork-Entscheidungen wurden im Brainstorming-Dialog festgelegt:

| # | Frage | Gewählt | Begründung |
|---|-------|---------|------------|
| 1 | TL/DM in zentraler Adress-DB? | **Ja, voll vereinheitlicht** | Doppelerfassung & Lifecycle-Brüche eliminieren |
| 2 | Scope der Tabelle? | **D — Voll-CRM** | Lieferanten, Partner, Behörden, Cold-Leads inklusive |
| 3 | Person ↔ Organisation? | **C — Hybrid** (alle Contacts + n:m-Relationships) | Mehrfachzugehörigkeit, Konzern-Hierarchien, Familien |
| 4 | Rollen-Modell? | **B — `roles[]` Array** | Flexibel, kein Schema-Migrieren bei neuen Rollen, GIN-Index |
| 5 | Rollenspezifische Daten? | **D — Hybrid: gemeinsame Felder auf `contacts`, sidecar pro Hauptrolle** | NULL-Wust vermeiden, FK-Constraints möglich |
| 6 | Primärer UI-Einstieg? | **C — Hybrid: Adressbuch + Workflow-Screens** | Spezial-Tools (Pipeline-Kanban, Skill-Matrix) bleiben, alle teilen Detail-Panel |
| 7 | ContactDetailPanel-Struktur? | **A + D — Adaptive Tabs + Kontext-Switching** | Tabs erscheinen nach Rollen, Default-Tab folgt Herkunft |

---

## 3. Datenmodell

### 3.1 Neue Tabellen

```sql
CREATE TYPE contact_kind AS ENUM ('person', 'organization');

CREATE TABLE contacts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  kind contact_kind NOT NULL,

  -- Personen-Felder (NULL für Orgs)
  first_name TEXT,
  last_name TEXT,
  birth_date DATE,
  gender TEXT,

  -- Org-Felder (NULL für Personen)
  legal_name TEXT,
  trading_name TEXT,

  -- Gemeinsame Felder
  display_name TEXT GENERATED ALWAYS AS (
    CASE
      WHEN kind = 'organization' THEN COALESCE(trading_name, legal_name)
      ELSE last_name || ', ' || first_name
    END
  ) STORED,

  primary_email TEXT,
  emails JSONB NOT NULL DEFAULT '[]',
    -- [{label:'work',email:'...',primary:true}]
  phones JSONB NOT NULL DEFAULT '[]',
    -- [{label:'mobile',e164:'+41...',whatsapp:true,primary:true}]
  addresses JSONB NOT NULL DEFAULT '[]',
    -- [{label:'home',street,city,country,postal,primary:true}]

  languages TEXT[] DEFAULT '{}',
  roles TEXT[] NOT NULL DEFAULT '{}',
    -- ['student','instructor','newsletter','supplier','partner_rep',...]
  tags TEXT[] DEFAULT '{}',

  notes TEXT,
  owner_id UUID REFERENCES contacts(id),
    -- "wer betreut den Kontakt" — verweist auf einen anderen Contact mit
    -- role 'instructor' (typisch CD oder Owner)

  consent_marketing BOOLEAN NOT NULL DEFAULT false,
  consent_marketing_at TIMESTAMPTZ,
  consent_marketing_source TEXT,

  source TEXT,
    -- 'manual' | 'web_form' | 'import' | 'referral' | 'legacy_migration'

  archived_at TIMESTAMPTZ,
  merged_into_id UUID REFERENCES contacts(id),
    -- bei Verschmelzung: Loser-Contact zeigt auf Gewinner

  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID,

  CONSTRAINT contacts_person_fields_check CHECK (
    kind = 'organization'
    OR (first_name IS NOT NULL AND last_name IS NOT NULL)
  ),
  CONSTRAINT contacts_org_fields_check CHECK (
    kind = 'person' OR legal_name IS NOT NULL
  )
);

CREATE INDEX idx_contacts_kind ON contacts(kind);
CREATE INDEX idx_contacts_owner ON contacts(owner_id);
CREATE INDEX idx_contacts_roles ON contacts USING GIN(roles);
CREATE INDEX idx_contacts_tags ON contacts USING GIN(tags);
CREATE INDEX idx_contacts_archived ON contacts(archived_at) WHERE archived_at IS NULL;
CREATE INDEX idx_contacts_search ON contacts USING GIN(
  to_tsvector('simple',
    COALESCE(first_name,'') || ' ' ||
    COALESCE(last_name,'') || ' ' ||
    COALESCE(legal_name,'') || ' ' ||
    COALESCE(trading_name,'') || ' ' ||
    COALESCE(primary_email,'') || ' ' ||
    COALESCE(notes,'')
  )
);
```

### 3.2 Sidecar — `contact_instructor`

```sql
CREATE TABLE contact_instructor (
  contact_id UUID PRIMARY KEY REFERENCES contacts(id) ON DELETE CASCADE,
  auth_user_id UUID UNIQUE REFERENCES auth.users(id),
  padi_pro_number TEXT,
  padi_level padi_pro_level,
  account_balance NUMERIC(10,2) NOT NULL DEFAULT 0,
  hourly_rate_chf NUMERIC(8,2),
  daily_rate_chf NUMERIC(8,2),
  active BOOLEAN NOT NULL DEFAULT true,
  hire_date DATE,
  termination_date DATE,
  emergency_contact_name TEXT,
  emergency_contact_phone TEXT,
  notes_internal TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_contact_instructor_active ON contact_instructor(active);
CREATE INDEX idx_contact_instructor_auth ON contact_instructor(auth_user_id);
```

### 3.3 Sidecar — `contact_student`

```sql
CREATE TABLE contact_student (
  contact_id UUID PRIMARY KEY REFERENCES contacts(id) ON DELETE CASCADE,
  pipeline_stage TEXT,
    -- 'lead' | 'qualified' | 'opportunity' | 'customer' | 'candidate' | 'lost'
  lead_source TEXT,
  highest_brevet TEXT,
  intake_status TEXT,
  external_brevet_history JSONB DEFAULT '[]',
  is_candidate BOOLEAN NOT NULL DEFAULT false,
  candidate_target_level padi_pro_level,
  medical_clearance_at DATE,
  insurance_provider TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_contact_student_pipeline ON contact_student(pipeline_stage);
CREATE INDEX idx_contact_student_candidate ON contact_student(is_candidate)
  WHERE is_candidate = true;
```

### 3.4 Sidecar — `contact_organization`

```sql
CREATE TABLE contact_organization (
  contact_id UUID PRIMARY KEY REFERENCES contacts(id) ON DELETE CASCADE,
  org_kind TEXT NOT NULL,
    -- 'tauchschule'|'partner'|'verband'|'lieferant'|'behörde'|'kunde'|'sonstiges'
  tax_id TEXT,
  billing_email TEXT,
  parent_org_id UUID REFERENCES contacts(id),
  contract_type TEXT,
  contract_until DATE,
  payment_terms TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_contact_org_kind ON contact_organization(org_kind);
CREATE INDEX idx_contact_org_parent ON contact_organization(parent_org_id);
```

### 3.5 Beziehungen — `contact_relationships`

```sql
CREATE TYPE relationship_kind AS ENUM (
  'works_at', 'owns', 'spouse_of', 'child_of', 'parent_of',
  'referred_by', 'subsidiary_of', 'partner_of', 'supplier_of',
  'student_of', 'mentor_of'
);

CREATE TABLE contact_relationships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  from_contact_id UUID NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  to_contact_id UUID NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  kind relationship_kind NOT NULL,
  role_at_org TEXT,           -- "Sales Rep", "Manager", "Owner"
  started_at DATE,
  ended_at DATE,
  is_primary BOOLEAN NOT NULL DEFAULT false,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT no_self_relationship CHECK (from_contact_id <> to_contact_id)
);

CREATE INDEX idx_contact_rel_from ON contact_relationships(from_contact_id);
CREATE INDEX idx_contact_rel_to ON contact_relationships(to_contact_id);
CREATE INDEX idx_contact_rel_kind ON contact_relationships(kind);
```

### 3.6 Audit-Log

```sql
CREATE TABLE contact_audit_log (
  id BIGSERIAL PRIMARY KEY,
  contact_id UUID NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  changed_by UUID,
  changed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  table_name TEXT NOT NULL,
    -- 'contacts'|'contact_instructor'|'contact_student'|'contact_organization'
  operation TEXT NOT NULL,        -- 'INSERT'|'UPDATE'|'DELETE'
  changed_fields JSONB,
    -- {field: {old: x, new: y}}
  old_row JSONB,
  new_row JSONB
);

CREATE INDEX idx_audit_contact ON contact_audit_log(contact_id, changed_at DESC);
```

### 3.7 Trigger & Constraints

- **Role-Sidecar-Konsistenz:** Trigger auf `contacts` und Sidecars stellt
  sicher, dass `roles ⊇ ['instructor']` ⇔ `contact_instructor`-Zeile existiert.
  Bei Insert in `contact_instructor` wird `roles` automatisch um `'instructor'`
  ergänzt.
- **Audit-Trigger** auf `contacts`, `contact_instructor`, `contact_student`,
  `contact_organization` schreiben jede Mutation in `contact_audit_log`.
- **`updated_at`-Trigger** auf allen Tabellen.
- **Dedup-Check-Function** `find_potential_duplicates(contact_id UUID)` —
  liefert Liste ähnlicher Contacts (gleiche normalisierte Phone, gleiche Email,
  gleicher Name + Geburtsdatum).
- **`merged_into_id`** wird nur via `merge_contacts(winner UUID, loser UUID)`
  RPC gesetzt — diese Function migriert auch alle FK-Verweise vom Loser zum
  Winner.

### 3.8 FK-Migration in bestehenden Tabellen

| Tabelle | Heute | Neu |
|---------|-------|-----|
| `course_assignments` | `instructor_id → instructors(id)` | `instructor_id → contacts(id)` (mit Check `roles ⊇ instructor`) |
| `course_participants` | `person_id → people(id)` | `contact_id → contacts(id)` |
| `account_movements` | `instructor_id → instructors(id)` | `contact_id → contacts(id)` |
| `communication_entries` | `person_id → people(id)`, `instructor_id → instructors(id)` (Bearbeiter) | beide → `contacts(id)` |
| `instructor_skills` | `instructor_id → instructors(id)` | `contact_id → contacts(id)` |
| `availability_blocks` | `instructor_id → instructors(id)` | `contact_id → contacts(id)` |
| `intake_checklists` | `person_id → people(id)` | `contact_id → contacts(id)` |

**Trick:** UUIDs aus den alten Tabellen werden als `contacts.id` übernommen, sodass alle existierenden FK-Verweise nach der Migration **automatisch korrekt** sind, ohne dass FK-Spalten umgeschrieben werden müssen. Nur das **referenzierte Ziel** ändert sich (von `instructors`-View zu `contacts`).

### 3.9 RLS-Policies

```sql
-- Lesen: alle authentifizierten User
CREATE POLICY contacts_select_authenticated
  ON contacts FOR SELECT TO authenticated USING (true);

-- Schreiben: Owner, CD, oder Owner-Rolle
CREATE POLICY contacts_write_role_based
  ON contacts FOR ALL TO authenticated
  USING (
    auth.role_in('cd','owner')
    OR owner_id IN (SELECT contact_id FROM contact_instructor
                    WHERE auth_user_id = auth.uid())
  );

-- account_balance: nur CD/Owner oder der TL selbst
CREATE POLICY contact_instructor_balance_read
  ON contact_instructor FOR SELECT TO authenticated
  USING (
    auth.role_in('cd','owner')
    OR auth_user_id = auth.uid()
  );
```

---

## 4. Migrations-Strategie (3 Phasen)

### Phase M1 — Schema additiv anlegen

**Risk:** Null. Bestehende Tabellen bleiben unangetastet.

1. Migration `0079_contacts_schema.sql` legt alle neuen Tabellen, Indexes,
   Constraints, Trigger an.
2. Migration `0080_contacts_backfill.sql` kopiert Daten:
   - Jede `instructors`-Zeile → ein `contacts` (kind='person',
     roles=['instructor']) + ein `contact_instructor` mit **identischer UUID**.
   - Jede `people`-Zeile → ein `contacts` (kind='person', roles abhängig von
     is_student/is_candidate/organization_id) + ein `contact_student`.
   - Jede `organizations`-Zeile → ein `contacts` (kind='organization') + ein
     `contact_organization`.
3. Vor dem Backfill läuft eine **Audit-Query** die potenzielle Duplikate
   zwischen `instructors` und `people` findet (gleiche Email oder
   Name+Geburtsdatum). Output: CSV für manuellen Review.
4. **User-Review-Schritt:** Dominik entscheidet pro Pärchen ob verschmelzen
   oder als separate Contacts halten. Default: nicht verschmelzen.
5. Nach dem Backfill: Audit-Query verifiziert dass Anzahl Zeilen passt und
   keine FKs broken sind.

### Phase M2 — Compatibility-Views

**Risk:** Niedrig. Bestehender Code liest weiter, ohne ihn zu kennen.

1. `instructors`-Tabelle → `instructors_legacy` umbenennen.
2. `instructors`-View anlegen, die aus `contacts JOIN contact_instructor` die
   alte Struktur reproduziert.
3. Analog für `people` → `people_legacy` + View, `organizations` →
   `organizations_legacy` + View.
4. Frontend-Code wird **schrittweise** auf das neue Schema migriert (Screen
   für Screen, jeder Screen ein eigener PR).
5. **Verifikation:** pgTAP-Tests stellen sicher dass alte Queries auf den
   Views identische Resultate liefern wie auf den `_legacy`-Tabellen.

### Phase M3 — Cleanup

**Risk:** Mittel — irreversibel nach 90 Tagen.

1. Wenn alle Frontend-Screens auf das neue Schema migriert sind:
   - FK-Spalten in `course_assignments`, `course_participants`,
     `account_movements`, `communication_entries`, `instructor_skills`,
     `availability_blocks`, `intake_checklists` werden umbenannt
     (`instructor_id`/`person_id` → `contact_id`).
   - Views `instructors`, `people`, `organizations` werden gedroppt.
2. `_legacy`-Tabellen bleiben als Backup für 90 Tage stehen.
3. Nach 90 Tagen ohne Probleme: `_legacy`-Tabellen droppen.

### Rollback-Strategie

| Phase | Rollback |
|-------|----------|
| Nach M1 | Neue Tabellen droppen — null Datenverlust |
| Nach M2 | Views droppen, `_legacy`-Tabellen wieder umbenennen — null Datenverlust |
| Nach M3 (vor 90 Tage) | `_legacy`-Tabellen restaurieren, FK-Spalten zurückbenennen — Aufwand: ein Tag |
| Nach 90 Tagen | Kein automatischer Rollback — Restore aus PITR-Backup |

### Aufwandsschätzung

- M1: 1 Tag (Schema + Backfill + Audit + Dedup-Review)
- M2: 1 Tag (Views + Verifikations-Tests)
- M3: 3-5 Tage (Frontend-Refactor)

---

## 5. UI-Architektur

### 5.1 Top-Level-Navigation

```
HEUTE
KURSE
KALENDER

ADRESSEN                          ← neuer zentraler Einstieg
  Adressbuch                      → Master-Detail über alle Contacts
  Pipeline                        → Workflow: Kanban-Board (CD)
  Communication Hub               → Workflow: Touchpoint-Log

TEAM
  TL/DM                           → vorgefilterte View "roles ⊇ instructor"
  Skill-Matrix                    → Workflow: Skills-Grid
  Verfügbarkeit                   → Workflow: Kalender-Grid

ADMIN (Owner)
  Settings, Buchungen, …
```

**Begründung:** Workflow-Screens (Pipeline, Skill-Matrix, Verfügbarkeit) sind
echte Werkzeuge, keine Filter. Das Adressbuch wird der zentrale "ich suche eine
Person"-Einstieg.

### 5.2 Adressbuch-Hauptscreen (Master-Detail)

**Linke Seite (Master, ~360 px):**

- Suchleiste (fuzzy über `to_tsvector`)
- Saved-Views als Pills/Dropdown:
  *Alle · Personen · Organisationen · Aktive Schüler · Pipeline-Leads ·
  Team · Lieferanten · Newsletter · Geburtstage 30 Tage · Eigene Kontakte*
- Sortierung: Nachname (default) / Letzte Aktivität / Neueste
- Items: Avatar + Name + Rollen-Chips + Subline ("Aqua Land · Sales Rep")
- `+` Button: "Neue Person" / "Neue Organisation" / "Aus Vorlage"

**Rechte Seite (Detail-Panel, fluid):**

- Sticky Header mit Avatar, Name, Rollen-Chips, Owner-Badge, Quick-Actions
- Adaptive Tabs (siehe 5.4)

**Empty-State:** Hübscher Hero mit Hinweis "Suche oder erstelle einen Kontakt".

### 5.3 Workflow-Screens

Bleiben strukturell wie heute. Klick auf Person/Org → öffnet `ContactDetailPanel`
als Side-Sheet (Desktop) oder Full-Screen-Modal (Mobile). Schliessen → zurück
zum Workflow.

### 5.4 ContactDetailPanel

**Header (sticky):**

- Avatar 64 px
- Display-Name (gross)
- Rollen-Chips (klickbar — springen zum entsprechenden Tab)
- Owner-Badge
- Kommunikationsdaten-Zeile (Email · Phone · Adresse)
- Quick-Actions: Email · WhatsApp · Call · Kurs buchen · `⋯`

**Adaptive Tabs:**

Immer sichtbar:

1. **Übersicht** — Stammdaten, Emails/Phones/Addresses, Tags, Notes, Audit-Footer
2. **Beziehungen** — alle `contact_relationships` ein-/ausgehend
3. **Aktivität** — chronologischer Stream (Buchungen, Brevets, Comms,
   Saldo-Bewegungen, Status-Wechsel) mit Filter-Chips
4. **Notizen & Dokumente** — Markdown-Notes, Datei-Uploads

Erscheinen nach Rolle:

5. **Schüler** (`roles ⊇ student`) — Pipeline, Lead-Source, Intake, Brevet-History
6. **Kurse** (`roles ⊇ instructor` ∨ `student`) — getrennt "Als Teilnehmer" / "Als TL/DM"
7. **Saldo** (`roles ⊇ instructor`)
8. **Skills & Specialties** (`roles ⊇ instructor`)
9. **Verfügbarkeit** (`roles ⊇ instructor`)
10. **Org-Mitglieder** (`kind=organization`)
11. **Vertrag & Billing** (`org_kind ∈ {tauchschule, partner, lieferant}`)

**Default-Tab nach Herkunft:**

| Klick aus | Default-Tab |
|---|---|
| Adressbuch | Übersicht |
| Pipeline-Kanban | Schüler |
| Kursliste / Kurs-Detail | Kurse |
| Skill-Matrix | Skills & Specialties |
| Communication Hub | Aktivität (Filter Comms) |
| Saldo-Liste | Saldo |

URL-Param `?tab=...` macht's deeplinkbar.

**Mehr-Menü (`⋯`):**

- Rollen verwalten (Mini-Sheet mit Checkbox-Liste)
- Owner zuweisen
- Mit anderem Contact verschmelzen
- Archivieren
- Löschen (Soft, nur Owner)
- Export vCard / CSV
- Audit-Historie

### 5.5 Inline-Edit überall

Statt EditSheet-Pattern: **Klick auf ein Feld → wird zum Input → ⏎ speichert /
Esc bricht ab**. Linear-/Notion-Style. Eliminiert die heutigen
`InstructorEditSheet`, `StudentEditSheet`, `OrgEditSheet`,
`CommunicationEditSheet` etc. — **enorme Code-Reduktion**.

**Ausnahmen (Sheet bleibt):**

- "Neuen Contact erstellen" (Pflichtfelder + initiale Rollen)
- "Verschmelzen" (Konflikt-Auflösung, Side-by-Side-Preview)
- "Org-Mitglied hinzufügen" (Beziehungstyp + Rolle festlegen)

### 5.6 Mobile-Verhalten

- Master-Detail wird zu Stack-Navigation
- Saved Views als horizontaler Scroll-Tab
- Sticky Action-Bar unten im Detail (Email · WhatsApp · Call)

---

## 6. Compliance, Audit & Datenqualität

### 6.1 GDPR / DSGVO

- **Consent-Felder** auf `contacts`: `consent_marketing`, `..._at`, `..._source`.
  Newsletter-Versand respektiert das Flag automatisch.
- **Right-to-be-forgotten:** Aktion "DSGVO-Löschung" im `⋯`-Menü → ersetzt PII
  (Name → "Gelöschter Kontakt #abc", Email/Phone → NULL), behält `contact_id`
  und Aktivitäts-Historie für Buchhaltung/Statistik.
- **Data-Export (Art. 20):** Aktion "Datenexport" → JSON+PDF mit allen Daten.
- **Audit-Log** (siehe 3.6) — sichtbar via "Audit-Historie" im Mehr-Menü.

### 6.2 Datenqualität & Dedup

- **Duplikat-Erkennung beim Insert/Update:** `find_potential_duplicates` läuft
  vor dem Speichern. UI-Warnung bei Treffer ("Sieht aus wie 'Sandra Müller'
  (Schüler) — wirklich neu anlegen?").
- **Verschmelzen-Workflow:** `merge_contacts(winner, loser)` RPC migriert FKs,
  schreibt Audit, setzt `merged_into_id` am Loser. UI: Side-by-Side-Preview-Sheet
  mit "Welcher Wert gewinnt?"-Toggles pro Feld.
- **Validation-Hooks:**
  - Email-Format (RFC 5322)
  - Phone-Normalization auf E.164 via `libphonenumber`
  - Postleitzahl-Plausibilität (länderabhängig)

### 6.3 Performance & Such-Erlebnis

- **Volltext-Index:** GIN auf `to_tsvector(...)` (siehe 3.1)
- **Pagination:** Master-Liste 50 Items + Infinite-Scroll
- **Realtime:** Supabase-Realtime auf `contacts` — Toast bei externer Änderung
  + automatischer Refresh

### 6.4 Notifications

- Owner-Zuweisung → Email-Notification an neuen Owner
- Pipeline-Stage-Change → optional Notification an Owner
- Geburtstags-Saved-View → tägliches Briefing

### 6.5 Out-of-MVP

- **Quality-Score** pro Contact (0–100, Pflichtfelder + Aktivitätsindikator) —
  später, niedriger Mehrwert im MVP

---

## 7. Tests & Verifikation

### 7.1 Schema-Tests (pgTAP)

- Constraints: Person braucht first_name+last_name, Org braucht legal_name
- RLS-Policies: User-X kann/kann-nicht Y lesen/schreiben
- Trigger: Role-Sidecar-Konsistenz, Audit-Schreibungen, `updated_at`
- Backfill-Korrektheit: Anzahl Zeilen, FK-Integrität

### 7.2 Migration-Smoke-Test

Skript erstellt **vor** der Migration einen Snapshot aus
`instructors`+`people`+`organizations`, verifiziert **nach** Phase M2 dass die
Compatibility-Views bit-identische Resultate liefern.

### 7.3 E2E-Tests (Playwright)

- Neuen Contact anlegen (Person + Org)
- Rolle hinzufügen
- Beziehung anlegen
- Verschmelzen-Flow
- DSGVO-Löschung
- Inline-Edit-Flow im DetailPanel
- Saved-View-Wechsel
- Adaptive Tabs nach Rolle

---

## 8. Side Notes & deferred Decisions

- **Communication Hub** bleibt zunächst Top-Level, weil
  Cross-Person-Touchpoint-Log für CDs hilfreich ist. Kann nach MVP-Launch
  reduziert werden auf "nur Aktivitäts-Tab im Adressbuch", wenn die
  Aktivitäts-Sortierung gut genug funktioniert.
- **Quality-Score** verschoben auf später (siehe 6.5).
- **iOS-App-Migration** — separater Spec, blockiert nicht das Web-Release.
- **Owner-FK** verweist auf `contacts(id)` (siehe 3.1). Validierungs-Trigger
  prüft dass der referenzierte Contact die Rolle `'instructor'` hat.

---

## 9. Implementierungs-Reihenfolge (High-Level)

1. **Phase M1** — Schema + Backfill + Dedup-Audit (1 Tag)
2. **Phase M2** — Compatibility-Views + pgTAP-Tests (1 Tag)
3. **Phase M3.1** — `ContactDetailPanel` (universell, adaptive Tabs) als
   neue Komponente, **parallel** zu existierenden DetailPanels (1-2 Tage)
4. **Phase M3.2** — Adressbuch-Screen (Master-Detail mit Saved Views) (1 Tag)
5. **Phase M3.3** — Schritt-für-Schritt Migration aller existierenden
   Personen-Listen auf neuen DetailPanel: StudentsScreen, InstructorsScreen,
   PipelineScreen, CommunicationHubScreen, SkillMatrixScreen,
   CourseDetailPanel-Subviews (3-5 Tage)
6. **Phase M3.4** — Inline-Edit-Migration: alte `*EditSheet`-Komponenten
   abbauen (1-2 Tage)
7. **Phase M3.5** — Audit, GDPR-Aktionen, Dedup-Workflow, Verschmelzen-Sheet
   (2 Tage)
8. **Phase M3.6** — FK-Spalten umbenennen, Views droppen (0.5 Tage)
9. **90 Tage Beobachtung**, dann Legacy-Tabellen droppen

**Gesamt-Aufwand:** ca. 11–14 Arbeitstage über 3–4 Wochen.

---

## 10. Erfolgs-Kriterien

- Eine zentrale Tabelle (`contacts`) statt drei (`instructors`, `people`,
  `organizations`)
- Ein universeller Detail-Panel statt fünf
- Inline-Edit überall — `*EditSheet`-Code-Anteil sinkt um >70%
- Doppelerfassung "TL als Schüler" eliminiert
- Lifecycle-Übergang Kandidat→Instructor ohne Datenbruch
- Voll-CRM-Scope (Lieferanten, Partner, Behörden, Newsletter) abgebildet
- DSGVO-konform (Consent, RtbF, Data-Export, Audit)
- Migration ohne Datenverlust, mit vollständigem Rollback bis Phase M2
