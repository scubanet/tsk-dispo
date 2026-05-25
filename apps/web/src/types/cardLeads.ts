/**
 * AtollCard Card-Lead Types
 *
 * Mirrors the v_card_leads_inbox view (defined in migration 0102).
 * Inserts/updates write directly to public.card_leads.
 */

export type CardLeadStatus =
  | 'new'
  | 'opened'
  | 'contacted'
  | 'imported'
  | 'archived'
  | 'spam'

export interface CardLeadRow {
  id: string
  card_id: string

  first_name: string
  last_name: string | null
  email: string | null
  phone: string | null
  message: string | null
  topic: string | null

  captured_at: string       // ISO timestamp
  status: CardLeadStatus
  avatar_color: string | null

  imported_to_address_book: boolean
  imported_contact_id: string | null

  // Joined from cards
  card_slug: string
  card_title: string
  card_badge: string | null
  card_person_id: string
}

/** RPC return type for public.import_card_lead(p_lead_id) */
export interface ImportCardLeadResult {
  contact_id: string
  action: 'created' | 'merged' | 'already_imported'
}
