# Comms-Integration — Plan 4: comms-outbound (Senden aus dem Composer)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Comms-Staff sendet E-Mail / WhatsApp / LinkedIn direkt aus dem Kontakt-Composer; die gesendete Nachricht erscheint als outbound-Event in der Timeline.

**Architecture:** Eine authentifizierte Edge Function `comms-outbound` löst Konto + Empfänger-Handle serverseitig auf, ruft Unipiles Send-API (E-Mail: `POST /api/v1/emails`; Messaging: `POST /api/v1/chats`) und schreibt das outbound-Event mit der zurückgegebenen Provider-ID als `external_id`. Der Inbound-Webhook echo't gesendete Nachrichten ohnehin — die Idempotenz über `external_id` verhindert das Doppeln.

**Tech Stack:** Supabase Edge Functions (Deno), Unipile Send-API, React/TS, Vitest.

**Spec:** `docs/superpowers/specs/2026-05-29-comms-integration-unipile-design.md` §6.1, §6.2
**Verifizierte Unipile-Send-API:**
- E-Mail: `POST https://{DSN}/api/v1/emails` (JSON) — `{ account_id, to:[{identifier}], subject, body }`.
- Messaging (neuer/bestehender 1:1-Chat): `POST https://{DSN}/api/v1/chats` (multipart) — `account_id`, `text`, `attendees_ids`. WhatsApp-`attendees_ids` = `<e164-ohne-plus>@s.whatsapp.net`; LinkedIn = `linkedin_member_id` (nur mit Relations, sonst InMail).

---

### Task 1: `toUnipileRecipient` (reine Empfänger-Konstruktion, TDD)

**Files:**
- Create: `apps/web/src/lib/comms/toUnipileRecipient.ts`
- Test: `apps/web/src/lib/comms/__tests__/toUnipileRecipient.test.ts`

- [ ] **Step 1: Failing test**

```ts
import { describe, it, expect } from 'vitest'
import { toUnipileRecipient } from '../toUnipileRecipient'

describe('toUnipileRecipient', () => {
  it('email → identifier', () => {
    expect(toUnipileRecipient('email', { email: 'a@b.com' })).toEqual({ kind: 'email', identifier: 'a@b.com' })
  })
  it('whatsapp → <e164 ohne +>@s.whatsapp.net', () => {
    expect(toUnipileRecipient('whatsapp', { e164: '+41791234567' }))
      .toEqual({ kind: 'attendee', identifier: '41791234567@s.whatsapp.net' })
  })
  it('linkedin → member_id', () => {
    expect(toUnipileRecipient('linkedin', { linkedin_member_id: 'ACoAAB' }))
      .toEqual({ kind: 'attendee', identifier: 'ACoAAB' })
  })
  it('fehlender Handle → null', () => {
    expect(toUnipileRecipient('email', {})).toBeNull()
    expect(toUnipileRecipient('whatsapp', {})).toBeNull()
    expect(toUnipileRecipient('linkedin', {})).toBeNull()
  })
})
```

- [ ] **Step 2: Test fehlschlagen lassen**

Run: `cd apps/web && npx vitest run src/lib/comms/__tests__/toUnipileRecipient.test.ts`
Expected: FAIL — Modul fehlt.

- [ ] **Step 3: Implementierung**

```ts
// apps/web/src/lib/comms/toUnipileRecipient.ts
// Baut aus den Kontaktdaten den Unipile-Empfänger pro Kanal.
// Spec: docs/superpowers/specs/2026-05-29-comms-integration-unipile-design.md §6.1
import type { CommsChannel } from '@/types/messaging'

export interface RecipientFields {
  email?: string | null
  e164?: string | null
  linkedin_member_id?: string | null
}
export interface UnipileRecipient {
  kind: 'email' | 'attendee'
  identifier: string
}

export function toUnipileRecipient(channel: CommsChannel, f: RecipientFields): UnipileRecipient | null {
  if (channel === 'email') {
    return f.email ? { kind: 'email', identifier: f.email } : null
  }
  if (channel === 'whatsapp') {
    if (!f.e164) return null
    return { kind: 'attendee', identifier: `${f.e164.replace(/^\+/, '')}@s.whatsapp.net` }
  }
  if (channel === 'linkedin') {
    return f.linkedin_member_id ? { kind: 'attendee', identifier: f.linkedin_member_id } : null
  }
  return null
}
```

- [ ] **Step 4: Test bestehen + volle Suite + Commit**

Run: `cd apps/web && npx vitest run` → grün.
```bash
git add apps/web/src/lib/comms/toUnipileRecipient.ts apps/web/src/lib/comms/__tests__/toUnipileRecipient.test.ts
git commit -m "feat(comms): toUnipileRecipient (TDD) [Comms Plan4 T1]"
```

---

### Task 2: Edge Function `comms-outbound`

**Files:**
- Create: `supabase/functions/comms-outbound/index.ts`

- [ ] **Step 1: Funktion schreiben**

