# Comms-Integration — Plan 3: comms-inbound (Nachrichten → Timeline)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eingehende & gesendete E-Mails, WhatsApp- und LinkedIn-Nachrichten landen automatisch als `contact_events` am richtigen Kontakt — oder in der Quarantäne, wenn kein Kontakt passt.

**Architecture:** Eine öffentliche Edge Function `comms-inbound` empfängt Unipiles zwei Webhook-Quellen (messaging + email), verifiziert ein Shared Secret, normalisiert beide Payload-Formen in eine gemeinsame Struktur, matcht den Gegenpart-Handle über eine Postgres-RPC auf einen Kontakt und schreibt das Event idempotent. Kein Treffer → `messaging_unmatched`.

**Tech Stack:** Supabase Edge Functions (Deno), Postgres RPC, React/TS (`apps/web`), Vitest.

**Spec:** `docs/superpowers/specs/2026-05-29-comms-integration-unipile-design.md` §4, §6.1, §7
**Verifizierte Unipile-Payloads:**
- Messaging (`new-messages-webhook`): `account_id, account_type, account_info.user_id, event, chat_id, timestamp, message_id, message, sender{attendee_provider_id,…}, attendees[], attachments[]`. `event='message_received'` deckt empfangen UND gesendet ab → outbound, wenn `sender.attendee_provider_id === account_info.user_id`.
- Email (`new-emails-webhook`): `email_id, account_id, event ('mail_received'|'mail_sent'|'mail_moved'), date, from_attendee{identifier}, to_attendees[], subject, body, body_plain, has_attachments, attachments[], message_id`.

**Shared Secret:** wir verwenden den vorhandenen `COMMS_NOTIFY_SECRET` als URL-Token (`?token=…`) — kein neues Secret nötig.

---

### Task 1: Migration 0124 — RPC `match_contact_by_handle`

**Files:**
- Create: `supabase/migrations/0124_match_contact_by_handle.sql`

- [ ] **Step 1: Migration schreiben**

```sql
-- 0124_match_contact_by_handle.sql
-- ─────────────────────────────────────────────────────────────────
-- Comms-Integration: matcht einen normalisierten Absender-Handle auf einen
-- Kontakt. E-Mail gegen contacts.emails[].email, WhatsApp gegen
-- contacts.phones[].e164, LinkedIn gegen contacts.linkedin_member_id.
-- Wird von der Service-Rolle der comms-inbound Edge Function gerufen.
-- Spec: …unipile-design.md §4.2
-- ─────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.match_contact_by_handle(p_channel TEXT, p_handle TEXT)
RETURNS UUID
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT c.id FROM public.contacts c
  WHERE CASE
    WHEN p_channel = 'email' THEN EXISTS (
      SELECT 1 FROM jsonb_array_elements(COALESCE(c.emails, '[]'::jsonb)) e
      WHERE lower(e->>'email') = lower(p_handle))
    WHEN p_channel = 'whatsapp' THEN EXISTS (
      SELECT 1 FROM jsonb_array_elements(COALESCE(c.phones, '[]'::jsonb)) p
      WHERE p->>'e164' = p_handle)
    WHEN p_channel = 'linkedin' THEN c.linkedin_member_id = p_handle
    ELSE false
  END
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.match_contact_by_handle(TEXT, TEXT) TO service_role, authenticated;
```

- [ ] **Step 2: Anwenden + verifizieren**

Run: `npx supabase db push`  (oder lokal `npx supabase db reset`)
Expected: Migration `0124` angewandt.

- [ ] **Step 3: Smoke-Test gegen echten Kontakt**

Run (eine bekannte E-Mail eines Kontakts einsetzen):
```sql
SELECT public.match_contact_by_handle('email', 'lena.brunner@gmail.com');
```
Expected: die `contacts.id` oder NULL — kein Fehler.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/0124_match_contact_by_handle.sql
git commit -m "feat(db): match_contact_by_handle RPC [Comms Plan3 T1]"
```

---

### Task 2: `normalizeInboundEvent` (reiner Normalizer, TDD)

**Files:**
- Create: `apps/web/src/lib/comms/normalizeInboundEvent.ts`
- Test: `apps/web/src/lib/comms/__tests__/normalizeInboundEvent.test.ts`

- [ ] **Step 1: Failing test (echte Unipile-Beispiel-Payloads)**

```ts
import { describe, it, expect } from 'vitest'
import { normalizeInboundEvent } from '../normalizeInboundEvent'

