import { PDFDocument } from 'pdf-lib'
import { FIELD_MAP, type PadiReferralData } from './padiReferralFieldMap'
import { supabase } from './supabase'

/**
 * Split a phone in E.164 (e.g. "+41798778080") into:
 *   - country code WITHOUT leading + (e.g. "41")
 *   - rest of the number (e.g. "798778080")
 *
 * If the input isn't E.164, falls back to {prefix: '', number: input}.
 */
export function splitE164Phone(e164: string | null | undefined): { prefix: string; number: string } {
  if (!e164) return { prefix: '', number: '' }
  const trimmed = e164.trim()
  // Match + followed by 1-3 country digits, then the rest
  const m = trimmed.match(/^\+(\d{1,3})\s*(.+)$/)
  if (m) return { prefix: m[1], number: m[2].replace(/\s+/g, ' ').trim() }
  return { prefix: '', number: trimmed }
}

/**
 * Look up the Haupt-TL for a given course and return instructor block data
 * suitable for filling the PADI referral PDF.
 */
export async function fetchInstructorBlockForCourse(courseId: string): Promise<{
  name: string
  padiPro: string | null
  email: string | null
  phonePrefix: string
  phoneNumber: string
} | null> {
  const { data } = await supabase
    .from('course_assignments')
    .select(`
      role,
      instructor:instructors(id, name, email, phone)
    `)
    .eq('course_id', courseId)
    .eq('role', 'haupt')
    .limit(1)
    .maybeSingle()

  if (!data?.instructor) return null
  // Supabase typed join may return array for 1-to-many; we use maybeSingle so take first element if array
  const raw = data.instructor
  const inst = (Array.isArray(raw) ? raw[0] : raw) as unknown as { id: string; name: string; email: string | null; phone: string | null }
  if (!inst) return null

  // Get padi_pro_number from contact_instructor sidecar
  const { data: ci } = await supabase
    .from('contact_instructor')
    .select('padi_pro_number')
    .eq('contact_id', inst.id)
    .maybeSingle()

  const phoneSplit = splitE164Phone(inst.phone)

  return {
    name: inst.name,
    padiPro: (ci as { padi_pro_number?: string | null } | null)?.padi_pro_number ?? null,
    email: inst.email,
    phonePrefix: phoneSplit.prefix,
    phoneNumber: phoneSplit.number,
  }
}

export async function generatePadiReferralPdf(data: PadiReferralData): Promise<Uint8Array> {
  const templateBytes = await fetch('/forms/padi-owd-referral.pdf').then((r) => r.arrayBuffer())
  const pdf = await PDFDocument.load(templateBytes)
  const form = pdf.getForm()

  // Fill all mapped text fields.
  // Year (Jahr) columns are narrow — default font cuts off the 4th digit. We
  // shrink font size for any dataKey ending in "Jahr" so 4 digits fit.
  for (const [dataKey, pdfFieldName] of Object.entries(FIELD_MAP)) {
    const value = (data as unknown as Record<string, unknown>)[dataKey]
    if (value == null || value === '') continue
    try {
      const field = form.getTextField(pdfFieldName)
      field.setText(String(value))
      if (dataKey.endsWith('Jahr')) {
        field.setFontSize(7)
      }
    } catch {
      console.warn(`PADI referral: text field "${pdfFieldName}" not found or wrong type`)
    }
  }

  // Gender checkboxes (M / W are CheckBox widgets in this PDF)
  if (data.studentGender === 'M') {
    try { form.getCheckBox('M').check() } catch {
      // Fall back: try as radio button
    }
  } else if (data.studentGender === 'W') {
    try { form.getCheckBox('W').check() } catch {
      // Fall back: try as radio button
    }
  }

  return pdf.save()
}

/**
 * Fetch course-day data and build auto-fill fields for the PADI referral PDF.
 * Fills CW 1–5 (pool days), Knowledge Development Teil 1–5 (theory/pool days),
 * and OW Tauchgänge 1–4 (see days).
 */
