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
