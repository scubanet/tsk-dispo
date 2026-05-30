# Comms-Integration — Plan 2: comms-connect + Verbindungs-UI

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Comms-Staff (dispo/cd/owner) kann E-Mail-, WhatsApp- und LinkedIn-Konten über Unipiles Hosted-Auth verbinden; die Verbindung landet in `messaging_accounts`.

**Architecture:** Eine authentifizierte Edge Function `comms-connect` erzeugt pro Klick einen Unipile-Hosted-Auth-Link (X-API-KEY bleibt serverseitig). Eine öffentliche Edge Function `comms-connect-notify` empfängt Unipiles Callback, holt die Account-Details und upsertet `messaging_accounts` (Service-Rolle). Im Settings-Screen listet eine neue Sektion die Konten und bietet „verbinden" pro Kanal.

**Tech Stack:** Supabase Edge Functions (Deno), Unipile Hosted-Auth-API, React/TS (`apps/web`), Vitest, Foundation-UI.

**Spec:** `docs/superpowers/specs/2026-05-29-comms-integration-unipile-design.md` §6.1, §6.2, §5
**Voraussetzung (Dominik):** Supabase-Secrets gesetzt — `UNIPILE_API_KEY`, `UNIPILE_DSN` (z.B. `apiXXX.unipile.com:XXX`), `COMMS_NOTIFY_SECRET` (zufälliger String), `APP_URL` (`https://tsk.atoll-os.com`).

**Referenz Unipile:** `POST https://{DSN}/api/v1/hosted/accounts/link` (Header `X-API-KEY`) →
`{ "object":"HostedAuthURL", "url":"…" }`. Callback an `notify_url`:
`{ "status":"CREATION_SUCCESS"|"RECONNECTED", "account_id":"…", "name":"<user_id>" }`.
Account-Details: `GET https://{DSN}/api/v1/accounts/{id}` (Header `X-API-KEY`).

---

### Task 1: Provider-Mapping (rein, TDD)

**Files:**
- Create: `apps/web/src/lib/comms/mapUnipileProvider.ts`
- Test: `apps/web/src/lib/comms/__tests__/mapUnipileProvider.test.ts`

- [ ] **Step 1: Failing test schreiben**

```ts
import { describe, it, expect } from 'vitest'
import { mapUnipileProvider, providersForChannel } from '../mapUnipileProvider'

describe('mapUnipileProvider', () => {
  it('GOOGLE → email/gmail', () => {
    expect(mapUnipileProvider('GOOGLE')).toEqual({ channel: 'email', provider: 'gmail' })
  })
  it('OUTLOOK → email/outlook', () => {
    expect(mapUnipileProvider('OUTLOOK')).toEqual({ channel: 'email', provider: 'outlook' })
  })
  it('MAIL → email/imap', () => {
    expect(mapUnipileProvider('MAIL')).toEqual({ channel: 'email', provider: 'imap' })
  })
  it('WHATSAPP → whatsapp', () => {
    expect(mapUnipileProvider('WHATSAPP')).toEqual({ channel: 'whatsapp', provider: 'whatsapp' })
  })
  it('LINKEDIN → linkedin', () => {
    expect(mapUnipileProvider('LINKEDIN')).toEqual({ channel: 'linkedin', provider: 'linkedin' })
  })
  it('Unbekannt → null', () => {
    expect(mapUnipileProvider('TELEGRAM')).toBeNull()
  })
})

describe('providersForChannel', () => {
  it('email → Google/Outlook/IMAP', () => {
    expect(providersForChannel('email')).toEqual(['GOOGLE', 'OUTLOOK', 'MAIL'])
  })
  it('whatsapp → WHATSAPP', () => {
    expect(providersForChannel('whatsapp')).toEqual(['WHATSAPP'])
  })
  it('linkedin → LINKEDIN', () => {
    expect(providersForChannel('linkedin')).toEqual(['LINKEDIN'])
  })
})
```

