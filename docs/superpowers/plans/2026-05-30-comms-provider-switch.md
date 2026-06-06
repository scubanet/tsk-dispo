# Comms Provider-Switch — Unipile raus → 360dialog + Cloudflare + Resend

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unipile vollständig ablösen — WhatsApp über 360dialog (offizielle Cloud API), E-Mail-Eingang über einen Cloudflare Email Worker, E-Mail-Ausgang über Resend (bereits für Login eingebunden).

**Architecture:** Die drei Kanal-Zweige in `comms-outbound`/`comms-inbound` werden je auf den passenden Provider umgestellt; Matching bleibt telefon-/adressbasiert (`match_contact_by_handle`). WhatsApp-Inbound (Meta-Webhook) und E-Mail-Inbound (Cloudflare-Worker-Webhook) liefern beide die **echte Kennung** (Telefonnummer bzw. Absender-Adresse) — kein LID, keine Handle-Mapping-Tabelle nötig. Unipile-spezifische Teile (`comms-connect` QR-Flow, `comms-connect-notify`, `UNIPILE_*`) werden entfernt.

**Tech Stack:** Supabase Edge Functions (Deno), Resend API, 360dialog (WhatsApp Cloud API), Cloudflare Email Routing + Email Workers (`postal-mime`), React/TS.

**Spec:** `docs/superpowers/specs/2026-05-29-comms-integration-unipile-design.md` (Provider-Teil wird durch diesen Plan ersetzt).

---

## Externe Einrichtung (durch Dominik, vor bzw. parallel zu den Tasks)

