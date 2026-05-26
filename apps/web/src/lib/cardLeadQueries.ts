/**
 * AtollCard Card-Lead Queries
 *
 * PostgREST wrappers + RPC client for the card-inbox.
 * Reads go via the v_card_leads_inbox view; writes go to card_leads.
 */
import { supabase } from '@/lib/supabase'
import type {
  CardLeadRow,
  CardLeadStatus,
  ImportCardLeadResult,
} from '@/types/cardLeads'

export type CardLeadViewId =
  | 'all' | 'new' | 'in_progress' | 'imported' | 'archived' | 'spam'

export interface CardLeadFilterInput {
  view: CardLeadViewId
  search?: string
}

export interface CardLeadFilter {
  statuses?: CardLeadStatus[]
  search?: string
}

/**
 * Convert URL-state into a Postgres-friendly filter object.
 * `in_progress` is a UI alias for status IN (opened, contacted).
 */
export function buildCardLeadsFilter(input: CardLeadFilterInput): CardLeadFilter {
  const out: CardLeadFilter = {}

  switch (input.view) {
    case 'new':         out.statuses = ['new']; break
    case 'in_progress': out.statuses = ['opened', 'contacted']; break
    case 'imported':    out.statuses = ['imported']; break
    case 'archived':    out.statuses = ['archived']; break
    case 'spam':        out.statuses = ['spam']; break
    case 'all':         /* no status filter */ break
  }

  const search = input.search?.trim().toLowerCase()
  if (search) out.search = search

  return out
}

/**
 * Fetch a page of card-leads from the inbox view.
 * RLS does the owner-scoping; we order by captured_at desc and cap at 500
 * (same convention as AddressbookScreen).
 */
export async function fetchCardLeads(
  filter: CardLeadFilter,
  limit = 500,
): Promise<CardLeadRow[]> {
  let q = supabase
    .from('v_card_leads_inbox')
    .select('*')
    .order('captured_at', { ascending: false })
    .limit(limit)

  if (filter.statuses && filter.statuses.length > 0) {
    q = q.in('status', filter.statuses)
  }

  if (filter.search) {
    // OR across first_name, last_name, email, topic, message
    const s = filter.search.replace(/[%,]/g, ' ')
    q = q.or(
      `first_name.ilike.%${s}%,` +
      `last_name.ilike.%${s}%,` +
      `email.ilike.%${s}%,` +
      `topic.ilike.%${s}%,` +
      `message.ilike.%${s}%`
    )
  }

  const { data, error } = await q
  if (error) throw new Error(error.message)
  return (data ?? []) as CardLeadRow[]
}

/**
 * Count of unread (status='new') leads — for the Sidebar badge.
 */
export async function fetchUnreadCount(): Promise<number> {
  const { count, error } = await supabase
    .from('v_card_leads_inbox')
    .select('id', { count: 'exact', head: true })
    .eq('status', 'new')

  if (error) throw new Error(error.message)
  return count ?? 0
}

/**
 * Update a single lead's status. Returns void on success, throws on RLS / FK.
 */
export async function updateLeadStatus(
  leadId: string,
  status: CardLeadStatus,
): Promise<void> {
  const { error } = await supabase
    .from('card_leads')
    .update({ status })
    .eq('id', leadId)

  if (error) throw new Error(error.message)
}

/**
 * Trigger the import_card_lead RPC.
 * Returns { contact_id, action: 'created' | 'merged' | 'already_imported' }.
 */
export async function importCardLeadRpc(
  leadId: string,
): Promise<ImportCardLeadResult> {
  const { data, error } = await supabase.rpc('import_card_lead', {
    p_lead_id: leadId,
  })

  if (error) throw new Error(error.message)

  // RPC returns SETOF — Supabase serializes that as an array of rows.
  const row = Array.isArray(data) ? data[0] : data
  if (!row) throw new Error('import_card_lead returned no row')

  return row as ImportCardLeadResult
}

/**
 * Hard-delete a card-lead. RLS (card_leads_owner from migration 0097)
 * ensures only the card-owner can delete. If the lead was already
 * imported to the address book, the bridge column imported_contact_id
 * is cleared via ON DELETE SET NULL — the contact itself remains.
 */
export async function deleteLead(leadId: string): Promise<void> {
  const { error } = await supabase
    .from('card_leads')
    .delete()
    .eq('id', leadId)

  if (error) throw new Error(error.message)
}