- [ ] **Step 2: Test laufen, Fehlschlag bestätigen**

Run: `cd apps/web && npx vitest run src/lib/comms/__tests__/mapUnipileProvider.test.ts`
Expected: FAIL — „Cannot find module '../mapUnipileProvider'".

- [ ] **Step 3: Implementierung**

```ts
// apps/web/src/lib/comms/mapUnipileProvider.ts
// Übersetzt zwischen Unipile-Account-Typen und unseren CommsChannel/provider.
// Spec: …unipile-design.md §4.4
import type { CommsChannel } from '@/types/messaging'

export interface ChannelProvider {
  channel: CommsChannel
  provider: string
}

const MAP: Record<string, ChannelProvider> = {
  GOOGLE:   { channel: 'email',    provider: 'gmail' },
  OUTLOOK:  { channel: 'email',    provider: 'outlook' },
  MAIL:     { channel: 'email',    provider: 'imap' },
  WHATSAPP: { channel: 'whatsapp', provider: 'whatsapp' },
  LINKEDIN: { channel: 'linkedin', provider: 'linkedin' },
}

export function mapUnipileProvider(unipileType: string): ChannelProvider | null {
  return MAP[unipileType.toUpperCase()] ?? null
}

export function providersForChannel(channel: CommsChannel): string[] {
  if (channel === 'email') return ['GOOGLE', 'OUTLOOK', 'MAIL']
  if (channel === 'whatsapp') return ['WHATSAPP']
  return ['LINKEDIN']
}
```

- [ ] **Step 4: Test laufen, Erfolg bestätigen**

Run: `cd apps/web && npx vitest run src/lib/comms/__tests__/mapUnipileProvider.test.ts`
Expected: PASS — 9 Tests grün.

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/lib/comms/mapUnipileProvider.ts apps/web/src/lib/comms/__tests__/mapUnipileProvider.test.ts
git commit -m "feat(comms): Unipile-Provider-Mapping (TDD) [Comms Plan2 T1]"
```

---

### Task 2: Edge Function `comms-connect` (Hosted-Auth-Link erzeugen)

**Files:**
- Create: `supabase/functions/comms-connect/index.ts`

- [ ] **Step 1: Funktion schreiben**

```ts
// supabase/functions/comms-connect/index.ts
// Erzeugt einen Unipile-Hosted-Auth-Link für den eingeloggten Comms-Staff.
// X-API-KEY bleibt serverseitig. Aufruf via supabase.functions.invoke('comms-connect',
// { body: { channel: 'email'|'whatsapp'|'linkedin' } }).
// Spec: …unipile-design.md §6.1
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0'

const UNIPILE_API_KEY = Deno.env.get('UNIPILE_API_KEY')!
const UNIPILE_DSN = Deno.env.get('UNIPILE_DSN')!          // z.B. apiXXX.unipile.com:XXX
const COMMS_NOTIFY_SECRET = Deno.env.get('COMMS_NOTIFY_SECRET')!
const APP_URL = Deno.env.get('APP_URL') ?? 'https://tsk.atoll-os.com'
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!

const PROVIDERS: Record<string, string[]> = {
  email: ['GOOGLE', 'OUTLOOK', 'MAIL'],
  whatsapp: ['WHATSAPP'],
  linkedin: ['LINKEDIN'],
}

