import { supabase } from './supabase'

export interface CourseRow {
  id: string
  title: string
  start_date: string
  additional_dates: string[]
  status: 'confirmed' | 'tentative' | 'completed' | 'cancelled'
  num_participants: number
  course_type: { code: string; label: string } | null
}

export interface CourseDetail extends CourseRow {
  info: string | null
  notes: string | null
  additional_dates: string[]
  pool_booked: boolean
  type_id: string
}

export interface AssignmentRow {
  id: string
  course_id: string
  instructor_id: string
  role: 'haupt' | 'assist' | 'opfer' | 'dmt'  // 'dmt' nur Legacy
  confirmed: boolean
  course?: CourseRow | null
  instructor: { id: string; name: string; initials: string; color: string; padi_level?: string } | null
}

export async function fetchCoursesInRange(from: string, to: string): Promise<CourseRow[]> {
  // Note: we widen the lower bound by 60 days to catch courses whose start_date
  // is BEFORE the visible range but whose additional_dates fall inside it.
  // Client-side filtering then matches against the union of [start_date, ...additional_dates].
  const widened = new Date(from)
  widened.setDate(widened.getDate() - 60)
  const widenedFrom = widened.toISOString().slice(0, 10)

  const { data, error } = await supabase
    .from('courses')
    .select(`
      id, title, start_date, additional_dates, status, num_participants,
      course_type:course_types(code, label)
    `)
    .gte('start_date', widenedFrom)
    .lte('start_date', to)
    .order('start_date')
  if (error) throw error
  return (data ?? []) as unknown as CourseRow[]
}

export async function fetchAllCourses(): Promise<CourseDetail[]> {
  const { data, error } = await supabase
    .from('courses')
    .select(`
      id, title, start_date, status, num_participants,
      info, notes, additional_dates, pool_booked, type_id,
      course_type:course_types(code, label)
    `)
    .order('start_date')
  if (error) throw error
  return (data ?? []) as unknown as CourseDetail[]
}

export async function fetchAssignmentsForCourses(courseIds: string[]): Promise<AssignmentRow[]> {
  if (courseIds.length === 0) return []
  const { data, error } = await supabase
    .from('course_assignments')
    .select(`
      id, course_id, instructor_id, role, confirmed,
      instructor:instructors(id, name, initials, color, padi_level)
    `)
    .in('course_id', courseIds)
  if (error) throw error
  return (data ?? []) as unknown as AssignmentRow[]
}

export type CourseDateType = 'theorie' | 'pool' | 'see'
export type PoolLocation = 'mooesli' | 'langnau' | 'kloten' | 'uitikon'

export interface CourseDate {
  id: string
  course_id: string
  date: string
  type: CourseDateType
  pool_location: PoolLocation | null
  pool_reserved?: boolean
  has_theory?: boolean
  has_pool?: boolean
  has_lake?: boolean
  time_from: string | null
  time_to: string | null
  // Per-Type-Zeiten (Migration 0095)
  theory_from: string | null
  theory_to: string | null
  pool_from: string | null
  pool_to: string | null
  lake_from: string | null
  lake_to: string | null
  note: string | null
}

export async function fetchCourseDates(courseId: string): Promise<CourseDate[]> {
  const { data, error } = await supabase
    .from('course_dates')
    .select(
      'id, course_id, date, type, pool_location, pool_reserved, has_theory, has_pool, has_lake, ' +
        'time_from, time_to, theory_from, theory_to, pool_from, pool_to, lake_from, lake_to, note',
    )
    .eq('course_id', courseId)
    .order('date')
  if (error) throw error
  return (data ?? []) as unknown as CourseDate[]
}

export const POOL_LOCATIONS: { value: PoolLocation; label: string }[] = [
  { value: 'mooesli',  label: 'Möösli' },
  { value: 'langnau',  label: 'Langnau' },
  { value: 'kloten',   label: 'Kloten' },
  { value: 'uitikon',  label: 'Uitikon' },
]

export const COURSE_DATE_TYPES: { value: CourseDateType; label: string; emoji: string }[] = [
  { value: 'theorie', label: 'Theorie', emoji: '📚' },
  { value: 'pool',    label: 'Pool',    emoji: '🏊' },
  { value: 'see',     label: 'See',     emoji: '🌊' },
]

export async function fetchCourseAssignments(courseId: string): Promise<(AssignmentRow & { assigned_for_dates: string[] })[]> {
  const { data, error } = await supabase
    .from('course_assignments')
    .select(`
      id, course_id, instructor_id, role, confirmed, assigned_for_dates,
      instructor:instructors(id, name, initials, color, padi_level)
    `)
    .eq('course_id', courseId)
  if (error) throw error
  return (data ?? []) as unknown as (AssignmentRow & { assigned_for_dates: string[] })[]
}

