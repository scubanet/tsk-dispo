# Comms-Integration — Plan 1: DB- & Typ-Fundament

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Schema, Constraints und TypeScript-Typen schaffen, auf denen die vier Comms-Edge-Functions (inbound/outbound/enrich/connect) aufbauen — ohne externe Unipile-Abhängigkeit, voll testbar.

**Architecture:** Vier Migrationen (0119–0122) erweitern `contact_events` und legen `messaging_accounts`, `messaging_unmatched` und `contact_enrichment` an; TypeScript-Typen werden synchron erweitert; eine reine `normalizeHandle`-Hilfsfunktion (TDD) bereitet das spätere Kontakt-Matching vor.

**Tech Stack:** Supabase Postgres (SQL-Migrationen, RLS), React/TypeScript (`apps/web`), Vitest, libphonenumber-js.

**Spec:** `docs/superpowers/specs/2026-05-29-comms-integration-unipile-design.md`

---

### Task 1: Migration 0119 — `messaging_accounts`

**Files:**
- Create: `supabase/migrations/0119_messaging_accounts.sql`

- [ ] **Step 1: Migration schreiben**

```sql
-- 0119_messaging_accounts.sql
-- ─────────────────────────────────────────────────────────────────
-- Comms-Integration: verbundene Messaging-Konten (E-Mail/WhatsApp/LinkedIn)
-- über Unipile. Speichert NUR die unipile_account_id — niemals OAuth-Tokens.
-- Spec: docs/superpowers/specs/2026-05-29-comms-integration-unipile-design.md §4.4, §5
-- ─────────────────────────────────────────────────────────────────

CREATE TABLE public.messaging_accounts (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  channel            TEXT NOT NULL CHECK (channel IN ('email', 'whatsapp', 'linkedin')),
  unipile_account_id TEXT NOT NULL,
  provider           TEXT,                       -- gmail | outlook | imap | cloud_api | linkedin
  label              TEXT NOT NULL,
  owner_user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status             TEXT NOT NULL DEFAULT 'connected'
    CHECK (status IN ('connected', 'disconnected', 'error')),
  connected_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_event_at      TIMESTAMPTZ
);

CREATE UNIQUE INDEX uq_messaging_accounts_unipile
  ON public.messaging_accounts(unipile_account_id);

CREATE INDEX idx_messaging_accounts_owner
  ON public.messaging_accounts(owner_user_id);

ALTER TABLE public.messaging_accounts ENABLE ROW LEVEL SECURITY;

-- Nutzer sehen/verwalten nur eigene Verbindungen. Inserts/Writes der
-- Edge Functions laufen über die Service-Rolle (umgeht RLS).
CREATE POLICY messaging_accounts_owner ON public.messaging_accounts
  FOR ALL TO authenticated
  USING (owner_user_id = auth.uid())
  WITH CHECK (owner_user_id = auth.uid());
```

- [ ] **Step 2: Migration anwenden (lokal) und verifizieren**

Run: `npx supabase db reset`
Expected: läuft ohne Fehler durch bis inkl. `0119_messaging_accounts.sql`; Ausgabe endet mit „Finished supabase db reset."

- [ ] **Step 3: Tabelle prüfen**

Run: `npx supabase db reset && echo "\d public.messaging_accounts" | npx supabase db psql`
Expected: Spalten `id, channel, unipile_account_id, provider, label, owner_user_id, status, connected_at, last_event_at`; RLS = enabled.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/0119_messaging_accounts.sql
git commit -m "feat(db): messaging_accounts table + RLS [Comms Plan1 T1]"
```

---

### Task 2: Migration 0120 — `messaging_unmatched`

**Files:**
- Create: `supabase/migrations/0120_messaging_unmatched.sql`

- [ ] **Step 1: Migration schreiben**

```sql
-- 0120_messaging_unmatched.sql
-- ─────────────────────────────────────────────────────────────────
-- Comms-Integration: Quarantäne für inbound-Nachrichten ohne Kontakt-Treffer.
-- Wird NIE verworfen; später per UI einem Kontakt zugeordnet.
-- Spec: …unipile-design.md §4.4, §5 (kein Auto-Anlegen von Kontakten)
-- ─────────────────────────────────────────────────────────────────