serve(async (req) => {
  if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 })

  // Authenticated user aus dem Bearer-Token (von functions.invoke gesetzt).
  const authHeader = req.headers.get('Authorization') ?? ''
  const supabase = createClient(SUPABASE_URL, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: authHeader } },
  })
  const { data: { user }, error: userErr } = await supabase.auth.getUser()
  if (userErr || !user) return new Response('Unauthorized', { status: 401 })

  const { channel } = await req.json().catch(() => ({ channel: null }))
  const providers = PROVIDERS[channel]
  if (!providers) return new Response('Bad channel', { status: 400 })

  const expiresOn = new Date(Date.now() + 60 * 60 * 1000).toISOString()  // +1h
  const notifyUrl = `${SUPABASE_URL}/functions/v1/comms-connect-notify?token=${COMMS_NOTIFY_SECRET}`

  const res = await fetch(`https://${UNIPILE_DSN}/api/v1/hosted/accounts/link`, {
    method: 'POST',
    headers: { 'X-API-KEY': UNIPILE_API_KEY, 'content-type': 'application/json', accept: 'application/json' },
    body: JSON.stringify({
      type: 'create',
      providers,
      api_url: `https://${UNIPILE_DSN}`,
      expiresOn,
      notify_url: notifyUrl,
      name: user.id,                                   // → kommt im Callback als `name` zurück
      success_redirect_url: `${APP_URL}/einstellungen?connected=1`,
      failure_redirect_url: `${APP_URL}/einstellungen?connected=0`,
    }),
  })
  if (!res.ok) {
    return new Response(JSON.stringify({ error: 'unipile_link_failed', detail: await res.text() }),
      { status: 502, headers: { 'content-type': 'application/json' } })
  }
  const { url } = await res.json()
  return new Response(JSON.stringify({ url }), { headers: { 'content-type': 'application/json' } })
})
```

- [ ] **Step 2: Lokal deployen & Smoke-Test**

Run:
```bash
cd ~/Desktop/Developer/Dispo
npx supabase functions deploy comms-connect
```
Expected: „Deployed Function comms-connect". (Voll-Test im Frontend in Task 5.)

- [ ] **Step 3: Commit**

```bash
git add supabase/functions/comms-connect/index.ts
git commit -m "feat(comms): comms-connect edge function — hosted-auth link [Comms Plan2 T2]"
```

---

### Task 3: Edge Function `comms-connect-notify` (Callback → messaging_accounts)

**Files:**
- Create: `supabase/functions/comms-connect-notify/index.ts`

- [ ] **Step 1: Funktion schreiben**

```ts
// supabase/functions/comms-connect-notify/index.ts
// Öffentlicher Callback von Unipile nach erfolgreicher Konto-Verbindung.
// Verifiziert ?token=COMMS_NOTIFY_SECRET, holt Account-Details, upsertet
// messaging_accounts via Service-Rolle (umgeht RLS).
// Spec: …unipile-design.md §6.1, §5
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0'

const UNIPILE_API_KEY = Deno.env.get('UNIPILE_API_KEY')!
const UNIPILE_DSN = Deno.env.get('UNIPILE_DSN')!
const COMMS_NOTIFY_SECRET = Deno.env.get('COMMS_NOTIFY_SECRET')!
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

// Mirror von apps/web/src/lib/comms/mapUnipileProvider.ts (Deno kann nicht aus src importieren).
const MAP: Record<string, { channel: string; provider: string }> = {
  GOOGLE:   { channel: 'email',    provider: 'gmail' },
  OUTLOOK:  { channel: 'email',    provider: 'outlook' },
  MAIL:     { channel: 'email',    provider: 'imap' },
  WHATSAPP: { channel: 'whatsapp', provider: 'whatsapp' },
  LINKEDIN: { channel: 'linkedin', provider: 'linkedin' },
}

