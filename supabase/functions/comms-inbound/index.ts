// supabase/functions/comms-inbound/index.ts
// Inbound-Webhook: WhatsApp (360dialog/Meta) + Resend Inbound (E-Mail).
// Verifiziert ?token, normalisiert, matcht Kontakt via RPC, schreibt contact_events
// oder messaging_unmatched. Deploy mit --no-verify-jwt. Idempotenz über external_id.
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0'

const COMMS_NOTIFY_SECRET = Deno.env.get('COMMS_NOTIFY_SECRET')!
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY') ?? ''
const D360_API_KEY = Deno.env.get('D360_API_KEY') ?? ''

const EVENT_TYPE: Record<string, string> = {
  email: 'email_external', whatsapp: 'whatsapp_log', linkedin: 'linkedin_message',
}

// "Name <a@b.com>" → "a@b.com"; nackte Adresse bleibt unverändert.
function extractEmail(s: string): string {
  const m = s.match(/<([^>]+)>/)
  return (m ? m[1] : s).trim()
}
// Grobes HTML→Text als Fallback, falls Resend kein text liefert.
function stripHtml(html?: string | null): string {
  return html ? html.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim() : ''
}

// Eingehende WhatsApp bei 360dialog als 'read' markieren → blaue Haken beim
// Absender. Best-effort: ein Fehler hier darf den Webhook nicht scheitern lassen.
async function markWhatsappRead(messageId: string) {
  if (!D360_API_KEY || !messageId) return
  try {
    await fetch('https://waba-v2.360dialog.io/messages', {
      method: 'POST',
      headers: { 'D360-API-KEY': D360_API_KEY, 'content-type': 'application/json' },
      body: JSON.stringify({ messaging_product: 'whatsapp', status: 'read', message_id: messageId }),
    })
  } catch (_) { /* Read-Receipt ist best-effort */ }
}

// Resend Inbound: der email.received-Webhook enthält NUR Metadaten (kein Body).
// Den Body holen wir per Received-Emails-API nach (GET /emails/receiving/:id).
// deno-lint-ignore no-explicit-any
async function resendInbound(p: any) {
  const d = p?.data ?? {}
  if (!d.email_id) return null
  const fromAddr = extractEmail(String(d.from ?? '')).toLowerCase()
  if (!fromAddr) return null

  let body = ''
  if (RESEND_API_KEY) {
    try {
      const r = await fetch(`https://api.resend.com/emails/receiving/${d.email_id}`, {
        headers: { Authorization: `Bearer ${RESEND_API_KEY}` },
      })
      if (r.ok) {
        const full = await r.json()
        body = full.text || stripHtml(full.html) || ''
      }
    } catch (_) { /* Body bleibt leer — Event wird trotzdem erfasst */ }
  }

  return {
    channel: 'email', direction: 'inbound', external_id: String(d.email_id),
    counterparty_handle: fromAddr,
    summary: d.subject || '(kein Betreff)',
    body,
    occurred_at: d.created_at || p.created_at || new Date().toISOString(),
    thread_id: d.message_id, attachment_count: Array.isArray(d.attachments) ? d.attachments.length : 0,
  }
}

// WhatsApp-Inbound (360dialog/Meta Cloud-API). E-Mail-Inbound siehe resendInbound().
// deno-lint-ignore no-explicit-any
function normalize(p: any) {
  // 360dialog/Meta Cloud-API Webhook (WhatsApp): entry[].changes[].value.messages[]
  const waChange = p.entry?.[0]?.changes?.[0]?.value
  if (waChange?.messages?.[0]) {
    const m = waChange.messages[0]
    if (m.type !== 'text') return null
    return { channel: 'whatsapp', direction: 'inbound', external_id: m.id,
      counterparty_handle: String(m.from).replace(/\D/g, ''),
      summary: (m.text?.body ?? '').slice(0, 140) || '(kein Text)', body: m.text?.body ?? '',
      occurred_at: m.timestamp ? new Date(Number(m.timestamp) * 1000).toISOString() : new Date().toISOString(),
      thread_id: undefined, attachment_count: 0 }
  }
  return null
}

serve(async (req) => {
  if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 })
  const reqToken = new URL(req.url).searchParams.get('token') ?? req.headers.get('x-comms-token')
  if (reqToken !== COMMS_NOTIFY_SECRET) {
    return new Response('Forbidden', { status: 403 })
  }

  const payload = await req.json().catch(() => null)
  if (!payload) return new Response('Bad payload', { status: 200 })

  // Resend Inbound (email.received) braucht einen async Body-Nachlade-Schritt,
  // daher separat von der synchronen normalize().
  let n = normalize(payload)
  if (!n && payload?.type === 'email.received') {
    n = await resendInbound(payload)
  }
  if (!n) return new Response('Ignored', { status: 200 })   // Reaktionen/Reads/unbekannte Kanäle

  // Eingehende WhatsApp sofort als gelesen markieren (blaue Haken beim Absender).
  if (n.channel === 'whatsapp' && n.direction === 'inbound') {
    await markWhatsappRead(n.external_id)
  }

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE)

  // Quell-Konto auflösen (owner + FK). Unbekanntes/fehlendes Konto → FK bleibt null.
  let messagingAccountId: string | null = null
  if (payload.account_id) {
    const { data: acct } = await admin.from('messaging_accounts')
      .select('id').eq('unipile_account_id', payload.account_id).maybeSingle()
    messagingAccountId = acct?.id ?? null
  }

  // Kontakt matchen
  const { data: contactId } = await admin
    .rpc('match_contact_by_handle', { p_channel: n.channel, p_handle: n.counterparty_handle })

  const eventPayload = {
    source: 'auto', direction: n.direction, provider_message_id: n.external_id,
    thread_id: n.thread_id, attachment_count: n.attachment_count, unipile_account_id: payload.account_id ?? null,
  }

  if (!contactId) {
    const { error } = await admin.from('messaging_unmatched').upsert({
      channel: n.channel, sender_handle: n.counterparty_handle,
      normalized_payload: { ...n, raw_event: payload.event ?? payload.type }, external_id: n.external_id,
    }, { onConflict: 'external_id' })
    if (error && !error.message.includes('duplicate')) return new Response(error.message, { status: 500 })
    return new Response('Quarantined', { status: 200 })
  }

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

  if (messagingAccountId) {
    await admin.from('messaging_accounts').update({ last_event_at: n.occurred_at }).eq('id', messagingAccountId)
  }

  return new Response('OK', { status: 200 })
})