export interface Kpis {
  totalCourses: number
  confirmedCourses: number
  instructorCount: number
  assignmentsThisWeek: number
}

export interface MyAssignment {
  id: string
  role: 'haupt' | 'assist' | 'opfer' | 'dmt'  // 'dmt' nur Legacy
  confirmed: boolean
  course: {
    id: string
    title: string
    start_date: string
    status: 'confirmed' | 'tentative' | 'cancelled'
    info: string | null
    notes: string | null
    additional_dates: string[]
    course_type: { code: string; label: string } | null
  } | null
}

export async function fetchMyAssignments(instructorId: string): Promise<MyAssignment[]> {
  const { data, error } = await supabase
    .from('course_assignments')
    .select(`
      id, role, confirmed,
      course:courses(
        id, title, start_date, status, info, notes, additional_dates,
        course_type:course_types(code, label)
      )
    `)
    .eq('instructor_id', instructorId)
  if (error) throw error
  const sorted = (data ?? []).sort((a: any, b: any) =>
    (a.course?.start_date ?? '').localeCompare(b.course?.start_date ?? ''),
  )
  return sorted as unknown as MyAssignment[]
}

export interface MyMovement {
  id: string
  date: string
  amount_chf: number
  kind: 'vergütung' | 'übertrag' | 'korrektur'
  description: string | null
  breakdown_json: Record<string, unknown> | null
  ref_assignment_id: string | null
}

export async function fetchMyMovements(instructorId: string): Promise<MyMovement[]> {
  // Fetch all movements WITH the linked course's status (via ref_assignment_id → course_assignments → courses).
  // Then filter: vergütung-Movements zählen nur, wenn der Kurs auf 'completed' steht.
  // Übertrag/Korrektur haben keine ref_assignment_id und werden immer aufgenommen.
  const { data, error } = await supabase
    .from('account_movements')
    .select(`
      id, date, amount_chf, kind, description, breakdown_json, ref_assignment_id,
      course_assignments:ref_assignment_id (
        courses ( status )
      )
    `)
    .eq('instructor_id', instructorId)
    .order('date', { ascending: false })
  if (error) throw error

  const visible = (data ?? []).filter((m: any) => {
    if (!m.ref_assignment_id) return true
    const status = m.course_assignments?.courses?.status
    return status === 'completed'
  })

  return visible as unknown as MyMovement[]
}

export interface MySkill {
  code: string
  label: string
  category: string | null
}

export async function fetchMySkills(instructorId: string): Promise<MySkill[]> {
  const { data, error } = await supabase
    .from('instructor_skills')
    .select('skills(code, label, category)')
    .eq('instructor_id', instructorId)
  if (error) throw error
  return (data ?? []).map((d: any) => d.skills).filter(Boolean) as MySkill[]
}

export interface AvailabilityRow {
  id: string
  instructor_id: string
  from_date: string
  to_date: string
  kind: 'urlaub' | 'abwesend' | 'verfügbar'
  note: string | null
}

export async function fetchAvailability(instructorId: string): Promise<AvailabilityRow[]> {
  const { data, error } = await supabase
    .from('availability')
    .select('id, instructor_id, from_date, to_date, kind, note')
    .eq('instructor_id', instructorId)
    .order('from_date', { ascending: false })
  if (error) throw error
  return (data ?? []) as AvailabilityRow[]
}

// ============================================================
// Students — Wrapper auf contactQueries.listStudents
// ============================================================
//
// Phase J Etappe 3a: fetchStudents liest seit 0091 nicht mehr direkt aus
// people, sondern delegiert an listStudents (contacts + contact_student).
// Student-Shape ist Backward-Compatible, ohne padi_nr/organization_id
// (existieren im neuen Modell nicht mehr auf Student-Ebene).

import { listStudents, type StudentRow } from '@/lib/contactQueries'

export type Student = StudentRow

export async function fetchStudents(): Promise<Student[]> {
  return listStudents()
}

export interface StudentCertification {
  id: string
  student_id: string
  certification: string
  issued_date: string | null
  issued_by: string | null
  certificate_nr: string | null
  notes: string | null
  created_at: string
}

export async function fetchStudentCertifications(studentId: string): Promise<StudentCertification[]> {
  const { data, error } = await supabase
    .from('student_certifications')
    .select('id, student_id, certification, issued_date, issued_by, certificate_nr, notes, created_at')
    .eq('student_id', studentId)
    .order('issued_date', { ascending: false, nullsFirst: false })
  if (error) throw error
  return (data ?? []) as StudentCertification[]
}

