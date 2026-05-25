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