CREATE TABLE public.messaging_unmatched (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  channel             TEXT NOT NULL CHECK (channel IN ('email', 'whatsapp', 'linkedin')),
  sender_handle       TEXT NOT NULL,             -- e164 | email | linkedin_member_id
  normalized_payload  JSONB NOT NULL,
  external_id         TEXT NOT NULL,             -- provider_message_id (Idempotenz)
  received_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  resolved_contact_id UUID REFERENCES public.contacts(id) ON DELETE SET NULL
);

CREATE UNIQUE INDEX uq_messaging_unmatched_external
  ON public.messaging_unmatched(external_id);

CREATE INDEX idx_messaging_unmatched_open
  ON public.messaging_unmatched(received_at DESC)
  WHERE resolved_contact_id IS NULL;

ALTER TABLE public.messaging_unmatched ENABLE ROW LEVEL SECURITY;

-- Org-weite Quarantäne: jeder authentifizierte Staff darf lesen + zuordnen.
-- Inserts laufen über die Service-Rolle der Edge Function (umgeht RLS).
CREATE POLICY messaging_unmatched_read ON public.messaging_unmatched
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY messaging_unmatched_assign ON public.messaging_unmatched
  FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);
```

- [ ] **Step 2: Anwenden + verifizieren**

Run: `npx supabase db reset`
Expected: läuft bis inkl. `0120_messaging_unmatched.sql` fehlerfrei durch.

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/0120_messaging_unmatched.sql
git commit -m "feat(db): messaging_unmatched quarantine table + RLS [Comms Plan1 T2]"
```

---

### Task 3: Migration 0121 — `contact_events` erweitern (linkedin_message, Idempotenz, Account-Link)

**Files:**
- Create: `supabase/migrations/0121_contact_events_messaging.sql`

- [ ] **Step 1: Migration schreiben**

```sql
-- 0121_contact_events_messaging.sql
-- ─────────────────────────────────────────────────────────────────
-- Comms-Integration: contact_events um Messaging-Felder erweitern.
-- - linkedin_message als neuer event_type
-- - external_id (provider_message_id) für Idempotenz gegen Webhook-Retries
-- - messaging_account_id FK auf das Quell-Konto
-- Spec: …unipile-design.md §4.1, §4.3
-- ─────────────────────────────────────────────────────────────────

-- event_type CHECK um 'linkedin_message' erweitern (Constraint neu setzen).
ALTER TABLE public.contact_events
  DROP CONSTRAINT IF EXISTS contact_events_event_type_check;

ALTER TABLE public.contact_events
  ADD CONSTRAINT contact_events_event_type_check CHECK (event_type IN (
    'note', 'call', 'email_external', 'meeting_past', 'task',
    'whatsapp_log', 'linkedin_message'
  ));

ALTER TABLE public.contact_events
  ADD COLUMN external_id TEXT,
  ADD COLUMN messaging_account_id UUID
    REFERENCES public.messaging_accounts(id) ON DELETE SET NULL;

-- Idempotenz: derselbe Provider-Message identisch nur einmal.
CREATE UNIQUE INDEX uq_contact_events_external_id
  ON public.contact_events(external_id)
  WHERE external_id IS NOT NULL;
```

- [ ] **Step 2: Anwenden + verifizieren**

Run: `npx supabase db reset && echo "\d public.contact_events" | npx supabase db psql`
Expected: neue Spalten `external_id`, `messaging_account_id`; Index `uq_contact_events_external_id`; CHECK enthält `linkedin_message`.

- [ ] **Step 3: Idempotenz-Constraint testen**

