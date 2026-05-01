// deno-lint-ignore-file no-explicit-any
import type { ParseResult } from './parser.ts'

export interface CoursePayload {
  excel_row: number
  code: string
  title: string
  status: 'confirmed' | 'tentative' | 'cancelled'
  start_date: string
  num_participants: number
  info: string
  notes: string
}

export interface AssignmentPayload {
  excel_row: number
  course_index: number
  instructor_name: string
  role: 'haupt' | 'assist' | 'dmt'
}

export interface MovementPayload {
  instructor_name: string
  date: string
  amount_chf: number
  kind: 'übertrag'
  description: string
}

export interface InstructorPayload {
  name: string
  padi_level: string
  opening_balance_chf: number
  excel_saldo_chf: number
  initials: string
}

export interface Plan {
  instructors: InstructorPayload[]
  courses: CoursePayload[]
  assignments: AssignmentPayload[]
  movements: MovementPayload[]
  ignored: { row: number; reason: string }[]
  summary: {
    instructors_count: number
    courses_count: number
    assignments_count: number
    opening_balance_sum: number
    ignored_rows: { row: number; reason: string }[]
  }
}

const VALID_PADI: Record<string, string> = {
  instructor: 'Instructor',
  'staff instructor': 'Staff Instructor',
  dm: 'DM',
  'shop staff': 'Shop Staff',
  'andere funktion': 'Andere Funktion',
}

function normalizePadi(raw: string): string {
  const k = raw.trim().toLowerCase()
  return VALID_PADI[k] ?? 'Andere Funktion'
}

function makeInitials(name: string): string {
  return name
    .split(/\s+/)
    .map((p) => p[0])
    .filter(Boolean)
    .slice(0, 2)
    .join('')
    .toUpperCase()
}

function toIsoDate(input: any): string | null {
  if (!input) return null
  if (input instanceof Date) return input.toISOString().slice(0, 10)
  if (typeof input === 'string') {
    // Try parse, fallback null
    const d = new Date(input)
    if (!isNaN(d.valueOf())) return d.toISOString().slice(0, 10)
  }
  return null
}

export function applyMappingsAndPlan(
  parsed: ParseResult,
  mappings: Record<string, string>,
): Plan {
  const codeMap: Record<string, string> = {}
  const nameMap: Record<string, string> = {}
  for (const [k, v] of Object.entries(mappings)) {
    if (k.startsWith('code:')) codeMap[k.slice(5)] = v
    if (k.startsWith('name:')) nameMap[k.slice(5)] = v
  }

  const instructors: InstructorPayload[] = parsed.raw.instructors.map((row) => ({
    name: row.name,
    padi_level: normalizePadi(row.padi_level),
    opening_balance_chf: row.opening_balance,
    excel_saldo_chf: row.excel_saldo,
    initials: makeInitials(row.name),
  }))

  const movements: MovementPayload[] = instructors
    .filter((i) => i.opening_balance_chf !== 0)
    .map((i) => ({
      instructor_name: i.name,
      date: '2026-01-01',
      amount_chf: i.opening_balance_chf,
      kind: 'übertrag',
      description: 'Eröffnungs-Saldo aus Excel-Import',
    }))

  const courses: CoursePayload[] = []
  const assignments: AssignmentPayload[] = []
  const ignored: { row: number; reason: string }[] = []

  for (const row of parsed.raw.courses) {
    const status_lower = row.status.trim().toLowerCase()
    if (status_lower.includes('cxl')) continue

    const isoDate = toIsoDate(row.start_date)
    if (!isoDate) {
      ignored.push({ row: row.excel_row, reason: 'kein gültiges Datum' })
      continue
    }

    const code = codeMap[row.code] ?? row.code.trim().toUpperCase()
    if (!code) {
      ignored.push({ row: row.excel_row, reason: 'kein Kurstyp' })
      continue
    }

    const haupt_resolved = nameMap[row.haupt_instr] ?? row.haupt_instr
    if (!haupt_resolved || haupt_resolved === '__skip__') {
      ignored.push({ row: row.excel_row, reason: 'kein Haupt-Instructor' })
      continue
    }

    const status: 'confirmed' | 'tentative' = status_lower.includes('evtl')
      ? 'tentative'
      : 'confirmed'

    courses.push({
      excel_row: row.excel_row,
      code,
      title: row.title || row.code,
      status,
      start_date: isoDate,
      num_participants: row.num_participants,
      info: row.info,
      notes: row.notes,
    })

    assignments.push({
      excel_row: row.excel_row,
      course_index: courses.length - 1,
      instructor_name: haupt_resolved,
      role: 'haupt',
    })

    if (row.assistenten) {
      for (const part of row.assistenten.split(/[/,]/)) {
        const trimmed = part.trim()
        if (!trimmed) continue
        const resolved = nameMap[trimmed] ?? trimmed
        if (resolved === '__skip__') continue
        assignments.push({
          excel_row: row.excel_row,
          course_index: courses.length - 1,
          instructor_name: resolved,
          role: 'assist',
        })
      }
    }
  }

  return {
    instructors,
    courses,
    assignments,
    movements,
    ignored,
    summary: {
      instructors_count: instructors.length,
      courses_count: courses.length,
      assignments_count: assignments.length,
      opening_balance_sum: instructors.reduce((s, i) => s + i.opening_balance_chf, 0),
      ignored_rows: ignored,
    },
  }
}