```ts
// supabase/functions/comms-outbound/index.ts
// Sendet eine Nachricht über Unipile und schreibt das outbound-Event.
// Aufruf via supabase.functions.invoke('comms-outbound',
//   { body: { contact_id, channel, body, subject? } }).
// Spec: …unipile-design.md §6.1
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0'

const UNIPILE_API_KEY = Deno.env.get('UNIPILE_API_KEY')!
const UNIPILE_DSN = 'api13.unipile.com:14315'           // wie comms-connect (DSN kein Geheimnis)
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...corsHeaders, 'content-type': 'application/json' } })

const EVENT_TYPE: Record<string, string> = {
  email: 'email_external', whatsapp: 'whatsapp_log', linkedin: 'linkedin_message',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405)

  try {
    // Auth-User
    const supa = createClient(SUPABASE_URL, Deno.env.get('SUPABASE_ANON_KEY')!, {
      global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } },
    })
    const { data: { user } } = await supa.auth.getUser()
    if (!user) return json({ error: 'unauthorized' }, 401)

    const { contact_id, channel, body, subject } = await req.json().catch(() => ({}))
    if (!contact_id || !channel || !body) return json({ error: 'bad_request' }, 400)

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE)

    // Verbundenes Konto des Users für diesen Kanal
    const { data: acct } = await admin.from('messaging_accounts')
      .select('id, unipile_account_id').eq('owner_user_id', user.id).eq('channel', channel)
      .eq('status', 'connected').limit(1).maybeSingle()
    if (!acct) return json({ error: 'no_connected_account', channel }, 409)

    // Kontakt-Handle bestimmen
    const { data: c } = await admin.from('contacts')
      .select('emails, phones, linkedin_member_id').eq('id', contact_id).single()
    const email = (c?.emails ?? []).find((e: { primary?: boolean }) => e.primary)?.email
      ?? (c?.emails ?? [])[0]?.email
    const e164 = (c?.phones ?? []).find((p: { whatsapp?: boolean }) => p.whatsapp)?.e164
      ?? (c?.phones ?? [])[0]?.e164

    let providerMessageId: string
    if (channel === 'email') {
      if (!email) return json({ error: 'no_recipient', channel }, 422)
      const res = await fetch(`https://${UNIPILE_DSN}/api/v1/emails`, {
        method: 'POST',
        headers: { 'X-API-KEY': UNIPILE_API_KEY, 'content-type': 'application/json', accept: 'application/json' },
        body: JSON.stringify({ account_id: acct.unipile_account_id, to: [{ identifier: email }], subject: subject ?? '(kein Betreff)', body }),
      })
      const text = await res.text()
      if (!res.ok) return json({ error: 'unipile_send_failed', http: res.status, detail: text }, 502)
      providerMessageId = (JSON.parse(text).id ?? JSON.parse(text).email_id ?? crypto.randomUUID())
    } else {
      const identifier = channel === 'whatsapp'
        ? (e164 ? `${e164.replace(/^\+/, '')}@s.whatsapp.net` : null)
        : c?.linkedin_member_id
      if (!identifier) return json({ error: 'no_recipient', channel }, 422)
      const form = new FormData()
      form.append('account_id', acct.unipile_account_id)
      form.append('text', body)
      form.append('attendees_ids', identifier)
      const res = await fetch(`https://${UNIPILE_DSN}/api/v1/chats`, {
        method: 'POST', headers: { 'X-API-KEY': UNIPILE_API_KEY, accept: 'application/json' }, body: form,
      })
      const text = await res.text()
      if (!res.ok) return json({ error: 'unipile_send_failed', http: res.status, detail: text }, 502)
      const parsed = JSON.parse(text)
      providerMessageId = parsed.message_id ?? parsed.id ?? crypto.randomUUID()
    }

    // Outbound-Event schreiben (Webhook-Echo wird per external_id dedupliziert)
    const { error } = await admin.from('contact_events').insert({
      contact_id, event_type: EVENT_TYPE[channel], occurred_at: new Date().toISOString(),
      summary: channel === 'email' ? (subject ?? '(kein Betreff)') : body.slice(0, 140),
      body,
      payload: { source: 'auto', direction: 'outbound', provider_message_id: providerMessageId, unipile_account_id: acct.unipile_account_id },
      external_id: providerMessageId, messaging_account_id: acct.id,
    })
    if (error && error.code !== '23505') return json({ error: 'db_insert_failed', detail: error.message }, 500)

    return json({ ok: true, provider_message_id: providerMessageId })
  } catch (e) {
    return json({ error: 'exception', detail: String((e as Error)?.message ?? e) }, 500)
  }
})
```

- [ ] **Step 2: Deployen**

Run: `npx supabase functions deploy comms-outbound`
Expected: „Deployed Function comms-outbound".

- [ ] **Step 3: Commit**

```bash
git add supabase/functions/comms-outbound/index.ts
git commit -m "feat(comms): comms-outbound send via Unipile [Comms Plan4 T2]"
```

---

### Task 3: `useSendMessage`-Hook + Composer auf echtes Senden

**Files:**
- Create: `apps/web/src/hooks/useSendMessage.ts`
- Modify: `apps/web/src/screens/contacts/timeline/composers/EmailLogComposer.tsx` (Senden statt Log, wenn E-Mail-Konto verbunden)

- [ ] **Step 1: Hook (TDD)**

Create `apps/web/src/hooks/useSendMessage.ts`:
```ts
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import type { CommsChannel } from '@/types/messaging'