const linkedinMsg = {
  account_id: 'acc1', account_type: 'LINKEDIN',
  account_info: { type: 'LINKEDIN', user_id: 'SELF_ID' },
  event: 'message_received', chat_id: 'chatA', timestamp: '2026-05-29T10:00:00.000Z',
  message_id: 'msg1', message: 'Hallo Dominik',
  sender: { attendee_provider_id: 'OTHER_ID', attendee_name: 'Sophie' },
  attendees: [{ attendee_provider_id: 'OTHER_ID' }, { attendee_provider_id: 'SELF_ID' }],
  attachments: [],
}
const emailIn = {
  email_id: 'mail1', account_id: 'acc2', event: 'mail_received',
  date: '2026-05-29T09:00:00.000Z',
  from_attendee: { identifier: 'Marco@Example.MT', identifier_type: 'EMAIL_ADDRESS' },
  to_attendees: [{ identifier: 'dominik@weckherlin.com' }],
  subject: 'Specialty Termine', body: '<p>Hi</p>', body_plain: 'Hi', has_attachments: false, message_id: '<x@y>',
}

describe('normalizeInboundEvent', () => {
  it('LinkedIn inbound', () => {
    const r = normalizeInboundEvent(linkedinMsg)
    expect(r).toMatchObject({ channel: 'linkedin', direction: 'inbound', external_id: 'msg1',
      counterparty_handle: 'OTHER_ID', summary: 'Hallo Dominik', thread_id: 'chatA' })
  })
  it('Messaging outbound erkennt eigenen Versand', () => {
    const r = normalizeInboundEvent({ ...linkedinMsg, message_id: 'msg2',
      sender: { attendee_provider_id: 'SELF_ID' } })
    expect(r).toMatchObject({ direction: 'outbound', counterparty_handle: 'OTHER_ID' })
  })
  it('E-Mail inbound matcht auf Absender (lowercased)', () => {
    const r = normalizeInboundEvent(emailIn)
    expect(r).toMatchObject({ channel: 'email', direction: 'inbound', external_id: 'mail1',
      counterparty_handle: 'marco@example.mt', summary: 'Specialty Termine', body: 'Hi' })
  })
  it('E-Mail outbound nimmt Empfänger als Gegenpart', () => {
    const r = normalizeInboundEvent({ ...emailIn, email_id: 'mail2', event: 'mail_sent' })
    expect(r).toMatchObject({ direction: 'outbound', counterparty_handle: 'dominik@weckherlin.com' })
  })
  it('Nicht-Nachrichten-Events → null', () => {
    expect(normalizeInboundEvent({ ...linkedinMsg, event: 'message_read' })).toBeNull()
    expect(normalizeInboundEvent({ email_id: 'x', account_id: 'a', event: 'mail_moved' })).toBeNull()
  })
  it('Unbekannter Kanal → null', () => {
    expect(normalizeInboundEvent({ ...linkedinMsg, account_type: 'TELEGRAM' })).toBeNull()
  })
})
```

- [ ] **Step 2: Test laufen, Fehlschlag bestätigen**

Run: `cd apps/web && npx vitest run src/lib/comms/__tests__/normalizeInboundEvent.test.ts`
Expected: FAIL — Modul fehlt.

- [ ] **Step 3: Implementierung**

```ts
// apps/web/src/lib/comms/normalizeInboundEvent.ts
// Normalisiert Unipiles zwei Webhook-Payloads (messaging + email) in eine
// gemeinsame Struktur fürs Einfügen in contact_events.
// Spec: …unipile-design.md §4.1, §6.1
import type { CommsChannel } from '@/types/messaging'
import type { Direction } from '@/types/contactEvents'

export interface NormalizedInbound {
  channel: CommsChannel
  direction: Direction
  external_id: string
  counterparty_handle: string
  summary: string
  body: string
  occurred_at: string
  thread_id?: string
  attachment_count: number
}

// deno-lint-ignore no-explicit-any
type Raw = Record<string, any>

