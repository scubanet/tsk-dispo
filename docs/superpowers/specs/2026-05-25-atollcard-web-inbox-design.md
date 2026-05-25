# AtollCard Web-Inbox + Adressbuch-Import

**Status:** Draft (User-Review pending)
**Date:** 2026-05-25
**Author:** Dominik Weckherlin (with Claude/Larry)
**Spec Owner:** Dominik
**Target Release:** Welle A des AtollCard-Roadmap-Umbrellas (Web-Inbox + APNs scharf)
**Sub-Projekt:** 1 von 9 (siehe `docs/superpowers/specs/2026-05-25-atollcard-roadmap-umbrella.md`, sofern angelegt)

---

## 1. Kontext & Problem

### Heutiger Zustand

AtollCard (iOS, v0.4) empfängt Leads aus seiner Public-Card-Seite
(`https://atoll-os.com/c/<slug>`) direkt in der Tabelle `card_leads`. Die
iOS-App zeigt die Leads in einer Inbox mit Detail-Sheet, Status-Workflow
(`new` / `opened` / `contacted` / `imported` / `archived` / `spam`) und einem
Pseudo-CTA "In Adressbuch importieren", der heute ins Leere führt — die
Adressdatenbank (`contacts`-Tabelle) lebt in **Atoll OS Web**, nicht in der
iOS-App.

### Pain-Points

1. **Lead-Triage funktioniert auf iOS, Import nicht.** Der "→ ABook"-Button
   in `LeadDetailSheet.swift` ist Dead-End.
2. **Keine Web-Sicht auf Card-Leads.** Wer am Mac sitzt, muss in der
   iOS-App scrollen oder direkt in die `card_leads`-Tabelle im
   Supabase-Dashboard schauen.
3. **Adressbuch-Wachstum manuell.** Jeder eingegangene Lead wird, wenn
   überhaupt, von Hand abgetippt — Tipfehler, doppelte Einträge,
   verlorene Telefonnummern.
4. **Keine Provenance.** Nach Abtippen ist nicht mehr nachvollziehbar,
   welcher Contact aus welchem Card-Lead entstand.

### Zielbild

Im Web erscheint unter `ADRESSEN` ein neuer Sidebar-Eintrag **"Card-Inbox"**.
Master-Detail-Layout (konsistent mit dem bestehenden Adressbuch). Saved
Views nach Status, Realtime-Updates via Supabase Channel, Bulk-Triage.
Per-Lead-Aktion "In Adressbuch importieren" macht in einem RPC-Aufruf
einen neuen Contact, mergt bei Email-Match in einen bestehenden, schreibt
einen Audit-Trail in `contacts.notes`, und verlinkt Lead ↔ Contact
bidirektional.

Der iOS-Inbox-Detail-CTA wird zu einem Deep-Link auf den Web-Inbox-Screen
mit Auto-Selektion des angeklickten Leads.

---

## 2. Architektur-Entscheidung

**Single Source of Truth für Import-Logik: Web + Postgres-RPC.**

Begründung gegenüber Alternativen:

| Aspekt | Web-only (gewählt) | iOS-Import via REST | Beide |
|---|---|---|---|
| Dedup-Logik | einmal | duplikt | duplikt |
| Role-Tagging-Workflow | im Adressbuch-Kontext | weg vom Adressbuch | beide |
| Mobile-Use-Case | "View only, deep-link zum Web" | "Voll mobil" | beide |
| Wartungsaufwand | minimal | hoch | sehr hoch |
| Risiko inkonsistenter Implementierungen | kein | hoch | sehr hoch |

**Atomare Import-Logik in Postgres-RPC** (`import_card_lead(p_lead_id uuid)`)
statt clientseitiger Choreographie. Vorteile:

- Transaktionsgrenze klar (Contact-Mutation + Lead-Status-Update + Bridge
  in einem `BEGIN; ... COMMIT;`)
- SECURITY DEFINER kapselt RLS-Lookups einmal richtig
- Idempotent von Natur aus (RPC ruft auf bereits importierten Lead retourniert
  den bestehenden `contact_id`)
- Client (TypeScript) macht nur `supabase.rpc(...)`, kein Branching im JS

---

## 3. Schema-Änderung