Run:
```bash
npx supabase db reset
echo "INSERT INTO public.contact_events (contact_id, event_type, summary, external_id)
SELECT id, 'whatsapp_log', 'dup-test', 'X1' FROM public.contacts LIMIT 1;
INSERT INTO public.contact_events (contact_id, event_type, summary, external_id)
SELECT id, 'whatsapp_log', 'dup-test', 'X1' FROM public.contacts LIMIT 1;" | npx supabase db psql
```
Expected: zweites INSERT scheitert mit `duplicate key value violates unique constraint "uq_contact_events_external_id"`.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/0121_contact_events_messaging.sql
git commit -m "feat(db): contact_events linkedin_message + external_id idempotency + account FK [Comms Plan1 T3]"
```

---

### Task 4: Migration 0122 — Kontakt-Anreicherung (`linkedin_member_id` + `contact_enrichment`)

**Files:**
- Create: `supabase/migrations/0122_contact_enrichment.sql`

- [ ] **Step 1: Migration schreiben**

```sql
-- 0122_contact_enrichment.sql
-- ─────────────────────────────────────────────────────────────────
-- Comms-Integration: LinkedIn-Anreicherung. linkedin_member_id am Kontakt
-- fürs Matching; contact_enrichment hält angereicherte Werte MIT Herkunft.
-- Regel: Enrichment überschreibt NIE Nutzer-Felder (siehe §4.5).
-- Spec: …unipile-design.md §4.2, §4.5, §5
-- ─────────────────────────────────────────────────────────────────

ALTER TABLE public.contacts
  ADD COLUMN linkedin_member_id TEXT;

CREATE UNIQUE INDEX uq_contacts_linkedin_member_id
  ON public.contacts(linkedin_member_id)
  WHERE linkedin_member_id IS NOT NULL;

