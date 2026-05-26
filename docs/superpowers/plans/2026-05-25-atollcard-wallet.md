# AtollCard Wallet-Pass-Signing — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Supabase Edge Function `atollcard-wallet-pass` baut, signiert und liefert einen `.pkpass`-File für den authentifizierten Karten-Owner — plus die iOS-Wireup damit der "In Wallet speichern"-Button funktioniert.

**Architecture:** TypeScript-Deno-Function, owner-only JWT-Auth, `pass.json` aus Card-Daten gerendert, PKCS#7-Signature via `node-forge` (NPM-Compat), Zip-Bundle via `zip-js`, 6 statische PNG-Assets im Function-Folder. iOS-Service-Stub kriegt JWT-Header + neuen Endpoint.

**Tech Stack:** Supabase Edge Functions (Deno), `npm:node-forge@1.3.1`, `jsr:@zip-js/zip-js@2.7`, `npm:@supabase/supabase-js@2`, SwiftUI / PassKit.

**Spec:** `docs/superpowers/specs/2026-05-25-atollcard-wallet-design.md`

---

## Phase A — Function-Scaffold + Static Assets

### Task 1: Edge Function Skelett mit Auth-Stub

**Files:**
- Create: `supabase/functions/atollcard-wallet-pass/index.ts`
- Create: `supabase/functions/atollcard-wallet-pass/deno.json`

- [ ] **Step 1: Deno-Manifest schreiben**

Inhalt von `supabase/functions/atollcard-wallet-pass/deno.json`:

```json
{
  "imports": {
    "@supabase/supabase-js": "npm:@supabase/supabase-js@2",
    "node-forge":            "npm:node-forge@1.3.1",
    "@zip-js/zip-js":        "jsr:@zip-js/zip-js@2.7"
  }
}
```

- [ ] **Step 2: Function-Skelett schreiben**

Inhalt von `supabase/functions/atollcard-wallet-pass/index.ts`:

```typescript
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

  // 3. TODO Phase B: load card + contact, build pass, sign, zip
  return jsonError(501, 'not_implemented', 'Pass building comes in Phase B')
})
```

- [ ] **Step 3: Lokal serven + Auth-Skelett testen**

```bash
cd ~/Desktop/Developer/Dispo
supabase functions serve atollcard-wallet-pass --no-verify-jwt 2>&1 &
sleep 3
# Test 1: kein body
curl -i -X POST http://localhost:54321/functions/v1/atollcard-wallet-pass -H 'Content-Type: application/json' -d '{}'
# Test 2: invalid uuid
curl -i -X POST http://localhost:54321/functions/v1/atollcard-wallet-pass -H 'Content-Type: application/json' -d '{"card_id":"not-a-uuid"}'
# Test 3: missing auth
curl -i -X POST http://localhost:54321/functions/v1/atollcard-wallet-pass -H 'Content-Type: application/json' -d '{"card_id":"11111111-1111-1111-1111-111111111111"}'
```

Expected:
- Test 1: 400 invalid_request "card_id is required (uuid)"
- Test 2: 400 invalid_request "card_id is required (uuid)"
- Test 3: 401 invalid_token "Authorization header required"

Stop server: `pkill -f "supabase functions serve"`

- [ ] **Step 4: Commit**

```bash
git add supabase/functions/atollcard-wallet-pass/index.ts \
        supabase/functions/atollcard-wallet-pass/deno.json
git commit -m "feat(fn): atollcard-wallet-pass skeleton with auth stub"
```

---

### Task 2: Statische Assets — 6 PNG-Placeholders

**Files:**
- Create: `supabase/functions/atollcard-wallet-pass/assets/icon.png` (29×29)
- Create: `supabase/functions/atollcard-wallet-pass/assets/icon@2x.png` (58×58)
- Create: `supabase/functions/atollcard-wallet-pass/assets/icon@3x.png` (87×87)
- Create: `supabase/functions/atollcard-wallet-pass/assets/logo.png` (160×50)
- Create: `supabase/functions/atollcard-wallet-pass/assets/logo@2x.png` (320×100)
- Create: `supabase/functions/atollcard-wallet-pass/assets/logo@3x.png` (480×150)
- Create: `supabase/functions/atollcard-wallet-pass/assets/README.md`

- [ ] **Step 1: Asset-README schreiben**

Inhalt von `supabase/functions/atollcard-wallet-pass/assets/README.md`:

```markdown
# AtollCard Wallet-Pass Assets

Apple-required:
- icon.png       29 × 29
- icon@2x.png    58 × 58
- icon@3x.png    87 × 87
- logo.png       max 160 × 50
- logo@2x.png    max 320 × 100
- logo@3x.png    max 480 × 150

Alle PNG, transparent background, sRGB.

Quelle: ATOLL-Logo-SVG aus `apps/web/src/components/Logo.tsx` oder vom
Dominik-Brand-Kit. Bei Updates: alle 6 Dateien neu rendern, sonst rendert
Wallet auf verschiedenen iOS-Devices unterschiedlich.

Placeholder-Generation (für Implementer): 1×1 transparente PNGs werden
mit `sips`-Skalierung auf die korrekten Dimensionen gestreckt — Wallet
akzeptiert sie, sehen aber unbrauchbar aus. Vor Production durch echte
Assets ersetzen.
```

- [ ] **Step 2: 6 Placeholder-PNGs erzeugen**

Wenn echte Assets verfügbar (User hat sie geliefert): die direkt in den Folder kopieren.

Wenn nicht: 1×1 transparente PNG erzeugen und auf die 6 Dimensionen aufblähen:

```bash
cd supabase/functions/atollcard-wallet-pass/assets/

# 1×1 transparent PNG erzeugen (base64-decoded)
echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+P+/HgAFhAJ/wlseKgAAAABJRU5ErkJggg==" \
  | base64 -d > _seed.png

# Auf die 6 Zielgrössen skalieren
sips -z 29 29 _seed.png --out icon.png
sips -z 58 58 _seed.png --out icon@2x.png
sips -z 87 87 _seed.png --out icon@3x.png
sips -z 50 160 _seed.png --out logo.png
sips -z 100 320 _seed.png --out logo@2x.png
sips -z 150 480 _seed.png --out logo@3x.png

rm _seed.png

# Sanity
file *.png
```

Expected: 6 PNG-Files mit den gewünschten Dimensionen.

- [ ] **Step 3: Commit**

```bash
git add supabase/functions/atollcard-wallet-pass/assets/
git commit -m "feat(fn): wallet-pass asset placeholders (replace with real ATOLL logo before prod)"
```

---

## Phase B — Pass-JSON Building

### Task 3: TypeScript Types für Pass-JSON

**Files:**
- Create: `supabase/functions/atollcard-wallet-pass/pass-types.ts`

- [ ] **Step 1: Type-Definitionen schreiben**

Inhalt von `supabase/functions/atollcard-wallet-pass/pass-types.ts`:

