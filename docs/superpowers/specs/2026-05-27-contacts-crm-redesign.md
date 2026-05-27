# Adressverwaltung CRM-Modernisierung — Phase G

**Status:** Draft (User-Review pending)
**Date:** 2026-05-27
**Author:** Dominik Weckherlin (with Claude)
**Spec Owner:** Dominik
**Target Release:** v5.1
**Builds on:** [2026-05-09-adressverwaltung-design.md](./2026-05-09-adressverwaltung-design.md) (Phase F1 — Unified Contacts + Sidecars)

---

## 1. Kontext & Problem

### Heutiger Zustand (nach Phase F1)

Phase F1 hat die Datenarchitektur vereinheitlicht:

- Unified `contacts` Tabelle ✅ gebaut
- Rollenbasierte Sidecars (Student/Instructor/Org) ✅ gebaut
- n:m-Relationships zwischen Contacts ✅ gebaut
- Universal `ContactDetailPanel` mit 15 Tabs ✅ gebaut
- `AddressbookScreen` master-detail mit 8 Saved Views ✅ gebaut
- TanStack-Query-Migration über alle Sheets und Tabs ✅ gebaut

Architektonisch sauber — UX-Erlebnis aber noch unter CRM-Niveau.

### Pain-Points

1. **Tabs-zentriertes Detail-Panel.** Mails, Notizen, Anrufe, Kurs-Events leben in
   getrennten Tabs (`CommunicationsTab`, `NotesAndDocsTab`, `ActivityTab`,
   `AuditHistoryTab`). Kein einheitlicher chronologischer Feed.

