// supabase/functions/comms-connect/index.ts
// Erzeugt einen Unipile-Hosted-Auth-Link für den eingeloggten Comms-Staff.
// X-API-KEY bleibt serverseitig. Aufruf via supabase.functions.invoke('comms-connect',
// { body: { channel: 'email'|'whatsapp'|'linkedin' } }).
// Spec: docs/superpowers/specs/2026-05-29-comms-integration-unipile-design.md §6.1
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
