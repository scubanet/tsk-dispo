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
  time_from: string | null
  time_to: string | null
  note: string | null
}

export async function fetchCourseDates(courseId: string): Promise<CourseDate[]> {
  const { data, error } = await supabase
    .from('course_dates')
    .select('id, course_id, date, type, pool_location, time_from, time_to, note')
    .eq('course_id', courseId)
    .order('date')
  if (error) throw error
  return (data ?? []) as CourseDate[]
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

export async function fetchMyAvailability(instructorId: string): Promise<AvailabilityRow[]> {
  const { data, error } = await supabase
    .from('availability')
    .select('id, instructor_id, from_date, to_date, kind, note')
    .eq('instructor_id', instructorId)
    .order('from_date', { ascending: false })
  if (error) throw error
  return (data ?? []) as AvailabilityRow[]
}

// ============================================================
// Students
// ============================================================

export interface Student {
  id: string
  name: string
  email: string | null
  phone: string | null
  birthday: string | null
  padi_nr: string | null
  level: string
  notes: string | null
  active: boolean
  created_at: string
}

export async function fetchStudents(): Promise<Student[]> {
  const { data, error } = await supabase
    .from('students')
    .select('id, name, email, phone, birthday, padi_nr, level, notes, active, created_at')
    .order('last_name')
    .order('first_name')
  if (error) throw error
  return (data ?? []) as Student[]
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

export interface CourseParticipant {
  id: string
  course_id: string
  student_id: string
  status: 'enrolled' | 'certified' | 'dropped'
  enrolled_at: string
  certificate_nr: string | null
  notes: string | null
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
  const { data, error } = await supabase
    .from('course_participants')
    .select(`
      id, course_id, student_id, status, enrolled_at, certificate_nr, notes,
      student:students(id, name, email, phone, birthday, padi_nr, notes, active, created_at)
    `)
    .eq('course_id', courseId)
  if (error) throw error
  return (data ?? []) as unknown as CourseParticipant[]
}

export async function fetchStudentCourses(studentId: string): Promise<CourseParticipant[]> {
  const { data, error } = await supabase
    .from('course_participants')
    .select(`
      id, course_id, student_id, status, enrolled_at, certificate_nr, notes,
      course:courses(id, title, start_date, status, course_type:course_types(code, label))
    `)
    .eq('student_id', studentId)
  if (error) throw error
  const sorted = (data ?? []).sort((a: any, b: any) =>
    (b.course?.start_date ?? '').localeCompare(a.course?.start_date ?? ''),
  )
  return sorted as unknown as CourseParticipant[]
}

export async function fetchKpis(): Promise<Kpis> {
  const today = new Date().toISOString().slice(0, 10)
  const [totalRes, confirmedRes, instructorRes] = await Promise.all([
    supabase.from('courses').select('*', { count: 'exact', head: true }),
    supabase.from('courses').select('*', { count: 'exact', head: true }).eq('status', 'confirmed'),
    supabase.from('instructors').select('*', { count: 'exact', head: true }).eq('active', true),
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
