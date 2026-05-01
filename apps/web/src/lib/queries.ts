import { supabase } from './supabase'

export interface CourseRow {
  id: string
  title: string
  start_date: string
  status: 'confirmed' | 'tentative' | 'cancelled'
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
  role: 'haupt' | 'assist' | 'dmt'
  confirmed: boolean
  course?: CourseRow | null
  instructor: { id: string; name: string; initials: string; color: string; padi_level?: string } | null
}

export async function fetchCoursesInRange(from: string, to: string): Promise<CourseRow[]> {
  const { data, error } = await supabase
    .from('courses')
    .select(`
      id, title, start_date, status, num_participants,
      course_type:course_types(code, label)
    `)
    .gte('start_date', from)
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

export async function fetchCourseAssignments(courseId: string): Promise<AssignmentRow[]> {
  const { data, error } = await supabase
    .from('course_assignments')
    .select(`
      id, course_id, instructor_id, role, confirmed, assigned_for_dates,
      instructor:instructors(id, name, initials, color, padi_level)
    `)
    .eq('course_id', courseId)
  if (error) throw error
  return (data ?? []) as unknown as AssignmentRow[]
}

export interface Kpis {
  totalCourses: number
  confirmedCourses: number
  instructorCount: number
  assignmentsThisWeek: number
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