// ──────────────────────────────────────────────────────────────────────────
// Cert-first model — `certifications` table (Foundation Tag 1).
// ──────────────────────────────────────────────────────────────────────────

import type { Certification } from '@/types/foundation'

/**
 * Cert-first read API. Fetch all certifications for a person
 * (works for both `people.id` and `instructors.id` — see migration 0076).
 *
 * Returns the data shaped for the foundation `Certification` interface
 * (camelCase fields).
 */
export async function fetchCertifications(personId: string): Promise<Certification[]> {
  const { data, error } = await supabase
    .from('certifications')
    .select(
      'id, person_id, agency, category, code, number, issued_at, ' +
      'issued_by_person_id, issued_by_name, issued_by_pro_tier, origin, ' +
      'evidence, notes, invalidated_at, invalidated_reason, created_at'
    )
    .eq('person_id', personId)
    .order('issued_at', { ascending: false, nullsFirst: false })
  if (error) throw error
  return ((data ?? []) as unknown as CertificationRow[]).map(rowToCertification)
}

interface CertificationRow {
  id: string
  person_id: string
  agency: string
  category: string
  code: string
  number: string | null
  issued_at: string
  issued_by_person_id: string | null
  issued_by_name: string | null
  issued_by_pro_tier: string | null
  origin: string
  evidence: { url: string; filename: string }[] | null
  notes: string | null
  invalidated_at: string | null
  invalidated_reason: string | null
  created_at: string
}

function rowToCertification(r: CertificationRow): Certification {
  return {
    id: r.id,
    personId: r.person_id,
    agency: r.agency as Certification['agency'],
    category: r.category as Certification['category'],
    code: r.code as Certification['code'],
    number: r.number ?? '',
    issuedAt: r.issued_at,
    issuedBy: r.issued_by_person_id
      ? {
          personId: r.issued_by_person_id,
          name: r.issued_by_name ?? '',
          proTier: (r.issued_by_pro_tier ?? null) as Certification['issuedBy'] extends infer T
            ? T extends { proTier: infer P } ? P : never
            : never,
        }
      : undefined,
    origin: r.origin as Certification['origin'],
    evidence: r.evidence ?? undefined,
    notes: r.notes ?? undefined,
    invalidatedAt: r.invalidated_at ?? undefined,
    invalidatedReason: r.invalidated_reason ?? undefined,
    createdAt: r.created_at,
  }
}

export interface CourseParticipant {
  id: string
  course_id: string
  student_id: string
  status: 'enrolled' | 'certified' | 'dropped'
  enrolled_at: string
  certificate_nr: string | null
  notes: string | null
  certified_by_instructor_id: string | null
  certified_on: string | null
  student?: Student | null
  course?: {
    id: string
    title: string
    start_date: string
    status: string
    course_type: { code: string; label: string } | null
  } | null
}

export async function fetchCourseParticipants(courseId: string): Promise<CourseParticipant[]> {
  // Phase J Etappe 3c: people-Tabelle gedroppt in 0093, FK course_participants.student_id
  // zeigt seit 0092 auf contacts(id). Embed entsprechend auf contacts mit client-side
  // Mapping zurück auf das bestehende Student-Shape, damit Consumer (CourseDetailPanel,
  // PADI-Referral-PDF) unverändert weiterlaufen.
  const { data, error } = await supabase
    .from('course_participants')
    .select(`
      id, course_id, student_id, status, enrolled_at, certificate_nr, notes, certified_by_instructor_id, certified_on,
      contact:contacts(id, first_name, last_name, display_name, primary_email, phones, birth_date, notes, archived_at, created_at)
    `)
    .eq('course_id', courseId)
  if (error) throw error
  return (data ?? []).map((cp: any) => ({
    id: cp.id,
    course_id: cp.course_id,
    student_id: cp.student_id,
    status: cp.status,
    enrolled_at: cp.enrolled_at,
    certificate_nr: cp.certificate_nr,
    notes: cp.notes,
    certified_by_instructor_id: cp.certified_by_instructor_id,
    certified_on: cp.certified_on,
    student: cp.contact
      ? {
          id: cp.contact.id,
          name:
            cp.contact.display_name ||
            [cp.contact.first_name, cp.contact.last_name].filter(Boolean).join(' '),
          email: cp.contact.primary_email ?? null,
          phone: Array.isArray(cp.contact.phones)
            ? (cp.contact.phones.find((p: any) => p?.primary)?.e164 ??
               cp.contact.phones[0]?.e164 ??
               null)
            : null,
          birthday: cp.contact.birth_date,
          level: null,
          notes: cp.contact.notes,
          active: cp.contact.archived_at === null,
          created_at: cp.contact.created_at,
          is_student: false,
          is_candidate: false,
          pipeline_stage: null,
        }
      : null,
  })) as unknown as CourseParticipant[]
}

