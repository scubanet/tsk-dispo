/**
 * atollcard-wallet-pass — signs a .pkpass for the authenticated card-owner.
 *
 * Spec: docs/superpowers/specs/2026-05-25-atollcard-wallet-design.md
 *
 * Deployment:
 *   supabase functions deploy atollcard-wallet-pass
 *   (no --no-verify-jwt — we want JWT auth)
 *
 * Required secrets:
 *   WALLET_PASS_CERT_BASE64
 *   WALLET_PASS_CERT_PASSWORD
 *   WALLET_WWDR_CERT_BASE64
 *   WALLET_PASS_TYPE_ID
 *   WALLET_TEAM_ID
 */
import { createClient } from '@supabase/supabase-js'

interface RequestBody { card_id?: string }

interface ErrorResponse { error: string; message: string }

function jsonError(status: number, code: string, msg: string): Response {
  return new Response(
    JSON.stringify({ error: code, message: msg } satisfies ErrorResponse),
    { status, headers: { 'Content-Type': 'application/json' } },
  )
}

function isUuid(s: unknown): s is string {
  return typeof s === 'string'
    && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s)
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== 'POST') return jsonError(405, 'method_not_allowed', 'POST only')

  // 1. Parse + validate body
  let body: RequestBody
  try {
    body = await req.json() as RequestBody
  } catch {
    return jsonError(400, 'invalid_request', 'Body must be JSON')
  }
  if (!isUuid(body.card_id)) {
    return jsonError(400, 'invalid_request', 'card_id is required (uuid)')
  }
  const cardId = body.card_id

  // 2. Validate JWT
  const authHeader = req.headers.get('Authorization') ?? ''
  const jwt = authHeader.replace(/^Bearer\s+/i, '')
  if (!jwt) return jsonError(401, 'invalid_token', 'Authorization header required')

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: `Bearer ${jwt}` } } },
  )

  const { data: userResult, error: userErr } = await supabase.auth.getUser(jwt)
  if (userErr || !userResult?.user) return jsonError(401, 'invalid_token', 'JWT invalid')

  // 3. Load card + contact (RLS via the user's JWT scopes to owner)
  const { data: cardRow, error: cardErr } = await supabase
    .from('cards')
    .select(`
      id, slug, title, subtitle, badge, theme, dive_profile, updated_at, is_active,
      person:contacts ( display_name, primary_email, phones )
    `)
    .eq('id', cardId)
    .eq('is_active', true)
    .maybeSingle()

  if (cardErr) return jsonError(500, 'unknown_error', cardErr.message)
  if (!cardRow) return jsonError(404, 'card_not_found', 'Karte nicht gefunden oder kein Zugriff')

  // Pick primary phone from phones[] JSONB
  const phones = (cardRow.person as { phones?: { e164: string; primary?: boolean }[] })?.phones ?? []
  const primaryPhone = phones.find(p => p.primary)?.e164 ?? phones[0]?.e164 ?? null

  // Compose CardData + ContactData (types from pass-types.ts)
  const card: import('./pass-types.ts').CardData = {
    id:           cardRow.id,
    slug:         cardRow.slug,
    title:        cardRow.title,
    subtitle:     cardRow.subtitle,
    badge:        cardRow.badge,
    theme:        cardRow.theme,
    dive_profile: cardRow.dive_profile,
    updated_at:   cardRow.updated_at,
    public_url:   `https://atoll-os.com/c/${cardRow.slug}`,
  }
  const contact: import('./pass-types.ts').ContactData = {
    display_name:  (cardRow.person as { display_name: string }).display_name,
    primary_email: (cardRow.person as { primary_email?: string }).primary_email ?? null,
    primary_phone: primaryPhone,
  }

  // 4. TODO Phase C: build pass, manifest, signature, zip
  return jsonError(501, 'not_implemented',
    `Loaded card "${card.title}" for "${contact.display_name}" — signing comes next`)
})