### 3.1 Migration `0102_card_leads_imported_contact.sql`

Eine neue Spalte plus Helper-View für die Inbox-Liste.

```sql
-- Bridge-Spalte: welcher Contact wurde aus diesem Lead erstellt
ALTER TABLE public.card_leads
  ADD COLUMN IF NOT EXISTS imported_contact_id uuid
    REFERENCES public.contacts(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_card_leads_imported_contact
  ON public.card_leads(imported_contact_id)
  WHERE imported_contact_id IS NOT NULL;

-- Convenience-View für die Inbox-Liste (joined card-title + import-status)
CREATE OR REPLACE VIEW public.v_card_leads_inbox AS
SELECT
  l.id, l.card_id, l.first_name, l.last_name, l.email, l.phone,
  l.message, l.topic, l.captured_at, l.status, l.avatar_color,
  l.imported_to_address_book, l.imported_contact_id,
  c.slug AS card_slug, c.title AS card_title, c.badge AS card_badge,
  c.person_id AS card_person_id
FROM public.card_leads l
JOIN public.cards c ON c.id = l.card_id;

ALTER VIEW public.v_card_leads_inbox SET (security_invoker = on);
```

**Bewusst nicht enthalten:**

- Keine neue Tabelle `contact_origins` — die Provenance läuft via
  `contacts.source = 'atollcard:lead:<uuid>'` (existierende Spalte) und
  `card_leads.imported_contact_id` (neue Spalte). Bidirektional in einem Hop.
- Keine Erweiterung der `app_role`-Enum um `'lead'` — Imported Contacts
  starten mit `roles = []`. Der User taggt manuell im Adressbuch.
- Keine Änderung an `0097` oder `0098` — Public-Access-Policies bleiben
  unberührt.

**Backfill:** Bestehende Leads behalten ihren Status. `imported_contact_id`
ist NULL für alle Alt-Daten. Kein Backfill nötig.

### 3.2 Migration `0103_rpc_import_card_lead.sql`