export interface WriteResult {
  success: boolean
  instructors_inserted: number
  courses_inserted: number
  assignments_inserted: number
}

export async function writePlanToDatabase(
  supabase: any,
  plan: Plan,
  triggered_by_user_id: string,
  storage_path: string,
): Promise<WriteResult> {
  const { data: dispatcher } = await supabase
    .from('instructors')
    .select('id')
    .eq('auth_user_id', triggered_by_user_id)
    .maybeSingle()

  // Insert/upsert instructors
  let instructors_inserted = 0
  for (const inst of plan.instructors) {
    const { error } = await supabase
      .from('instructors')
      .upsert(inst, { onConflict: 'name' })
    if (!error) instructors_inserted++
  }

  // Insert opening-balance movements
  for (const mv of plan.movements) {
    const { data: target } = await supabase
      .from('instructors')
      .select('id')
      .eq('name', mv.instructor_name)
      .maybeSingle()
    if (target) {
      await supabase.from('account_movements').insert({
        instructor_id: target.id,
        date: mv.date,
        amount_chf: mv.amount_chf,
        kind: mv.kind,
        description: mv.description,
      })
    }
  }

  // Insert courses (resolve type_id by code)
  const courseIds: Record<number, string> = {}
  let courses_inserted = 0
  for (let i = 0; i < plan.courses.length; i++) {
    const c = plan.courses[i]
    const { data: type } = await supabase
      .from('course_types')
      .select('id')
      .eq('code', c.code)
      .maybeSingle()
    if (!type) continue
    const { data: inserted, error } = await supabase
      .from('courses')
      .insert({
        type_id: type.id,
        title: c.title,
        status: c.status,
        start_date: c.start_date,
        num_participants: c.num_participants,
        info: c.info,
        notes: c.notes,
      })
      .select('id')
      .single()
    if (!error && inserted) {
      courseIds[i] = inserted.id
      courses_inserted++
    }
  }

  // Insert assignments — triggers fire automatically and write account_movements
  let assignments_inserted = 0
  for (const a of plan.assignments) {
    const courseId = courseIds[a.course_index]
    if (!courseId) continue
    const { data: inst } = await supabase
      .from('instructors')
      .select('id')
      .eq('name', a.instructor_name)
      .maybeSingle()
    if (!inst) continue
    const { error } = await supabase.from('course_assignments').insert({
      course_id: courseId,
      instructor_id: inst.id,
      role: a.role,
      confirmed: false,
    })
    if (!error) assignments_inserted++
  }

  // Audit log
  await supabase.from('import_logs').insert({
    source_filename: storage_path.split('/').pop() ?? storage_path,
    storage_path,
    status: 'success',
    finished_at: new Date().toISOString(),
    triggered_by: dispatcher?.id ?? null,
    summary_json: {
      ...plan.summary,
      written: { instructors_inserted, courses_inserted, assignments_inserted },
    },
  })

  return { success: true, instructors_inserted, courses_inserted, assignments_inserted }
}