```typescript
/**
 * Apple Wallet Pass Format types — minimal subset for the generic
 * pass style. Full spec: developer.apple.com/library/archive/documentation/
 * UserExperience/Reference/PassKit_Bundle/Chapters/Lower-Level.html
 */

export interface PassField {
  key: string
  label?: string
  value: string | number
  textAlignment?: 'PKTextAlignmentLeft' | 'PKTextAlignmentCenter' | 'PKTextAlignmentRight' | 'PKTextAlignmentNatural'
}

export interface PassStructure {
  headerFields?:    PassField[]   // max 3
  primaryFields?:   PassField[]   // max 1 in generic
  secondaryFields?: PassField[]   // max 4
  auxiliaryFields?: PassField[]   // max 4
  backFields?:      PassField[]   // unlimited
}

export interface PassBarcode {
  format:           'PKBarcodeFormatQR' | 'PKBarcodeFormatPDF417' | 'PKBarcodeFormatAztec' | 'PKBarcodeFormatCode128'
  message:          string
  messageEncoding:  string         // 'iso-8859-1' for QR
  altText?:         string
}

export interface PassJson {
  formatVersion:      1
  passTypeIdentifier: string
  serialNumber:       string
  teamIdentifier:     string
  organizationName:   string
  description:        string
  logoText?:          string
  backgroundColor?:   string       // "rgb(r, g, b)"
  foregroundColor?:   string
  labelColor?:        string       // "rgba(r, g, b, a)"
  generic?:           PassStructure
  barcodes?:          PassBarcode[]
}

/**
 * Subset of card+contact data we need from DB to render a pass.
 * Comes from a SELECT join in Phase C.
 */
export interface CardData {
  id:           string
  slug:         string
  title:        string
  subtitle:     string | null
  badge:        string | null
  theme:        {
    preset: 'courseDirector' | 'seaExplorers' | 'privat' | 'custom'
    gradient_start_hex?: string | null
    gradient_end_hex?:   string | null
  }
  dive_profile: {
    padi_member_number?: string | null
    instructor_level?:   string | null
    total_dives?:        number | null
    since_year?:         number | null
    specialties?:        string[]
    teaching_languages?: string[]
  } | null
  updated_at:   string  // ISO timestamp
  public_url:   string  // 'https://atoll-os.com/c/<slug>'
}

export interface ContactData {
  display_name:   string
  primary_email?: string | null
  primary_phone?: string | null
}
```

- [ ] **Step 2: Commit**

```bash
git add supabase/functions/atollcard-wallet-pass/pass-types.ts
git commit -m "feat(fn): pass.json + card/contact TypeScript types"
```

---

### Task 4: `colorForTheme()` mit Unit-Tests

**Files:**
- Create: `supabase/functions/atollcard-wallet-pass/colors.ts`
- Create: `supabase/functions/atollcard-wallet-pass/__tests__/colors_test.ts`

- [ ] **Step 1: Failing Test schreiben**

Inhalt von `supabase/functions/atollcard-wallet-pass/__tests__/colors_test.ts`:

```typescript
import { assertEquals } from 'jsr:@std/assert@1'
import { colorForTheme, hexToRgb } from '../colors.ts'

Deno.test('colorForTheme: courseDirector preset', () => {
  assertEquals(
    colorForTheme({ preset: 'courseDirector' }),
    'rgb(34, 103, 16)',
  )
})

Deno.test('colorForTheme: seaExplorers preset', () => {
  assertEquals(
    colorForTheme({ preset: 'seaExplorers' }),
    'rgb(0, 95, 138)',
  )
})

Deno.test('colorForTheme: privat preset', () => {
  assertEquals(
    colorForTheme({ preset: 'privat' }),
    'rgb(80, 80, 80)',
  )
})

Deno.test('colorForTheme: custom with hex', () => {
  assertEquals(
    colorForTheme({ preset: 'custom', gradient_start_hex: '#FF8800' }),
    'rgb(255, 136, 0)',
  )
})

Deno.test('colorForTheme: custom without hex falls back to privat', () => {
  assertEquals(
    colorForTheme({ preset: 'custom' }),
    'rgb(80, 80, 80)',
  )
})

Deno.test('hexToRgb: lowercase + uppercase + leading hash', () => {
  assertEquals(hexToRgb('#ff0088'), { r: 255, g: 0, b: 136 })
  assertEquals(hexToRgb('FFFFFF'),  { r: 255, g: 255, b: 255 })
  assertEquals(hexToRgb('#000'),    { r: 0,   g: 0,   b: 0 })   // short form
})

Deno.test('hexToRgb: invalid returns null', () => {
  assertEquals(hexToRgb('not-hex'),  null)
  assertEquals(hexToRgb('#gg0000'),  null)
})
```

- [ ] **Step 2: Run tests, verify they fail**

```bash
cd supabase/functions/atollcard-wallet-pass
deno test __tests__/colors_test.ts
```

Expected: FAIL with "Cannot find module '../colors.ts'".

- [ ] **Step 3: Implementation schreiben**

Inhalt von `supabase/functions/atollcard-wallet-pass/colors.ts`:

```typescript
/**
 * Color helpers for pass.json: theme-preset → CSS rgb(...) string,
 * plus a robust hex parser that handles 3- and 6-digit hex with/without #.
 */
import type { CardData } from './pass-types.ts'

const PRESET_RGB = {
  courseDirector: 'rgb(34, 103, 16)',   // PADI-green-ish
  seaExplorers:   'rgb(0, 95, 138)',    // ocean blue
  privat:         'rgb(80, 80, 80)',    // neutral grey
} as const

export interface Rgb { r: number; g: number; b: number }

export function hexToRgb(hex: string): Rgb | null {
  let h = hex.trim().replace(/^#/, '')
  if (h.length === 3) {
    h = h.split('').map((c) => c + c).join('')
  }
  if (!/^[0-9a-fA-F]{6}$/.test(h)) return null
  return {
    r: parseInt(h.slice(0, 2), 16),
    g: parseInt(h.slice(2, 4), 16),
    b: parseInt(h.slice(4, 6), 16),
  }
}

export function colorForTheme(theme: CardData['theme']): string {
  if (theme.preset !== 'custom') {
    return PRESET_RGB[theme.preset]
  }

  const rgb = theme.gradient_start_hex ? hexToRgb(theme.gradient_start_hex) : null
  if (!rgb) return PRESET_RGB.privat
  return `rgb(${rgb.r}, ${rgb.g}, ${rgb.b})`
}
```

- [ ] **Step 4: Run tests, verify they pass**

```bash
deno test __tests__/colors_test.ts
```

Expected: 7 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/atollcard-wallet-pass/colors.ts \
        supabase/functions/atollcard-wallet-pass/__tests__/colors_test.ts
git commit -m "feat(fn): colorForTheme + hexToRgb with unit tests"
```

---

### Task 5: `buildPassJson()` mit Unit-Tests

**Files:**
- Create: `supabase/functions/atollcard-wallet-pass/build-pass.ts`
- Create: `supabase/functions/atollcard-wallet-pass/__tests__/build_pass_test.ts`

- [ ] **Step 1: Failing Test schreiben**

Inhalt von `supabase/functions/atollcard-wallet-pass/__tests__/build_pass_test.ts`:

```typescript
import { assertEquals, assertStringIncludes } from 'jsr:@std/assert@1'
import { buildPassJson, serialNumberFor } from '../build-pass.ts'
import type { CardData, ContactData } from '../pass-types.ts'

