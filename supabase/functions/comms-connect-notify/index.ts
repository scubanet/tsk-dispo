// supabase/functions/comms-connect-notify/index.ts
// Öffentlicher Callback von Unipile nach erfolgreicher Konto-Verbindung.
// Verifiziert ?token=COMMS_NOTIFY_SECRET, holt Account-Details, upsertet
// messaging_accounts via Service-Rolle (umgeht RLS).
// Deploy mit --no-verify-jwt (Unipile schickt keinen Supabase-JWT).
// Spec: docs/superpowers/specs/2026-05-29-comms-integration-unipile-design.md §6.1, §5
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0'

const UNIPILE_API_KEY = Deno.env.get('UNIPILE_API_KEY')!
// DSN fest verdrahtet (kein Geheimnis) — siehe Kommentar in comms-connect.
const UNIPILE_DSN = 'api13.unipile.com:14315'
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
