/**
 * Contact query layer — all Supabase calls for the contacts domain.
 *
 * Keep each function small and single-purpose. React Query wrappers
 * live in hooks/useContacts.ts (Phase E).
 */

import { supabase } from './supabase'
import type {
  Contact,
  ContactWithSidecars,
  ContactInstructor,
  ContactStudent,
  ContactOrganization,
  ContactRelationship,
  ContactRole,
  ContactKind,
  RelationshipKind,
  PhoneEntry,
  EmailEntry,
} from '@/types/contacts'

// ─────────────────────────── Filter type ─────────────────────────────

export interface ContactListFilter {
  kind?: ContactKind
  roles?: ContactRole[]
  searchText?: string
  archivedOnly?: boolean
  ownerId?: string
  pipelineStage?: string
}

// ─────────────────────── List / search ───────────────────────────────

export async function listContacts(
  filter: ContactListFilter = {},
  page = 0,
  pageSize = 50,
): Promise<{ rows: Contact[]; count: number }> {
  let query = supabase
    .from('contacts')
    .select(
      'id, kind, first_name, last_name, birth_date, gender, ' +
      'legal_name, trading_name, display_name, ' +
      'primary_email, emails, phones, addresses, ' +
      'languages, roles, tags, notes, owner_id, ' +
      'consent_marketing, consent_marketing_at, consent_marketing_source, ' +
      'source, archived_at, merged_into_id, created_at, updated_at, created_by',
      { count: 'exact' },
    )

  // Archived / active
  if (filter.archivedOnly) {
    query = query.not('archived_at', 'is', null)
  } else {
    query = query.is('archived_at', null)
  }

  // Only non-merged contacts
  query = query.is('merged_into_id', null)

  if (filter.kind) {
    query = query.eq('kind', filter.kind)
  }

  if (filter.roles && filter.roles.length > 0) {
    query = query.overlaps('roles', filter.roles)
  }

  if (filter.ownerId) {
    query = query.eq('owner_id', filter.ownerId)
  }

  if (filter.searchText && filter.searchText.trim() !== '') {
    // Use PostgREST full-text search on the search index
    query = query.textSearch(
      'display_name',
      filter.searchText.trim(),
      { type: 'websearch', config: 'simple' },
    )
  }

  const from = page * pageSize
  const to = from + pageSize - 1
  query = query.range(from, to).order('display_name')

  const { data, error, count } = await query
  if (error) throw error
  return { rows: (data ?? []) as unknown as Contact[], count: count ?? 0 }
}

// ──────────────────── Single contact + sidecars ───────────────────────

export async function getContactWithSidecars(
  id: string,
): Promise<ContactWithSidecars | null> {
  const { data: contact, error } = await supabase
    .from('contacts')
    .select(
      'id, kind, first_name, last_name, birth_date, gender, ' +
      'legal_name, trading_name, display_name, ' +
      'primary_email, emails, phones, addresses, ' +
      'languages, roles, tags, notes, owner_id, ' +
      'consent_marketing, consent_marketing_at, consent_marketing_source, ' +
      'source, archived_at, merged_into_id, created_at, updated_at, created_by',
    )
    .eq('id', id)
    .maybeSingle()
  if (error) throw error
  if (!contact) return null

  const base = contact as unknown as Contact

  // Fetch sidecars in parallel
  const [instructorRes, studentRes, orgRes] = await Promise.all([
    supabase
      .from('contact_instructor')
      .select('*')
      .eq('contact_id', id)
      .maybeSingle(),
    supabase
      .from('contact_student')
      .select('*')
      .eq('contact_id', id)
      .maybeSingle(),
    supabase
      .from('contact_organization')
      .select('*')
      .eq('contact_id', id)
      .maybeSingle(),
  ])

  return {
    ...base,
    instructor: (instructorRes.data as unknown as ContactInstructor) ?? null,
    student: (studentRes.data as unknown as ContactStudent) ?? null,
    organization: (orgRes.data as unknown as ContactOrganization) ?? null,
  }
}

// ────────────────────── Inline-edit helpers ───────────────────────────

export async function updateContactField<K extends keyof Contact>(
  id: string,
  field: K,
  value: Contact[K],
): Promise<void> {
  const { error } = await supabase
    .from('contacts')
    .update({ [field]: value })
    .eq('id', id)
  if (error) throw error
}