export async function fetchStudentCourses(studentId: string): Promise<CourseParticipant[]> {
  const { data, error } = await supabase
    .from('course_participants')
    .select(`
      id, course_id, student_id, status, enrolled_at, certificate_nr, notes, certified_by_instructor_id, certified_on,
      course:courses(id, title, start_date, status, course_type:course_types(code, label))
    `)
    .eq('student_id', studentId)
  if (error) throw error
  const sorted = (data ?? []).sort((a: any, b: any) =>
    (b.course?.start_date ?? '').localeCompare(a.course?.start_date ?? ''),
  )
  return sorted as unknown as CourseParticipant[]
}

// ──────────────────────── My Profile ────────────────────────

export interface MyProfile {
  name: string
  padi_level: string
  padi_nr: string | null
  email: string | null
  phone: string | null
}

interface PhoneEntry { label?: string; e164?: string; primary?: boolean }

/**
 * Reads contact + contact_instructor for the instructor view of MyProfile.
 * Extracts primary phone from the `phones[]` JSONB array.
 */
export async function fetchMyProfile(instructorId: string): Promise<MyProfile | null> {
  const { data, error } = await supabase
    .from('contacts')
    .select(
      'display_name, primary_email, phones, ' +
        'instructor:contact_instructor!inner(padi_level, padi_pro_number)',
    )
    .eq('id', instructorId)
    .single()
  if (error) throw error
  if (!data) return null
  const row = data as unknown as {
    display_name: string | null
    primary_email: string | null
    phones: PhoneEntry[] | null
    instructor: { padi_level: string | null; padi_pro_number: string | null } | null
  }
  const phonesArr = Array.isArray(row.phones) ? row.phones : []
  const primaryPhone = phonesArr.find((p) => p?.primary)?.e164 ?? phonesArr[0]?.e164 ?? null
  return {
    name: row.display_name ?? '—',
    padi_level: row.instructor?.padi_level ?? '',
    padi_nr: row.instructor?.padi_pro_number ?? null,
    email: row.primary_email,
    phone: primaryPhone,
  }
}

/** Reads only the `phones` JSONB column (used by ProfileEditSheet on open). */
export async function fetchInstructorPhones(instructorId: string): Promise<PhoneEntry[]> {
  const { data, error } = await supabase
    .from('contacts')
    .select('phones')
    .eq('id', instructorId)
    .single()
  if (error) throw error
  const phonesArr = (data as { phones?: PhoneEntry[] } | null)?.phones
  return Array.isArray(phonesArr) ? phonesArr : []
}

/** Replaces the `phones` JSONB array on a contact row. */
export async function updateInstructorPhones(
  instructorId: string,
  phones: PhoneEntry[],
): Promise<void> {
  const { error } = await supabase
    .from('contacts')
    .update({ phones })
    .eq('id', instructorId)
  if (error) throw error
}

// ──────────────────────── Course edit ────────────────────────

export interface CourseTypeOption {
  id: string
  code: string
  label: string
}

export interface CourseForEdit {
  type_id: string
  title: string
  status: 'tentative' | 'confirmed' | 'completed' | 'cancelled'
  start_date: string
  additional_dates: string[]
  num_participants: number
  info: string | null
  notes: string | null
}

export interface CourseDateForEdit {
  date: string
  type: CourseDateType
  pool_location: PoolLocation | null
  pool_reserved: boolean
  has_theory: boolean | null
  has_pool: boolean | null
  has_lake: boolean | null
  theory_from: string | null
  theory_to: string | null
  pool_from: string | null
  pool_to: string | null
  lake_from: string | null
  lake_to: string | null
}

export interface ScheduleConflict {
  conflicting_course_id: string
  conflicting_course_title: string
  conflicting_role: string
}

export interface CourseSaveInput {
  type_id: string
  title: string
  status: 'tentative' | 'confirmed' | 'completed' | 'cancelled'
  start_date: string
  additional_dates: string[]
  num_participants: number
  pool_booked: boolean
  info: string | null
  notes: string | null
}