export function normalizeInboundEvent(p: Raw): NormalizedInbound | null {
  // ── E-Mail-Quelle ──
  if (p.email_id) {
    if (p.event !== 'mail_received' && p.event !== 'mail_sent') return null
    const direction: Direction = p.event === 'mail_sent' ? 'outbound' : 'inbound'
    const handleRaw = direction === 'inbound'
      ? p.from_attendee?.identifier
      : p.to_attendees?.[0]?.identifier
    if (!handleRaw) return null
    return {
      channel: 'email',
      direction,
      external_id: p.email_id,
      counterparty_handle: String(handleRaw).trim().toLowerCase(),
      summary: p.subject || '(kein Betreff)',
      body: p.body_plain || p.body || '',
      occurred_at: p.date,
      attachment_count: Array.isArray(p.attachments) ? p.attachments.length : 0,
    }
  }

  // ── Messaging-Quelle (WhatsApp / LinkedIn) ──
  if (p.message_id) {
    if (p.event !== 'message_received') return null
    const channel: CommsChannel | null =
      p.account_type === 'WHATSAPP' ? 'whatsapp'
      : p.account_type === 'LINKEDIN' ? 'linkedin'
      : null
    if (!channel) return null

    const selfId = p.account_info?.user_id
    const senderId = p.sender?.attendee_provider_id
    const isOutbound = !!selfId && senderId === selfId
    const direction: Direction = isOutbound ? 'outbound' : 'inbound'

    const counterparty = isOutbound
      ? (p.attendees ?? []).map((a: Raw) => a.attendee_provider_id).find((id: string) => id && id !== selfId)
      : senderId
    if (!counterparty) return null

    return {
      channel,
      direction,
      external_id: p.message_id,
      counterparty_handle: String(counterparty).trim(),
      summary: (p.message ?? '').slice(0, 140) || '(kein Text)',
      body: p.message ?? '',
      occurred_at: p.timestamp,
      thread_id: p.chat_id,
      attachment_count: Array.isArray(p.attachments) ? p.attachments.length : 0,
    }
  }

  return null
}
```

- [ ] **Step 4: Test laufen, Erfolg bestätigen**

Run: `cd apps/web && npx vitest run src/lib/comms/__tests__/normalizeInboundEvent.test.ts`
Expected: PASS — alle Tests grün.

- [ ] **Step 5: Volle Suite + Commit**

Run: `cd apps/web && npx vitest run`  → alle grün.
```bash
git add apps/web/src/lib/comms/normalizeInboundEvent.ts apps/web/src/lib/comms/__tests__/normalizeInboundEvent.test.ts
git commit -m "feat(comms): normalizeInboundEvent (messaging+email, TDD) [Comms Plan3 T2]"
```

---

### Task 3: Edge Function `comms-inbound`

**Files:**
- Create: `supabase/functions/comms-inbound/index.ts`

- [ ] **Step 1: Funktion schreiben** (Normalizer-Logik gespiegelt — Deno kann nicht aus src importieren)

```ts
// supabase/functions/comms-inbound/index.ts
// Unipile-Webhook (messaging + email). Verifiziert ?token, normalisiert,
// matcht Kontakt via RPC, schreibt contact_events oder messaging_unmatched.
// Deploy mit --no-verify-jwt. Idempotenz über contact_events.external_id.
// Spec: …unipile-design.md §6.1, §7
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0'

const COMMS_NOTIFY_SECRET = Deno.env.get('COMMS_NOTIFY_SECRET')!
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

const EVENT_TYPE: Record<string, string> = {
  email: 'email_external', whatsapp: 'whatsapp_log', linkedin: 'linkedin_message',
}