export async function updateInstructorField<K extends keyof ContactInstructor>(
  contactId: string,
  field: K,
  value: ContactInstructor[K],
): Promise<void> {
  const { error } = await supabase
    .from('contact_instructor')
    .update({ [field]: value })
    .eq('contact_id', contactId)
  if (error) throw error
}

export async function updateStudentField<K extends keyof ContactStudent>(
  contactId: string,
  field: K,
  value: ContactStudent[K],
): Promise<void> {
  const { error } = await supabase
    .from('contact_student')
    .update({ [field]: value })
    .eq('contact_id', contactId)
  if (error) throw error
}

export async function updateOrganizationField<K extends keyof ContactOrganization>(
  contactId: string,
  field: K,
  value: ContactOrganization[K],
): Promise<void> {
  const { error } = await supabase
    .from('contact_organization')
    .update({ [field]: value })
    .eq('contact_id', contactId)
  if (error) throw error
}

// ────────────────────────── Relationships ────────────────────────────

export async function listRelationships(
  contactId: string,
): Promise<ContactRelationship[]> {
  const [fromRes, toRes] = await Promise.all([
    supabase
      .from('contact_relationships')
      .select(
        'id, from_contact_id, to_contact_id, kind, role_at_org, ' +
        'started_at, ended_at, is_primary, notes, created_at, ' +
        'to_contact:contacts!contact_relationships_to_contact_id_fkey(id, display_name, kind, roles)',
      )
      .eq('from_contact_id', contactId),
    supabase
      .from('contact_relationships')
      .select(
        'id, from_contact_id, to_contact_id, kind, role_at_org, ' +
        'started_at, ended_at, is_primary, notes, created_at, ' +
        'from_contact:contacts!contact_relationships_from_contact_id_fkey(id, display_name, kind, roles)',
      )
      .eq('to_contact_id', contactId),
  ])
  if (fromRes.error) throw fromRes.error
  if (toRes.error) throw toRes.error

  return [
    ...((fromRes.data ?? []) as unknown as ContactRelationship[]),
    ...((toRes.data ?? []) as unknown as ContactRelationship[]),
  ]
}

export async function addRelationship(params: {
  from_contact_id: string
  to_contact_id: string
  kind: RelationshipKind
  role_at_org?: string
  is_primary?: boolean
}): Promise<void> {
  const { error } = await supabase.from('contact_relationships').insert(params)
  if (error) throw error
}

// ────────────────────── Dedup & merge ────────────────────────────────

export async function findPotentialDuplicates(
  contactId: string,
): Promise<Contact[]> {
  const { data, error } = await supabase.rpc('find_contact_duplicates', {
    p_contact_id: contactId,
  })
  if (error) throw error
  return (data ?? []) as Contact[]
}

export async function mergeContacts(
  winnerId: string,
  loserId: string,
): Promise<void> {
  const { error } = await supabase.rpc('merge_contacts', {
    p_winner_id: winnerId,
    p_loser_id: loserId,
  })
  if (error) throw error
}

// ──────────────────────── GDPR ───────────────────────────────────────

export async function gdprAnonymize(contactId: string): Promise<void> {
  const { error } = await supabase.rpc('gdpr_anonymize_contact', {
    p_contact_id: contactId,
  })
  if (error) throw error
}

// ────────────────────── Create / archive ─────────────────────────────

export async function createContact(params: {
  kind: ContactKind
  first_name?: string
  last_name?: string
  legal_name?: string
  primary_email?: string
  phones?: PhoneEntry[]
  emails?: EmailEntry[]
  roles: ContactRole[]
}): Promise<string> {
  const { data, error } = await supabase
    .from('contacts')
    .insert({
      kind: params.kind,
      first_name: params.first_name ?? null,
      last_name: params.last_name ?? null,
      legal_name: params.legal_name ?? null,
      primary_email: params.primary_email ?? null,
      phones: params.phones ?? [],
      emails: params.emails ?? [],
      addresses: [],
      roles: params.roles,
    })
    .select('id')
    .single()
  if (error) throw error
  return (data as { id: string }).id
}

export async function archiveContact(id: string): Promise<void> {
  const { error } = await supabase
    .from('contacts')
    .update({ archived_at: new Date().toISOString() })
    .eq('id', id)
  if (error) throw error
}