const cardSample: CardData = {
  id:        '11111111-2222-3333-4444-555555555555',
  slug:      'dominik-cd',
  title:     'PADI Course Director',
  subtitle:  '#226710',
  badge:     'PADI CD',
  theme:     { preset: 'courseDirector' },
  dive_profile: {
    padi_member_number:  '226710',
    instructor_level:    'CD',
    total_dives:         7800,
    since_year:          2008,
    specialties:         ['Deep', 'Nitrox', 'Wreck'],
    teaching_languages:  ['DE', 'EN', 'FR'],
  },
  updated_at:  '2026-05-25T10:00:00Z',
  public_url:  'https://atoll-os.com/c/dominik-cd',
}

const contactSample: ContactData = {
  display_name:  'Dominik Weckherlin',
  primary_email: 'weckherlin@icloud.com',
  primary_phone: '+41791234567',
}

Deno.test('buildPassJson: top-level meta', () => {
  const pass = buildPassJson(cardSample, contactSample, {
    passTypeId: 'pass.swiss.atoll.card.persona',
    teamId:     'XK8V89P2QV',
  })

  assertEquals(pass.formatVersion,      1)
  assertEquals(pass.passTypeIdentifier, 'pass.swiss.atoll.card.persona')
  assertEquals(pass.teamIdentifier,     'XK8V89P2QV')
  assertEquals(pass.organizationName,   'ATOLL')
  assertEquals(pass.logoText,           'AtollCard')
  assertStringIncludes(pass.description, 'PADI Course Director')
})

Deno.test('buildPassJson: serial number changes with updated_at', () => {
  const a = serialNumberFor(cardSample)
  const b = serialNumberFor({ ...cardSample, updated_at: '2026-05-25T11:00:00Z' })
  assertEquals(a === b, false)
  assertStringIncludes(a, '11111111-2222-3333-4444-555555555555')
})

Deno.test('buildPassJson: front-fields shape', () => {
  const pass = buildPassJson(cardSample, contactSample, {
    passTypeId: 'pass.swiss.atoll.card.persona',
    teamId:     'XK8V89P2QV',
  })
  const gen = pass.generic!

  assertEquals(gen.headerFields?.length, 1)
  assertEquals(gen.headerFields![0].value, 'PADI CD')

  assertEquals(gen.primaryFields?.length, 1)
  assertEquals(gen.primaryFields![0].value, 'Dominik Weckherlin')

  assertEquals(gen.secondaryFields?.length, 2)
  assertEquals(gen.secondaryFields![0].value, 'PADI Course Director')
  assertEquals(gen.secondaryFields![1].value, '226710')
})

Deno.test('buildPassJson: barcode is QR with public_url', () => {
  const pass = buildPassJson(cardSample, contactSample, {
    passTypeId: 'pass.swiss.atoll.card.persona',
    teamId:     'XK8V89P2QV',
  })
  assertEquals(pass.barcodes?.length, 1)
  assertEquals(pass.barcodes![0].format,  'PKBarcodeFormatQR')
  assertEquals(pass.barcodes![0].message, 'https://atoll-os.com/c/dominik-cd')
  assertEquals(pass.barcodes![0].messageEncoding, 'iso-8859-1')
})

Deno.test('buildPassJson: backFields skip empty values', () => {
  const minimalCard: CardData = {
    ...cardSample,
    dive_profile: null,
  }
  const minimalContact: ContactData = {
    display_name: 'X Y',
    primary_email: null,
    primary_phone: null,
  }
  const pass = buildPassJson(minimalCard, minimalContact, {
    passTypeId: 'pass.swiss.atoll.card.persona',
    teamId:     'XK8V89P2QV',
  })
  const back = pass.generic?.backFields ?? []
  // card_url + updated must always be present
  const keys = back.map(f => f.key)
  assertEquals(keys.includes('card_url'),  true)
  assertEquals(keys.includes('updated'),   true)
  // email/phone/level/dives etc. should be absent
  assertEquals(keys.includes('email'),  false)
  assertEquals(keys.includes('phone'),  false)
  assertEquals(keys.includes('level'),  false)
})
```

- [ ] **Step 2: Run tests, verify they fail**

```bash
deno test __tests__/build_pass_test.ts
```

Expected: FAIL with "Cannot find module '../build-pass.ts'".

- [ ] **Step 3: Implementation schreiben**

Inhalt von `supabase/functions/atollcard-wallet-pass/build-pass.ts`:

```typescript
/**
 * buildPassJson — assembles the pass.json from card + contact data.
 *
 * Front layout (per spec §3.2):
 *   header[badge] · primary[name] · secondary[title, padi] · barcode[QR]
 *
 * Back layout (per spec §3.3): email, phone, level, dives, since,
 * specs, langs, card_url, updated — empty fields omitted.
 */
import type {
  CardData, ContactData, PassJson, PassField, PassStructure,
} from './pass-types.ts'
import { colorForTheme } from './colors.ts'

export interface PassBuildConfig {
  passTypeId: string
  teamId:     string
}

export function serialNumberFor(card: CardData): string {
  const unix = Math.floor(new Date(card.updated_at).getTime() / 1000)
  return `${card.id}-v${unix}`
}

function fmtDate(iso: string): string {
  const d = new Date(iso)
  const dd = String(d.getDate()).padStart(2, '0')
  const mm = String(d.getMonth() + 1).padStart(2, '0')
  const yy = d.getFullYear()
  return `${dd}.${mm}.${yy}`
}

function maybeField(key: string, label: string, value: string | number | null | undefined): PassField | null {
  if (value == null) return null
  const s = String(value).trim()
  if (!s) return null
  return { key, label, value: s }
}

export function buildPassJson(
  card:    CardData,
  contact: ContactData,
  cfg:     PassBuildConfig,
): PassJson {
  const dp = card.dive_profile ?? {}

  const headerFields:    PassField[] = []
  if (card.badge) headerFields.push({ key: 'badge', label: '', value: card.badge })

  const primaryFields:   PassField[] = [
    { key: 'name', label: '', value: contact.display_name },
  ]

  const secondaryFields: PassField[] = [
    { key: 'title', label: 'TITEL',  value: card.title },
  ]
  if (dp.padi_member_number) {
    secondaryFields.push({ key: 'padi', label: 'PADI #', value: dp.padi_member_number })
  }

  const backFields: PassField[] = []
  const maybes: Array<PassField | null> = [
    maybeField('email',  'EMAIL',        contact.primary_email),
    maybeField('phone',  'TELEFON',      contact.primary_phone),
    maybeField('level',  'LEVEL',        dp.instructor_level),
    maybeField('dives',  'TAUCHGÄNGE',   dp.total_dives),
    maybeField('since',  'SEIT',         dp.since_year),
    (dp.specialties && dp.specialties.length > 0)
      ? { key: 'specs', label: 'SPECIALTIES', value: dp.specialties.join(', ') }
      : null,
    (dp.teaching_languages && dp.teaching_languages.length > 0)
      ? { key: 'langs', label: 'SPRACHEN', value: dp.teaching_languages.join(', ') }
      : null,
    { key: 'card_url', label: 'ATOLLCARD',    value: card.public_url },
    { key: 'updated',  label: 'AKTUALISIERT', value: fmtDate(card.updated_at) },
  ]
  maybes.forEach((f) => f && backFields.push(f))

  const generic: PassStructure = { headerFields, primaryFields, secondaryFields, backFields }

  return {
    formatVersion:      1,
    passTypeIdentifier: cfg.passTypeId,
    serialNumber:       serialNumberFor(card),
    teamIdentifier:     cfg.teamId,
    organizationName:   'ATOLL',
    description:        `AtollCard — ${card.title}`,
    logoText:           'AtollCard',
    backgroundColor:    colorForTheme(card.theme),
    foregroundColor:    'rgb(255, 255, 255)',
    labelColor:         'rgba(255, 255, 255, 0.7)',
    generic,
    barcodes: [{
      format:          'PKBarcodeFormatQR',
      message:         card.public_url,
      messageEncoding: 'iso-8859-1',
    }],
  }
}
```

- [ ] **Step 4: Run tests, verify they pass**

```bash
deno test __tests__/build_pass_test.ts
```

Expected: 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/atollcard-wallet-pass/build-pass.ts \
        supabase/functions/atollcard-wallet-pass/__tests__/build_pass_test.ts
git commit -m "feat(fn): buildPassJson + serialNumberFor with unit tests"
```