```sql
CREATE OR REPLACE FUNCTION public.import_card_lead(p_lead_id uuid)
RETURNS TABLE (contact_id uuid, action text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_lead        public.card_leads%ROWTYPE;
  v_email_norm  text;
  v_existing    public.contacts%ROWTYPE;
  v_new_id      uuid;
  v_audit_note  text;
BEGIN
  -- 1. Lead laden + RLS-Check
  SELECT * INTO v_lead
  FROM public.card_leads
  WHERE id = p_lead_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'lead_not_found';
  END IF;

  -- 2. Bereits importiert? Idempotent: return existing.
  IF v_lead.imported_to_address_book = true AND v_lead.imported_contact_id IS NOT NULL THEN
    RETURN QUERY SELECT v_lead.imported_contact_id, 'already_imported'::text;
    RETURN;
  END IF;

  -- 3. Email normalisieren + Match suchen (case-insensitive, getrimmt)
  v_email_norm := lower(trim(v_lead.email));

  IF v_email_norm IS NOT NULL AND v_email_norm <> '' THEN
    SELECT * INTO v_existing
    FROM public.contacts
    WHERE lower(primary_email) = v_email_norm
       OR EXISTS (
         SELECT 1 FROM jsonb_array_elements(emails) AS e
         WHERE lower(e->>'email') = v_email_norm
       )
    ORDER BY created_at ASC
    LIMIT 1;
  END IF;

  -- Audit-Note (immer angehängt, format konsistent)
  v_audit_note := format(
    E'\n\n[%s · aus Card-Inbox] Lead von "%s %s" (Karte: %s%s)\n  > "%s"',
    to_char(now(), 'YYYY-MM-DD HH24:MI'),
    coalesce(v_lead.first_name, ''),
    coalesce(v_lead.last_name, ''),
    (SELECT slug FROM public.cards WHERE id = v_lead.card_id),
    coalesce(', ' || v_lead.topic, ''),
    coalesce(v_lead.message, '(keine Nachricht)')
  );

  IF v_existing.id IS NOT NULL THEN
    -- 4a. MERGE — nur leere Felder füllen, Email+Phone in JSONB anhängen, Note dranhängen
    UPDATE public.contacts
    SET
      first_name = coalesce(nullif(first_name, ''), v_lead.first_name),
      last_name  = coalesce(nullif(last_name, ''),  v_lead.last_name),
      primary_email = coalesce(nullif(primary_email, ''), v_email_norm),
      emails = CASE
        WHEN v_email_norm IS NULL OR v_email_norm = '' THEN emails
        WHEN EXISTS (SELECT 1 FROM jsonb_array_elements(emails) e WHERE lower(e->>'email') = v_email_norm)
          THEN emails
        ELSE emails || jsonb_build_array(jsonb_build_object('label', 'card-inbox', 'email', v_email_norm))
      END,
      phones = CASE
        WHEN v_lead.phone IS NULL OR v_lead.phone = '' THEN phones
        WHEN EXISTS (SELECT 1 FROM jsonb_array_elements(phones) p WHERE p->>'e164' = v_lead.phone)
          THEN phones
        ELSE phones || jsonb_build_array(jsonb_build_object('label', 'card-inbox', 'e164', v_lead.phone))
      END,
      notes = coalesce(notes, '') || v_audit_note,
      updated_at = now()
    WHERE id = v_existing.id;

    -- Lead-Side-Effects
    UPDATE public.card_leads
    SET imported_to_address_book = true,
        status = 'imported',
        imported_contact_id = v_existing.id
    WHERE id = p_lead_id;

    RETURN QUERY SELECT v_existing.id, 'merged'::text;

  ELSE
    -- 4b. CREATE — neuer Contact, source-Tag setzen, Tags inkl. 'card-inbox'
    INSERT INTO public.contacts (
      kind, first_name, last_name, primary_email,
      emails, phones, roles, tags, notes, source
    ) VALUES (
      'person',
      v_lead.first_name,
      v_lead.last_name,
      v_email_norm,
      CASE
        WHEN v_email_norm IS NULL OR v_email_norm = '' THEN '[]'::jsonb
        ELSE jsonb_build_array(jsonb_build_object('label', 'card-inbox', 'email', v_email_norm, 'primary', true))
      END,
      CASE
        WHEN v_lead.phone IS NULL OR v_lead.phone = '' THEN '[]'::jsonb
        ELSE jsonb_build_array(jsonb_build_object('label', 'card-inbox', 'e164', v_lead.phone))
      END,
      ARRAY[]::text[],
      ARRAY['card-inbox']::text[],
      v_audit_note,
      'atollcard:lead:' || v_lead.id::text
    )
    RETURNING id INTO v_new_id;

    UPDATE public.card_leads
    SET imported_to_address_book = true,
        status = 'imported',
        imported_contact_id = v_new_id
    WHERE id = p_lead_id;

    RETURN QUERY SELECT v_new_id, 'created'::text;
  END IF;
END;
$$;

-- RPC darf von authenticated user gerufen werden; Owner-Check passiert
-- via card_leads-RLS (SELECT auf v_lead schlägt fehl wenn nicht Owner)
GRANT EXECUTE ON FUNCTION public.import_card_lead(uuid) TO authenticated;
```

**Idempotenz-Garantie:** Zweimal-Klick auf "Importieren" retourniert beim
zweiten Aufruf `action='already_imported'` mit unverändertem `contact_id`.
Kein doppelter Contact, keine doppelte Audit-Note.

---

## 4. Import-Logik — Merge-Regeln im Detail

| Lead-Feld | Contact-Ziel | Regel |
|---|---|---|
| `first_name` | `first_name` | nur wenn Contact-Wert NULL/leer |
| `last_name` | `last_name` | nur wenn Contact-Wert NULL/leer |
| `email` | `primary_email` + `emails[]` | hinzufügen wenn nicht schon drin (`label='card-inbox'`) |
| `phone` | `phones[]` | hinzufügen wenn nicht schon drin (`label='card-inbox'`, kein `primary`-Flag) |
| `message` + `topic` + `captured_at` | `notes` (append) | _immer_ angehängt |
| `avatar_color` | – | ignoriert (Contact-Avatar-Logik ist getrennt) |
| `custom_answers` | `notes` (innerhalb der Note) | als JSON-Snippet im Audit-Block |

**Match-Definition für Auto-Merge:** Case-insensitive exakte Email-Übereinstimmung
(lowercased, getrimmt). Phone allein triggert keinen Match — Phones haben
zu viele Format-Varianten ohne strikte E.164-Normalisierung in beide
Richtungen.

