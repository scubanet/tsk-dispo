// supabase/functions/comms-outbound/index.ts
// Sendet eine Nachricht über Unipile und schreibt das outbound-Event.
// Aufruf via supabase.functions.invoke('comms-outbound',
//   { body: { contact_id, channel, body, subject? } }).
// Spec: docs/superpowers/specs/2026-05-29-comms-integration-unipile-design.md §6.1
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0'

const UNIPILE_API_KEY = Deno.env.get('UNIPILE_API_KEY')!
const UNIPILE_DSN = 'api13.unipile.com:14315'           // wie comms-connect (DSN kein Geheimnis)
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')!
const COMMS_FROM_EMAIL = Deno.env.get('COMMS_FROM_EMAIL') ?? 'dominik@weckherlin.com'
const D360_API_KEY = Deno.env.get('D360_API_KEY')!

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
    const supa = createClient(SUPABASE_URL, Deno.env.get('SUPABASE_ANON_KEY')!, {
      global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } },
    })
    const { data: { user } } = await supa.auth.getUser()
    if (!user) return json({ error: 'unauthorized' }, 401)

    const { contact_id, channel, body, subject } = await req.json().catch(() => ({}))
    if (!contact_id || !channel || !body) return json({ error: 'bad_request' }, 400)

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE)

    const { data: acct } = await admin.from('messaging_accounts')
      .select('id, unipile_account_id').eq('owner_user_id', user.id).eq('channel', channel)
      .eq('status', 'connected').limit(1).maybeSingle()

    const { data: c } = await admin.from('contacts')
      .select('emails, phones, linkedin_member_id').eq('id', contact_id).single()
    // deno-lint-ignore no-explicit-any
    const email = (c?.emails ?? []).find((e: any) => e.primary)?.email ?? (c?.emails ?? [])[0]?.email
    // deno-lint-ignore no-explicit-any
    const e164 = (c?.phones ?? []).find((p: any) => p.whatsapp)?.e164 ?? (c?.phones ?? [])[0]?.e164

    let providerMessageId: string
    if (channel === 'email') {
      if (!email) return json({ error: 'no_recipient', channel }, 422)
      const res = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${RESEND_API_KEY}`, 'content-type': 'application/json' },
        body: JSON.stringify({ from: COMMS_FROM_EMAIL, to: [email], subject: subject ?? '(kein Betreff)', text: body }),
      })
      const text = await res.text()
      if (!res.ok) return json({ error: 'resend_send_failed', http: res.status, detail: text }, 502)
      providerMessageId = JSON.parse(text).id ?? crypto.randomUUID()
    } else if (channel === 'whatsapp') {
      const digits = e164 ? e164.replace(/\D/g, '') : null
      if (!digits) return json({ error: 'no_recipient', channel }, 422)
      const res = await fetch('https://waba-v2.360dialog.io/messages', {
        method: 'POST',
        headers: { 'D360-API-KEY': D360_API_KEY, 'content-type': 'application/json' },
        body: JSON.stringify({ messaging_product: 'whatsapp', recipient_type: 'individual', to: digits, type: 'text', text: { body } }),
      })
      const text = await res.text()
      if (!res.ok) return json({ error: 'd360_send_failed', http: res.status, detail: text }, 502)
      providerMessageId = JSON.parse(text).messages?.[0]?.id ?? crypto.randomUUID()
    } else {
      return json({ error: 'unsupported_channel', channel }, 400)
    }

    const { error } = await admin.from('contact_events').insert({
      contact_id, event_type: EVENT_TYPE[channel], occurred_at: new Date().toISOString(),
      summary: channel === 'email' ? (subject ?? '(kein Betreff)') : String(body).slice(0, 140),
      body,
      payload: { source: 'auto', direction: 'outbound', provider_message_id: providerMessageId },
      external_id: providerMessageId, messaging_account_id: acct?.id ?? null,
    })
    if (error && error.code !== '23505') return json({ error: 'db_insert_failed', detail: error.message }, 500)

    return json({ ok: true, provider_message_id: providerMessageId })
  } catch (e) {
    return json({ error: 'exception', detail: String((e as Error)?.message ?? e) }, 500)
  }
})