---

### Task 6: Card + Contact aus DB laden

**Files:**
- Modify: `supabase/functions/atollcard-wallet-pass/index.ts`

- [ ] **Step 1: Card-Loading hinzufügen (nach JWT-Check, vor Phase-B-Stub-Return)**

Im `index.ts` direkt nach dem `getUser`-Block (vor dem `return jsonError(501, ...)`):

```typescript
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
```

- [ ] **Step 2: Local smoke**

```bash
cd ~/Desktop/Developer/Dispo
supabase functions serve atollcard-wallet-pass --no-verify-jwt 2>&1 &
sleep 3

# Hole eine echte card_id von der DB (im Browser: localhost:5173/contacts/card-inbox → DevTools → Netz-Tab → eine Card-Query → eine card_id rauspicken)
CARD_ID="<eine echte UUID einsetzen>"
JWT="<JWT aus dem Browser-DevTools localStorage 'sb-axnrilhdokkfujzjifhj-auth-token' kopieren>"

curl -i -X POST http://localhost:54321/functions/v1/atollcard-wallet-pass \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $JWT" \
  -d "{\"card_id\":\"$CARD_ID\"}"
```

Expected: 501 mit Body `{"error":"not_implemented","message":"Loaded card \"...\" for \"...\" — signing comes next"}`

Stop: `pkill -f "supabase functions serve"`

- [ ] **Step 3: Commit**

```bash
git add supabase/functions/atollcard-wallet-pass/index.ts
git commit -m "feat(fn): load card + contact via RLS-scoped query"
```

---

## Phase C — Signing (Manifest + PKCS#7)

### Task 7: Cert-Loader Helper

**Files:**
- Create: `supabase/functions/atollcard-wallet-pass/certs.ts`
- Create: `supabase/functions/atollcard-wallet-pass/__tests__/certs_test.ts`

- [ ] **Step 1: Failing Test (deferred to integration — cert needs real .p12)**

`__tests__/certs_test.ts`:

```typescript
import { assertEquals, assertThrows } from 'jsr:@std/assert@1'
import { base64ToBytes } from '../certs.ts'

Deno.test('base64ToBytes: roundtrips simple ASCII', () => {
  const enc = btoa('hello world')
  const bytes = base64ToBytes(enc)
  assertEquals(new TextDecoder().decode(bytes), 'hello world')
})

Deno.test('base64ToBytes: throws on garbage', () => {
  assertThrows(() => base64ToBytes('!!!not-base64!!!'))
})
```

(`loadPassCert` is too cert-dependent for a clean unit test — gets integration-tested in Task 13.)

- [ ] **Step 2: Run, verify fail**

```bash
deno test __tests__/certs_test.ts
```

Expected: FAIL "Cannot find module '../certs.ts'".

- [ ] **Step 3: Implementation**

Inhalt von `supabase/functions/atollcard-wallet-pass/certs.ts`:

```typescript
/**
 * Cert-Loader: parse a .p12 (PKCS#12) bundle into { cert, privateKey }
 * for use with node-forge's PKCS#7 signing API. Also parses a separate
 * WWDR intermediate cert (Apple's CA chain).
 *
 * Secrets are passed as base64-encoded strings via Deno.env.
 */
import forge from 'node-forge'

export function base64ToBytes(b64: string): Uint8Array {
  // Validate first — atob throws on invalid base64 in some runtimes
  if (!/^[A-Za-z0-9+/]+={0,2}$/.test(b64.replace(/\s+/g, ''))) {
    throw new Error('invalid base64 string')
  }
  const bin = atob(b64.replace(/\s+/g, ''))
  const out = new Uint8Array(bin.length)
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i)
  return out
}

function bytesToForgeBinaryString(bytes: Uint8Array): string {
  let s = ''
  for (let i = 0; i < bytes.length; i++) s += String.fromCharCode(bytes[i])
  return s
}

export interface PassCertBundle {
  cert:       forge.pki.Certificate
  privateKey: forge.pki.rsa.PrivateKey
}

export function loadPassCert(p12Base64: string, password: string): PassCertBundle {
  const p12Bytes  = base64ToBytes(p12Base64)
  const p12Binary = bytesToForgeBinaryString(p12Bytes)
  const asn1      = forge.asn1.fromDer(p12Binary)
  const p12       = forge.pkcs12.pkcs12FromAsn1(asn1, password)

  // Find the cert + key bag
  const certBags = p12.getBags({ bagType: forge.pki.oids.certBag })[forge.pki.oids.certBag]
  const keyBags  = p12.getBags({ bagType: forge.pki.oids.pkcs8ShroudedKeyBag })[forge.pki.oids.pkcs8ShroudedKeyBag]
                || p12.getBags({ bagType: forge.pki.oids.keyBag })[forge.pki.oids.keyBag]

  if (!certBags?.length || !keyBags?.length) {
    throw new Error('p12 missing cert or key bag')
  }
  const cert = certBags[0].cert as forge.pki.Certificate
  const key  = keyBags[0].key  as forge.pki.rsa.PrivateKey
  return { cert, privateKey: key }
}

export function loadWwdrCert(cerBase64: string): forge.pki.Certificate {
  const bytes  = base64ToBytes(cerBase64)
  const binary = bytesToForgeBinaryString(bytes)
  const asn1   = forge.asn1.fromDer(binary)
  return forge.pki.certificateFromAsn1(asn1)
}
```

- [ ] **Step 4: Run tests, verify pass**

```bash
deno test --allow-env __tests__/certs_test.ts
```

Expected: 2 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/atollcard-wallet-pass/certs.ts \
        supabase/functions/atollcard-wallet-pass/__tests__/certs_test.ts
git commit -m "feat(fn): cert loader (p12 + wwdr) via node-forge"
```

---

### Task 8: Manifest-Builder mit SHA-1

**Files:**
- Create: `supabase/functions/atollcard-wallet-pass/manifest.ts`
- Create: `supabase/functions/atollcard-wallet-pass/__tests__/manifest_test.ts`

- [ ] **Step 1: Failing Test**

`__tests__/manifest_test.ts`:

```typescript
import { assertEquals } from 'jsr:@std/assert@1'
import { buildManifest } from '../manifest.ts'

