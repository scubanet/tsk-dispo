// deno-lint-ignore-file no-explicit-any
import ExcelJS from 'exceljs'

export interface ParsedCourse {
  excel_row: number
  code: string
  title: string
  status: string
  start_date: any
  haupt_instr: string
  assistenten: string
  num_participants: number
  info: string
  notes: string
}

export interface ParsedInstructor {
  excel_row: number
  name: string
  padi_level: string
  opening_balance: number
  excel_saldo: number
}

/**
 * Robustly extract a number from an ExcelJS cell value.
 * Handles plain numbers, strings, formula results ({formula, result}),
 * and empty/null cells.
 */
function cellNumber(cell: any): number {
  const v = cell?.value
  if (v === null || v === undefined) return 0
  if (typeof v === 'number') return v
  if (typeof v === 'string') {
    const cleaned = v.replace(/['',]/g, '').trim()
    const n = parseFloat(cleaned)
    return isNaN(n) ? 0 : n
  }
  if (typeof v === 'object') {
    if ('result' in v && v.result !== null && v.result !== undefined) {
      return Number(v.result) || 0
    }
    if ('text' in v) {
      const n = parseFloat(String((v as any).text))
      return isNaN(n) ? 0 : n
    }
  }
  return 0
}

export interface ParsedSkillRow {
  name: string
  skills_held: string[]
}

export interface ParseResult {
  sheets_found: string[]
  course_rows: number
  instructors_in_summary: number
  ambiguous_codes: string[]
  ambiguous_names: string[]
  raw: {
    courses: ParsedCourse[]
    instructors: ParsedInstructor[]
    skill_matrix: ParsedSkillRow[]
  }
}

export async function parseWorkbook(buffer: Uint8Array): Promise<ParseResult> {
  const wb = new ExcelJS.Workbook()
  await wb.xlsx.load(buffer)

  const sheets_found = wb.worksheets.map((s) => s.name)

  // Sheet "1 Kursplanung"
  const planning = wb.getWorksheet('1 Kursplanung')
  const courses: ParsedCourse[] = []
  const ambiguous_codes = new Set<string>()
  if (planning) {
    for (let r = 3; r <= planning.rowCount; r++) {
      const row = planning.getRow(r)
      const code = String(row.getCell(1).value ?? '').trim()
      const status = String(row.getCell(3).value ?? '').trim()
      if (!code || !status) continue
      const startDate = row.getCell(4).value
      courses.push({
        excel_row: r,
        code,
        title: String(row.getCell(2).value ?? '').trim(),
        status,
        start_date: startDate,
        haupt_instr: String(row.getCell(9).value ?? '').trim(),
        assistenten: String(row.getCell(10).value ?? '').trim(),
        num_participants: Number(row.getCell(11).value) || 0,
        info: String(row.getCell(8).value ?? '').trim(),
        notes: String(row.getCell(13).value ?? '').trim(),
      })
      if (!/^[A-Z]+\s*$/.test(code.toUpperCase())) {
        ambiguous_codes.add(code)
      }
    }
  }

  // Sheet "8 Zusammenfassung"
  const summary = wb.getWorksheet('8 Zusammenfassung')
  const instructors: ParsedInstructor[] = []
  if (summary) {
    for (let r = 2; r <= summary.rowCount; r++) {
      const row = summary.getRow(r)
      const name = String(row.getCell(1).value ?? '').trim()
      if (!name || name === 'TL/DM') continue
      instructors.push({
        excel_row: r,
        name,
        padi_level: String(row.getCell(2).value ?? '').trim(),
        // Col C (3): "Eröffnung CHF" — true carry-over from prior year.
        // We seed account_movements with this so the trigger can compute
        // 2026 movements on top.
        opening_balance: cellNumber(row.getCell(3)),
        // Col G (7): "Saldo CHF" — current Excel saldo (incl. all 2026
        // movements as Excel sees them). Used for diff reporting only.
        excel_saldo: cellNumber(row.getCell(7)),
      })
    }
  }

  // Sheet "4 SkillMatrix"
  const matrix = wb.getWorksheet('4 SkillMatrix')
  const skill_matrix: ParsedSkillRow[] = []
  if (matrix) {
    const headerRow = matrix.getRow(1)
    const headers: string[] = []
    headerRow.eachCell({ includeEmpty: true }, (cell) => {
      headers.push(String(cell.value ?? '').trim())
    })

    for (let r = 2; r <= matrix.rowCount; r++) {
      const row = matrix.getRow(r)
      const name = String(row.getCell(1).value ?? '').trim()
      if (!name) continue
      const skills_held: string[] = []
      for (let c = 3; c < headers.length; c++) {
        const v = String(row.getCell(c).value ?? '').trim().toLowerCase()
        if (v === 'x') {
          skills_held.push(headers[c - 1] ?? `col${c}`)
        }
      }
      skill_matrix.push({ name, skills_held })
    }
  }

  // Ambiguous instructor names: those in courses' haupt_instr that aren't exact matches in instructors[]
  const known_names = new Set(instructors.map((i) => i.name))
  const ambiguous_names = new Set<string>()
  for (const c of courses) {
    if (c.haupt_instr && !known_names.has(c.haupt_instr)) {
      ambiguous_names.add(c.haupt_instr)
    }
  }

  return {
    sheets_found,
    course_rows: courses.length,
    instructors_in_summary: instructors.length,
    ambiguous_codes: [...ambiguous_codes],
    ambiguous_names: [...ambiguous_names],
    raw: { courses, instructors, skill_matrix },
  }
}