- **Resend (Ausgang):** Domain ist bereits verifiziert (Login nutzt Resend). Eine Absender-Adresse festlegen, z. B. `TSK <kontakt@tsk.atoll-os.com>`, und als Secret `COMMS_FROM_EMAIL` setzen. `RESEND_API_KEY` existiert schon.
- **360dialog (WhatsApp):** Account anlegen (~€49/Mt.), Nummer per Embedded Signup / Coexistence onboarden, den `D360-API-KEY` der Nummer kopieren → als Supabase-Secret `D360_API_KEY` setzen. Webhook (Task 4) auf unsere `comms-inbound`-URL registrieren.
- **Cloudflare (E-Mail-Eingang):** Die Domain, deren Mails ins CRM sollen (z. B. `weckherlin.com` oder eine `@tsk.atoll-os.com`-Adresse), in Cloudflare Email Routing aktivieren (MX auf Cloudflare). Email Worker aus Task 3 deployen; optional `message.forward()` aufs echte Postfach, damit normale Mail weiterläuft.
- **Secrets setzen** (Supabase → Edge Functions):
  ```bash
  supabase secrets set D360_API_KEY=... COMMS_FROM_EMAIL="TSK <kontakt@tsk.atoll-os.com>"
  ```
  (`RESEND_API_KEY`, `COMMS_NOTIFY_SECRET`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` sind bereits gesetzt.)

## File Structure

- `supabase/functions/comms-outbound/index.ts` — Senden: E-Mail→Resend, WhatsApp→360dialog (LinkedIn entfällt).
- `supabase/functions/comms-inbound/index.ts` — Empfangen: normalize-Branches für Cloudflare-E-Mail-Payload und 360dialog/Meta-WhatsApp-Webhook.
- `supabase/migrations/0127_match_whatsapp_normalize.sql` — `match_contact_by_handle` WhatsApp-Zweig auf ziffern-normalisierten Vergleich.
- `cloudflare/email-worker/` — `src/worker.js`, `wrangler.toml`, `package.json` (postal-mime).
- `apps/web/src/screens/settings/...` (Verbundene Konten) — Unipile-Connect-Buttons entfernen/ersetzen.
- Entfernen: `supabase/functions/comms-connect/`, `supabase/functions/comms-connect-notify/`, `UNIPILE_*`-Referenzen.

---

### Task 1: Outbound E-Mail über Resend

**Files:**
- Modify: `supabase/functions/comms-outbound/index.ts` (E-Mail-Zweig + Secrets-Konstanten)

- [ ] **Step 1: Secrets-Konstanten ergänzen** (oben in der Datei, bei den anderen `Deno.env.get`)

```ts
const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')!
const COMMS_FROM_EMAIL = Deno.env.get('COMMS_FROM_EMAIL') ?? 'TSK <kontakt@tsk.atoll-os.com>'
```

- [ ] **Step 2: E-Mail-Zweig auf Resend umstellen** (ersetzt den Unipile-`/api/v1/emails`-Block)

```ts
if (channel === 'email') {
  if (!email) return json({ error: 'no_recipient', channel }, 422)
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${RESEND_API_KEY}`, 'content-type': 'application/json' },
    body: JSON.stringify({
      from: COMMS_FROM_EMAIL,
      to: [email],
      subject: subject ?? '(kein Betreff)',
      text: body,
    }),
  })
  const text = await res.text()
  if (!res.ok) return json({ error: 'resend_send_failed', http: res.status, detail: text }, 502)
  providerMessageId = JSON.parse(text).id ?? crypto.randomUUID()
}
```

- [ ] **Step 3: Deploy**

Run: `npx supabase functions deploy comms-outbound`
Expected: „Deployed Function comms-outbound".

- [ ] **Step 4: E2E** — Kontakt mit E-Mail öffnen → E-Mail-Composer → Senden. Erwartung: Mail kommt an (Resend), outbound-Event in der Timeline.

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/comms-outbound/index.ts
git commit -m "feat(comms): Outbound-E-Mail via Resend statt Unipile [Provider-Switch T1]"
```

---

### Task 2: Outbound WhatsApp über 360dialog

**Files:**
- Modify: `supabase/functions/comms-outbound/index.ts` (WhatsApp-Zweig)

- [ ] **Step 1: Secret-Konstante ergänzen**

```ts
const D360_API_KEY = Deno.env.get('D360_API_KEY')!
```

- [ ] **Step 2: WhatsApp-Zweig auf 360dialog umstellen** (ersetzt den Unipile-`/api/v1/chats`-Block; LinkedIn-Zweig entfällt)

```ts
} else if (channel === 'whatsapp') {
  const digits = e164 ? e164.replace(/\D/g, '') : null
  if (!digits) return json({ error: 'no_recipient', channel }, 422)
  const res = await fetch('https://waba-v2.360dialog.io/messages', {
    method: 'POST',
    headers: { 'D360-API-KEY': D360_API_KEY, 'content-type': 'application/json' },
    body: JSON.stringify({
      messaging_product: 'whatsapp',
      recipient_type: 'individual',
      to: digits,
      type: 'text',
      text: { body },
    }),
  })
  const text = await res.text()
  if (!res.ok) return json({ error: 'd360_send_failed', http: res.status, detail: text }, 502)
  providerMessageId = JSON.parse(text).messages?.[0]?.id ?? crypto.randomUUID()
} else {
  return json({ error: 'unsupported_channel', channel }, 400)
}
```

- [ ] **Step 3: Deploy**

Run: `npx supabase functions deploy comms-outbound`

- [ ] **Step 4: E2E** — WhatsApp-Composer → Senden an einen Kontakt mit Nummer. Erwartung: Nachricht kommt an, outbound-Event in der Timeline. (Schlägt es fehl → `detail` aus der Antwort prüfen.)

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/comms-outbound/index.ts
git commit -m "feat(comms): Outbound-WhatsApp via 360dialog statt Unipile [Provider-Switch T2]"
```

---

### Task 3: Inbound E-Mail über Cloudflare Email Worker

**Files:**
- Create: `cloudflare/email-worker/src/worker.js`
- Create: `cloudflare/email-worker/wrangler.toml`
- Create: `cloudflare/email-worker/package.json`
- Modify: `supabase/functions/comms-inbound/index.ts` (normalize-Branch für Cloudflare-Payload)

- [ ] **Step 1: Worker-Projekt anlegen** — `cloudflare/email-worker/package.json`

```json
{
  "name": "atoll-email-worker",
  "private": true,
  "type": "module",
  "dependencies": { "postal-mime": "^2.2.0" },
  "devDependencies": { "wrangler": "^3.0.0" }
}
```

- [ ] **Step 2: Worker-Code** — `cloudflare/email-worker/src/worker.js`

```js
import PostalMime from 'postal-mime'

export default {
  async email(message, env, ctx) {
    const parsed = await PostalMime.parse(message.raw)
    const payload = {
      source: 'cloudflare-email',
      from: message.from,                       // Envelope-Absender (echte Adresse)
      to: message.to,
      subject: parsed.subject ?? '(kein Betreff)',
      text: parsed.text ?? (parsed.html ? parsed.html.replace(/<[^>]+>/g, ' ').trim() : ''),
      message_id: parsed.messageId ?? crypto.randomUUID(),
      date: parsed.date ?? new Date().toISOString(),
    }
    await fetch(`${env.SUPABASE_FUNCTIONS_URL}/comms-inbound?token=${env.COMMS_NOTIFY_SECRET}`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(payload),
    })
    if (env.FORWARD_TO) { try { await message.forward(env.FORWARD_TO) } catch (_) {} }
  },
}
```

- [ ] **Step 3: `wrangler.toml`**

```toml
name = "atoll-email-worker"
main = "src/worker.js"
compatibility_date = "2026-05-01"
compatibility_flags = ["nodejs_compat"]

[vars]
SUPABASE_FUNCTIONS_URL = "https://axnrilhdokkfujzjifhj.supabase.co/functions/v1"
# COMMS_NOTIFY_SECRET + FORWARD_TO als Secrets: `npx wrangler secret put COMMS_NOTIFY_SECRET`
```

- [ ] **Step 4: `comms-inbound` normalize() — Cloudflare-E-Mail-Branch ergänzen** (am Anfang von `normalize(p)`)

```ts
if (p.source === 'cloudflare-email') {
  if (!p.from) return null
  return {
    channel: 'email', direction: 'inbound', external_id: p.message_id,
    counterparty_handle: String(p.from).trim().toLowerCase(),
    summary: p.subject || '(kein Betreff)', body: p.text || '',
    occurred_at: p.date, thread_id: undefined,
    attachment_count: 0,
  }
}
```

- [ ] **Step 5: Worker deployen + Email Routing aktivieren**

Run: `cd cloudflare/email-worker && npm i && npx wrangler deploy`
Dann in Cloudflare: Email Routing → Route „Send to a Worker" → `atoll-email-worker`. Secrets setzen (`COMMS_NOTIFY_SECRET`, optional `FORWARD_TO`).

- [ ] **Step 6: Deploy comms-inbound + E2E**

Run: `npx supabase functions deploy comms-inbound`
E2E: eine Mail an die geroutete Adresse schicken (von einer Adresse, die als Kontakt existiert) → Event erscheint beim Kontakt.

- [ ] **Step 7: Commit**

```bash
git add cloudflare/email-worker supabase/functions/comms-inbound/index.ts
git commit -m "feat(comms): Inbound-E-Mail via Cloudflare Email Worker [Provider-Switch T3]"
```

---

### Task 4: Inbound WhatsApp über 360dialog (Meta-Webhook)

**Files:**
- Modify: `supabase/functions/comms-inbound/index.ts` (normalize-Branch für Meta/360dialog-Webhook + Account-Auflösung)

- [ ] **Step 1: Meta-WhatsApp-Branch in normalize() ergänzen** (ersetzt den alten Unipile-`p.message_id`-Branch)

```ts
// 360dialog liefert Metas Cloud-API-Webhook: entry[].changes[].value.{messages,contacts,metadata}
const change = p.entry?.[0]?.changes?.[0]?.value
if (change?.messages?.[0]) {
  const m = change.messages[0]
  if (m.type !== 'text') return null            // vorerst nur Text
  return {
    channel: 'whatsapp', direction: 'inbound', external_id: m.id,
    counterparty_handle: String(m.from).replace(/\D/g, ''),   // echte Nummer (Ziffern)
    summary: (m.text?.body ?? '').slice(0, 140) || '(kein Text)',
    body: m.text?.body ?? '',
    occurred_at: m.timestamp ? new Date(Number(m.timestamp) * 1000).toISOString() : new Date().toISOString(),
    thread_id: undefined, attachment_count: 0,
  }
}
```

- [ ] **Step 2: Account-Auflösung anpassen** — `payload.account_id` gibt es bei Meta nicht; das WABA-Konto ist eindeutig (eine Nummer). `messaging_account_id` über `metadata.phone_number_id` oder fix per Lookup auf das einzige verbundene WhatsApp-Konto:

```ts
const { data: waAcct } = await admin.from('messaging_accounts')
  .select('id').eq('channel', 'whatsapp').eq('status', 'connected').limit(1).maybeSingle()
```
(im Mail-Fall analog über die Empfänger-Domain/Konto; für den Start genügt `null`, FK ist nullable.)

- [ ] **Step 3: Webhook bei 360dialog registrieren**

```bash
curl -X POST https://waba-v2.360dialog.io/v1/configs/webhook \
  -H "D360-API-KEY: $D360_API_KEY" -H "content-type: application/json" \
  -d '{"url":"https://axnrilhdokkfujzjifhj.supabase.co/functions/v1/comms-inbound?token=<COMMS_NOTIFY_SECRET>"}'
```

- [ ] **Step 4: Deploy + E2E**

Run: `npx supabase functions deploy comms-inbound`
E2E: von einem Kontakt-Handy an die tsk-Nummer schreiben → Event erscheint beim Kontakt (Match über echte Nummer, kein LID mehr).

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/comms-inbound/index.ts
git commit -m "feat(comms): Inbound-WhatsApp via 360dialog/Meta-Webhook [Provider-Switch T4]"
```

---

### Task 5: Matcher ziffern-normalisieren (WhatsApp)

**Files:**
- Create: `supabase/migrations/0127_match_whatsapp_normalize.sql`

- [ ] **Step 1: Migration** (Inbound-`from` sind Ziffern, gespeichertes `e164` hat führendes `+`)

```sql
CREATE OR REPLACE FUNCTION public.match_contact_by_handle(p_channel TEXT, p_handle TEXT)
RETURNS UUID LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT c.id FROM public.contacts c
  WHERE CASE
    WHEN p_channel = 'email' THEN EXISTS (
      SELECT 1 FROM jsonb_array_elements(COALESCE(c.emails, '[]'::jsonb)) e
      WHERE lower(e->>'email') = lower(p_handle))
    WHEN p_channel = 'whatsapp' THEN EXISTS (
      SELECT 1 FROM jsonb_array_elements(COALESCE(c.phones, '[]'::jsonb)) p
      WHERE regexp_replace(p->>'e164', '\D', '', 'g') = regexp_replace(p_handle, '\D', '', 'g'))
    WHEN p_channel = 'linkedin' THEN c.linkedin_member_id = p_handle
    ELSE false
  END LIMIT 1;
$$;
```

- [ ] **Step 2: Anwenden** (Supabase MCP `apply_migration` oder `supabase db push`) + **Commit**

```bash
git add supabase/migrations/0127_match_whatsapp_normalize.sql
git commit -m "feat(comms): WhatsApp-Matcher ziffern-normalisiert [Provider-Switch T5]"
```

---

### Task 6: Unipile entfernen

**Files:**
- Delete: `supabase/functions/comms-connect/`, `supabase/functions/comms-connect-notify/`
- Modify: Verbundene-Konten-UI (`apps/web/src/screens/settings/…`), `comms-outbound`/`comms-inbound` (UNIPILE_*-Reste)

- [ ] **Step 1:** Alle `UNIPILE_*`-Konstanten/Fetches aus `comms-outbound`/`comms-inbound` entfernen (sind nach T1–T4 ungenutzt). Suchlauf: `grep -rn "UNIPILE\|unipile" supabase/functions apps/web/src`.
- [ ] **Step 2:** Connect-UI: „WhatsApp/E-Mail verbinden"-Buttons (Unipile-QR) entfernen; stattdessen statischer Status „WhatsApp: 360dialog · E-Mail: Cloudflare+Resend". Kein Client-Connect mehr nötig.
- [ ] **Step 3:** Funktionen löschen + im Dashboard die Functions `comms-connect`, `comms-connect-notify` deaktivieren/löschen.
- [ ] **Step 4: Commit**

```bash
git rm -r supabase/functions/comms-connect supabase/functions/comms-connect-notify
git add -A apps/web/src supabase/functions
git commit -m "chore(comms): Unipile entfernt (Connect/Notify, UNIPILE_*) [Provider-Switch T6]"
```

---

### Task 7: E2E-Gesamtverifikation

- [ ] E-Mail senden (Resend) → kommt an, Event in Timeline.
- [ ] E-Mail empfangen (Cloudflare → Worker → comms-inbound) → Event beim Kontakt.
- [ ] WhatsApp senden (360dialog) → kommt an, Event in Timeline.
- [ ] WhatsApp empfangen (360dialog-Webhook) → Event beim **richtigen Kontakt** (Nummer-Match, kein LID).
- [ ] `npm -w @tsk/web run typecheck && npm -w @tsk/web run test` grün; `git push origin main` (CI + Deploy).

---

## Self-Review (durchgeführt)

- **Spec-Abdeckung:** Senden E-Mail (T1) / WhatsApp (T2); Empfangen E-Mail (T3) / WhatsApp (T4); Matching ziffern-tolerant (T5); Unipile-Abbau (T6); E2E (T7). LinkedIn bewusst gestrichen (kein Provider ohne Aggregator).
- **Konsistenz:** `counterparty_handle` ist im E-Mail-Fall die lowercased Adresse (matcht `emails[].email`), im WhatsApp-Fall die Ziffernnummer (matcht ziffern-normalisiertes `e164`). `external_id` (Resend-`id` / Meta-`messages[].id` / Mail-`message_id`) sichert die bestehende Idempotenz (`contact_events.external_id`).
- **Offen/zu setzen:** Secrets `D360_API_KEY`, `COMMS_FROM_EMAIL`; Cloudflare-Route + Worker-Secrets; 360dialog-Webhook-URL. Die LID-Mapping-Tabelle (0126) wird **nicht** benötigt und nicht angewandt.
- **Hinweis:** 360dialog-Outbound außerhalb des 24-h-Fensters erfordert genehmigte Templates; reine Antworten/laufende Chats sind frei.