Deno.test('buildManifest: SHA-1 hashes of file contents', async () => {
  const files = {
    'pass.json':       new TextEncoder().encode('{"hello":"world"}'),
    'icon.png':        new Uint8Array([137, 80, 78, 71]),  // PNG magic
  }
  const m = await buildManifest(files)
  // SHA-1 of '{"hello":"world"}' = a45cc7ed85bd62f37b50a6cd1ce32edd5ac21a9c
  assertEquals(m['pass.json'], 'a45cc7ed85bd62f37b50a6cd1ce32edd5ac21a9c')
  // SHA-1 of [137,80,78,71] = a839ada4cb6bd0fa78b78a48e9bcf6cf8a4dc9bb
  assertEquals(m['icon.png'],  'a839ada4cb6bd0fa78b78a48e9bcf6cf8a4dc9bb')
})

Deno.test('buildManifest: empty input returns empty object', async () => {
  const m = await buildManifest({})
  assertEquals(Object.keys(m).length, 0)
})
```

- [ ] **Step 2: Run, verify fail**

```bash
deno test __tests__/manifest_test.ts
```

Expected: FAIL "Cannot find module '../manifest.ts'".

- [ ] **Step 3: Implementation**

Inhalt von `supabase/functions/atollcard-wallet-pass/manifest.ts`:

```typescript
/**
 * Apple Wallet manifest.json builder: SHA-1 hex digest of each file in
 * the pass bundle. The manifest itself is what gets PKCS#7-signed.
 */

export interface ManifestMap { [filename: string]: string }

async function sha1Hex(bytes: Uint8Array): Promise<string> {
  const hash = await crypto.subtle.digest('SHA-1', bytes)
  return Array.from(new Uint8Array(hash))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('')
}

export async function buildManifest(
  files: Record<string, Uint8Array>,
): Promise<ManifestMap> {
  const out: ManifestMap = {}
  for (const [name, bytes] of Object.entries(files)) {
    out[name] = await sha1Hex(bytes)
  }
  return out
}
```

- [ ] **Step 4: Run tests, verify pass**

```bash
deno test __tests__/manifest_test.ts
```

Expected: 2 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/atollcard-wallet-pass/manifest.ts \
        supabase/functions/atollcard-wallet-pass/__tests__/manifest_test.ts
git commit -m "feat(fn): manifest.json builder (SHA-1 hex digests)"
```

---

### Task 9: PKCS#7-Signing Helper

**Files:**
- Create: `supabase/functions/atollcard-wallet-pass/sign.ts`

(No isolated unit test — needs real cert, gets tested via integration in Task 13.)

- [ ] **Step 1: Implementation**

Inhalt von `supabase/functions/atollcard-wallet-pass/sign.ts`:

```typescript
/**
 * PKCS#7 detached signature of manifest.json using the Pass Type ID
 * certificate + Apple WWDR intermediate, as required by Apple Wallet.
 *
 * Output: DER-encoded PKCS#7 message (binary) — written to `signature`
 * file inside the .pkpass bundle.
 */
import forge from 'node-forge'
import type { PassCertBundle } from './certs.ts'

export function signManifest(
  manifestBytes: Uint8Array,
  pass:          PassCertBundle,
  wwdr:          forge.pki.Certificate,
): Uint8Array {
  const p7 = forge.pkcs7.createSignedData()

  // Convert manifest to forge's binary string format
  let manifestBinary = ''
  for (let i = 0; i < manifestBytes.length; i++) {
    manifestBinary += String.fromCharCode(manifestBytes[i])
  }
  p7.content = forge.util.createBuffer(manifestBinary, 'binary')

  p7.addCertificate(pass.cert)
  p7.addCertificate(wwdr)

  p7.addSigner({
    key:           pass.privateKey,
    certificate:   pass.cert,
    digestAlgorithm: forge.pki.oids.sha256,
    authenticatedAttributes: [
      { type: forge.pki.oids.contentType,   value: forge.pki.oids.data },
      { type: forge.pki.oids.messageDigest /* SHA-256 of content set automatically */ },
      { type: forge.pki.oids.signingTime,   value: new Date() },
    ],
  })

  // Detached signature — content is NOT included, just the message digest
  p7.sign({ detached: true })

  const derBytes = forge.asn1.toDer(p7.toAsn1()).getBytes()
  const out = new Uint8Array(derBytes.length)
  for (let i = 0; i < derBytes.length; i++) out[i] = derBytes.charCodeAt(i)
  return out
}
```

- [ ] **Step 2: Commit**

```bash
git add supabase/functions/atollcard-wallet-pass/sign.ts
git commit -m "feat(fn): PKCS#7 detached signer via forge (SHA-256)"
```

---

## Phase D — Zipping + Function Wireup

### Task 10: Zip-Bundle Builder

**Files:**
- Create: `supabase/functions/atollcard-wallet-pass/zip.ts`
- Create: `supabase/functions/atollcard-wallet-pass/__tests__/zip_test.ts`

- [ ] **Step 1: Failing Test**

`__tests__/zip_test.ts`:

```typescript
import { assertEquals } from 'jsr:@std/assert@1'
import {
  BlobReader, BlobWriter, ZipReader, Uint8ArrayReader,
} from 'jsr:@zip-js/zip-js@2.7'
import { buildZip } from '../zip.ts'

Deno.test('buildZip: roundtrip — files in, same files out', async () => {
  const files = {
    'pass.json':       new TextEncoder().encode('{"a":1}'),
    'manifest.json':   new TextEncoder().encode('{"pass.json":"abc"}'),
    'icon.png':        new Uint8Array([1, 2, 3]),
  }
  const zipBytes = await buildZip(files)

  // Validate zip is readable + same entries
  const reader = new ZipReader(new BlobReader(new Blob([zipBytes])))
  const entries = await reader.getEntries()
  await reader.close()

  const names = entries.map(e => e.filename).sort()
  assertEquals(names, ['icon.png', 'manifest.json', 'pass.json'])
})
```

- [ ] **Step 2: Run, verify fail**

```bash
deno test __tests__/zip_test.ts
```

Expected: FAIL "Cannot find module '../zip.ts'".

- [ ] **Step 3: Implementation**

Inhalt von `supabase/functions/atollcard-wallet-pass/zip.ts`:

```typescript
/**
 * Builds a .pkpass zip bundle from a map of filename → bytes.
 * Uses zip-js, returns the zip as Uint8Array ready to send in the response.
 */
import {
  ZipWriter, Uint8ArrayWriter, Uint8ArrayReader,
} from '@zip-js/zip-js'

export async function buildZip(
  files: Record<string, Uint8Array>,
): Promise<Uint8Array> {
  const writer = new ZipWriter(new Uint8ArrayWriter())
  for (const [name, bytes] of Object.entries(files)) {
    await writer.add(name, new Uint8ArrayReader(bytes))
  }
  return await writer.close()
}
```

- [ ] **Step 4: Run tests, verify pass**

```bash
deno test __tests__/zip_test.ts
```

Expected: 1 test PASS.

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/atollcard-wallet-pass/zip.ts \
        supabase/functions/atollcard-wallet-pass/__tests__/zip_test.ts