**Side-Effects in derselben Transaction:**
- `card_leads.imported_to_address_book = true`
- `card_leads.status = 'imported'`
- `card_leads.imported_contact_id = contact_id`

**Bei Lead-Löschung:** `ON DELETE SET NULL` auf der FK. Contact bleibt
bestehen, Bridge wird auf NULL gesetzt.

**Bei Contact-Löschung:** `ON DELETE SET NULL` auf `card_leads.imported_contact_id`.
Lead bleibt mit `status='imported'`, aber `imported_contact_id` ist NULL. UI
zeigt "Contact gelöscht". Re-Import möglich.

---

## 5. UI-Layout

### 5.1 Sidebar-Anker

Neuer Eintrag in `ADRESSEN_ITEMS` (in `apps/web/src/components/Sidebar.tsx`):

```ts
{ to: '/contacts/card-inbox', icon: 'inbox', i18nKey: 'card_inbox', roles: ['owner', 'cd'] }
```

**Sichtbarkeit:** nur `owner` und `cd` (siehe RLS-Diskussion in Sektion 7).

**Badge:** rechts neben dem Label, rote Pille mit `count(status='new')`. Hook
`useCardLeadsUnreadCount()` mit Realtime-Subscription, damit der Badge live
mit-zählt.

### 5.2 Screen — `CardInboxScreen.tsx`

`MasterDetail`-Layout, parallel zu `AddressbookScreen`:

- **Header:** Page-Title "Card-Inbox", rechts ein "Aktualisieren"-Button
  (Reload manuell — Realtime macht das normalerweise transparent).
- **ListPane:**
  - `SearchInput` (Suche in `first_name`, `last_name`, `email`, `topic`, `message`)
  - Saved-View-Chips: **Alle** / **Neu** (default) / **In Bearbeitung** /
    **Importiert** / **Archiv** / **Spam**
  - Lead-Rows als `CardLeadRow` (Avatar mit `avatar_color`, Name,
    Card-Pille mit `card_badge`, Zeitstempel, Status-Pill)
  - Bulk-Select via Checkbox links jeder Row
  - URL-Persistenz: `?view=new&q=alex&lead=<id>`
- **DetailPane:**
  - Header: Avatar + Name + Status-Pill + "…"-Menü (Statusrücksetzung, Löschen)
  - Body: Email + Phone (klickbare `mailto:` / `tel:` / `wa.me`-Links) +
    Topic + Message + `card_title` + `captured_at`
  - Action-Bar (sticky bottom):
    - **Antworten** (`mailto:` mit prefilled subject `Re: <topic> — via Atoll-Card`)
    - **Anrufen** (`tel:` wenn Phone)
    - **WhatsApp** (`https://wa.me/<E164>` wenn Phone, E.164-strict)
    - **Importieren** (RPC → Navigation zum neuen Contact)
    - **Archivieren**
    - **Als Spam**

### 5.3 Empty States

- Alle-View leer: "Noch keine Card-Leads. Sobald jemand deine Public-Card-Seite
  ausfüllt, landet die Anfrage hier."
- Neu-View leer: "Alle Leads sind bearbeitet. ✓"
- Spam-View leer: "Kein Spam — die Welt ist freundlich."

### 5.4 Brand-Konventionen

Deutsche UI durchgehend, brand-konform (siehe Brand-Identity-Skill):
- Subjekt-Verb-Punkt, keine Marketing-Floskeln in Empty States
- Status-Farben aus `var(--brand-*)`:
  - new = brandRed
  - opened = brandAmber
  - contacted = brandBlue
  - imported = brandTeal
  - archived = textTertiary
  - spam = textTertiary mit Strikethrough

---

## 6. Status-Workflow

### 6.1 Auto-Transitions (sparsam, vorhersagbar)

| Trigger | Von → Nach | Wer setzt |
|---|---|---|
| Lead-Detail erstmals geöffnet | `new` → `opened` | Client beim Mount |
| Import-RPC erfolgreich | `*` → `imported` | RPC |
| Alles andere | – | manuell |

### 6.2 Manuelle Actions

