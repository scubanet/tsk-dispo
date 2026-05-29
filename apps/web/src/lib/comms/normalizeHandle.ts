// apps/web/src/lib/comms/normalizeHandle.ts
// Normalisiert einen eingehenden Absender-Handle in die Form, in der er
// gegen contacts gematcht wird. Rein, keine I/O — Edge Function nutzt das
// Ergebnis als Query-Filter.
// Spec: docs/superpowers/specs/2026-05-29-comms-integration-unipile-design.md §4.2
import { parsePhoneNumberFromString } from 'libphonenumber-js'
import type { CommsChannel } from '@/types/messaging'

export function normalizeHandle(channel: CommsChannel, raw: string): string | null {
  if (channel === 'whatsapp') {
    const trimmed = raw.trim()
    const withPlus = trimmed.startsWith('+') ? trimmed : `+${trimmed}`
    const parsed = parsePhoneNumberFromString(withPlus)
    return parsed?.isValid() ? parsed.number : null
  }
  if (channel === 'email') {
    const email = raw.trim().toLowerCase()
    return /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email) ? email : null
  }
  if (channel === 'linkedin') {
    const id = raw.trim()
    return id.length > 0 ? id : null
  }
  return null
}