// deno-lint-ignore no-explicit-any
function normalize(p: any) {
  if (p.email_id) {
    if (p.event !== 'mail_received' && p.event !== 'mail_sent') return null
    const direction = p.event === 'mail_sent' ? 'outbound' : 'inbound'
    const handleRaw = direction === 'inbound' ? p.from_attendee?.identifier : p.to_attendees?.[0]?.identifier
    if (!handleRaw) return null
    return { channel: 'email', direction, external_id: p.email_id,
      counterparty_handle: String(handleRaw).trim().toLowerCase(),
      summary: p.subject || '(kein Betreff)', body: p.body_plain || p.body || '',
      occurred_at: p.date, thread_id: undefined,
      attachment_count: Array.isArray(p.attachments) ? p.attachments.length : 0 }
  }
  if (p.message_id) {
    if (p.event !== 'message_received') return null
    const channel = p.account_type === 'WHATSAPP' ? 'whatsapp' : p.account_type === 'LINKEDIN' ? 'linkedin' : null
    if (!channel) return null
    const selfId = p.account_info?.user_id
    const senderId = p.sender?.attendee_provider_id
    const isOutbound = !!selfId && senderId === selfId
    const counterparty = isOutbound
      ? (p.attendees ?? []).map((a: any) => a.attendee_provider_id).find((id: string) => id && id !== selfId)
      : senderId
    if (!counterparty) return null
    return { channel, direction: isOutbound ? 'outbound' : 'inbound', external_id: p.message_id,
      counterparty_handle: String(counterparty).trim(),
      summary: (p.message ?? '').slice(0, 140) || '(kein Text)', body: p.message ?? '',
      occurred_at: p.timestamp, thread_id: p.chat_id,
      attachment_count: Array.isArray(p.attachments) ? p.attachments.length : 0 }
  }
  return null
}

serve(async (req) => {
  if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 })
  if (new URL(req.url).searchParams.get('token') !== COMMS_NOTIFY_SECRET) {
    return new Response('Forbidden', { status: 403 })
  }

  const payload = await req.json().catch(() => null)
  if (!payload) return new Response('Bad payload', { status: 200 })

  const n = normalize(payload)
  if (!n) return new Response('Ignored', { status: 200 })   // Reaktionen/Reads/unbekannte Kanäle

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE)

  // Quell-Konto auflösen (owner + FK). Unbekanntes Konto → still ignorieren.
  const { data: acct } = await admin.from('messaging_accounts')
    .select('id').eq('unipile_account_id', payload.account_id).maybeSingle()
  const messagingAccountId = acct?.id ?? null

  // Kontakt matchen
  const { data: contactId } = await admin
    .rpc('match_contact_by_handle', { p_channel: n.channel, p_handle: n.counterparty_handle })

  const eventPayload = {
    source: 'auto', direction: n.direction, provider_message_id: n.external_id,
    thread_id: n.thread_id, attachment_count: n.attachment_count, unipile_account_id: payload.account_id,
  }

  if (!contactId) {
    // Quarantäne — idempotent über external_id (unique index)
    const { error } = await admin.from('messaging_unmatched').upsert({
      channel: n.channel, sender_handle: n.counterparty_handle,
      normalized_payload: { ...n, raw_event: payload.event }, external_id: n.external_id,
    }, { onConflict: 'external_id' })
    if (error && !error.message.includes('duplicate')) return new Response(error.message, { status: 500 })
    return new Response('Quarantined', { status: 200 })
  }

  // Event schreiben — Idempotenz: bei Unique-Verletzung (external_id) einfach 200.
  const { error } = await admin.from('contact_events').insert({
    contact_id: contactId,
    event_type: EVENT_TYPE[n.channel],
    occurred_at: n.occurred_at,
    summary: n.summary,
    body: n.body,
    payload: eventPayload,
    external_id: n.external_id,
    messaging_account_id: messagingAccountId,
  })
  if (error) {
    if (error.code === '23505') return new Response('Duplicate', { status: 200 })  // unique_violation
    return new Response(error.message, { status: 500 })
  }

  // last_event_at am Konto nachziehen (best effort)
  if (messagingAccountId) {
    await admin.from('messaging_accounts').update({ last_event_at: n.occurred_at }).eq('id', messagingAccountId)
  }

  return new Response('OK', { status: 200 })
})
```

- [ ] **Step 2: Deployen**

Run: `npx supabase functions deploy comms-inbound --no-verify-jwt`
Expected: „Deployed Function comms-inbound".

- [ ] **Step 3: Lokal simulieren (E-Mail-Inbound auf bekannten Kontakt)**

Run (eine echte Kontakt-E-Mail + dein Token einsetzen):
```bash
curl -X POST "https://axnrilhdokkfujzjifhj.supabase.co/functions/v1/comms-inbound?token=$COMMS_NOTIFY_SECRET" \
  -H 'content-type: application/json' \
  -d '{"email_id":"test-1","account_id":"<UNIPILE_ACCOUNT_ID>","event":"mail_received","date":"2026-05-29T10:00:00.000Z","from_attendee":{"identifier":"<KONTAKT_EMAIL>"},"to_attendees":[{"identifier":"dominik@weckherlin.com"}],"subject":"Webhook-Test","body_plain":"Hallo aus dem Test"}'
