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
    // ilike-based substring search — matches single chars + partial words.
    // PostgREST websearch tokenizes and skips stopwords/single-letters, so we
    // use a multi-column ilike instead. % wildcards on both sides.
    const term = `%${filter.searchText.trim()}%`
    query = query.or(
      `display_name.ilike.${term},first_name.ilike.${term},last_name.ilike.${term},legal_name.ilike.${term},trading_name.ilike.${term},primary_email.ilike.${term}`,
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

// ────────────────────── Instructor lookup helpers ─────────────────────

/**
 * Light-weight Instructor-Liste für Dropdowns (AssignmentEditSheet,
 * CourseEditSheet, CorrectionSheet, EnrollStudentSheet, etc.).
 *
 * Query: contacts JOIN contact_instructor (INNER), filtered auf active=true.
 * Display-Name kommt aus contacts.display_name (kanonisch "Last, First").
 */
export async function listActiveInstructors(): Promise<
  { id: string; name: string; padi_level: string; active: boolean }[]
> {
  const { data, error } = await supabase
    .from('contacts')
    .select(
      'id, display_name, last_name, first_name, ' +
        'instructor:contact_instructor!inner(padi_level, active)',
    )
    .eq('contact_instructor.active', true)
    .is('archived_at', null)
    .order('last_name', { nullsFirst: false })
    .order('first_name', { nullsFirst: false })
  if (error) throw error
  return (data ?? []).map((c: unknown) => {
    const row = c as {
      id: string
      display_name: string | null
      last_name: string | null
      first_name: string | null
      instructor: { padi_level: string | null; active: boolean } | null
    }
    return {
      id: row.id,
      name: row.display_name ?? [row.last_name, row.first_name].filter(Boolean).join(', '),
      padi_level: row.instructor?.padi_level ?? '',
      active: row.instructor?.active ?? false,
    }
  })
}

/**
 * Pipeline-Liste für CDPipelineScreen — contacts mit contact_student.pipeline_stage gesetzt.
 *
 * Sortierung: nach `contact_student.updated_at DESC` als Proxy für
 * `stage_changed_on` (existiert nur in der Legacy-`people`-Tabelle, wandert
 * in Etappe 3 in den Sidecar). Funktional sehr ähnlich, da der updated_at-
 * Trigger bei jeder Sidecar-Änderung feuert.
 */
export async function listPipelineContacts(): Promise<
  {
    id: string
    first_name: string | null
    last_name: string | null
    pipeline_stage: string | null
    stage_changed_on: string | null
  }[]
> {
  const { data, error } = await supabase
    .from('contacts')
    .select(
      'id, first_name, last_name, ' +
        'student:contact_student!inner(pipeline_stage, updated_at)',
    )
    .is('archived_at', null)
    .neq('contact_student.pipeline_stage', 'none')
  if (error) throw error
  const mapped = (data ?? []).map((c: unknown) => {
    const row = c as {
      id: string
      first_name: string | null
      last_name: string | null
      student: { pipeline_stage: string | null; updated_at: string | null } | null
    }
    return {
      id: row.id,
      first_name: row.first_name,
      last_name: row.last_name,
      pipeline_stage: row.student?.pipeline_stage ?? null,
      stage_changed_on: row.student?.updated_at ?? null,
    }
  })
  // Sort client-side by stage_changed_on (descending)
  mapped.sort((a, b) => (b.stage_changed_on ?? '').localeCompare(a.stage_changed_on ?? ''))
  return mapped
}

// ────────────────────── Communication entries ─────────────────────────

export interface CommunicationEntry {
  id: string
  contact_id: string
  channel: string
  direction: string
  occurred_on: string
  subject: string | null
  body: string | null
  duration_minutes: number | null
  outcome: string | null
  contact: {
    id: string
    name: string
    is_student: boolean
    is_candidate: boolean
  } | null
  created_by_instructor: { id: string; name: string } | null
}

/**
 * Reads recent communication entries (touchpoints) with their contact and
 * created-by instructor joined. Bounded at 500 rows — the CommunicationHub
 * is a recency view, not an archive.
 */
export async function fetchCommunicationEntries(): Promise<CommunicationEntry[]> {
  const { data, error } = await supabase
    .from('communication_entries')
    .select(
      'id, contact_id, channel, direction, occurred_on, subject, body, duration_minutes, outcome, contact:people!contact_id(id, name, is_student, is_candidate), created_by_instructor:instructors!created_by(id, name)',
    )
    .order('occurred_on', { ascending: false })
    .limit(500)
  if (error) throw error
  return (data ?? []) as unknown as CommunicationEntry[]
}

// ────────────────────── Students-Liste ────────────────────────────────

/**
 * Schüler-Liste für EnrollStudentSheet, MyStudentsScreen etc.
 *
 * Query: contacts JOIN contact_student (INNER), filtered auf archived_at IS NULL.
 * Liefert Backward-Compatible-Shape für fetchStudents-Caller.
 */
export interface StudentRow {
  id: string
  name: string
  email: string | null
  phone: string | null
  birthday: string | null
  level: string | null
  notes: string | null
  active: boolean
  created_at: string
  is_student: boolean
  is_candidate: boolean
  pipeline_stage: string | null
}

export async function listStudents(): Promise<StudentRow[]> {
  const { data, error } = await supabase
    .from('contacts')
    .select(
      'id, first_name, last_name, display_name, primary_email, phones, birth_date, ' +
        'notes, roles, archived_at, created_at, ' +
        'student:contact_student!inner(level, is_candidate, pipeline_stage)',
    )
    .is('archived_at', null)
    .order('last_name', { nullsFirst: false })
    .order('first_name', { nullsFirst: false })
  if (error) throw error
  return (data ?? []).map((c: unknown) => {
    const row = c as {
      id: string
      first_name: string | null
      last_name: string | null
      display_name: string | null
      primary_email: string | null
      phones: Array<{ e164?: string; primary?: boolean }> | null
      birth_date: string | null
      notes: string | null
      roles: string[] | null
      archived_at: string | null
      created_at: string
      student: { level: string | null; is_candidate: boolean; pipeline_stage: string | null } | null
    }
    const primaryPhone =
      (row.phones ?? []).find((p) => p.primary)?.e164 ?? row.phones?.[0]?.e164 ?? null
    return {
      id: row.id,
      name: row.display_name ?? [row.last_name, row.first_name].filter(Boolean).join(', '),
      email: row.primary_email,
      phone: primaryPhone,
      birthday: row.birth_date,
      level: row.student?.level ?? null,
      notes: row.notes,
      active: row.archived_at === null,
      created_at: row.created_at,
      is_student: (row.roles ?? []).includes('student'),
      is_candidate: row.student?.is_candidate ?? false,
      pipeline_stage: row.student?.pipeline_stage ?? null,
    }
  })
}

/**
 * Kandidaten-Liste für IDC/SPEI-Enrollment.
 *
 * Filter: contacts.roles enthält 'candidate'. KEIN contact_student-Join
 * (Kandidaten können gleichzeitig Instructor sein und brauchen keinen
 * Student-Sidecar).
 */
export async function listCandidates(): Promise<StudentRow[]> {
  const { data, error } = await supabase
    .from('contacts')
    .select(
      'id, first_name, last_name, display_name, primary_email, phones, birth_date, ' +
        'notes, roles, archived_at, created_at',
    )
    .is('archived_at', null)
    .contains('roles', ['candidate'])
    .order('last_name', { nullsFirst: false })
    .order('first_name', { nullsFirst: false })
  if (error) throw error
  return (data ?? []).map((c: unknown) => {
    const row = c as {
      id: string
      first_name: string | null
      last_name: string | null
      display_name: string | null
      primary_email: string | null
      phones: Array<{ e164?: string; primary?: boolean }> | null
      birth_date: string | null
      notes: string | null
      roles: string[] | null
      archived_at: string | null
      created_at: string
    }
    const primaryPhone =
      (row.phones ?? []).find((p) => p.primary)?.e164 ?? row.phones?.[0]?.e164 ?? null
    return {
      id: row.id,
      name: row.display_name ?? [row.last_name, row.first_name].filter(Boolean).join(', '),
      email: row.primary_email,
      phone: primaryPhone,
      birthday: row.birth_date,
      level: null,
      notes: row.notes,
      active: row.archived_at === null,
      created_at: row.created_at,
      is_student: (row.roles ?? []).includes('student'),
      is_candidate: true,
      pipeline_stage: null,
    }
  })
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

// ────────────────────── Contact-Detail Tab queries ─────────────────────────

export interface ContactAuditRow {
  id: string
  changed_at: string
  table_name: string
  operation: string
  changed_fields?: Record<string, unknown> | null
}

/**
 * Reads contact_audit_log rows for one contact. Caller controls the limit
 * (Activity tab passes 100, Audit-History tab passes 200) — same query
 * shape, different page size.
 */
export async function fetchContactAuditLog(
  contactId: string,
  limit: number = 100,
): Promise<ContactAuditRow[]> {
  const { data, error } = await supabase
    .from('contact_audit_log')
    .select('id, changed_at, table_name, operation, changed_fields')
    .eq('contact_id', contactId)
    .order('changed_at', { ascending: false })
    .limit(limit)
  if (error) throw error
  return (data ?? []) as ContactAuditRow[]
}

export interface ContactCommunicationRow {
  id: string
  channel: string
  direction: string
  occurred_on: string
  subject: string | null
  body: string | null
  duration_minutes: number | null
  outcome: string | null
  created_by_instructor: { id: string; name: string } | null
}

/** Communication entries scoped to one contact (Communications tab). */
export async function fetchContactCommunications(contactId: string): Promise<ContactCommunicationRow[]> {
  const { data, error } = await supabase
    .from('communication_entries')
    .select(
      'id, channel, direction, occurred_on, subject, body, duration_minutes, outcome, created_by_instructor:instructors!created_by(id, name)',
    )
    .eq('contact_id', contactId)
    .order('occurred_on', { ascending: false })
    .limit(200)
  if (error) throw error
  return (data ?? []) as unknown as ContactCommunicationRow[]
}

export interface ContactSkillRow {
  id: string
  code: string
  label: string
  category: string | null
}

/** Instructor-skills via embed-join (Skills tab read-only). */
export async function fetchContactSkills(contactId: string): Promise<ContactSkillRow[]> {
  const { data, error } = await supabase
    .from('instructor_skills')
    .select('skill:skills(id, code, label, category)')
    .eq('instructor_id', contactId)
  if (error) throw error
  return ((data ?? []) as unknown as { skill: ContactSkillRow | null }[])
    .map((r) => r.skill)
    .filter((s): s is ContactSkillRow => s !== null)
    .sort((a, b) => {
      const ca = a.category ?? ''
      const cb = b.category ?? ''
      if (ca !== cb) return ca.localeCompare(cb)
      return a.label.localeCompare(b.label)
    })
}

export interface ContactCourseAssignment {
  id: string
  role: string
  courses: { id: string; title: string; start_date: string | null; status: string } | null
}

export interface ContactCourseParticipation {
  id: string
  courses: { id: string; title: string; start_date: string | null; status: string } | null
}

/** Courses where this contact is assigned as instructor. */
export async function fetchInstructorCourses(contactId: string): Promise<ContactCourseAssignment[]> {
  const { data, error } = await supabase
    .from('course_assignments')
    .select('id, role, courses(id, title, start_date, status)')
    .eq('instructor_id', contactId)
    .order('id', { ascending: false })
    .limit(50)
  if (error) throw error
  return (data ?? []) as unknown as ContactCourseAssignment[]
}

/** Courses where this contact is enrolled as student/candidate. */
export async function fetchStudentParticipations(contactId: string): Promise<ContactCourseParticipation[]> {
  const { data, error } = await supabase
    .from('course_participants')
    .select('id, courses(id, title, start_date, status)')
    .eq('student_id', contactId)
    .order('id', { ascending: false })
    .limit(50)
  if (error) throw error
  return (data ?? []) as unknown as ContactCourseParticipation[]
}

/** Count of `account_movements` rows for one contact (SaldoTab stub). */
export async function fetchContactBookingCount(contactId: string): Promise<number> {
  const { count, error } = await supabase
    .from('account_movements')
    .select('*', { count: 'exact', head: true })
    .eq('contact_id', contactId)
  if (error) throw error
  return count ?? 0
}

export interface OrgMemberRow {
  id: string
  from_contact_id: string
  role_at_org: string | null
  from_contact: {
    id: string
    display_name: string
    primary_email: string | null
    roles: string[]
  } | null
}

/** Members of an organization via `works_at` relationship. */
export async function fetchOrgMembers(orgId: string): Promise<OrgMemberRow[]> {
  const { data, error } = await supabase
    .from('contact_relationships')
    .select(
      'id, from_contact_id, role_at_org, ' +
      'from_contact:contacts!contact_relationships_from_contact_id_fkey(id, display_name, primary_email, roles)',
    )
    .eq('to_contact_id', orgId)
    .eq('kind', 'works_at')
  if (error) throw error
  return (data ?? []) as unknown as OrgMemberRow[]
}

/** Removes one `contact_relationships` row by id (used by RelationshipsTab). */
export async function removeRelationship(relationshipId: string): Promise<void> {
  const { error } = await supabase
    .from('contact_relationships')
    .delete()
    .eq('id', relationshipId)
  if (error) throw error
}

// ────────────────────── Communication edit support ─────────────────────────

export interface ContactPickerOption {
  id: string
  name: string
  email: string | null
  phone: string | null
  is_student: boolean
  is_candidate: boolean
}

export interface ContactBasics {
  id: string
  name: string
  email: string | null
  phone: string | null
}

export interface CommunicationEntryForEdit {
  channel: string
  direction: string
  occurred_on: string
  subject: string | null
  body: string | null
  duration_minutes: number | null
  outcome: string | null
  contact_id: string
  created_by: string | null
}

export interface CommunicationEntryInput {
  contact_id: string
  channel: string
  direction: string
  occurred_on: string  // ISO
  subject: string | null
  body: string | null
  duration_minutes: number | null
  outcome: string | null
  created_by: string | null
}

/**
 * Reads all non-archived contacts as a picker list for CommunicationEditSheet.
 * Flat structure: id + display name + best-effort email/phone + role flags.
 */
export async function fetchContactPickerList(): Promise<ContactPickerOption[]> {
  const { data, error } = await supabase
    .from('contacts')
    .select('id, display_name, primary_email, phones, roles')
    .is('archived_at', null)
    .order('display_name')
  if (error) throw error
  return ((data ?? []) as Array<{
    id: string
    display_name: string | null
    primary_email: string | null
    phones: Array<{ e164?: string }> | null
    roles: string[] | null
  }>).map((c) => ({
    id: c.id,
    name: c.display_name ?? '',
    email: c.primary_email ?? null,
    phone: (Array.isArray(c.phones) && c.phones[0]?.e164) || null,
    is_student: Array.isArray(c.roles) && c.roles.includes('student'),
    is_candidate: Array.isArray(c.roles) && c.roles.includes('candidate'),
  }))
}

/** Reads just name + email + first-phone for the send-buttons row. */
export async function fetchContactBasics(contactId: string): Promise<ContactBasics | null> {
  const { data, error } = await supabase
    .from('contacts')
    .select('id, display_name, primary_email, phones')
    .eq('id', contactId)
    .maybeSingle()
  if (error) throw error
  if (!data) return null
  const c = data as {
    id: string
    display_name: string | null
    primary_email: string | null
    phones: Array<{ e164?: string }> | null
  }
  return {
    id: c.id,
    name: c.display_name ?? '',
    email: c.primary_email ?? null,
    phone: (Array.isArray(c.phones) && c.phones[0]?.e164) || null,
  }
}

/** Reads a single communication_entries row for the edit form. */
export async function fetchCommunicationEntry(entryId: string): Promise<CommunicationEntryForEdit | null> {
  const { data, error } = await supabase
    .from('communication_entries')
    .select('channel, direction, occurred_on, subject, body, duration_minutes, outcome, contact_id, created_by')
    .eq('id', entryId)
    .single()
  if (error) throw error
  return (data as CommunicationEntryForEdit | null) ?? null
}

/** Inserts a new communication entry. */
export async function insertCommunicationEntry(input: CommunicationEntryInput): Promise<void> {
  const { error } = await supabase.from('communication_entries').insert(input)
  if (error) throw error
}

/** Updates an existing communication entry. */
export async function updateCommunicationEntry(entryId: string, input: CommunicationEntryInput): Promise<void> {
  const { error } = await supabase.from('communication_entries').update(input).eq('id', entryId)
  if (error) throw error
}

/** Deletes a communication entry. */
export async function deleteCommunicationEntry(entryId: string): Promise<void> {
  const { error } = await supabase.from('communication_entries').delete().eq('id', entryId)
  if (error) throw error
}