export interface CourseDateInsert {
  date: string
  type: CourseDateType
  has_theory: boolean
  has_pool: boolean
  has_lake: boolean
  pool_location: PoolLocation | null
  pool_reserved: boolean
  theory_from: string | null
  theory_to: string | null
  pool_from: string | null
  pool_to: string | null
  lake_from: string | null
  lake_to: string | null
}

/** Active course types (id, code, label) — used by CourseEditSheet dropdown. */
export async function fetchCourseTypeOptions(): Promise<CourseTypeOption[]> {
  const { data, error } = await supabase
    .from('course_types')
    .select('id, code, label')
    .eq('active', true)
    .order('code')
  if (error) throw error
  return (data ?? []) as CourseTypeOption[]
}

/** Single course row for the edit form. */
export async function fetchCourseForEdit(courseId: string): Promise<CourseForEdit | null> {
  const { data, error } = await supabase
    .from('courses')
    .select('type_id, title, status, start_date, additional_dates, num_participants, info, notes')
    .eq('id', courseId)
    .single()
  if (error) throw error
  return (data as CourseForEdit | null) ?? null
}

/** Per-date breakdown including time-ranges, used by the edit form. */
export async function fetchCourseDatesForEdit(courseId: string): Promise<CourseDateForEdit[]> {
  const { data, error } = await supabase
    .from('course_dates')
    .select(
      'date, type, pool_location, pool_reserved, has_theory, has_pool, has_lake, ' +
        'theory_from, theory_to, pool_from, pool_to, lake_from, lake_to',
    )
    .eq('course_id', courseId)
    .order('date')
  if (error) throw error
  return (data ?? []) as unknown as CourseDateForEdit[]
}

/** Calls `conflict_check` RPC for a candidate instructor + date list. */
export async function checkScheduleConflicts(
  instructorId: string,
  dates: string[],
): Promise<ScheduleConflict[]> {
  const { data, error } = await supabase.rpc('conflict_check', {
    p_instructor_id: instructorId,
    p_dates: dates,
  })
  if (error) throw error
  return (data ?? []) as ScheduleConflict[]
}

/** Inserts a new course, returns its id. */
export async function insertCourse(input: CourseSaveInput): Promise<string> {
  const { data, error } = await supabase
    .from('courses')
    .insert(input)
    .select('id')
    .single()
  if (error) throw error
  return (data as { id: string }).id
}

/** Updates an existing course. */
export async function updateCourseRow(courseId: string, input: CourseSaveInput): Promise<void> {
  const { error } = await supabase.from('courses').update(input).eq('id', courseId)
  if (error) throw error
}

/**
 * Idempotent rebuild of `course_dates` for a course — deletes all existing
 * rows then re-inserts the given list. The form treats course-dates as
 * derived state from the in-memory editor.
 */
export async function replaceCourseDates(
  courseId: string,
  rows: CourseDateInsert[],
): Promise<void> {
  const { error: delErr } = await supabase.from('course_dates').delete().eq('course_id', courseId)
  if (delErr) throw delErr
  if (rows.length === 0) return
  const { error: insErr } = await supabase
    .from('course_dates')
    .insert(rows.map((r) => ({ ...r, course_id: courseId })))
  if (insErr) throw insErr
}

/** Inserts a single course_assignments row. */
export async function insertCourseAssignment(
  courseId: string,
  instructorId: string,
  role: string,
): Promise<void> {
  const { error } = await supabase
    .from('course_assignments')
    .insert({ course_id: courseId, instructor_id: instructorId, role })
  if (error) throw error
}

/**
 * Deletes a course and its associated payment movements. Order matters:
 * the `vergütung` movements reference assignments which would be cascaded
 * away by the course delete — without this cleanup the movements become
 * orphans pointing at a NULL ref_assignment_id.
 */
export async function deleteCourseWithCleanup(courseId: string): Promise<void> {
  // 1. Find assignments belonging to this course.
  const { data: assignments, error: aErr } = await supabase
    .from('course_assignments')
    .select('id')
    .eq('course_id', courseId)
  if (aErr) throw aErr
  const assignmentIds = (assignments ?? []).map((a) => a.id)

  // 2. Delete the corresponding `vergütung` movements first.
  if (assignmentIds.length > 0) {
    const { error: delMovErr } = await supabase
      .from('account_movements')
      .delete()
      .eq('kind', 'vergütung')
      .in('ref_assignment_id', assignmentIds)
    if (delMovErr) throw delMovErr
  }

  // 3. Delete the course — assignments, dates, participants cascade.
  const { error: delErr } = await supabase.from('courses').delete().eq('id', courseId)
  if (delErr) throw delErr
}