```
Expected: `OK` (Kontakt-Treffer) → neue Zeile in `contact_events` (event_type `email_external`); ODER `Quarantined` (kein Treffer) → Zeile in `messaging_unmatched`. Falscher Token → `Forbidden`.

- [ ] **Step 4: Commit**

```bash
git add supabase/functions/comms-inbound/index.ts
git commit -m "feat(comms): comms-inbound webhook → timeline/quarantine [Comms Plan3 T3]"
```

---

### Task 4: Unipile-Webhooks registrieren + E2E (Dominik)

**Files:** keine (Betrieb).

- [ ] **Step 1: Beide Webhook-Quellen bei Unipile anlegen**

Im Unipile-Dashboard (Webhooks) ODER per API zwei Webhooks auf dieselbe URL zeigen lassen:
`https://axnrilhdokkfujzjifhj.supabase.co/functions/v1/comms-inbound?token=<COMMS_NOTIFY_SECRET>`
- Quelle **messaging** (WhatsApp/LinkedIn), Event `message_received`
- Quelle **email** (Gmail/Outlook/IMAP), Event `mail_received` (+ optional `mail_sent`)

Per API (Beispiel messaging):
```bash
curl -X POST "https://api13.unipile.com:14315/api/v1/webhooks" \
  -H "X-API-KEY: <UNIPILE_API_KEY>" -H 'content-type: application/json' \
  -d '{"source":"messaging","request_url":"https://axnrilhdokkfujzjifhj.supabase.co/functions/v1/comms-inbound?token=<COMMS_NOTIFY_SECRET>","name":"comms-inbound-messaging","headers":[{"key":"content-type","value":"application/json"}]}'
```
(Für E-Mail `"source":"email"`.)

- [ ] **Step 2: Echte Nachricht testen**

Schick eine E-Mail an das verbundene Postfach von einer Adresse, die als Kontakt hinterlegt ist → in der Timeline dieses Kontakts erscheint das Event. Von einer unbekannten Adresse → Quarantäne (`messaging_unmatched`).

Expected: Event erscheint automatisch (Spec §1 Ziel erreicht).

- [ ] **Step 3: `acct.type`/`provider_id`-Formate verifizieren (Spec §9)**

Beim ersten echten WhatsApp/LinkedIn-Event prüfen, ob `sender.attendee_provider_id` (WhatsApp = Telefonnummer-Format) sauber gegen `contacts.phones[].e164` matcht. Falls WhatsApp-IDs einen Suffix tragen (z.B. `@s.whatsapp.net`), im Normalizer vor dem Match abschneiden. Logs: Supabase → Edge Functions → comms-inbound.

---

## Self-Review (durchgeführt)

- **Spec-Abdeckung:** §6.1 inbound (T3), §4.1 Event-Payload (T2/T3), §4.2 Matching (T1/T2), §4.3 Idempotenz (T3 via external_id unique), §7 Fehlerfälle (Quarantäne, Duplicate, unbekanntes Konto → alle 200; Signatur via Token → 403).
- **Platzhalter:** keiner (Ops-Werte wie `<UNIPILE_API_KEY>` sind bewusste Einsetzpunkte, keine Code-Lücken).
- **Typ-Konsistenz:** `NormalizedInbound`, `CommsChannel`, `Direction`, `EVENT_TYPE`, `external_id`, `match_contact_by_handle` durchgängig identisch über RPC, Normalizer und Edge Function.
- **Live zu verifizieren (Spec §9):** WhatsApp-`attendee_provider_id`-Format (evtl. Suffix) und ob Unipile pro Quelle exakt diese Feldnamen schickt — beim ersten echten Event gegenprüfen.

## Nächster Plan

- **Plan 4 — `comms-outbound`:** Senden aus dem Composer → Unipile-Send-API → outbound-Event (das Empfangen gesendeter Nachrichten deckt `comms-inbound` bereits ab, also Fokus auf den Sende-Pfad + Composer-UI).