CREATE TABLE public.contact_enrichment (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_id  UUID NOT NULL REFERENCES public.contacts(id) ON DELETE CASCADE,
  source      TEXT NOT NULL CHECK (source IN ('linkedin')),
  fields      JSONB NOT NULL DEFAULT '{}'::jsonb,   -- {headline, company, position, location, avatar_url, …}
  status      TEXT NOT NULL DEFAULT 'suggested'
    CHECK (status IN ('suggested', 'accepted', 'rejected')),
  fetched_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_contact_enrichment_contact
  ON public.contact_enrichment(contact_id, fetched_at DESC);

ALTER TABLE public.contact_enrichment ENABLE ROW LEVEL SECURITY;

-- Lesen/Verwalten nur durch Kontakt-Owner (Helper aus Migration 0111).
-- Inserts der enrich-Edge-Function laufen über die Service-Rolle.
CREATE POLICY contact_enrichment_owner ON public.contact_enrichment
  FOR ALL TO authenticated
  USING (public.is_contact_owner(contact_id))
  WITH CHECK (public.is_contact_owner(contact_id));
```

- [ ] **Step 2: Anwenden + verifizieren**

Run: `npx supabase db reset && echo "\d public.contact_enrichment" | npx supabase db psql`
Expected: Tabelle vorhanden, RLS enabled; `contacts.linkedin_member_id` existiert.

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/0122_contact_enrichment.sql
git commit -m "feat(db): contacts.linkedin_member_id + contact_enrichment table + RLS [Comms Plan1 T4]"
```

---

### Task 5: TypeScript-Typen erweitern

**Files:**
- Modify: `apps/web/src/types/contactEvents.ts`
- Create: `apps/web/src/types/messaging.ts`

- [ ] **Step 1: `linkedin_message` + Messaging-Payload in contactEvents.ts**

In `apps/web/src/types/contactEvents.ts`, `UserEventType` erweitern:

```ts
export type UserEventType =
  | 'note'
  | 'call'
  | 'email_external'
  | 'meeting_past'
  | 'task'
  | 'whatsapp_log'
  | 'linkedin_message'
```

Direkt nach `WhatsAppLogPayload` einfügen:

```ts
/** Gemeinsames Payload für auto-synct Messaging-Events (E-Mail/WA/LinkedIn). */
export interface MessagingPayload {
  source: 'auto' | 'manual'
  direction: Direction
  provider_message_id: string
  thread_id?: string
  attachment_count?: number
  unipile_account_id: string
}
```

`EventComposerInput` um die LinkedIn-Variante ergänzen:

```ts
  | { event_type: 'linkedin_message'; summary: string; body?: string; payload: MessagingPayload; occurred_at?: string }
```

- [ ] **Step 2: Messaging-Account- und Enrichment-Typen anlegen**

Create `apps/web/src/types/messaging.ts`:

```ts
// apps/web/src/types/messaging.ts
// Spec: docs/superpowers/specs/2026-05-29-comms-integration-unipile-design.md §4

export type CommsChannel = 'email' | 'whatsapp' | 'linkedin'

export interface MessagingAccount {
  id: string
  channel: CommsChannel
  unipile_account_id: string
  provider: string | null
  label: string
  owner_user_id: string
  status: 'connected' | 'disconnected' | 'error'
  connected_at: string
  last_event_at: string | null
}

export interface ContactEnrichment {
  id: string
  contact_id: string
  source: 'linkedin'
  fields: Record<string, unknown>
  status: 'suggested' | 'accepted' | 'rejected'
  fetched_at: string
}

export interface UnmatchedMessage {
  id: string
  channel: CommsChannel
  sender_handle: string
  normalized_payload: Record<string, unknown>
  external_id: string
  received_at: string
  resolved_contact_id: string | null
}
```

- [ ] **Step 3: Typecheck**

Run: `cd apps/web && npx tsc --noEmit`
Expected: 0 Fehler.

- [ ] **Step 4: Commit**

```bash
git add apps/web/src/types/contactEvents.ts apps/web/src/types/messaging.ts
git commit -m "feat(types): linkedin_message event + messaging/enrichment types [Comms Plan1 T5]"
```

---

### Task 6: `normalizeHandle` (reine Matching-Vorbereitung, TDD)

**Files:**
- Create: `apps/web/src/lib/comms/normalizeHandle.ts`
- Test: `apps/web/src/lib/comms/__tests__/normalizeHandle.test.ts`

- [ ] **Step 1: Failing test schreiben**

Create `apps/web/src/lib/comms/__tests__/normalizeHandle.test.ts`:

```ts
import { describe, it, expect } from 'vitest'
import { normalizeHandle } from '../normalizeHandle'

describe('normalizeHandle', () => {
  it('WhatsApp: Nummer ohne Plus → E.164', () => {
    expect(normalizeHandle('whatsapp', '41791234567')).toBe('+41791234567')
  })
  it('WhatsApp: Nummer mit Plus bleibt E.164', () => {
    expect(normalizeHandle('whatsapp', '+41 79 123 45 67')).toBe('+41791234567')
  })
  it('WhatsApp: ungültige Nummer → null', () => {
    expect(normalizeHandle('whatsapp', '123')).toBeNull()
  })
  it('E-Mail: trimmt und lowercased', () => {
    expect(normalizeHandle('email', '  Max@Example.COM ')).toBe('max@example.com')
  })
  it('E-Mail: ohne @ → null', () => {
    expect(normalizeHandle('email', 'kein-email')).toBeNull()
  })
  it('LinkedIn: trimmt Member-ID', () => {
    expect(normalizeHandle('linkedin', '  ACoAAB123  ')).toBe('ACoAAB123')
  })
  it('LinkedIn: leer → null', () => {
    expect(normalizeHandle('linkedin', '   ')).toBeNull()
  })
})
```

- [ ] **Step 2: Test laufen, Fehlschlag bestätigen**

Run: `cd apps/web && npx vitest run src/lib/comms/__tests__/normalizeHandle.test.ts`
Expected: FAIL — „Cannot find module '../normalizeHandle'".

- [ ] **Step 3: Implementierung schreiben**

Create `apps/web/src/lib/comms/normalizeHandle.ts`:

```ts
// apps/web/src/lib/comms/normalizeHandle.ts
// Normalisiert einen eingehenden Absender-Handle in die Form, in der er
// gegen contacts gematcht wird. Rein, keine I/O — Edge Function nutzt das
// Ergebnis als Query-Filter.
// Spec: docs/superpowers/specs/2026-05-29-comms-integration-unipile-design.md §4.2
import { parsePhoneNumberFromString } from 'libphonenumber-js'
import type { CommsChannel } from '@/types/messaging'

export function normalizeHandle(channel: CommsChannel, raw: string): string | null {
  if (channel === 'whatsapp') {
    const withPlus = raw.trim().startsWith('+') ? raw.trim() : `+${raw.trim()}`
    const parsed = parsePhoneNumberFromString(withPlus)
    return parsed?.isValid() ? parsed.number : null
  }
  if (channel === 'email') {
    const email = raw.trim().toLowerCase()
    return /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email) ? email : null
  }
  if (channel === 'linkedin') {
    const id = raw.trim()
    return id.length > 0 ? id : null
  }
  return null
}
```

- [ ] **Step 4: Test laufen, Erfolg bestätigen**

Run: `cd apps/web && npx vitest run src/lib/comms/__tests__/normalizeHandle.test.ts`
Expected: PASS — 7 Tests grün.

- [ ] **Step 5: Volle Suite grün halten**

Run: `cd apps/web && npx vitest run`
Expected: alle bestehenden + neuen Tests grün (≥ 429).

- [ ] **Step 6: Commit**

```bash
git add apps/web/src/lib/comms/normalizeHandle.ts apps/web/src/lib/comms/__tests__/normalizeHandle.test.ts
git commit -m "feat(comms): normalizeHandle für Kontakt-Matching (TDD) [Comms Plan1 T6]"
```

---

## Self-Review (durchgeführt)

- **Spec-Abdeckung:** §4.1 (T3, T5), §4.2 (T4, T6), §4.3 (T3), §4.4 (T1, T2), §4.5 (T4), §5-RLS (T1–T4). Edge Functions (§6), DSGVO-Lösch/Export-Pfade (§5), Unified Inbox (§6.2) → Folge-Pläne.
- **Platzhalter:** keine.
- **Typ-Konsistenz:** `CommsChannel`, `MessagingPayload`, `external_id`, `messaging_account_id`, `linkedin_member_id` durchgängig identisch in SQL + TS.

## Roadmap — Folge-Pläne (eigene Dateien, je lauffähig)

- **Plan 2 — `comms-connect` + Verbindungs-UI:** Unipile-Hosted-Auth-Link, Callback → `messaging_accounts`; Settings-Screen „Konten verbinden". Voraussetzung: Unipile-API-Key in Supabase Secrets.
- **Plan 3 — `comms-inbound`:** Webhook (HMAC-Verify) → `normalizeUnipileEvent` (Payload-Shapes vorher **live** verifizieren, Spec §9) → matchen via `normalizeHandle` → `contact_events` oder `messaging_unmatched`. Idempotent.
- **Plan 4 — `comms-outbound`:** Senden aus Composer → Unipile-Send-API → outbound-Event; Composer-Upgrade (echtes Senden statt Log, Fallback wenn Kanal nicht verbunden).
- **Plan 5 — `comms-enrich`:** LinkedIn-Anreicherung (rate-limited) → `contact_enrichment`; „Vorschlag" annehmen/ablehnen am Kontakt (Nie-Überschreiben-Regel).
- **Plan 6 — Unified Inbox + Quarantäne-UI:** kanalübergreifender Screen + „Zuordnen"-Flow für `messaging_unmatched`; optional Realtime-Subscription.
