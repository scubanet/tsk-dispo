// supabase/functions/comhub-push/index.ts
// ComHub-Push: sendet eine APNs-Notification an alle Geraete der OWNER eines
// Kontakts (contact_instructor.auth_user_id -> comhub_device_tokens).
//
// Aufruf (Service-Role-intern, z. B. aus comms-inbound nach dem Event-Insert):
//   POST { contact_id, title, body, threadKey? }
//   Header: x-comhub-push-secret: <COMHUB_PUSH_SECRET>
//
// Deploy:  supabase functions deploy comhub-push --no-verify-jwt
// Secrets (vom Betreiber zu setzen — NICHT im Repo):
//   COMHUB_PUSH_SECRET   beliebiges geteiltes Geheimnis (Aufrufer-Auth)
//   APNS_KEY_P8          Inhalt des AuthKey_XXXX.p8 (BEGIN/END PRIVATE KEY inkl.)
//   APNS_KEY_ID          10-stellige Key-ID des .p8
//   APNS_TEAM_ID         Apple Team-ID
//   APNS_BUNDLE_ID       swiss.atoll.hub
//   APNS_PRODUCTION      "true" -> api.push.apple.com, sonst Sandbox (default)
//   SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY  (Standard-Function-Env)

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0'

const PUSH_SECRET = Deno.env.get('COMHUB_PUSH_SECRET') ?? ''
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const APNS_KEY_P8 = Deno.env.get('APNS_KEY_P8') ?? ''
const APNS_KEY_ID = Deno.env.get('APNS_KEY_ID') ?? ''
const APNS_TEAM_ID = Deno.env.get('APNS_TEAM_ID') ?? ''
const APNS_BUNDLE_ID = Deno.env.get('APNS_BUNDLE_ID') ?? 'swiss.atoll.hub'

const db = createClient(SUPABASE_URL, SERVICE_ROLE)

// — APNs JWT (ES256), 50 Min gecacht (APNs erlaubt max 60 Min) —
let cachedJwt: { token: string; at: number } | null = null

function base64url(bytes: Uint8Array): string {
  let bin = ''
  for (const b of bytes) bin += String.fromCharCode(b)
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

function pemToPkcs8(pem: string): ArrayBuffer {
  const body = pem.replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '').replace(/\s+/g, '')
  const raw = atob(body)
  const buf = new Uint8Array(raw.length)
  for (let i = 0; i < raw.length; i++) buf[i] = raw.charCodeAt(i)
  return buf.buffer
}

async function apnsJwt(): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  if (cachedJwt && now - cachedJwt.at < 3000) return cachedJwt.token
  const header = base64url(new TextEncoder().encode(JSON.stringify({ alg: 'ES256', kid: APNS_KEY_ID })))
  const claims = base64url(new TextEncoder().encode(JSON.stringify({ iss: APNS_TEAM_ID, iat: now })))
  const signingInput = `${header}.${claims}`
  const key = await crypto.subtle.importKey(
    'pkcs8', pemToPkcs8(APNS_KEY_P8), { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign'])
  const sig = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' }, key, new TextEncoder().encode(signingInput))
  const token = `${signingInput}.${base64url(new Uint8Array(sig))}`
  cachedJwt = { token, at: now }
  return token
}

interface TokenRow { apns_token: string; app_env: string }

async function sendOne(jwt: string, t: TokenRow, payload: unknown): Promise<boolean> {
  const prod = Deno.env.get('APNS_PRODUCTION') === 'true' || t.app_env === 'production'
  const host = prod ? 'api.push.apple.com' : 'api.sandbox.push.apple.com'
  const res = await fetch(`https://${host}/3/device/${t.apns_token}`, {
    method: 'POST',
    headers: {
      'authorization': `bearer ${jwt}`,
      'apns-topic': APNS_BUNDLE_ID,
      'apns-push-type': 'alert',
      'apns-priority': '10',
      'content-type': 'application/json',
    },
    body: JSON.stringify(payload),
  })
  if (res.status === 410 || res.status === 400) {
    // Token ungueltig -> entfernen (best effort).
    await db.from('comhub_device_tokens').delete().eq('apns_token', t.apns_token)
  }
  return res.ok
}

serve(async (req) => {
  if (req.method !== 'POST') return new Response('method not allowed', { status: 405 })
  if (!PUSH_SECRET || req.headers.get('x-comhub-push-secret') !== PUSH_SECRET) {
    return new Response('unauthorized', { status: 401 })
  }
  if (!APNS_KEY_P8 || !APNS_KEY_ID || !APNS_TEAM_ID) {
    return new Response('apns not configured', { status: 503 })
  }

  let payloadIn: { contact_id?: string; title?: string; body?: string; threadKey?: string }
  try { payloadIn = await req.json() } catch { return new Response('bad json', { status: 400 }) }
  const { contact_id, title, body, threadKey } = payloadIn
  if (!contact_id || !body) return new Response('missing contact_id/body', { status: 400 })

  // Owner(s) des Kontakts -> deren auth_user_ids.
  const { data: owners } = await db
    .from('contact_instructor').select('auth_user_id').eq('contact_id', contact_id)
  const userIds = (owners ?? []).map((o: { auth_user_id: string }) => o.auth_user_id)
  if (userIds.length === 0) return new Response(JSON.stringify({ sent: 0, reason: 'no_owner' }), { status: 200 })

  const { data: tokens } = await db
    .from('comhub_device_tokens').select('apns_token, app_env').in('auth_user_id', userIds)
  const rows = (tokens ?? []) as TokenRow[]
  if (rows.length === 0) return new Response(JSON.stringify({ sent: 0, reason: 'no_tokens' }), { status: 200 })

  const apnsPayload = {
    aps: { alert: { title: title ?? 'ComHub', body }, sound: 'default', 'thread-id': threadKey ?? contact_id },
    contact_id,
  }
  const jwt = await apnsJwt()
  const results = await Promise.all(rows.map((t) => sendOne(jwt, t, apnsPayload)))
  const sent = results.filter(Boolean).length
  return new Response(JSON.stringify({ sent, total: rows.length }), {
    status: 200, headers: { 'content-type': 'application/json' },
  })
})
