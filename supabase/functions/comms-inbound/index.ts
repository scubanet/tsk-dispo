// supabase/functions/comms-inbound/index.ts
// Unipile-Webhook (messaging + email). Verifiziert ?token, normalisiert,
// matcht Kontakt via RPC, schreibt contact_events oder messaging_unmatched.
// Deploy mit --no-verify-jwt. Idempotenz über contact_events.external_id.
// Spec: docs/superpowers/specs/2026-05-29-comms-integration-unipile-design.md §6.1, §7
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0'

const COMMS_NOTIFY_SECRET = Deno.env.get('COMMS_NOTIFY_SECRET')!
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

const EVENT_TYPE: Record<string, string> = {
  email: 'email_external', whatsapp: 'whatsapp_log', linkedin: 'linkedin_message',
}

// Gespiegelt aus apps/web/src/lib/comms/normalizeInboundEvent.ts (Deno kann nicht aus src importieren).
// deno-lint-ignore no-explicit-any
function normalize(p: any) {
  if (p.email_id) {
    if (p.event !== 'mail_received' && p.event !== 'mail_sent') return null
    const direction = p.event === 'mail_sent' ? 'outbound' : 'inbound'
    const handleRaw = direction === 'inbound' ? p.from_attendee?.identifier : p.to_attendees?.[0]?.identifier
    if (!handleRaw) return null
    return { channel: 'email', direction, external_id: p.message_id || p.email_id,
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
    // deno-lint-ignore no-explicit-any
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

  // Quell-Konto auflösen (owner + FK). Unbekanntes Konto → FK bleibt null.
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
    const { error } = await admin.from('messaging_unmatched').upsert({
      channel: n.channel, sender_handle: n.counterparty_handle,
      normalized_payload: { ...n, raw_event: payload.event }, external_id: n.external_id,
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