// ──────────────────────── Excel Import (edge function) ────────────────────────

export interface ImportPreview {
  sheets_found: string[]
  course_rows: number
  instructors_in_summary: number
  ambiguous_codes: string[]
  ambiguous_names: string[]
  raw: {
    courses: unknown[]
    instructors: { name: string }[]
    skill_matrix: unknown[]
  }
}

export interface ImportDryRunSummary {
  instructors_count: number
  courses_count: number
  assignments_count: number
  opening_balance_sum: number
  ignored_rows: { row: number; reason: string }[]
}

/**
 * Uploads an xlsx file to the `imports` storage bucket with a timestamp
 * prefix and returns the resulting storage path.
 */
export async function uploadImportFile(file: File): Promise<string> {
  const path = `${Date.now()}-${file.name}`
  const { error } = await supabase.storage.from('imports').upload(path, file)
  if (error) throw error
  return path
}

/** Invokes the `excel-import` edge function in preview mode. */
export async function importExcelPreview(storagePath: string): Promise<ImportPreview> {
  const { data, error } = await supabase.functions.invoke('excel-import', {
    body: { action: 'preview', storage_path: storagePath },
  })
  if (error) throw error
  return data as ImportPreview
}

/** Invokes the `excel-import` edge function in dry-run mode. */
export async function importExcelDryRun(
  storagePath: string,
  mappings: Record<string, string>,
): Promise<ImportDryRunSummary> {
  const { data, error } = await supabase.functions.invoke('excel-import', {
    body: { action: 'dryrun', storage_path: storagePath, mappings },
  })
  if (error) throw error
  return data as ImportDryRunSummary
}

/** Invokes the `excel-import` edge function in apply (write) mode. */
export async function importExcelApply(
  storagePath: string,
  mappings: Record<string, string>,
): Promise<unknown> {
  const { data, error } = await supabase.functions.invoke('excel-import', {
    body: { action: 'apply', storage_path: storagePath, mappings },
  })
  if (error) throw error
  return data
}

// ──────────────────────── Settings ────────────────────────

export interface CompRate {
  id: string
  level: string
  hourly_rate_chf: number
}

export interface SettingsCourseType {
  id: string
  code: string
  label: string
  theory_units: number
  pool_units: number
  lake_units: number
  active: boolean
}

export interface SettingsUser {
  id: string
  name: string
  email: string | null
  role: string
  auth_linked: boolean
}

export type CourseTypeUnitField = 'theory_units' | 'pool_units' | 'lake_units'
export type CompUnitField = 'theory_h' | 'pool_h' | 'lake_h'

/** Reads currently-valid compensation rates (valid_to IS NULL). */
export async function fetchCompRates(): Promise<CompRate[]> {
  const { data, error } = await supabase
    .from('comp_rates')
    .select('id, level, hourly_rate_chf')
    .is('valid_to', null)
    .order('level')
  if (error) throw error
  return (data ?? []) as CompRate[]
}

/** Reads active course types with their unit allocations. */
export async function fetchSettingsCourseTypes(): Promise<SettingsCourseType[]> {
  const { data, error } = await supabase
    .from('course_types')
    .select('id, code, label, theory_units, pool_units, lake_units, active')
    .eq('active', true)
    .order('code')
  if (error) throw error
  return (data ?? []) as SettingsCourseType[]
}

/**
 * Reads the User-Liste (Settings → Benutzer) via `contact_instructor` JOIN
 * `contacts`. Filters out archived contacts and sorts by last/first name.
 */
export async function fetchSettingsUsers(): Promise<SettingsUser[]> {
  const { data, error } = await supabase
    .from('contact_instructor')
    .select(
      'contact_id, app_role, auth_user_id, ' +
        'contact:contacts!inner(display_name, primary_email, last_name, first_name, archived_at)',
    )
  if (error) throw error
  const rows =
    ((data ?? []) as unknown as Array<{
      contact_id: string
      app_role: string
      auth_user_id: string | null
      contact: {
        display_name: string | null
        primary_email: string | null
        last_name: string | null
        first_name: string | null
        archived_at: string | null
      } | null
    }>)
      .filter((d) => d.contact?.archived_at == null)
      .sort((a, b) => {
        const al = (a.contact?.last_name ?? '').toLowerCase()
        const bl = (b.contact?.last_name ?? '').toLowerCase()
        if (al !== bl) return al.localeCompare(bl)
        const af = (a.contact?.first_name ?? '').toLowerCase()
        const bf = (b.contact?.first_name ?? '').toLowerCase()
        return af.localeCompare(bf)
      })
  return rows.map((d) => ({
    id: d.contact_id,
    name: d.contact?.display_name ?? '—',
    email: d.contact?.primary_email ?? null,
    role: d.app_role,
    auth_linked: !!d.auth_user_id,
  }))
}