git commit -m "feat(fn): zip builder via zip-js (Uint8Array in/out)"
```

---

### Task 11: Asset-Loader

**Files:**
- Create: `supabase/functions/atollcard-wallet-pass/assets.ts`

- [ ] **Step 1: Implementation**

Inhalt von `supabase/functions/atollcard-wallet-pass/assets.ts`:

```typescript
/**
 * Loads the 6 static PNG assets from the assets/ folder.
 * Reads them once at module-load time and caches in a closure variable
 * so per-request handling is just a dict-lookup.
 */

const ASSET_NAMES = [
  'icon.png', 'icon@2x.png', 'icon@3x.png',
  'logo.png', 'logo@2x.png', 'logo@3x.png',
] as const

let cachedAssets: Record<string, Uint8Array> | null = null

export async function loadAssets(): Promise<Record<string, Uint8Array>> {
  if (cachedAssets) return cachedAssets

  const out: Record<string, Uint8Array> = {}
  for (const name of ASSET_NAMES) {
    const url = new URL(`./assets/${name}`, import.meta.url)
    out[name] = await Deno.readFile(url)
  }
  cachedAssets = out
  return out
}
```

- [ ] **Step 2: Commit**

```bash
git add supabase/functions/atollcard-wallet-pass/assets.ts
git commit -m "feat(fn): asset loader (6 PNGs, cached after first load)"
```

---

### Task 12: Function-Wireup (alles zusammenstecken)

**Files:**
- Modify: `supabase/functions/atollcard-wallet-pass/index.ts`

- [ ] **Step 1: Imports + Pass-Build-Pipeline ergänzen**

In `index.ts`, am Anfang nach den existing imports:

```typescript
import { buildPassJson } from './build-pass.ts'
import { loadPassCert, loadWwdrCert } from './certs.ts'
import { buildManifest } from './manifest.ts'
import { signManifest }  from './sign.ts'
import { buildZip }      from './zip.ts'
import { loadAssets }    from './assets.ts'
```

Und unten in `Deno.serve(...)`, im Block wo aktuell `// 4. TODO Phase C: build pass, manifest, signature, zip` steht, das durch ersetzen:

```typescript
  // 4. Build pass.json
  const passJson = buildPassJson(card, contact, {
    passTypeId: Deno.env.get('WALLET_PASS_TYPE_ID') ?? 'pass.swiss.atoll.card.persona',
    teamId:     Deno.env.get('WALLET_TEAM_ID')      ?? 'XK8V89P2QV',
  })

  // 5. Load assets
  const assets = await loadAssets()

  // 6. Bundle files (excluding signature + manifest — those come next)
  const passJsonBytes = new TextEncoder().encode(JSON.stringify(passJson))
  const filesForManifest: Record<string, Uint8Array> = {
    'pass.json': passJsonBytes,
    ...assets,
  }

  // 7. Manifest
  const manifest = await buildManifest(filesForManifest)
  const manifestBytes = new TextEncoder().encode(JSON.stringify(manifest))

  // 8. Sign
  let signature: Uint8Array
  try {
    const passCert = loadPassCert(
      Deno.env.get('WALLET_PASS_CERT_BASE64')!,
      Deno.env.get('WALLET_PASS_CERT_PASSWORD')!,
    )
    const wwdr = loadWwdrCert(Deno.env.get('WALLET_WWDR_CERT_BASE64')!)
    signature = signManifest(manifestBytes, passCert, wwdr)
  } catch (e) {
    console.error('signing_failed:', e)
    return jsonError(500, 'signing_failed', (e as Error).message)
  }

  // 9. Zip the full bundle
  const pkpass = await buildZip({
    ...filesForManifest,
    'manifest.json': manifestBytes,
    'signature':     signature,
  })

  // 10. Respond
  return new Response(pkpass, {
    status: 200,
    headers: {
      'Content-Type':        'application/vnd.apple.pkpass',
      'Content-Disposition': `attachment; filename="${card.slug}.pkpass"`,
      'Cache-Control':       'no-store',
    },
  })
```

Den existing `return jsonError(501, ...)`-Stub im Block ENTFERNEN.

- [ ] **Step 2: Local smoke (mit echten Test-Secrets oder Mock-Cert)**

Lokales Testen benötigt entweder echte Secrets oder einen Mock-`.p12`. Easiest: erstmal nur Compile-Check:

```bash
cd ~/Desktop/Developer/Dispo/supabase/functions/atollcard-wallet-pass
deno check index.ts
```

Expected: keine Type-Errors.

Falls echte Secrets schon gesetzt sind (siehe Runbook Phase B des Wallet-Rollouts):

```bash
cd ~/Desktop/Developer/Dispo
supabase functions serve atollcard-wallet-pass --env-file supabase/.env.local 2>&1 &
# Dann curl wie in Task 6 Step 2, aber jetzt sollte ein .pkpass kommen.
```

- [ ] **Step 3: Commit**

```bash
git add supabase/functions/atollcard-wallet-pass/index.ts
git commit -m "feat(fn): wire build-pass + manifest + sign + zip into request handler"
```

---

### Task 13: Integration Smoke-Test Script

**Files:**
- Create: `supabase/functions/atollcard-wallet-pass/__tests__/smoke.sh`

- [ ] **Step 1: Smoke-Script schreiben**

Inhalt von `supabase/functions/atollcard-wallet-pass/__tests__/smoke.sh`:

```bash
#!/usr/bin/env bash
# Integration smoke for atollcard-wallet-pass.
#
# Requires:
#   - All 5 WALLET_* secrets exported in env
#   - SUPABASE_URL + SUPABASE_ANON_KEY exported
#   - A real card_id (from your test data) in CARD_ID env
#   - A valid JWT in JWT env (copy from browser DevTools after login)
#
# Usage:
#   export CARD_ID=<uuid> JWT=<jwt>
#   bash __tests__/smoke.sh

set -euo pipefail

: "${CARD_ID:?CARD_ID env var required}"
: "${JWT:?JWT env var required}"
: "${SUPABASE_URL:?SUPABASE_URL env var required}"

out=$(mktemp -t pkpass.XXXXXX).pkpass

echo "→ POST to ${SUPABASE_URL}/functions/v1/atollcard-wallet-pass"
curl -sS -X POST "${SUPABASE_URL}/functions/v1/atollcard-wallet-pass" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${JWT}" \
  -d "{\"card_id\":\"${CARD_ID}\"}" \
  -o "${out}"

size=$(wc -c < "${out}")
echo "→ Received ${size} bytes → ${out}"
[ "${size}" -gt 1000 ] || { echo "✗ pass too small, probably an error response:"; cat "${out}"; exit 1; }

echo "→ Inspecting zip contents:"
unzip -l "${out}" | grep -E "(pass\.json|manifest\.json|signature|icon|logo)"

echo "→ Extracting + verifying signature"
work=$(mktemp -d)
unzip -q -o "${out}" -d "${work}"

if [ ! -f "${work}/pass.json" ]; then echo "✗ no pass.json in zip"; exit 1; fi
if [ ! -f "${work}/manifest.json" ]; then echo "✗ no manifest.json in zip"; exit 1; fi
if [ ! -f "${work}/signature" ]; then echo "✗ no signature in zip"; exit 1; fi

# OpenSSL signature verification (noverify = skip chain validation, just check signature math)
openssl smime -verify \
  -in "${work}/signature" \
  -content "${work}/manifest.json" \
  -inform DER \
  -noverify \
  > /dev/null

echo "✓ Signature verification: SUCCESS"
echo "✓ pass.json preview:"
cat "${work}/pass.json" | head -30
echo
echo "✓ Smoke passed. Pass file: ${out}"
```