serve(async (req) => {
  if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 })

  const token = new URL(req.url).searchParams.get('token')
  if (token !== COMMS_NOTIFY_SECRET) return new Response('Forbidden', { status: 403 })

  const { status, account_id, name } = await req.json().catch(() => ({}))
  if ((status !== 'CREATION_SUCCESS' && status !== 'RECONNECTED') || !account_id || !name) {
    return new Response('Ignored', { status: 200 })   // nichts zu tun, aber 200 damit Unipile nicht retryed
  }

  // Account-Details holen, um Kanal/Provider/Label zu bestimmen.
  const acctRes = await fetch(`https://${UNIPILE_DSN}/api/v1/accounts/${account_id}`, {
    headers: { 'X-API-KEY': UNIPILE_API_KEY, accept: 'application/json' },
  })
  if (!acctRes.ok) return new Response('account_fetch_failed', { status: 502 })
  const acct = await acctRes.json()
  const mapped = MAP[(acct.type ?? '').toUpperCase()]
  if (!mapped) return new Response('unknown_provider', { status: 200 })

  const label = acct.name ?? acct.username ?? acct.email ?? mapped.channel

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE)
  const { error } = await admin.from('messaging_accounts').upsert({
    channel: mapped.channel,
    unipile_account_id: account_id,
    provider: mapped.provider,
    label,
    owner_user_id: name,            // = user.id, von comms-connect gesetzt
    status: 'connected',
    last_event_at: null,
  }, { onConflict: 'unipile_account_id' })

  if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  return new Response('OK', { status: 200 })
})
```

- [ ] **Step 2: Deployen (--no-verify-jwt, da Unipile keinen Supabase-JWT schickt)**

Run:
```bash
cd ~/Desktop/Developer/Dispo
npx supabase functions deploy comms-connect-notify --no-verify-jwt
```
Expected: „Deployed Function comms-connect-notify".

- [ ] **Step 3: Callback simulieren**

Run (DSN/SECRET einsetzen; account_id muss real existieren):
```bash
curl -X POST "https://axnrilhdokkfujzjifhj.supabase.co/functions/v1/comms-connect-notify?token=$COMMS_NOTIFY_SECRET" \
  -H 'content-type: application/json' \
  -d '{"status":"CREATION_SUCCESS","account_id":"<REAL_ID>","name":"<DEIN_AUTH_USER_ID>"}'
```
Expected: `OK`; eine Zeile in `messaging_accounts`. Falscher Token → `Forbidden`.

- [ ] **Step 4: Commit**

```bash
git add supabase/functions/comms-connect-notify/index.ts
git commit -m "feat(comms): comms-connect-notify callback → messaging_accounts [Comms Plan2 T3]"
```

---

### Task 4: Frontend-Hook `useMessagingAccounts` (TDD)

**Files:**
- Create: `apps/web/src/hooks/useMessagingAccounts.ts`
- Test: `apps/web/src/hooks/__tests__/useMessagingAccounts.test.tsx`

- [ ] **Step 1: Failing test schreiben**

```tsx
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { renderHook, waitFor } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { createElement, type ReactNode } from 'react'
import { useMessagingAccounts } from '../useMessagingAccounts'

const rows = [{ id: 'a1', channel: 'email', unipile_account_id: 'u1', provider: 'gmail',
  label: 'lena@gmail.com', owner_user_id: 'me', status: 'connected', connected_at: 'x', last_event_at: null }]

vi.mock('@/lib/supabase', () => ({
  supabase: { from: () => ({ select: () => ({ order: () => Promise.resolve({ data: rows, error: null }) }) }) },
}))

function wrapper({ children }: { children: ReactNode }) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  return createElement(QueryClientProvider, { client: qc }, children)
}

describe('useMessagingAccounts', () => {
  beforeEach(() => vi.clearAllMocks())
  it('lädt verbundene Konten', async () => {
    const { result } = renderHook(() => useMessagingAccounts(), { wrapper })
    await waitFor(() => expect(result.current.data).toHaveLength(1))
    expect(result.current.data![0].label).toBe('lena@gmail.com')
  })
})
```

- [ ] **Step 2: Test laufen, Fehlschlag bestätigen**

Run: `cd apps/web && npx vitest run src/hooks/__tests__/useMessagingAccounts.test.tsx`
Expected: FAIL — Modul fehlt.

- [ ] **Step 3: Implementierung**

```ts
// apps/web/src/hooks/useMessagingAccounts.ts
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import type { MessagingAccount, CommsChannel } from '@/types/messaging'