2. **Keine Properties-Sidebar.** Saldo, Pipeline-Stage, letzter Kontakt sind nur
   sichtbar wenn man den richtigen Tab öffnet. Für CRM-typische
   At-a-glance-Workflows („Saldo prüfen während Mail tippen") fehlt der
   Always-on-Context.

3. **Listenansicht ist puristisch.** Zeigt nur Avatar + Name + Rollen. Keine
   konfigurierbaren Spalten, keine Filter-Chips (nur die 8 Saved-Views-Tabs),
   keine Bulk-Actions, kein Sort-by-Header, keine Density-Optionen.

4. **`CommunicationHubScreen` als separater Screen** fühlt sich abgekoppelt vom
   Adressbuch. User wechselt mental zwischen „Adressbuch" und „Kommunikation",
   obwohl beide dieselben Personen betreffen.

5. **WhatsApp als wichtiger Channel** hat keinen first-class Slot — Touchpoints
   werden in `communications` als generische `channel='other'` geloggt.

### Ziel

Eine professionelle, CRM-typische Adressverwaltung im **HubSpot-Stil**:

- **ContactDetailPanel** 3-Pane: Liste · Activity-Timeline (Center) · Properties-Sidebar (rechts, collapsible)
- **Quick-Actions** prominent oben (Mail, Notiz, Anruf, Termin, Task, WhatsApp)
- **AddressbookScreen** mit Spalten, Filter-Chip-Bar, Bulk-Selection, Sortierung, Density-Toggle, User-Custom-Saved-Views
- **`CommunicationHub` aufgelöst** in globalen „Aktivität"-Feed
- **Hybrid-Datenmodell:** eigene `contact_events`-Tabelle für User-Logs, System-Events bleiben in Source-Tables, View `v_contact_timeline` unioniert beides

### Nicht-Ziel (in dieser Phase)

- **Pipeline-Screen** (`CDPipelineScreen`) auf neuen Stil ziehen — separater Spec
- **Sheets-Konsolidierung** (Create/Edit/Merge-Flows einheitlich) — separater Spec
- **Card-Inbox in Activity-Timeline integrieren** — separater Spec; Foundation hier ermöglicht es
- **WhatsApp-Business-API-Integration** für auto-generierte Events — Phase G hat nur User-Logged WhatsApp; API-Anbindung folgt
- **Mobile/iOS-App-Anpassung** — atoll-ios bleibt unverändert

---

## 2. Designentscheidungen (im Brainstorming-Dialog festgelegt)

| # | Frage | Gewählt | Begründung |
|---|---|---|---|
| 1 | CRM-DNA? | **HubSpot — Activity-first** | Vertraut, ruhig, actionable; Properties immer sichtbar |
| 2 | Scope? | **ContactDetailPanel + AddressbookScreen + CommHub-Auflösung** | Pipeline und Sheets-Konsolidierung später |
| 3 | Layout? | **A — Klassisch 3-Pane** (Liste · Timeline · Sidebar) | Standard-CRM-Muster, mobile-friendly Reduktion möglich |
| 4 | Sidebar collapsible? | **Ja**, via `⟶`-Toggle, Zustand in localStorage | Beim Mail-Komponieren mehr Platz |
| 5 | Timeline-Events? | 8 System + 5 User + WhatsApp | Siehe §4 |
| 6 | Bulk-Action-Prio? | **Tags · Pipeline-Stage · Massen-Mail** | Front-and-center in Action-Bar |
| 7 | Default-Density? | **Comfortable (44px)** | Lesefreundlicher als Compact-Default |
| 8 | Datenmodell? | **C — Hybrid** | User-Logs in eigener Tabelle + View über Source-Tables |
| 9 | Sidebar-Label? | **„Aktivität"** | i18n: de „Aktivität", en „Activity", fr „Activité" |
| 10 | Rollout? | **6 Phasen** hinter `crm_v2`-Feature-Flag | Jede Phase eigenständig deploybar |

---

## 3. Layout & Information Architecture

### 3.1 Drei-Pane-Struktur

```
┌────────────────┬─────────────────────────────────┬──────────────────┐
│ Liste (~280px) │ Timeline-Center (flex)          │ Sidebar (~280px) │
│                │                                 │                  │
│ Search +       │ Header: Name · Quick-Actions    │ Sticky-Top:      │
│ Saved Views    │ ─────────────────────────────── │ Avatar + Roles   │
│ ─────────────  │ Composer (sticky)               │ + CTA            │
│ Filter-Chips   │ ─────────────────────────────── │ ───────────────  │
│ ─────────────  │ Filter-Chips                    │ Stat-Band 4-Tile │
│ List-Rows      │ ─────────────────────────────── │ ───────────────  │
│ ...            │ Timeline-Cards (scroll)         │ 7 Sektionen      │
│                │ ...                             │ (collapsible)    │
└────────────────┴─────────────────────────────────┴──────────────────┘
```

- Liste links und Sidebar rechts haben **eigenständigen Scroll**, Timeline-Center scrollt unabhängig.
- Min-Width für 3-Pane: **1280px**. Unter 1280px collapsiert die Sidebar default.
- Unter 1024px wird Liste zu Slide-Over-Drawer (`☰`-Toggle).

### 3.2 Sidebar-Toggle

- `⟶`-Button rechts in Detail-Panel-Header
- Klick → Sidebar collapsed (Breite 0), Timeline nimmt vollen Platz
- Klick auf `⟵` an gleicher Stelle → expandiert zurück
- Persistiert in `localStorage` als `contactDetail.sidebarOpen` (default `true`)

---

## 4. Timeline — Events & Composer

### 4.1 System-generierte Events (lesen aus Source-Tables)

| Event-Typ | Source-Table (verifiziert) | Icon (Tabler) | Beispiel-Summary |
|---|---|---|---|
| `course_enrollment` | `course_participants` JOIN `courses` | `ti-school` | „Eingeschrieben in OWD #2456 (08.06.2026)" |
| `certification_issued` | `certifications` (Migration 0028) | `ti-certificate` | „AOWD zertifiziert" |
| `saldo_movement` | `account_movements` (Migration 0012) | `ti-cash` | „+CHF 480 (Einzahlung)" |
| `pipeline_change` | trigger-gefütterte Audit-Spur via `sync_pipeline_stage_changed` (Migration 0048) — Phase 1 entscheidet ob eigene Tabelle oder Filter über bestehenden Audit-Stream | `ti-arrow-right` | „Lead → Qualified" |
| `intake_checkpoint` | `intake_checklists`-Familie (Migration 0050) — konkrete Detail-Tabelle in Phase 1 verifizieren | `ti-checkbox` | „Tauchmedizinische Untersuchung gesichtet" |
| `skill_checked` | `padi_skill_records` (Migration 0090) | `ti-anchor` | „OWD Skill 5 — Mask Clear (TL: Max M.)" |
| `card_lead_imported` | `card_leads` (via `imported_contact_id`, Migration 0105) | `ti-id-badge` | „Erste Berührung via AtollCard (test.com-Kampagne)" |
| `role_change` | `audit_log` (gefiltert auf Rollen-Felder) | `ti-user-cog` | „Wurde Instructor" |
| `audit_edit` | `audit_log` (gefiltert auf PII-Felder: email, phone) | `ti-edit` | „Email geändert" |

**Schema-Verifikation in Phase 1:** die UNION-Joins im View `v_contact_timeline` brauchen das post-F1-Schema. Speziell: nach der `students → contacts`-Migration sind FKs eventuell auf `contacts.id` umgebogen — Phase 1 startet mit kurzem Schema-Audit und passt die UNION-SELECTs entsprechend an. Auch zu klären: existiert nach Phase F1 ein `contact_balance`-View (analog zum bestehenden `instructor_balance` aus Migration 0014), oder muss der noch gebaut werden?

### 4.2 User-geloggte Events (`contact_events`-Tabelle)

| Typ | Composer-Fields | Payload-JSON |
|---|---|---|
| `note` | `body` (Markdown-Textarea) | — |
| `call` | `summary`, `duration_min` (optional), `occurred_at` (default now) | `{duration_min, direction}` |
| `email_external` | `summary`, `subject`, `occurred_at` | `{subject, direction}` |
| `meeting_past` | `summary`, `occurred_at`, `duration_min` | `{duration_min, location?}` |
| `task` | `title` (→ summary), `due_date`, `reminder?` | `{due_date, reminder_at, completed_at}` |
| `whatsapp_log` | `summary`, `direction` (sent/received), `occurred_at` | `{direction}` |

`task` ist insofern speziell, als es offen sein kann (`status='open'`) und mit `due_date` einen zukünftigen Anker hat. Offene Tasks erscheinen zusätzlich im Stat-Band als „Nächste Action".

### 4.3 Composer-UI

Sticky-Bar oben im Timeline-Pane:

```
┌─────────────────────────────────────────────────────────────────┐
│ [Notiz] [Anruf] [Mail] [Meeting] [Task] [WhatsApp]              │
│ ─────────────────────────────────────────────────────────────── │
│ <expandierte Inline-Form für aktiven Slot>                      │
│                                          [Cancel] [Speichern]   │
└─────────────────────────────────────────────────────────────────┘
```

- Segmented Control (`ti-*`-Icons + Label)
- Aktiver Slot → expandiert Inline-Form
- Save: optimistic insert in Timeline + invalidate `useContactTimeline`-Query
- Cancel: Form collapsiert, kein Verlust wenn versehentlich
- Keyboard: `Esc` cancelt, `Cmd+Enter` speichert

### 4.4 Filter-Chips (über Timeline)

```
Alle · System · User-Logs · Mails · Notizen · Anrufe · WhatsApp · Tasks · Kurse · Saldo · Pipeline
```

- Klick toggelt; Mehrfachauswahl als OR-Filter
- URL-Param `?timeline-filter=user-logs,whatsapp` (kombinierbar)

---

## 5. Properties Sidebar

### 5.1 Sticky-Top (immer sichtbar)

- Avatar (40px) · Vor- + Nachname (font-weight 500, 16px) · Pronomen (caption)
- Rollen-Badges (horizontal, wrap wenn mehr als 3 → vertikal stacked)
- Primary CTA: **„Bearbeiten"**-Button (öffnet bestehendes Edit-Sheet) + ⋯-Dropdown

⋯-Dropdown enthält:
- Merge mit anderem Contact
- Archivieren / Reaktivieren
- PADI Referral PDF generieren (bestehende Funktion)
- Löschen (mit Confirm)

### 5.2 Stat-Band (1 Zeile, 4 Mini-Tiles)

| Tile | Quelle | Format | Sichtbar wenn |
|---|---|---|---|
| Saldo | `contact_balance` view (Phase 1: prüfen ob existiert oder als View bauen, analog `instructor_balance` aus Migration 0014) | CHF · color-coded | Rolle ist saldo-relevant |
| Aktive Kurse | `course_participants` count, gefiltert auf laufende Kurse | Zahl + „aktiv" | Immer (auch wenn 0) |
| Letzter Kontakt | `MAX(occurred_at)` aus `v_contact_timeline` | relative („vor 3 Tagen") | Immer |
| Nächste Action | `MIN(due_date)` aus offenen Tasks in `contact_events` | relative („in 2 Tagen") | Wenn offene Task |

### 5.3 Aufklappbare Sektionen

In dieser Reihenfolge, mit Default-Zustand:

| # | Sektion | Default | Inhalt |
|---|---|---|---|
| 1 | Kontakt | offen | Email, Telefon, WhatsApp, Bevorzugter Kanal, Sprache |
| 2 | Rollen & Status | offen | Role-aware: Pipeline-Stage (Lead), Intake-Status (Kandidat), Aktiv-Flag (Instructor), Letztes Brevet (Student) |
| 3 | Organisation & Beziehungen | geschlossen | Org-Zugehörigkeit, Partner, Familie, Buddy |
| 4 | Tags | geschlossen | Freie Labels, klickbar → filtert Adressbuch |
| 5 | Key Dates | geschlossen | Created, letzter Kontakt, nächster Follow-up, Geburtstag, Zertifizierungs-Daten |
| 6 | PADI-Spezifika | geschlossen | `pro_number`, `member_status`, `spec_count` — nur bei Rollen Student/Instructor |
| 7 | Quelle & Audit | geschlossen | Angelegt via (Card-Inbox/Excel/manuell), Owner, letzte Bearbeitung |

### 5.4 Inline-Edit-Verhalten

- Klick auf Wert → wird zum entsprechenden Input (Text/Phone/Email/Date/Select)
- `Tab` oder `Enter` → optimistic update via TanStack-Mutation
- `Esc` → cancel, Originalwert zurück
- Validierung: Email-Regex, Phone E.164 (libphonenumber-js, schon im Stack), Date-Format
- Bei Server-Fehler: roter Border + Toast mit Message, Wert bleibt im Input zum Korrigieren

---

## 6. AddressbookScreen — Listenansicht

### 6.1 Spalten (Defaults)

Bei Default-Density (Comfortable, 44px Row-Height):

1. ☑ Checkbox (für Bulk-Select)
2. Avatar (24px) + Name + Primary-Role (z.B. „Hugo Eugster · Student")
3. Rollen-Dots (alle weiteren Rollen als farbige Punkte, max 5 sichtbar + „+N")
4. Email
5. Telefon
6. Letzter Kontakt (relative: „vor 3 Tagen")
7. Saldo (CHF, rechtsbündig — nur wenn Rolle saldo-relevant; sonst leer)
8. Tags (chips, max 3 sichtbar + „+N")
9. ⋯ (Row-Action-Menü)

### 6.2 Column-Picker

Topbar-Icon `ti-adjustments`. Öffnet Dropdown mit allen verfügbaren Spalten als Checkboxes. Zusätzlich verfügbar:

- Org-Zugehörigkeit
- Pipeline-Stage
- Sprache
- Quelle (Card-Inbox / Excel-Import / manuell)
- Geburtstag
- Nächster Follow-up
- PADI-Nummer
- Skills (chip-summary)
- Erstellt-am

Column-Order und Sichtbarkeit persistiert in localStorage; per User-Custom-View überschreibbar (siehe §6.6).

### 6.3 Filter-Chip-Bar

Über der Liste, zusätzlich zu den Saved-Views-Tabs:

```
Rolle ▾  ·  Tag ▾  ·  Status ▾  ·  Pipeline ▾  ·  Letzter Kontakt ▾  ·  Saldo ▾  ·  Sprache ▾  ·  Quelle ▾   [Filter zurücksetzen]
```

- Filter AND-kombiniert
- Aktive Filter = farbiger Chip + Wert; inaktive = grauer Outline-Chip
- URL-Param-persistiert: `?filter=role:instructor,tag:vip,saldo:negative` (deep-linkable, shareable)

### 6.4 Bulk-Selection

- Checkbox-Spalte pro Row
- Header-Checkbox selektiert alle gefilterten Treffer (mit Confirm wenn >100)
- Wenn ≥1 selektiert: Slide-in Action-Bar am unteren Rand mit Counter („3 ausgewählt")

Action-Bar Layout (Top-3 prominent, Rest unter ⋯):

```
[3 ausgewählt]  [+ Tags ▾]  [Pipeline ▾]  [✉ Massen-Mail]  [⋯]   [✕ Auswahl aufheben]
```

⋯ enthält: Aktiv/Inaktiv setzen · Export CSV · Zu Saved View hinzufügen · Archivieren

### 6.5 Sortierung

- Klick auf Spaltenkopf → sortiert auf-/absteigend
- Shift-Klick → Multi-Sort (zweiter Sort-Schlüssel)
- Pfeil-Icon im Header zeigt aktive Sort-Richtung
- Sortierbar: Name · Letzter Kontakt · Saldo · Erstellt
- URL-Param: `?sort=last_contact:desc,name:asc`

### 6.6 Saved Views

Die 8 Built-ins bleiben (`All`, `Persons`, `Orgs`, `Students`, `Candidates`, `Team`, `Suppliers`, `Newsletter`).

**Neu:** User-Custom-Views — Kombination aus Filter + Columns + Sort + Density. Speicherbar via „Diese Ansicht speichern…"-Button rechts oben.

Custom-Views erscheinen in Dropdown neben den Built-in-Tabs. Persistiert in neuer Tabelle `contact_saved_views`:

```sql
CREATE TABLE public.contact_saved_views (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  filter      JSONB NOT NULL,    -- {roles, tags, status, ...}
  columns     JSONB NOT NULL,    -- ordered visible columns
  sort        JSONB NOT NULL,    -- [{column, direction}, ...]
  density     TEXT NOT NULL DEFAULT 'comfortable' CHECK (density IN ('compact', 'comfortable')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_contact_saved_views_user ON public.contact_saved_views(user_id);

ALTER TABLE public.contact_saved_views ENABLE ROW LEVEL SECURITY;

CREATE POLICY contact_saved_views_owner ON public.contact_saved_views
  FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
```

### 6.7 Density-Toggle

Topbar-Icon `ti-baseline-density-medium` ↔ `ti-line-height`:

- **Compact:** 32px Row-Height, kleinere Schrift (13px), engerer Padding
- **Comfortable:** 44px Row-Height, normale Schrift (14px), luftiger Padding

Default: Comfortable. Persistiert in localStorage (`addressbook.density`).

### 6.8 Row-Hover Quick-Actions

Bei Hover erscheinen rechts in der Row (vor ⋯) Icon-Buttons:

- `ti-mail` Quick-Mail → öffnet Composer mit Empfänger vorbefüllt
- `ti-note` Quick-Note → öffnet inline Notiz-Form
- `ti-phone` Quick-Call → öffnet inline Anruf-Log-Form
- `ti-edit` Edit → öffnet bestehendes Edit-Sheet

---

## 7. „Aktivität"-Screen (globaler Activity-Feed)

### 7.1 Route + Sidebar

- Neue Route: `/aktivitaet`
- Sidebar-Eintrag „Aktivität" (rename von „Communication Hub")
- i18n-Keys: `nav.activity` → de „Aktivität", en „Activity", fr „Activité"

### 7.2 Layout

Volle Breite, kein Master-Detail (Klick auf Card → Navigation zu Contact-Detail mit Event-Highlighting):

```
┌──────────────────────────────────────────────────────────────────┐
│ Topbar: Filter-Bar                                               │
│ ──────────────────────────────────────────────────────────────── │
│ Composer (sticky, mit Pflichtfeld „Welcher Contact?")            │
│ ──────────────────────────────────────────────────────────────── │
│ Event-Karten chronologisch (alle Contacts gemischt)              │
│ ...                                                              │
└──────────────────────────────────────────────────────────────────┘
```

### 7.3 Filter-Bar

- Event-Typ (multi-pill, gleiche Werte wie Timeline-Filter)
- Channel (Email · Anruf · WhatsApp · Notiz · Meeting · Task)
- Owner: Mein vs. Team
- Date-Range (Today · Gestern · Letzte 7 Tage · Letzte 30 Tage · Custom)
- Tag
- Status: Unbeantwortet (Heuristik: Mail mit `direction='inbound'`, keine outbound-Response nach `occurred_at`)

### 7.4 Event-Karten

Identische Komponente wie in Contact-Timeline (§4), zusätzlich rechts in jeder Karte:

```
→ Contact-Avatar + Name (klickbar → öffnet ContactDetailPanel mit ?event=<id>)
```

### 7.5 Inbox-Triage-Mode (Phase 5b — optional)

Toggle „Triage" oben rechts. Aktiviert:

- `j`/`k` navigiert vertikal durch Karten (Fokus-Indikator)
- `e` archiviert die fokussierte Karte (= status='resolved')
- `r` öffnet Reply-Composer mit Contact + Vorbelegung
- `x` selektiert/deselektiert für Bulk-Action
- `Cmd+A` selektiert alle sichtbaren

Triage ist optional in Phase 5 — kann auch in Phase 5b als Nachzügler.

---

## 8. Datenmodell

### 8.1 Neue Tabelle: `contact_events`

```sql
CREATE TABLE public.contact_events (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_id   UUID NOT NULL REFERENCES public.contacts(id) ON DELETE CASCADE,
  event_type   TEXT NOT NULL CHECK (event_type IN (
    'note', 'call', 'email_external', 'meeting_past', 'task', 'whatsapp_log'
  )),
  occurred_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  actor_id     UUID REFERENCES public.contacts(id),
  summary      TEXT NOT NULL,
  body         TEXT,
  payload      JSONB,
  status       TEXT NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'resolved', 'archived')),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_contact_events_contact_occurred
  ON public.contact_events(contact_id, occurred_at DESC);

CREATE INDEX idx_contact_events_actor_occurred
  ON public.contact_events(actor_id, occurred_at DESC)
  WHERE actor_id IS NOT NULL;

CREATE INDEX idx_contact_events_open_tasks
  ON public.contact_events(contact_id, (payload->>'due_date'))
  WHERE event_type = 'task' AND status = 'open';

ALTER TABLE public.contact_events ENABLE ROW LEVEL SECURITY;
```

### 8.2 RLS

```sql
CREATE OR REPLACE FUNCTION public.is_contact_owner(p_contact_id UUID)
RETURNS BOOLEAN
LANGUAGE SQL STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.contact_instructor
    WHERE contact_id = p_contact_id
      AND auth_user_id = auth.uid()
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_contact_owner(UUID) TO authenticated;

CREATE POLICY contact_events_owner ON public.contact_events
  FOR ALL TO authenticated
  USING (public.is_contact_owner(contact_id))
  WITH CHECK (public.is_contact_owner(contact_id));
```

Falls bereits ein vergleichbarer Owner-Helper für Contacts existiert (Phase F1 hat solche Pattern angelegt), wird der wiederverwendet — in Phase 1 verifizieren und ggf. konsolidieren.

### 8.3 Unified View: `v_contact_timeline`

```sql
CREATE OR REPLACE VIEW public.v_contact_timeline AS
-- User-logged events
SELECT
  e.id                  AS event_id,
  e.contact_id,
  e.event_type,
  e.occurred_at,
  e.actor_id            AS actor_contact_id,
  e.summary,
  e.body,
  e.payload,
  e.status,
  'contact_events'::text AS source_table,
  e.id                  AS source_id
FROM public.contact_events e

UNION ALL

-- System events: Kurs-Teilnahmen (Tabelle: course_participants nach Phase 1 Audit)
SELECT
  cp.id, cp.contact_id, 'course_enrollment'::text,
  cp.created_at, NULL::uuid,
  'Eingeschrieben in ' || c.code, NULL::text,
  jsonb_build_object('course_id', cp.course_id, 'course_code', c.code),
  'open'::text, 'course_participants'::text, cp.id
FROM public.course_participants cp
JOIN public.courses c ON c.id = cp.course_id

UNION ALL

-- System events: weitere SELECT-Blöcke für certifications, account_movements,
-- pipeline-Wechsel (via audit_log oder eigene Tabelle — Phase 1),
-- intake-Checkpoints (intake_checklists-Familie), padi_skill_records,
-- card_lead-Imports, audit-Edits auf PII-Feldern.
-- Exakte Joins/Filter werden im Phase-1-Schema-Audit fixiert.
;

ALTER VIEW public.v_contact_timeline SET (security_invoker = on);
GRANT SELECT ON public.v_contact_timeline TO authenticated;
```

### 8.4 Pagination-Strategie

Cursor-basiert auf `(occurred_at, event_id)`:

```typescript
function useContactTimeline(contactId: string, filter?: TimelineFilter) {
  return useInfiniteQuery({
    queryKey: ['contact-timeline', contactId, filter],
    queryFn: async ({ pageParam }) => {
      let q = supabase
        .from('v_contact_timeline')
        .select('*')
        .eq('contact_id', contactId)
        .order('occurred_at', { ascending: false })
        .order('event_id', { ascending: false })
        .limit(50)
      if (pageParam) {
        q = q.or(`occurred_at.lt.${pageParam.occurred_at},and(occurred_at.eq.${pageParam.occurred_at},event_id.lt.${pageParam.event_id})`)
      }
      // apply filter
      return await q
    },
    getNextPageParam: (lastPage) => {
      const last = lastPage.data?.at(-1)
      return last ? { occurred_at: last.occurred_at, event_id: last.event_id } : undefined
    },
  })
}
```

### 8.5 Performance-Erwartung

- 1000 Contacts × 50 Events ≈ 50k View-Rows
- Mit `contact_id`-Filter + DESC-Sort + LIMIT 50 → unter 50ms erwartet (Indexe pro Source-Table vorhanden bzw. werden in Phase 1 ergänzt)
- Globaler Feed (`/aktivitaet`) ohne `contact_id`-Filter könnte langsamer werden bei wachsenden Daten — falls Skalierungsproblem, in Phase 7+ Materialisierung via `pg_cron` evaluieren. Out of scope für Phase G.

### 8.6 Audit & DSGVO

- `contact_events` ist Audit-relevant — Owner-only-Read via RLS
- Bei Contact-Löschung: `ON DELETE CASCADE` von `contact_events` weg
- Body-Felder können sensitive Infos enthalten — keine Index-Storage in Plaintext, kein Export ohne Owner-Auth

---

## 9. Komponenten-Struktur

```
apps/web/src/screens/contacts/
  ContactDetailPanel.tsx                # refactor — neuer 3-Pane-Frame
  ContactDetailHeader.tsx               # NEU
  timeline/
    TimelineFeed.tsx                    # NEU
    EventComposer.tsx                   # NEU
    EventCard.tsx                       # NEU (polymorphic per event_type)
    TimelineFilterBar.tsx               # NEU
    composers/
      NoteComposer.tsx                  # NEU
      CallComposer.tsx                  # NEU
      EmailLogComposer.tsx              # NEU
      MeetingComposer.tsx               # NEU
      TaskComposer.tsx                  # NEU
      WhatsAppLogComposer.tsx           # NEU
  sidebar/
    PropertiesSidebar.tsx               # NEU
    StatBand.tsx                        # NEU
    SidebarSection.tsx                  # NEU (collapsible primitive)
    sections/
      ContactSection.tsx                # NEU
      RolesStatusSection.tsx            # NEU
      OrgRelationsSection.tsx           # NEU
      TagsSection.tsx                   # NEU
      KeyDatesSection.tsx               # NEU
      PadiSection.tsx                   # NEU
      SourceAuditSection.tsx            # NEU
  tabs/                                 # bestehend — Secondary-Tabs
    # ActivityTab.tsx, CommunicationsTab.tsx, NotesAndDocsTab.tsx
    # werden in Phase 6 entfernt (durch Timeline ersetzt)
    # Restliche Tabs (Student, Instructor, Saldo, Courses, Skills, etc.) bleiben
  AddressbookScreen.tsx                 # refactor — Spalten, Filter, Bulk
  AddressbookColumns.tsx                # NEU
  AddressbookFilterBar.tsx              # NEU
  AddressbookBulkActionBar.tsx          # NEU
  SavedViewDropdown.tsx                 # NEU
  ColumnPicker.tsx                      # NEU

apps/web/src/screens/activity/
  ActivityScreen.tsx                    # NEU
  ActivityFilterBar.tsx                 # NEU
  TriageMode.tsx                        # NEU (Phase 5b optional)

apps/web/src/hooks/
  useContactTimeline.ts                 # NEU
  useGlobalActivity.ts                  # NEU
  useEventComposer.ts                   # NEU
  useContactSavedViews.ts               # NEU
  useAddressbookColumns.ts              # NEU (localStorage + saved-view)

apps/web/src/lib/
  contactEventQueries.ts                # NEU
```

---

## 10. Rollout-Phasen

Hinter `crm_v2`-Feature-Flag in 6 Phasen.

### Phase 1 — Foundation (1-2 Tage)

- Migration `contact_events` (Tabelle + Constraints + Indexe)
- Migration `is_contact_owner()` Helper (oder bestehenden konsolidieren)
- Migration `v_contact_timeline` View (mit allen System-Event-UNIONs; Quelltabellen verifizieren)
- Migration `contact_saved_views` Tabelle + RLS
- Hooks: `useContactTimeline`, `useGlobalActivity`, `useEventComposer`
- `lib/contactEventQueries.ts` mit allen CRUD-Funktionen

**Verifikation:** PgTAP für RLS auf `contact_events` und `contact_saved_views`, Vitest für Query-Funktionen, smoke-test View-Query via Supabase-Dashboard.

### Phase 2 — Detail-Panel: Timeline + Composer (3-4 Tage)

Hinter `crm_v2`-Flag:
- Refactor `ContactDetailPanel` zu 3-Pane-Frame
- `ContactDetailHeader` mit Quick-Actions
- `TimelineFeed` mit `EventCard` (polymorphic per event_type)
- `EventComposer` mit segmented control + 6 Composer-Komponenten
- `TimelineFilterBar`
- Bestehende Tabs (ActivityTab, CommunicationsTab, NotesAndDocsTab) bleiben **parallel** sichtbar zur Sicherheit

**Verifikation:** Vitest für Composer-State, Playwright-E2E `log note → erscheint in timeline → reload → noch da`.

### Phase 3 — Detail-Panel: Properties Sidebar (2-3 Tage)

- `PropertiesSidebar` mit Sticky-Top + Stat-Band
- `SidebarSection` collapsible primitive
- 7 Sektionen-Komponenten
- Inline-Edit-Infrastruktur (TanStack-Mutation pro Feld, optimistic update)
- Role-aware visibility (PADI-Sektion nur bei Student/Instructor)
- Sidebar-Toggle mit localStorage-Persistence

**Verifikation:** Vitest für Inline-Edit-State, manueller Test pro Role-Variante.

### Phase 4 — AddressbookScreen-Liste-Refresh (3-4 Tage)

- Spalten + `ColumnPicker`
- `AddressbookFilterBar` mit URL-Param-Sync
- `AddressbookBulkActionBar` (Slide-in)
- Sort-Header mit Multi-Sort
- Density-Toggle
- User-Custom-Saved-Views via `useContactSavedViews`
- Row-Hover Quick-Actions

**Verifikation:** Vitest für Filter-State, Playwright-E2E `select 3 → tag „VIP" → alle 3 haben Tag`, manueller Test der URL-Param-Persistierung.

### Phase 5 — „Aktivität"-Screen + Sidebar-Rename (2-3 Tage)

- `ActivityScreen` mit `ActivityFilterBar`
- Sidebar `Communication Hub` → `Aktivität` (i18n-Update)
- Route `/aktivitaet` registrieren
- Alte Route `/communication-hub` redirected auf `/aktivitaet` (1 Release lang)
- `CommunicationHubScreen.tsx` deprecaten (Datei bleibt im Repo bis Phase 6)

**Phase 5b (optional):** `TriageMode` mit Keyboard-Shortcuts. Kann auch in Folge-Spec.

**Verifikation:** Playwright-E2E `klick Event-Card → öffnet Contact-Detail mit highlighting`.

### Phase 6 — Flag-Flip + Cleanup (1 Tag)

- `crm_v2`-Flag entfernen (alle Code-Pfade unconditionally neu)
- Alte Tabs entfernen: `ActivityTab`, `CommunicationsTab`, `NotesAndDocsTab`
- `CommunicationHubScreen` löschen
- Doku-Update: README, CHANGELOG, Migration-Notes
- Memory-Update für künftige Sessions (Phase G abgeschlossen)

**Verifikation:** typecheck + alle Tests grün, manueller Safari/Chrome Smoke-Test in Production-Preview, Lighthouse-Check der Detail-Panel-Performance.

---

## 11. Error-Handling & Loading-States

| Situation | Behandlung |
|---|---|
| Timeline lädt | Skeleton-Cards (3 Stück, animiert) |
| Timeline empty | EmptyState mit Composer-Hinweis („Erste Notiz erfassen") |
| Timeline-Query-Failure | Error-Card mit Retry-Button + Toast |
| Composer-Submit ok | Optimistic insert; auf Error-Response → undo + Toast |
| Inline-Edit ok | Optimistic update; auf Error → Border rot + Tooltip mit Message |
| Sidebar-Section-Failure (z.B. Saldo lädt nicht) | Section zeigt „—" + Retry-Icon, andere Sections funktionieren weiter |
| List-Query-Failure | Full-page EmptyState mit Retry-Button |
| Bulk-Action partial-Failure | Toast mit „3 von 5 ok, 2 mit Fehler — Details" und Logging-Button |

---

## 12. Testing

### PgTAP (Phase 1)
- `contact_events_owner` RLS: Owner darf lesen/schreiben, anderer User darf nicht
- `v_contact_timeline` korrekte UNION-Ergebnisse pro Contact
- `contact_saved_views_owner` RLS Isolation

### Vitest (Phase 2-6)
- `useContactTimeline` Hook: Pagination-Cursor, Filter-Anwendung
- `EventComposer` Form-State: Validierung, optimistic insert
- `useAddressbookColumns` localStorage-Sync
- Filter-Bar URL-Param-Serialisierung

### Playwright E2E (Phase 2, 4, 5)
- `log note → erscheint in timeline → reload → noch da`
- `select 3 contacts → bulk-tag „VIP" → alle 3 haben Tag`
- `Aktivität-Screen → klick Event → öffnet Detail-Panel mit Highlighting`

---

## 13. Open Questions (Phase-1-Schema-Audit)

Alle Design-Entscheidungen sind geklärt. Diese **Schema-Verifikations-Punkte** stehen als erste Task in Phase 1 an, bevor der View `v_contact_timeline` geschrieben wird:

1. **`course_participants` vs. `course_assignments`** — welche Tabelle ist nach Phase F1 die kanonische Quelle für „Contact ist in Kurs X eingeschrieben"? Wahrscheinlich `course_participants` (Migration 0027), aber FK könnte nach Phase F1 von `students.id` auf `contacts.id` umgebogen sein.

2. **Pipeline-Stage-History** — der bestehende Trigger `sync_pipeline_stage_changed` (Migration 0048) feuert auf `students`. Schreibt er aktuell in eine eigene Tabelle, oder muss eine `pipeline_history`-Tabelle in Phase 1 mit angelegt werden? Wenn schon vorhanden: Spaltennamen verifizieren.

3. **`contact_balance`-View** — existiert ein unifizierter Saldo-View nach Phase F1, oder muss er als Sibling zum bestehenden `instructor_balance` (Migration 0014) noch gebaut werden?

4. **Intake-Checkpoints-Detail-Tabelle** — Migration 0050 hat `intake_checklists`. Sind die einzelnen Checkpoint-Abhakungen in einer Sub-Tabelle (`intake_checklist_entries` o.Ä.) oder als JSONB im Haupteintrag? Bestimmt die UNION-SELECT-Struktur.

5. **`audit_log`-Filter für Role-Changes und PII-Edits** — welche Feldnamen genau in der Audit-Log-Tabelle? `field_name`-Spalte mit Werten wie `'role'`, `'email'`, `'phone'`? Konkrete WHERE-Klausel.

6. **Owner-Helper-Konsolidierung** — gibt es bereits `is_contact_owner()` aus Phase F1 RLS-Setup, oder muss er neu gebaut werden? Wenn neu: ist `contact_instructor` das richtige Linking, oder gibt es nach Phase F1 ein direkteres Mapping?

Diese sechs Punkte sind das erste Deliverable in Phase 1 — Schema-Audit-Notes als kurzes Markdown-Doc, dann fließt das in die `v_contact_timeline`-Migration ein.

---

## Anhang: Beziehung zum 2026-05-09-Spec

Dieser Spec setzt direkt auf dem [2026-05-09-Adressverwaltung-Redesign](./2026-05-09-adressverwaltung-design.md) auf:

- **Phase F1** hat die Datenarchitektur vereinheitlicht (unified contacts, Sidecars, n:m-Relationships, universal ContactDetailPanel, AddressbookScreen master-detail) — ✅ gebaut.
- **Phase G** (dieser Spec) ist die UX-Modernisierung auf diesem Fundament — Timeline-zentriertes Detail-Panel, Properties-Sidebar, Listen-Refresh, CommHub-Auflösung.

Phase H+ (separate Specs): Pipeline-Refresh, Sheets-Konsolidierung, Card-Inbox-Integration in Activity-Timeline, WhatsApp-Business-API-Integration.