Pill-Buttons + Bulk-Aktionen (siehe 5.2). Klick auf Antworten/Anrufen/WhatsApp
setzt zusätzlich `contacted` wenn vorher `opened` (clientseitig nach Window-Blur).

### 6.3 Realtime-UX

- Supabase-Channel-Sub auf `INSERT ON public.card_leads`
- Neuer Lead → erscheint oben in der Liste mit 2s Highlight-Animation (gelber Fade)
- Badge in Sidebar inkrementiert
- Browser-Tab-Title bekommt `(3) Atoll OS`-Präfix wenn ungelesene da sind
- Optionaler Sound: Settings-Toggle in Settings, default off
- **Kein Browser-Push** in MVP (Service-Worker-Setup ist out-of-scope; APNs
  auf iPhone deckt Push-Bedürfnis ab)

---

## 7. Permissions (RLS)

**Card-Inbox ist owner-only.** Heute schützt 0097 `card_leads` über
`is_card_owner(c.person_id)`. Da nur `owner` und `cd` Karten haben, sieht
ein `dispatcher` heute gar nichts in `card_leads`. **Diese Entscheidung
bleibt:** keine Dispatcher-Triage.

Begründung: Card-Leads sind sehr persönlich (Trial-Dive-Anfragen, IDC-Interesse,
private Empfehlungen). Eine Dispo, die alle Card-Inboxen aller Owner/CDs sehen
würde, wäre eine Datenschutz-Eskalation, die niemand bestellt hat.

**Folgerung:** Sidebar-Entry nur für Rollen `owner` und `cd`. RLS aus 0097
unverändert. `v_card_leads_inbox` läuft mit `security_invoker = on` — vererbt
die RLS der Basistabelle.

---

## 8. iOS-Anpassung

Eine einzige Datei wird geändert:

**`apps/atollcard-native/AtollCard/Views/Leads/LeadDetailSheet.swift`**

Der bestehende "In Adressbuch importieren"-Button wird umetikettiert zu
"**In Atoll Web öffnen**" und öffnet:

```
https://atoll-os.com/contacts/card-inbox?lead=<id>
```

via Universal Link (wenn Sub-Projekt 3 fertig) oder über `UIApplication.open(_:)`
als Web-Browser-Fallback.

**Web-Seite reagiert auf `?lead=<id>`-Param:** wenn der Lead existiert und für
den User sichtbar ist, wird er auto-selektiert und das DetailPane aufgeklappt.

Keine weiteren iOS-Änderungen in diesem Sub-Projekt. iOS-App-Version bleibt
v0.4, kein TestFlight-Build nötig fürs Schalten der Web-Inbox — der CTA-Text-
Change kann mit dem nächsten regulären Build raus.

---

## 9. File-Inventar

### Neu

```
apps/web/src/
├── screens/
│   └── contacts/
│       ├── CardInboxScreen.tsx          Master-Detail-Shell, Saved-Views, Realtime-Sub
│       └── CardInboxDetailPanel.tsx     DetailPane-Inhalt (Header, Body, Actions)
├── components/
│   ├── CardLeadRow.tsx                  ListPane-Zeile
│   └── CardLeadStatusPill.tsx           Wiederverwendbare Status-Pille
├── hooks/
│   ├── useCardLeads.ts                  React-Query gegen v_card_leads_inbox
│   ├── useCardLeadRealtime.ts           Supabase-Channel-Subscription
│   ├── useCardLeadsUnreadCount.ts       Sidebar-Badge-Hook
│   └── useCardLeadActions.ts            setStatus, archive, spam, importLead
├── lib/
│   └── cardLeadQueries.ts               PostgREST-Queries + RPC-Wrapper
└── types/
    └── cardLeads.ts                     TypeScript-Mirror von v_card_leads_inbox

supabase/migrations/
├── 0102_card_leads_imported_contact.sql Bridge-Spalte + View
└── 0103_rpc_import_card_lead.sql        RPC-Function

apps/web/tests/playwright/
└── card-inbox.spec.ts                   E2E: Public-Page → Inbox → Import → Adressbuch
```

### Geändert

