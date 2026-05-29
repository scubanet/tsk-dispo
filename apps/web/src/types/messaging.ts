// apps/web/src/types/messaging.ts
// Spec: docs/superpowers/specs/2026-05-29-comms-integration-unipile-design.md §4

export type CommsChannel = 'email' | 'whatsapp' | 'linkedin'

export interface MessagingAccount {
  id: string
  channel: CommsChannel
  unipile_account_id: string
  provider: string | null
  label: string
  owner_user_id: string
  status: 'connected' | 'disconnected' | 'error'
  connected_at: string
  last_event_at: string | null
}

export interface ContactEnrichment {
  id: string
  contact_id: string
  source: 'linkedin'
  fields: Record<string, unknown>
  status: 'suggested' | 'accepted' | 'rejected'
  fetched_at: string
}

export interface UnmatchedMessage {
  id: string
  channel: CommsChannel
  sender_handle: string
  normalized_payload: Record<string, unknown>
  external_id: string
  received_at: string
  resolved_contact_id: string | null
}