/** Patches one `comp_rates.hourly_rate_chf`. */
export async function updateCompRate(rateId: string, newValue: number): Promise<void> {
  const { error } = await supabase
    .from('comp_rates')
    .update({ hourly_rate_chf: newValue })
    .eq('id', rateId)
  if (error) throw error
}

/** Patches one unit-allocation column on `course_types`. */
export async function updateCourseTypeUnits(
  id: string,
  field: CourseTypeUnitField,
  newValue: number,
): Promise<void> {
  const { error } = await supabase
    .from('course_types')
    .update({ [field]: newValue })
    .eq('id', id)
  if (error) throw error
}

/**
 * Patches the matching `comp_units.<theory|pool|lake>_h` row for a given
 * course-type. Settings keeps these two tables in sync; the field name
 * maps `*_units → *_h`.
 */
export async function updateCompUnitsForCourseType(
  courseTypeId: string,
  field: CompUnitField,
  newValue: number,
): Promise<void> {
  const { error } = await supabase
    .from('comp_units')
    .update({ [field]: newValue })
    .eq('course_type_id', courseTypeId)
  if (error) throw error
}

export interface RecalcResult {
  deleted_count: number
  inserted_count: number
}

/** Invokes the `recalc_all_compensations` RPC and returns the row counts. */
export async function recalcAllCompensations(): Promise<RecalcResult | null> {
  const { data, error } = await supabase.rpc('recalc_all_compensations')
  if (error) throw error
  return Array.isArray(data) && data[0] ? (data[0] as RecalcResult) : null
}

// ──────────────────────── Skills ────────────────────────

export interface SkillRow {
  id: string
  code: string
  label: string
  category: string | null
}

/** Read the skill catalog (`skills` table). */
export async function fetchSkills(): Promise<SkillRow[]> {
  const { data, error } = await supabase
    .from('skills')
    .select('id, code, label, category')
    .order('label')
  if (error) throw error
  return (data ?? []) as SkillRow[]
}

/**
 * Read the instructor-skills join. Returned as plain rows; the caller can
 * fold into a `Set<"instructorId|skillId">` for fast `has()` lookups.
 */
export async function fetchInstructorSkillsMatrix(): Promise<
  { instructor_id: string; skill_id: string }[]
> {
  const { data, error } = await supabase
    .from('instructor_skills')
    .select('instructor_id, skill_id')
  if (error) throw error
  return (data ?? []) as { instructor_id: string; skill_id: string }[]
}

/** Adds one row to `instructor_skills`. */
export async function addInstructorSkill(instructorId: string, skillId: string): Promise<void> {
  const { error } = await supabase
    .from('instructor_skills')
    .insert({ instructor_id: instructorId, skill_id: skillId })
  if (error) throw error
}

/** Removes one row from `instructor_skills`. */
export async function removeInstructorSkill(instructorId: string, skillId: string): Promise<void> {
  const { error } = await supabase
    .from('instructor_skills')
    .delete()
    .match({ instructor_id: instructorId, skill_id: skillId })
  if (error) throw error
}

// ──────────────────────── Pool ────────────────────────

export interface PoolDateRow {
  id: string
  course_id: string
  date: string
  pool_location: PoolLocation
  pool_reserved: boolean
  time_from: string | null
  time_to: string | null
  course: {
    id: string
    title: string
    course_type: { code: string } | null
  } | null
}

/**
 * Reads every `course_dates` row of type `pool` (with a non-null location)
 * within an ISO-date range — the input for the weekly pool grid.
 */
export async function fetchPoolDatesInRange(from: string, to: string): Promise<PoolDateRow[]> {
  const { data, error } = await supabase
    .from('course_dates')
    .select(`
      id, course_id, date, pool_location, pool_reserved, time_from, time_to,
      course:courses(id, title, course_type:course_types(code))
    `)
    .eq('type', 'pool')
    .not('pool_location', 'is', null)
    .gte('date', from)
    .lte('date', to)
    .order('date')
  if (error) throw error
  return (data ?? []) as unknown as PoolDateRow[]
}

// ──────────────────────── PR (Performance Records) ────────────────────────

export interface PrCatalogRow {
  course_type: string
  language: string
  version: string
  data: unknown
}

export interface PrRecordRow {
  id: string
  student_id: string
  pr_code: string
  status: string
  score: number | null
  pass: boolean | null
  assessed_on: string | null
  assessed_by_text: string | null
  notes: string | null
  with_assistant: boolean | null
}