- [ ] **Step 2: Ausführbar machen + commit**

```bash
chmod +x supabase/functions/atollcard-wallet-pass/__tests__/smoke.sh
git add supabase/functions/atollcard-wallet-pass/__tests__/smoke.sh
git commit -m "test(fn): integration smoke script (signature verify via openssl)"
```

---

## Phase E — iOS Wireup

### Task 14: `Config.walletPassEndpoint` Konstante

**Files:**
- Modify: `apps/atollcard-native/AtollCard/Config.swift`

- [ ] **Step 1: Konstante hinzufügen**

In `Config.swift`, in der `Config`-Struct, unter `supabaseURL`:

```swift
  /// Direct URL to the wallet-pass Edge Function on Supabase.
  /// (Don't route through atoll-os.com — the function lives on the
  /// Supabase Functions hostname.)
  static let walletPassEndpoint = URL(
    string: "\(supabaseURL.absoluteString)/functions/v1/atollcard-wallet-pass"
  )!
```

- [ ] **Step 2: Commit**

```bash
git add apps/atollcard-native/AtollCard/Config.swift
git commit -m "feat(ios): Config.walletPassEndpoint constant"
```

---

### Task 15: `WalletPassService` — JWT + Endpoint + Mock-Guard

**Files:**
- Modify: `apps/atollcard-native/AtollCard/Services/WalletPassService.swift`

- [ ] **Step 1: `passViewController(for:)` updaten**

In `WalletPassService.swift`, die Methode `passViewController(for:)` so ersetzen:

```swift
  public func passViewController(for card: Card) async throws -> PKAddPassesViewController {
    guard Self.isAvailable else { throw WalletPassError.unavailable }

    if Config.useMockData {
      throw WalletPassError.mockMode
    }

    let endpoint = Config.walletPassEndpoint

    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    // JWT for owner-auth on the Edge Function
    if let session = try? await SupabaseClient.shared.auth.session {
      request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
    } else {
      throw WalletPassError.notAuthenticated
    }

    request.httpBody = try JSONEncoder().encode(["card_id": card.id.uuidString])

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
      let status = (response as? HTTPURLResponse)?.statusCode ?? -1
      throw WalletPassError.serverError(status)
    }
    guard !data.isEmpty else { throw WalletPassError.emptyResponse }

    let pass = try PKPass(data: data)
    guard let vc = PKAddPassesViewController(pass: pass) else {
      throw WalletPassError.passInvalid
    }
    return vc
  }
```

- [ ] **Step 2: `WalletPassError` um zwei Fälle erweitern**

In der `WalletPassError`-Enum unten zwei neue Cases ergänzen:

```swift
public enum WalletPassError: LocalizedError {
  case unavailable
  case mockMode
  case notAuthenticated
  case serverError(Int)
  case emptyResponse
  case passInvalid

  public var errorDescription: String? {
    switch self {
    case .unavailable:        "Apple Wallet ist auf diesem Gerät nicht verfügbar."
    case .mockMode:           "Wallet im Mock-Modus nicht verfügbar — bitte useMockData=false setzen und neu starten."
    case .notAuthenticated:   "Kein gültiges Login — bitte erneut einloggen."
    case .serverError(let s): "Server-Fehler beim Erstellen des Wallet-Passes (Status \(s))."
    case .emptyResponse:      "Server hat keinen Pass geliefert."
    case .passInvalid:        "Pass-Datei ist beschädigt."
    }
  }
}
```

- [ ] **Step 3: xcodebuild compile-check**

```bash
cd ~/Desktop/Developer/Dispo/apps/atollcard-native
xcodegen generate
xcodebuild -scheme AtollCard -sdk iphonesimulator -configuration Debug build 2>&1 | tail -10
```

Expected: BUILD SUCCEEDED. Wenn nicht: error-message lesen, fixen, neu builden.

- [ ] **Step 4: Commit**

```bash
git add apps/atollcard-native/AtollCard/Services/WalletPassService.swift
git commit -m "feat(ios): WalletPassService — JWT header, new endpoint, mock guard"
```

---

### Task 16: `PersonaDetailCard` Wallet-Button verdrahten

**Files:**
- Modify: `apps/atollcard-native/AtollCard/Views/Cards/PersonaDetailCard.swift`

- [ ] **Step 1: Heutigen Wallet-Button identifizieren**

```bash
grep -n "Wallet\|walletPass" apps/atollcard-native/AtollCard/Views/Cards/PersonaDetailCard.swift
```

Identifiziert: der existierende "Wallet"-Quick-Action-Button + sein heutiges Action-Closure (vermutlich ein Toast oder Info-Alert).

- [ ] **Step 2: Action-Closure ersetzen**

Im PersonaDetailCard-File die existing Wallet-Button-Aktion durch folgendes ersetzen (Wenn `card: Card` der State-Wert ist; falls anders heisst, anpassen):

```swift
.task(id: addingPassFor?.id) {
  guard let card = addingPassFor else { return }
  addingPassFor = nil
  do {
    let vc = try await WalletPassService().passViewController(for: card)
    presentingPassVC = vc
  } catch {
    toastCenter.show("Wallet: \(error.localizedDescription)", severity: .error)
  }
}
```

Und am View-Level (z.B. unter `body`) zwei `@State`s + ein `.sheet`:

```swift
@State private var addingPassFor: Card?
@State private var presentingPassVC: PKAddPassesViewController?

// im body, ans äusserste Container-View:
.sheet(item: $presentingPassVC) { vc in
  PKAddPassesViewControllerRepresentable(viewController: vc)
}
```

Wallet-Button-Action wird:

```swift
Button {
  addingPassFor = card
} label: { /* existing label */ }
```

Falls es noch keinen `UIViewControllerRepresentable` für `PKAddPassesViewController` gibt, im selben File unten ergänzen:

```swift
private struct PKAddPassesViewControllerRepresentable: UIViewControllerRepresentable {
  let viewController: PKAddPassesViewController
  func makeUIViewController(context: Context) -> PKAddPassesViewController { viewController }
  func updateUIViewController(_ uiViewController: PKAddPassesViewController, context: Context) {}
}
```

Und `import PassKit` oben falls noch nicht da.

- [ ] **Step 3: xcodebuild compile**

```bash
cd ~/Desktop/Developer/Dispo/apps/atollcard-native
xcodebuild -scheme AtollCard -sdk iphonesimulator -configuration Debug build 2>&1 | tail -10
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add apps/atollcard-native/AtollCard/Views/Cards/PersonaDetailCard.swift
git commit -m "feat(ios): wire PersonaDetailCard wallet button to WalletPassService"
```

---

## Phase F — Rollout

### Task 17: Rollout-Runbook + CHANGELOG-Eintrag

**Files:**
- Create: `docs/superpowers/runbooks/2026-05-25-atollcard-wallet-welle-c-rollout.md`
- Modify: `apps/atollcard-native/CHANGELOG.md`

- [ ] **Step 1: Runbook schreiben**

Inhalt von `docs/superpowers/runbooks/2026-05-25-atollcard-wallet-welle-c-rollout.md`:

```markdown
# Runbook: AtollCard Wallet-Pass-Signing (Welle C)

**Spec:** `docs/superpowers/specs/2026-05-25-atollcard-wallet-design.md`
**Plan:** `docs/superpowers/plans/2026-05-25-atollcard-wallet.md`

## Pre-Implementation

- [ ] Echte ATOLL-Logo-Assets in den 6 Dimensionen besorgen (29/58/87 für icon, 160×50 / 320×100 / 480×150 für logo) — Placeholder-PNGs durch echte ersetzen
- [ ] Code-Review der Edge-Function (Tasks 1-12)

## Apple Developer Portal (einmalig, ~30 Min)

### Pass Type ID registrieren

- [ ] developer.apple.com → Identifiers → Pass Type IDs → +
- [ ] Description: "AtollCard Persona Pass"
- [ ] Identifier: `pass.swiss.atoll.card.persona`
- [ ] Continue → Register

### Pass Type ID Certificate erstellen

- [ ] Auf der neu angelegten Pass-Type-ID den Button "Create Certificate"
- [ ] CSR via Keychain Access generieren (Email = deine, CN = "AtollCard Pass", 2048-bit RSA)
- [ ] CSR-File hochladen → Download `pass.cer`
- [ ] `pass.cer` doppelklicken → wird in Keychain importiert
- [ ] In Keychain Access: Private Key + Cert markieren → Rechtsklick → Export 2 items → `.p12` → Passwort vergeben (1Password) → speichern als `~/Downloads/PassTypeId_Persona.p12`

### Apple WWDR G4 Cert

- [ ] https://www.apple.com/certificateauthority/ → "Worldwide Developer Relations - G4" → `.cer` herunterladen
- [ ] Speichern als `~/Downloads/AppleWWDRCAG4.cer`

## Supabase Secrets

```bash
cd ~/Desktop/Developer/Dispo

P12=~/Downloads/PassTypeId_Persona.p12
WWDR=~/Downloads/AppleWWDRCAG4.cer

supabase secrets set \
  WALLET_PASS_CERT_BASE64="$(base64 -i $P12)" \
  WALLET_PASS_CERT_PASSWORD="<dein-passwort>" \
  WALLET_WWDR_CERT_BASE64="$(base64 -i $WWDR)" \
  WALLET_PASS_TYPE_ID="pass.swiss.atoll.card.persona" \
  WALLET_TEAM_ID="XK8V89P2QV"

supabase secrets list | grep WALLET
```

## Deploy

```bash
supabase functions deploy atollcard-wallet-pass
# Wichtig: kein --no-verify-jwt — Owner-Auth braucht JWT-Verifikation
```

## Smoke

```bash
# CARD_ID + JWT besorgen (aus Browser-DevTools nach Login)
export CARD_ID=<uuid>
export JWT=<jwt-string>
export SUPABASE_URL=https://axnrilhdokkfujzjifhj.supabase.co

bash supabase/functions/atollcard-wallet-pass/__tests__/smoke.sh
```

Expected:
- File ~5-10 KB gross
- `pass.json`, `manifest.json`, `signature`, 6 PNGs im Zip
- "✓ Signature verification: SUCCESS"

## iPhone-Test

- [ ] iOS-Build via Xcode aufs echte iPhone (Push-Notifications & Wallet brauchen echte Hardware)
- [ ] App öffnen → eine Karte → "In Wallet speichern"-Button
- [ ] `PKAddPassesViewController` zeigt sich → "Hinzufügen" → Pass im Wallet sichtbar
- [ ] QR scannen → öffnet `https://atoll-os.com/c/<slug>` im Browser

## Pass-Cert Renewal-Reminder

- [ ] Captain's Log Eintrag: "Pass Type ID Cert läuft <datum + 1 Jahr> — vor Ablauf neu generieren"

## Rollback

Wenn nach Deploy alles bricht:

```bash
# Function pausieren (Dashboard → Edge Functions → atollcard-wallet-pass → Disable)
# oder vorherige Version restoren:
supabase functions list
supabase functions undeploy atollcard-wallet-pass
```

iOS-Seite bleibt: Wallet-Button zeigt Server-Error-Toast, kein Crash.
```

- [ ] **Step 2: CHANGELOG-Eintrag**

In `apps/atollcard-native/CHANGELOG.md` oben über dem aktuellen Top-Eintrag:

```markdown
## 0.10.0 — Wallet-Pass-Signing (Larry, 25.05.2026)

`PKAddPassesViewController` zeigt jetzt einen echten signierten Pass —
nicht mehr den Info-Alert-Stub. Edge Function `atollcard-wallet-pass`
baut, signiert (PKCS#7 via forge), zipped und liefert den `.pkpass`-File.

### Architektur-Entscheidung: Edge Function statt Web-Server

Pass-Cert lebt in Supabase Secrets, signing in Deno. Vorteil:
- Cert nie im iPhone-Binary (würde sonst leaken)
- Keine extra Web-Service zu deployen
- forge + zip-js + supabase-js — alles via npm:/jsr: für Deno

Cold-Start steigt um ~200ms wegen forge-Import — akzeptabel für einen
Endpoint der vermutlich <10× pro Tag gefeuert wird.

### Bewusst nicht enthalten

- **Pass-Updates via APNs** (Welle-D-Folge wenn Bedarf da ist)
- **"Save to Wallet"-Button auf der Public Card Page** (separate Spec, anonyme Auth)
- **Pass-Cert auto-Renewal** (Renewal-Reminder im Captain's Log)
```

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/runbooks/2026-05-25-atollcard-wallet-welle-c-rollout.md \
        apps/atollcard-native/CHANGELOG.md
git commit -m "docs: wallet rollout runbook + AtollCard 0.10.0 changelog"
```

---

## Self-Review-Checklist (post-hoc)

**Spec-Coverage:**
- §3.1-3.4 Pass-Inhalt + Colors → Tasks 4 + 5 ✓
- §4 Edge Function (Auth, Flow, Deps, Assets, Secrets, Errors) → Tasks 1, 6, 7-13 ✓
- §5 iOS-Anpassungen → Tasks 14, 15, 16 ✓
- §6 Apple-Setup → Runbook in Task 17 ✓
- §7 File-Inventar → über alle Tasks abgedeckt ✓
- §8 Rollout-Plan → Task 17 (Runbook) ✓
- §11 Akzeptanzkriterien → Smoke-Script (Task 13) + iPhone-Test (Runbook) decken ab ✓

**Placeholder-Scan:** keine TBD / TODO im Plan. Ein `TODO Phase B` und `TODO Phase C` als bewusste Stub-Marker in Tasks 1 + 6, die in Tasks 6 + 12 ersetzt werden.

**Typkonsistenz:** `CardData` + `ContactData` in Task 3 definiert, in Tasks 5 (buildPassJson) + 6 (DB-Load) konsistent verwendet. `PassCertBundle` aus Task 7 wird in Task 9 (sign) korrekt importiert.

**Bekannte Follow-ups (nicht im Plan):**
- Echte Logo-Assets statt Placeholder (Runbook-Pre-Implementation-Step)
- Bessere Toast-Statt-Alert-Migration (cross-cutting concern aus Welle A)
- Pass-Cert-Renewal-Reminder (Personal-Assistant-Task, separat)