export function useMessagingAccounts() {
  return useQuery({
    queryKey: ['messaging-accounts'],
    queryFn: async (): Promise<MessagingAccount[]> => {
      const { data, error } = await supabase
        .from('messaging_accounts')
        .select('*')
        .order('connected_at', { ascending: false })
      if (error) throw error
      return (data ?? []) as MessagingAccount[]
    },
  })
}

/** Startet den Hosted-Auth-Flow: holt den Link und leitet weiter. */
export function useConnectAccount() {
  return useMutation({
    mutationFn: async (channel: CommsChannel) => {
      const { data, error } = await supabase.functions.invoke('comms-connect', { body: { channel } })
      if (error) throw error
      const url = (data as { url?: string })?.url
      if (!url) throw new Error('Kein Auth-Link erhalten')
      return url
    },
    onSuccess: (url) => { window.location.href = url },
  })
}
```

- [ ] **Step 4: Test laufen, Erfolg bestätigen**

Run: `cd apps/web && npx vitest run src/hooks/__tests__/useMessagingAccounts.test.tsx`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/hooks/useMessagingAccounts.ts apps/web/src/hooks/__tests__/useMessagingAccounts.test.tsx
git commit -m "feat(comms): useMessagingAccounts + useConnectAccount hooks (TDD) [Comms Plan2 T4]"
```

---

### Task 5: Settings-Sektion „Verbundene Konten" (Comms-Staff-gated)

**Files:**
- Create: `apps/web/src/screens/settings/ConnectedAccountsSection.tsx`
- Modify: `apps/web/src/screens/SettingsScreen.tsx` (Sektion einhängen, nur für dispo/cd/owner)

- [ ] **Step 1: Sektion-Komponente schreiben**

```tsx
// apps/web/src/screens/settings/ConnectedAccountsSection.tsx
import { useMessagingAccounts, useConnectAccount } from '@/hooks/useMessagingAccounts'
import type { CommsChannel } from '@/types/messaging'
import { Icon } from '@/foundation'

const CHANNELS: { key: CommsChannel; label: string; icon: 'mail' | 'brand-whatsapp' | 'brand-linkedin' }[] = [
  { key: 'email', label: 'E-Mail', icon: 'mail' },
  { key: 'whatsapp', label: 'WhatsApp', icon: 'brand-whatsapp' },
  { key: 'linkedin', label: 'LinkedIn', icon: 'brand-linkedin' },
]

export function ConnectedAccountsSection() {
  const { data: accounts = [], isLoading } = useMessagingAccounts()
  const connect = useConnectAccount()

  return (
    <section style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-3)' }}>
      <h2 className="title-3">Verbundene Konten</h2>
      <div style={{ display: 'flex', gap: 'var(--space-2)' }}>
        {CHANNELS.map(c => (
          <button key={c.key} className="btn btn-secondary"
            disabled={connect.isPending}
            onClick={() => connect.mutate(c.key)}>
            <Icon name={c.icon} /> {c.label} verbinden
          </button>
        ))}
      </div>
      {connect.error && <p style={{ color: 'var(--brand-red)' }}>Verbindung fehlgeschlagen.</p>}
      {isLoading ? <p className="caption">Lädt…</p> : (
        <ul style={{ listStyle: 'none', padding: 0, margin: 0, display: 'flex', flexDirection: 'column', gap: 'var(--space-2)' }}>
          {accounts.map(a => (
            <li key={a.id} style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-2)' }}>
              <Icon name={a.channel === 'email' ? 'mail' : a.channel === 'whatsapp' ? 'brand-whatsapp' : 'brand-linkedin'} />
              <span>{a.label}</span>
              <span className="caption-2">{a.status === 'connected' ? '· verbunden' : '· getrennt'}</span>
            </li>
          ))}
          {accounts.length === 0 && <li className="caption">Noch keine Konten verbunden.</li>}
        </ul>
      )}
    </section>
  )
}
```