export interface SendInput { contact_id: string; channel: CommsChannel; body: string; subject?: string }

export function useSendMessage(contactId: string) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async (input: SendInput) => {
      const { data, error } = await supabase.functions.invoke('comms-outbound', { body: input })
      if (error) throw error
      return data as { ok: boolean; provider_message_id: string }
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['contact-timeline', contactId] })
      qc.invalidateQueries({ queryKey: ['global-activity'] })
    },
  })
}
```

Test `apps/web/src/hooks/__tests__/useSendMessage.test.tsx`:
```tsx
import { describe, it, expect, vi } from 'vitest'
import { renderHook, waitFor, act } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { createElement, type ReactNode } from 'react'
import { useSendMessage } from '../useSendMessage'

const invoke = vi.fn().mockResolvedValue({ data: { ok: true, provider_message_id: 'm1' }, error: null })
vi.mock('@/lib/supabase', () => ({ supabase: { functions: { invoke: (...a: unknown[]) => invoke(...a) } } }))

function wrapper({ children }: { children: ReactNode }) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false }, mutations: { retry: false } } })
  return createElement(QueryClientProvider, { client: qc }, children)
}

describe('useSendMessage', () => {
  it('ruft comms-outbound mit dem Input', async () => {
    const { result } = renderHook(() => useSendMessage('c1'), { wrapper })
    await act(async () => { await result.current.mutateAsync({ contact_id: 'c1', channel: 'email', body: 'Hi', subject: 'S' }) })
    await waitFor(() => expect(invoke).toHaveBeenCalledWith('comms-outbound',
      { body: { contact_id: 'c1', channel: 'email', body: 'Hi', subject: 'S' } }))
  })
})
```

Run: `cd apps/web && npx vitest run src/hooks/__tests__/useSendMessage.test.tsx` → erst FAIL, nach Implementierung PASS.

- [ ] **Step 2: EmailLogComposer auf Senden umstellen** (wenn E-Mail-Konto verbunden, sonst Fallback aufs bestehende Log)

In `EmailLogComposer.tsx`: `useMessagingAccounts()` lesen; gibt es ein verbundenes `email`-Konto, ruft „Senden" `useSendMessage(...).mutate({ contact_id, channel:'email', subject, body })` statt `useInsertContactEvent`. Sonst unverändert (manuelles Log). Bestehende Tests dürfen nicht brechen.

- [ ] **Step 3: Typecheck + Suite + Commit**

Run: `cd apps/web && npx tsc --noEmit && npx vitest run` → grün.
```bash
git add apps/web/src/hooks/useSendMessage.ts apps/web/src/hooks/__tests__/useSendMessage.test.tsx apps/web/src/screens/contacts/timeline/composers/EmailLogComposer.tsx
git commit -m "feat(comms): useSendMessage + EmailComposer echtes Senden [Comms Plan4 T3]"
```

---

### Task 4: E2E + Kanal-Formate verifizieren (Dominik)

- [ ] **Step 1:** `npx supabase functions deploy comms-outbound` (falls noch nicht).
- [ ] **Step 2:** In AtollKom einen Kontakt mit hinterlegter E-Mail öffnen → E-Mail-Composer → senden. Erwartung: Mail geht raus, outbound-Event erscheint in der Timeline (genau einmal — Webhook-Echo dedupliziert).
- [ ] **Step 3 (Spec §9):** Beim ersten echten WhatsApp-Versand prüfen, ob `attendees_ids = <e164>@s.whatsapp.net` von Unipile akzeptiert wird, und beim ersten WhatsApp-**Empfang** ob `sender.attendee_provider_id` denselben `@s.whatsapp.net`-Suffix trägt — falls ja, im Inbound-Normalizer für WhatsApp vor dem Kontakt-Match den Suffix abschneiden (Plan-3-Hardening).

---

## Self-Review (durchgeführt)

- **Spec-Abdeckung:** §6.1 Senden (T2), §6.2 Composer (T3), Idempotenz ggü. Webhook-Echo via `external_id` (T2).
- **Platzhalter:** keiner.
- **Typ-Konsistenz:** `CommsChannel`, `EVENT_TYPE`, `external_id`, `messaging_accounts`-Felder, `comms-outbound` durchgängig identisch.
- **Live zu verifizieren (Spec §9):** WhatsApp-`attendees_ids`/`provider_id`-Format (`@s.whatsapp.net`) beim ersten echten WhatsApp-Verkehr; LinkedIn nur mit Relations.

## Cross-cutting Hardening (separat, klein)
- Inbound-WhatsApp-Matching: `@s.whatsapp.net`-Suffix in `normalizeInboundEvent` abschneiden, sobald per Live-Event bestätigt.
- DSN: derzeit in `comms-connect` / `comms-connect-notify` / `comms-outbound` hardcoded — zurück auf ein (korrekt gesetztes) Secret, sobald die CLI-Token-Hygiene erledigt ist.
