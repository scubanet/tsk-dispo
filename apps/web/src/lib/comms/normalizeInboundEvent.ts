// apps/web/src/lib/comms/normalizeInboundEvent.ts
// Normalisiert Unipiles zwei Webhook-Payloads (messaging + email) in eine
// gemeinsame Struktur fürs Einfügen in contact_events.
// Spec: docs/superpowers/specs/2026-05-29-comms-integration-unipile-design.md §4.1, §6.1
import type { CommsChannel } from '@/types/messaging'
import type { Direction } from '@/types/contactEvents'

export interface NormalizedInbound {
  channel: CommsChannel
  direction: Direction
  external_id: string
  counterparty_handle: string
  summary: string
  body: string
  occurred_at: string
  thread_id?: string
  attachment_count: number
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type Raw = Record<string, any>

export function normalizeInboundEvent(p: Raw): NormalizedInbound | null {
  // ── E-Mail-Quelle ──
  if (p.email_id) {
    if (p.event !== 'mail_received' && p.event !== 'mail_sent') return null
    const direction: Direction = p.event === 'mail_sent' ? 'outbound' : 'inbound'
    const handleRaw = direction === 'inbound'
      ? p.from_attendee?.identifier
      : p.to_attendees?.[0]?.identifier
    if (!handleRaw) return null
    return {
      channel: 'email',
      direction,
      // RFC-message_id ist stabil über Ordner/Syncs; Unipiles email_id kann
      // pro Sync variieren und denselben Mail-Event mehrfach liefern.
      external_id: p.message_id || p.email_id,
      counterparty_handle: String(handleRaw).trim().toLowerCase(),
      summary: p.subject || '(kein Betreff)',
      body: p.body_plain || p.body || '',
      occurred_at: p.date,
      attachment_count: Array.isArray(p.attachments) ? p.attachments.length : 0,
    }
  }

  // ── Messaging-Quelle (WhatsApp / LinkedIn) ──
  if (p.message_id) {
    if (p.event !== 'message_received') return null
    const channel: CommsChannel | null =
      p.account_type === 'WHATSAPP' ? 'whatsapp'
      : p.account_type === 'LINKEDIN' ? 'linkedin'
      : null
    if (!channel) return null

    const selfId = p.account_info?.user_id
    const senderId = p.sender?.attendee_provider_id
    const isOutbound = !!selfId && senderId === selfId
    const direction: Direction = isOutbound ? 'outbound' : 'inbound'

    const counterparty = isOutbound
      ? (p.attendees ?? [])
          .map((a: Raw) => a.attendee_provider_id)
          .find((id: string) => id && id !== selfId)
      : senderId
    if (!counterparty) return null

    return {
      channel,
      direction,
      external_id: p.message_id,
      counterparty_handle: String(counterparty).trim(),
      summary: (p.message ?? '').slice(0, 140) || '(kein Text)',
      body: p.message ?? '',
      occurred_at: p.timestamp,
      thread_id: p.chat_id,
      attachment_count: Array.isArray(p.attachments) ? p.attachments.length : 0,
    }
  }

  return null
}
