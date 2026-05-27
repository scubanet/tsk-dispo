// AtollCard — Lead-arrived APNs push fan-out.
//
// Trigger: invoked when a new row lands in `card_leads`. The trigger is set
// up by migration 0100 (after the user has generated an APNs Auth Key —
// see README "Phase 6: Push setup"). Wiring:
//
//   1. Postgres trigger on card_leads INSERT calls `pg_net.http_post()`
//      to this Edge Function with `{ record: ... }`.
//   2. We look up the card owner's auth_user_id via cards → contact_instructor.
//   3. We fetch all `device_tokens` for that user.
//   4. We sign a fresh JWT for APNs using the .p8 Auth Key, then POST to
//      `https://api.push.apple.com/3/device/<token>` for each device.
//
// Secrets expected in the Supabase Function env:
//   APNS_KEY_ID         — 10-char key id from Apple Dev Portal
//   APNS_TEAM_ID        — XK8V89P2QV (your Apple Team)
//   APNS_BUNDLE_ID      — swiss.atoll.card
//   APNS_AUTH_KEY_BASE64 — base64 of the .p8 file contents
//
// Set via Supabase dashboard → Edge Functions → atollcard-lead-push →
// Secrets, or via `supabase secrets set APNS_KEY_ID=...`.

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { create as createJwt, getNumericDate } from 'https://deno.land/x/djwt@v3.0.2/mod.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0'

interface InboundPayload {
  record: {
    id: string
    card_id: string
    first_name: string
    last_name: string | null
    topic: string | null
  }
}

interface CardOwnerLookup {
  person_id: string
  title: string
}

const APNS_HOST = Deno.env.get('APNS_HOST') ?? 'api.push.apple.com'  // sandbox: api.sandbox.push.apple.com

serve(async (req) => {
  if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 })

  const { record } = (await req.json()) as InboundPayload
  if (!record?.card_id) return new Response('Missing card_id', { status: 400 })

  // Service-role client — needed to bypass RLS for cross-table lookups.
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  // 1. Find the card owner.
  const { data: card, error: cardErr } = await supabase
    .from('cards')
    .select('person_id, title')
    .eq('id', record.card_id)
    .single<CardOwnerLookup>()
  if (cardErr || !card) {
    return new Response(`card lookup failed: ${cardErr?.message ?? 'not found'}`, { status: 500 })
  }

  // 2. Find the auth_user_id behind that person via contact_instructor.
  const { data: sidecar } = await supabase
    .from('contact_instructor')
    .select('auth_user_id')
    .eq('contact_id', card.person_id)
    .maybeSingle<{ auth_user_id: string }>()
  if (!sidecar?.auth_user_id) {
    return new Response('owner has no auth user', { status: 200 })
  }

  // 3. Pull all device tokens for that user. The table is namespaced as
  // `atollcard_device_tokens` to coexist with the legacy `device_tokens`
  // used by AtollCal (different schema, instructor_id-based).
  const { data: tokens } = await supabase
    .from('atollcard_device_tokens')
    .select('device_token, platform')
    .eq('auth_user_id', sidecar.auth_user_id)
  if (!tokens?.length) return new Response('no devices registered', { status: 200 })

  // 4. Build APNs JWT (5-min expiry).
  const apnsJwt = await createApnsJwt()

  const fullName = [record.first_name, record.last_name].filter(Boolean).join(' ')
  const apsPayload = {
    aps: {
      alert: {
        title: `Neuer Lead — ${fullName}`,
        body: [card.title, record.topic].filter(Boolean).join(' · '),
      },
      sound: 'default',
      badge: 1,
    },
    lead_id: record.id,
    card_id: record.card_id,
  }

  // 5. Fan out — one HTTP/2 POST per device. Errors are logged but don't
  // fail the function (one bad token shouldn't kill the others).
  const results = await Promise.allSettled(tokens.map((t) =>
    fetch(`https://${APNS_HOST}/3/device/${t.device_token}`, {
      method: 'POST',
      headers: {
        'authorization': `bearer ${apnsJwt}`,
        'apns-topic': Deno.env.get('APNS_BUNDLE_ID')!,
        'apns-push-type': 'alert',
        'content-type': 'application/json',
      },
      body: JSON.stringify(apsPayload),
    })
  ))

  const summary = results.map((r, i) => ({
    token: tokens[i].device_token.slice(0, 8) + '…',
    status: r.status === 'fulfilled' ? (r.value as Response).status : 'error',
  }))
  return new Response(JSON.stringify({ pushed: summary }), {
    headers: { 'content-type': 'application/json' },
  })
})

// ─── APNs JWT ─────────────────────────────────────────────────────────

async function createApnsJwt(): Promise<string> {
  const keyBase64 = Deno.env.get('APNS_AUTH_KEY_BASE64')!
  const keyPem   = atob(keyBase64)
  const keyPkcs8 = pemToArrayBuffer(keyPem)

  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    keyPkcs8,
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign'],
  )
  return await createJwt(
    { alg: 'ES256', kid: Deno.env.get('APNS_KEY_ID')! },
    {
      iss: Deno.env.get('APNS_TEAM_ID')!,
      iat: getNumericDate(0),
      exp: getNumericDate(60 * 5),
    },
    cryptoKey,
  )
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '')
  const bin = atob(b64)
  const buf = new Uint8Array(bin.length)
  for (let i = 0; i < bin.length; i++) buf[i] = bin.charCodeAt(i)
  return buf.buffer
}