export async function buildCourseAutofillData(courseId: string): Promise<Partial<PadiReferralData>> {
  // Fetch course dates with kind array
  const { data: cd } = await supabase
    .from('course_dates')
    .select('date, kind')
    .eq('course_id', courseId)

  // Fetch haupt assignments with instructor initials
  const { data: ca } = await supabase
    .from('course_assignments')
    .select('instructor_id, role, assigned_for_dates, instructor:instructors(id, initials)')
    .eq('course_id', courseId)
    .eq('role', 'haupt')

  // Fetch PADI pro numbers for involved instructors
  const instructorIds = (ca ?? []).map((a) => (a as any).instructor_id as string)
  const { data: cis } = instructorIds.length === 0
    ? { data: [] as Array<{ contact_id: string; padi_pro_number: string | null }> }
    : await supabase
        .from('contact_instructor')
        .select('contact_id, padi_pro_number')
        .in('contact_id', instructorIds)

  /** Return initials + PADI Nr for the haupt instructor covering a given date. */
  function infoForDate(date: string): { initials: string; padi: string } {
    const assignments = (ca ?? []) as unknown as Array<{
      instructor_id: string
      role: string
      assigned_for_dates: string[] | null
      instructor: { id: string; initials: string | null } | { id: string; initials: string | null }[] | null
    }>
    const specific = assignments.find(
      (a) => Array.isArray(a.assigned_for_dates) && a.assigned_for_dates.includes(date),
    )
    const fallback = assignments.find(
      (a) => !a.assigned_for_dates || a.assigned_for_dates.length === 0,
    )
    const a = specific ?? fallback
    if (!a) return { initials: '', padi: '' }
    const rawInst = a.instructor
    const inst = Array.isArray(rawInst) ? rawInst[0] : rawInst
    const initials = inst?.initials ?? ''
    const padi =
      (cis ?? []).find((c) => c.contact_id === a.instructor_id)?.padi_pro_number ?? ''
    return { initials: initials ?? '', padi: padi ?? '' }
  }

  /** Split ISO date string (YYYY-MM-DD) into tag/monat/jahr. */
  function splitDate(iso: string): { tag: string; monat: string; jahr: string } {
    const [yyyy, mm, dd] = iso.split('-')
    return { tag: dd ?? '', monat: mm ?? '', jahr: yyyy ?? '' }
  }

  const courseDates = (cd ?? []) as Array<{ date: string; kind: string[] | null }>
  const poolDays   = courseDates.filter((d) => (d.kind ?? []).includes('pool')).map((d) => d.date).sort()
  const seeDays    = courseDates.filter((d) => (d.kind ?? []).includes('see')).map((d) => d.date).sort()
  const theoryDays = courseDates.filter((d) => (d.kind ?? []).includes('theorie')).map((d) => d.date).sort()

  const result: Partial<PadiReferralData> = {}

  // CW 1–5: one entry per pool day (up to 5)
  for (let i = 0; i < Math.min(poolDays.length, 5); i++) {
    const date = poolDays[i]
    const { tag, monat, jahr } = splitDate(date)
    const { initials, padi } = infoForDate(date)
    const n = (i + 1) as 1 | 2 | 3 | 4 | 5
    result[`cw${n}Tag`]      = tag
    result[`cw${n}Monat`]    = monat
    result[`cw${n}Jahr`]     = jahr
    result[`cw${n}Initialen`] = initials
    result[`cw${n}PadiNr`]   = padi
  }

  // Knowledge Development Teil 1–5: spread theory days; fall back to pool days if no theory
  // Only fill if we have at least one source day (graceful degrade)
  const kdSource = theoryDays.length > 0 ? theoryDays : poolDays
  for (let i = 0; i < 5; i++) {
    const date = kdSource[i] ?? kdSource[0]
    if (!date) break
    const { tag, monat, jahr } = splitDate(date)
    const { initials, padi } = infoForDate(date)
    const n = (i + 1) as 1 | 2 | 3 | 4 | 5
    result[`kd${n}Tag`]      = tag
    result[`kd${n}Monat`]    = monat
    result[`kd${n}Jahr`]     = jahr
    result[`kd${n}Initialen`] = initials
    result[`kd${n}PadiNr`]   = padi
  }

  // OW Tauchgänge 1–4: one entry per see day (up to 4)
  for (let i = 0; i < Math.min(seeDays.length, 4); i++) {
    const date = seeDays[i]
    const { tag, monat, jahr } = splitDate(date)
    const { initials, padi } = infoForDate(date)
    const n = (i + 1) as 1 | 2 | 3 | 4
    result[`ow${n}Tag`]      = tag
    result[`ow${n}Monat`]    = monat
    result[`ow${n}Jahr`]     = jahr
    if (n !== 2) {
      // ow2Initialen is unmapped (PDF field is a long label name, not reliably fillable)
      result[`ow${n}Initialen`] = initials
    }
    result[`ow${n}PadiNr`]   = padi
  }

  return result
}

export function downloadPdf(bytes: Uint8Array, filename: string): void {
  const blob = new Blob([bytes as BlobPart], { type: 'application/pdf' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  document.body.appendChild(a)
  a.click()
  a.remove()
  setTimeout(() => URL.revokeObjectURL(url), 1000)
}
