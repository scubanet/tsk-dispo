// supabase/functions/comms-connect/index.ts
// Erzeugt einen Unipile-Hosted-Auth-Link für den eingeloggten Comms-Staff.
// X-API-KEY bleibt serverseitig. Aufruf via supabase.functions.invoke('comms-connect',
// { body: { channel: 'email'|'whatsapp'|'linkedin' } }).
// Spec: docs/superpowers/specs/2026-05-29-comms-integration-unipile-design.md §6.1
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0'

const UNIPILE_API_KEY = Deno.env.get('UNIPILE_API_KEY')!
// DSN ist kein Geheimnis (nur der API-Endpunkt). Fest verdrahtet, weil das
// alte UNIPILE_DSN-Secret auf einen falschen Wert gesetzt ist und `secrets set`
// hier am CLI-Token scheitert. TODO: zurück auf Deno.env.get('UNIPILE_DSN'),
// sobald das Secret korrigiert werden kann.
const UNIPILE_DSN = 'api13.unipile.com:14315'
const COMMS_NOTIFY_SECRET = Deno.env.get('COMMS_NOTIFY_SECRET')!
const APP_URL = Deno.env.get('APP_URL') ?? 'https://tsk.atoll-os.com'
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!

// CORS — die Function wird aus dem Browser via supabase.functions.invoke aufgerufen.
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, 'content-type': 'application/json' } })

const PROVIDERS: Record<string, string[]> = {
  email: ['GOOGLE', 'OUTLOOK', 'MAIL'],
  whatsapp: ['WHATSAPP'],
  linkedin: ['LINKEDIN'],
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405)

  try {
    // Sichtbarkeit: welche Secrets fehlen? (Wert wird NICHT geloggt.)
    const missing = ['UNIPILE_API_KEY', 'COMMS_NOTIFY_SECRET']
      .filter((k) => !Deno.env.get(k))
    if (missing.length) return json({ error: 'missing_secrets', missing }, 500)

    // Authenticated user aus dem Bearer-Token (von functions.invoke gesetzt).
    const authHeader = req.headers.get('Authorization') ?? ''
    const supabase = createClient(SUPABASE_URL, Deno.env.get('SUPABASE_ANON_KEY')!, {
      global: { headers: { Authorization: authHeader } },
    })
    const { data: { user }, error: userErr } = await supabase.auth.getUser()
    if (userErr || !user) return json({ error: 'unauthorized', detail: userErr?.message }, 401)

    const { channel } = await req.json().catch(() => ({ channel: null }))
    const providers = PROVIDERS[channel]
    if (!providers) return json({ error: 'bad_channel', channel }, 400)

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
    const text = await res.text()
    if (!res.ok) return json({ error: 'unipile_link_failed', http: res.status, detail: text }, 502)

    const data = JSON.parse(text)
    return json({ url: data.url })
  } catch (e) {
    console.error('comms-connect exception', e)
    return json({ error: 'exception', detail: String((e as Error)?.message ?? e) }, 500)
  }
})