```
apps/web/src/
├── App.tsx                              + Route /contacts/card-inbox
├── components/Sidebar.tsx               + Eintrag in ADRESSEN_ITEMS + Badge-Hook
└── i18n/de.json + en.json + fr.json     + Keys nav.card_inbox, card_inbox.*

apps/atollcard-native/AtollCard/Views/Leads/
└── LeadDetailSheet.swift                CTA umetikettiert + URL-Öffnen
```

### Test-Coverage

- `cardLeadQueries.test.ts` — Mock-Supabase, RPC happy-path + idempotent-Import
  + Email-Match-Merge + Phone-no-match-Create + Already-imported-Return
- `CardInboxScreen.test.tsx` — React Testing Library, Saved-Views-Switch behält
  Search nicht, Bulk-Select toggelt korrekt, Realtime-Insert triggert Re-Render
- `tests/playwright/card-inbox.spec.ts` — Public-Page füllt Form aus,
  Card-Inbox sieht den Lead innert 2s, Import-Klick erstellt einen Contact,
  Contact erscheint im Adressbuch unter "Alle"

---

## 10. Error-Handling & Edge-Cases

### 10.1 Pro Aktion

| Aktion | Fehlerart | UI-Verhalten |
|---|---|---|
| Inbox laden | RLS-Verstoss / Netz | EmptyState "Keine Inbox verfügbar — Login prüfen" + Retry |
| Realtime-Sub bricht ab | Channel-Drop | Exponential-Backoff 1s/2s/4s/max 30s. Nach 3 Fails: Toast "Live-Updates pausiert" |
| `import_card_lead` RPC | `already_imported` | Toast "Schon importiert", navigiert zum Contact |
| `import_card_lead` RPC | `lead_not_found` | Toast "Lead nicht gefunden", entfernt Row |
| Status-Update | Optimistic-UI-Mismatch | Roll-back lokal, Toast "Update fehlgeschlagen" |
| Bulk-Import | Teil-Fehler | Toast "5 importiert · 2 schon vorhanden · 1 fehlgeschlagen", Failed-Row markiert |

### 10.2 Edge-Cases

- **Lead ohne Email + ohne Phone:** Import erstellt Contact mit Name + Notes.
  UI warnt vorher (einziger Confirm-Dialog im Flow): "Lead hat keine Kontaktdaten
  — Import erstellt unvollständigen Contact. Trotzdem?"
- **Lead mit nur `first_name`:** OK, Contact `display_name` ist generated.
- **Email matched mehrere Contacts** (theoretisch unique, nicht enforced): Merge
  in ältesten (`ORDER BY created_at ASC LIMIT 1`). Audit-Note enthält Warnung.
- **Contact wurde gelöscht nach Import:** `imported_contact_id → NULL` via
  `ON DELETE SET NULL`. UI zeigt "Contact gelöscht" als Hinweis. Re-Import möglich.
- **Spam-Lead-Import-Attempt:** "Importieren"-Button disabled wenn
  `status='spam'`. Manuelles "Status zurück auf neu" hebt die Sperre auf.
- **iOS-Deep-Link mit `?lead=<id>`:** Auto-Selection wenn sichtbar, sonst Toast
  "Lead nicht gefunden oder ohne Zugriff".
- **Lead-Form füllt zeitgleich aus, während Browser-Inbox offen ist:** Realtime
  delivert duplikatfrei (UUID-PK), Optimistic-Render skipt wenn schon in der Liste.

### 10.3 Performance

- Inbox lädt erste **500 Rows** (Cap wie Adressbuch), sortiert nach
  `captured_at DESC`. Pagination wenn >500 — kommt erst bei Bedarf, MVP cappt.
- Realtime-Channel ist **serverseitig gefiltert** über RLS (`security_invoker`),
  damit kein cross-owner-Traffic im Browser landet.

---

## 11. Rollout-Plan

1. **Migration 0102 + 0103 lokal testen** (`supabase db reset && supabase db push`),
   dann gegen Staging-DB.
2. **Code-Deployment in 2 Schritten:**
   - Schritt 1: Web-Inbox als versteckte Route (`/contacts/card-inbox` reachable,
     Sidebar-Entry hinter Feature-Flag `tweaks.cardInbox`). Dominik testet selber.
   - Schritt 2: Feature-Flag default-on, iOS-CTA-Update wird mit nächstem
     TestFlight-Build ausgerollt.