/**
 * Loads the active German PR catalog for a course-type kind (DM/IDC/EFRI/SPEI).
 */
export async function fetchPrCatalog(catalogKind: string): Promise<PrCatalogRow | null> {
  const { data, error } = await supabase
    .from('pr_catalogs')
    .select('course_type, language, version, data')
    .eq('course_type', catalogKind)
    .eq('language', 'de')
    .eq('active', true)
    .maybeSingle()
  if (error) throw error
  return (data as unknown as PrCatalogRow | null) ?? null
}

/**
 * Loads every performance record attached to a specific course.
 */
export async function fetchCoursePrRecords(courseId: string): Promise<PrRecordRow[]> {
  const { data, error } = await supabase
    .from('performance_records')
    .select('id, student_id, pr_code, status, score, pass, assessed_on, assessed_by_text, notes, with_assistant')
    .eq('course_id', courseId)
  if (error) throw error
  return (data ?? []) as PrRecordRow[]
}

// ──────────────────────── Cockpit ────────────────────────

export interface CockpitKpis {
  payments_chf: number
  payments_count: number
  courses_in_period: number
  active_instructors_in_period: number
  total_active_instructors: number
  active_students: number
}

export interface CockpitMonthlyPayment {
  month: string
  total: number
}

export interface CockpitTopInstructor {
  id: string
  name: string
  padi_level: string
  color: string | null
  initials: string | null
  total_chf: number
  course_count: number
}

export interface CockpitPipeline {
  today: number
  this_week: number
  next_30_days: number
}

export interface CockpitAttention {
  courses_without_haupt: number
  long_tentative: number
  idle_instructors_6w: number
}

export interface CockpitData {
  kpis: CockpitKpis
  monthly_payments: CockpitMonthlyPayment[]
  top_instructors: CockpitTopInstructor[]
  pipeline: CockpitPipeline
  attention: CockpitAttention
}

/**
 * Single-RPC dashboard payload. The server-side `cockpit_data` function
 * computes everything (KPIs, monthly chart, top instructors, pipeline,
 * attention list) inside one query plan, so the client gets one round-trip
 * regardless of how many cards the dashboard renders.
 */
export async function fetchCockpitData(start: string, end: string): Promise<CockpitData> {
  const { data, error } = await supabase.rpc('cockpit_data', { p_start: start, p_end: end })
  if (error) throw error
  return data as CockpitData
}

export interface SaldoDiffRow {
  instructor_id: string
  name: string
  app_balance: number
  excel_saldo: number
  diff: number
}

/**
 * Reads the `v_saldo_diff` view, coercing numeric strings (Supabase returns
 * postgres `numeric` columns as strings) into JS numbers for the UI.
 */
export async function fetchSaldoDiffs(): Promise<SaldoDiffRow[]> {
  const { data, error } = await supabase.from('v_saldo_diff').select('*')
  if (error) throw error
  return ((data ?? []) as Array<{
    instructor_id: string
    name: string
    app_balance: number | string | null
    excel_saldo: number | string | null
    diff: number | string | null
  }>).map((d) => ({
    instructor_id: d.instructor_id,
    name: d.name,
    app_balance: Number(d.app_balance ?? 0),
    excel_saldo: Number(d.excel_saldo ?? 0),
    diff: Number(d.diff ?? 0),
  }))
}

export async function fetchKpis(): Promise<Kpis> {
  const today = new Date().toISOString().slice(0, 10)
  const [totalRes, confirmedRes, instructorRes] = await Promise.all([
    supabase.from('courses').select('*', { count: 'exact', head: true }),
    supabase.from('courses').select('*', { count: 'exact', head: true }).eq('status', 'confirmed'),
    supabase.from('contact_instructor').select('contact_id', { count: 'exact', head: true }).eq('active', true),
  ])
  const { data: futureCourses } = await supabase
    .from('courses')
    .select('id')
    .gte('start_date', today)
  const ids = (futureCourses ?? []).map((c: any) => c.id)
  let assignmentsThisWeek = 0
  if (ids.length > 0) {
    const { count } = await supabase
      .from('course_assignments')
      .select('*', { count: 'exact', head: true })
      .in('course_id', ids)
    assignmentsThisWeek = count ?? 0
  }
  return {
    totalCourses: totalRes.count ?? 0,
    confirmedCourses: confirmedRes.count ?? 0,
    instructorCount: instructorRes.count ?? 0,
    assignmentsThisWeek,
  }
}