- [ ] **Step 2: In SettingsScreen einhängen (nur Comms-Staff)**

In `apps/web/src/screens/SettingsScreen.tsx`: Import ergänzen und die Sektion rendern, sofern die Rolle des Users dispo/cd/owner ist. Die Rolle kommt aus `useOutletContext<OutletCtx>()` (enthält die Session/Rolle wie in den anderen dispatcher-gated Sektionen — denselben Guard wie beim „Recalc banner (dispatcher)" verwenden).

```tsx
import { ConnectedAccountsSection } from '@/screens/settings/ConnectedAccountsSection'
// … in der Render-Liste, am selben Rollen-Guard wie die Dispatcher-Sektionen:
{isCommsStaff && <ConnectedAccountsSection />}
```

(`isCommsStaff` = Rolle ∈ {dispatcher, cd, owner}; den vorhandenen Rollen-Wert aus `OutletCtx`/`useSettingsUsers` wiederverwenden — kein neuer Fetch.)

- [ ] **Step 3: Typecheck + Tests**

Run: `cd apps/web && npx tsc --noEmit && npx vitest run`
Expected: tsc 0 Fehler; alle Tests grün.

- [ ] **Step 4: Commit**

```bash
git add apps/web/src/screens/settings/ConnectedAccountsSection.tsx apps/web/src/screens/SettingsScreen.tsx
git commit -m "feat(comms): Settings-Sektion 'Verbundene Konten' (comms-staff) [Comms Plan2 T5]"
```

---

### Task 6: Secrets setzen + manuelle E2E-Verifikation

**Files:** keine (Betrieb).

- [ ] **Step 1: Secrets setzen (Dominik)**

```bash
cd ~/Desktop/Developer/Dispo
npx supabase secrets set UNIPILE_API_KEY=… UNIPILE_DSN=apiXXX.unipile.com:XXX \
  COMMS_NOTIFY_SECRET="$(openssl rand -hex 24)" APP_URL=https://tsk.atoll-os.com
```
Expected: „Finished supabase secrets set."

- [ ] **Step 2: End-to-End durchspielen**

1. In `/einstellungen` → „E-Mail verbinden" klicken → Weiterleitung zum Unipile-Wizard.
2. Test-Konto verbinden → Rückleitung auf `/einstellungen?connected=1`.
3. Konto erscheint in der Liste („verbunden").
4. In `messaging_accounts` (Supabase) liegt die Zeile mit korrektem `owner_user_id`, `channel`, `provider`.

Expected: alle vier Punkte erfüllt. Danach ist die Verbindungsschicht bereit für Plan 3 (inbound).

---

## Self-Review (durchgeführt)

- **Spec-Abdeckung:** §6.1 comms-connect (T2) + Callback (T3); §6.2 Verbindungs-UI (T5); §5 Service-Rolle-Insert + Secrets serverseitig (T3, T6); Rollen-Gate `is_comms_staff` UI-seitig gespiegelt (T5).
- **Platzhalter:** keiner — vollständiger Funktions-/Hook-/Komponenten-Code.
- **Typ-Konsistenz:** `CommsChannel`, `MessagingAccount`, `messaging_accounts`-Spalten, `comms-connect`/`comms-connect-notify`-Namen, `COMMS_NOTIFY_SECRET` durchgängig identisch über Edge Functions, Hooks und UI.
- **Bekannte Annahme zu verifizieren (Spec §9):** Unipile-Account-Objekt-Feld `type` (GOOGLE/OUTLOOK/MAIL/WHATSAPP/LINKEDIN) — beim ersten echten Connect gegen `GET /accounts/{id}` gegenprüfen und `MAP` ggf. anpassen.

## Nächster Plan

- **Plan 3 — `comms-inbound`:** Webhook (HMAC) → `normalizeUnipileEvent` (Payload live verifizieren) → matchen via `normalizeHandle` → `contact_events` oder `messaging_unmatched`.