3. **Backwards-Compatibility:** iOS-App (v0.4) braucht keinen Update für
   Migration 0102/0103 — neue Spalte ist NULL-default. iOS-Hooks aufs Schema
   sind nicht betroffen.
4. **Smoke-Test nach Deployment:**
   - Im Inkognito-Browser eine Test-Lead-Form auf
     `https://atoll-os.com/c/dominik-cd` ausfüllen
   - In der Inbox erscheint die Zeile innert 2s (Realtime-Highlight)
   - Klick auf "Importieren" → Toast "Contact angelegt"
   - Im Adressbuch unter "Alle" erscheint der neue Contact
   - `contacts.source` enthält `atollcard:lead:<uuid>`
   - `card_leads.imported_contact_id` enthält die Contact-ID

---

## 12. Out-of-Scope (in spätere Sub-Projekte)

- Lead-Reply-Templates / vorgefüllte Email-Texte (Communication Hub)
- Auto-Assignment (Lead landet automatisch bei bestimmtem User-Profil)
- Browser-Push-Notifications (APNs auf iPhone deckt's; Sub-Projekt 2)
- Lead-Konversations-Thread mit IMAP/SMTP-Reply-Tracking (Communication Hub)
- Card-Lead-Analytics-Dashboard (bleibt Card-Owner-Sicht in iOS-Analytics)
- Dispatcher-Triage-Modus mit RLS-Lockerung (separates Sub-Projekt, falls
  später bestellt)

---

## 13. Open Questions / Risiken

1. **Universal-Link-Setup für iOS-Deep-Link:** Funktioniert nur wenn
   Sub-Projekt 3 (Universal Links) fertig ist. Bis dahin Fallback via
   `UIApplication.open(URL)` → öffnet im Mobile-Browser, was OK ist.
2. **`tags='card-inbox'`-Konvention:** Wird `card-inbox` als Tag bereits
   anderweitig verwendet? Wenn nicht, ist es ein neuer reserved-Tag.
   Prüfen vor Deployment.
3. **`security_invoker`-Views in der Codebase:** Erstes Vorkommen? Wenn ja,
   im Migration-Header dokumentieren als Pattern für künftige Views.
4. **Bulk-Import-Performance:** RPC läuft in Schleife per Lead. Bei 50+ Leads
   am Stück könnte ein dedicated Bulk-RPC besser sein. MVP per Lead — beobachten.

---

## 14. Akzeptanzkriterien

- [ ] Sidebar-Eintrag "Card-Inbox" sichtbar für `owner` + `cd`, mit Live-Badge
- [ ] Master-Detail-Layout konsistent mit Adressbuch (Saved Views, Search, URL-Params)
- [ ] Realtime: neuer Public-Lead erscheint innert 2s in offenem Browser
- [ ] Import erstellt neuen Contact bei Email-Miss, Contact taucht im Adressbuch auf
- [ ] Import mergt bei Email-Match in bestehenden Contact, leere Felder gefüllt
- [ ] Audit-Note in `contacts.notes` enthält Timestamp + Karten-Slug + Message-Snippet
- [ ] `card_leads.imported_contact_id` ist nach Import nicht NULL
- [ ] Zweimal-Klick "Importieren" verursacht keine Doppel-Contacts
- [ ] iOS-CTA "In Atoll Web öffnen" öffnet Web-Inbox mit auto-selektiertem Lead
- [ ] Status `archived` / `spam` / "zurück auf neu" funktionieren per Single-Click
- [ ] Bulk-Triage (Select-Multiple → Archivieren) markiert alle in einem Roundtrip
- [ ] Tests passieren: Unit (`cardLeadQueries.test.ts`), Component
  (`CardInboxScreen.test.tsx`), E2E (`card-inbox.spec.ts`)

---

## 15. Referenzen

- AtollCard README: `apps/atollcard-native/README.md`
- AtollCard CHANGELOG: `apps/atollcard-native/CHANGELOG.md`
- Bestehende Migrations: `supabase/migrations/0097_atollcard_schema.sql` ff.
- Adressbuch-Pattern: `apps/web/src/screens/contacts/AddressbookScreen.tsx`
- Sidebar-Pattern: `apps/web/src/components/Sidebar.tsx`
- ContactRole-Enum: `apps/web/src/types/contacts.ts`
