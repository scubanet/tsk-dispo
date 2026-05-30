// apps/web/src/lib/comms/toUnipileRecipient.ts
// Baut aus den Kontaktdaten den Unipile-Empfänger pro Kanal.
// Spec: docs/superpowers/specs/2026-05-29-comms-integration-unipile-design.md §6.1
import type { CommsChannel } from '@/types/messaging'

export interface RecipientFields {
  email?: string | null
  e164?: string | null
  linkedin_member_id?: string | null
}
export interface UnipileRecipient {
  kind: 'email' | 'attendee'
  identifier: string
}

export function toUnipileRecipient(channel: CommsChannel, f: RecipientFields): UnipileRecipient | null {
  if (channel === 'email') {
    return f.email ? { kind: 'email', identifier: f.email } : null
  }
  if (channel === 'whatsapp') {
    if (!f.e164) return null
    return { kind: 'attendee', identifier: `${f.e164.replace(/^\+/, '')}@s.whatsapp.net` }
  }
  if (channel === 'linkedin') {
    return f.linkedin_member_id ? { kind: 'attendee', identifier: f.linkedin_member_id } : null
  }
  return null
}
