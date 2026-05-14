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
  // Year (Jahr) columns are narrow — 4-digit years got clipped even at small
  // font sizes. We display the last 2 digits only (e.g. 1991 → "91", 2026 → "26").
  for (const [dataKey, pdfFieldName] of Object.entries(FIELD_MAP) as [string, string | undefined][]) {
    if (!pdfFieldName) continue
    const value = (data as unknown as Record<string, unknown>)[dataKey]
    if (value == null || value === '') continue
    try {
      const field = form.getTextField(pdfFieldName)
      let text = String(value)
      if (dataKey.endsWith('Jahr') && text.length === 4) {
        text = text.slice(-2)
      }
      field.setText(text)
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

/** Skill record shape returned from padi_skill_records */
interface SkillRecord {
  skill_code: string
  completed_on: string | null
  tg_number: number | null
  instructor_id: string | null
}

/**
 * Fetch course-day data and build auto-fill fields for the PADI referral PDF.
 * If participantId is supplied, explicit padi_skill_records override the
 * course-day fallback. Without skill records the function behaves as before,
 * so existing PDFs are unaffected.
 *
 * Fills:
 *  - CW 1–5        (pool days / skill records cw_1..cw_5)
 *  - KD Teil 1–5 + Quick Review (theory days / skill records kd_teil_1..kd_quick_review)
 *  - OW 1–4        (see days / skill records ow_1..ow_4)
 *  - Assessment    (skill records assessment_swim, assessment_float)
 *  - CW Flex       (skill records cw_flex_*)
 *  - OW Flex       (skill records ow_flex_*)
 */
export async function buildCourseAutofillData(courseId: string, participantId?: string): Promise<Partial<PadiReferralData>> {
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

  // Collect assignment instructor ids (needed for ciMap below)
  const instructorIds = (ca ?? []).map((a) => (a as any).instructor_id as string)

  // Optionally load explicit skill records for this participant
  let skillRecords: SkillRecord[] = []
  if (participantId) {
    const { data: sr } = await supabase
      .from('padi_skill_records')
      .select('skill_code, completed_on, tg_number, instructor_id')
      .eq('participant_id', participantId)
    skillRecords = (sr ?? []) as SkillRecord[]
  }
  const skillMap = new Map<string, SkillRecord>()
  for (const r of skillRecords) skillMap.set(r.skill_code, r)

  // Also fetch initials/PADI for ALL instructors referenced in skill records
  const skillInstructorIds = [...new Set(skillRecords.map((r) => r.instructor_id).filter((id): id is string => !!id))]
  const allInstructorIds = [...new Set([...instructorIds, ...skillInstructorIds])]

  // Phase J Etappe 3b: contact_instructor liefert sowohl padi_pro_number als auch
  // initials (Spalte aus 0091). Eine Query reicht für beide Maps.
  const { data: allCis } = allInstructorIds.length === 0
    ? { data: [] as Array<{ contact_id: string; padi_pro_number: string | null; initials: string | null }> }
    : await supabase
        .from('contact_instructor')
        .select('contact_id, padi_pro_number, initials')
        .in('contact_id', allInstructorIds)

  const instInitialsMap = new Map<string, string>()
  const ciMap = new Map<string, string>()
  for (const c of (allCis ?? []) as Array<{ contact_id: string; padi_pro_number: string | null; initials: string | null }>) {
    if (c.initials) instInitialsMap.set(c.contact_id, c.initials)
    if (c.padi_pro_number) ciMap.set(c.contact_id, c.padi_pro_number)
  }

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
    const padi = ciMap.get(a.instructor_id) ?? ''
    return { initials: initials ?? '', padi: padi ?? '' }
  }

  /** Return initials + PADI Nr for a specific instructor id (from skill records). */
  function infoForInstructor(instructorId: string | null): { initials: string; padi: string } {
    if (!instructorId) return { initials: '', padi: '' }
    return {
      initials: instInitialsMap.get(instructorId) ?? '',
      padi: ciMap.get(instructorId) ?? '',
    }
  }

  /** Split ISO date string (YYYY-MM-DD) into tag/monat/jahr. */
  function splitDate(iso: string): { tag: string; monat: string; jahr: string } {
    const [yyyy, mm, dd] = iso.split('-')
    return { tag: dd ?? '', monat: mm ?? '', jahr: yyyy ?? '' }
  }

  /**
   * For a skill code and its course-day fallback date:
   * - If a skill record exists, use its date + instructor info
   * - Otherwise fall back to the course-day date + infoForDate
   */
  function resolveSkill(skillCode: string, fallbackDate: string | undefined): {
    tag: string; monat: string; jahr: string; initials: string; padi: string
  } | null {
    const rec = skillMap.get(skillCode)
    if (rec && rec.completed_on) {
      const { tag, monat, jahr } = splitDate(rec.completed_on)
      const { initials, padi } = infoForInstructor(rec.instructor_id)
      return { tag, monat, jahr, initials, padi }
    }
    if (!fallbackDate) return null
    const { tag, monat, jahr } = splitDate(fallbackDate)
    const { initials, padi } = infoForDate(fallbackDate)
    return { tag, monat, jahr, initials, padi }
  }

  const courseDates = (cd ?? []) as Array<{ date: string; kind: string[] | null }>
  const poolDays   = courseDates.filter((d) => (d.kind ?? []).includes('pool')).map((d) => d.date).sort()
  const seeDays    = courseDates.filter((d) => (d.kind ?? []).includes('see')).map((d) => d.date).sort()
  const theoryDays = courseDates.filter((d) => (d.kind ?? []).includes('theorie')).map((d) => d.date).sort()

  const result: Partial<PadiReferralData> = {}

  // CW 1–5: prefer skill record, fall back to pool day N
  for (let i = 0; i < 5; i++) {
    const skillCode = `cw_${i + 1}`
    const fallback = poolDays[i]
    const info = resolveSkill(skillCode, fallback)
    if (!info) continue
    const n = (i + 1) as 1 | 2 | 3 | 4 | 5
    result[`cw${n}Tag`]       = info.tag
    result[`cw${n}Monat`]     = info.monat
    result[`cw${n}Jahr`]      = info.jahr
    result[`cw${n}Initialen`] = info.initials
    result[`cw${n}PadiNr`]    = info.padi
  }

  // Knowledge Development Teil 1–5: prefer skill record, fall back to theory/pool day
  const kdSource = theoryDays.length > 0 ? theoryDays : poolDays
  for (let i = 0; i < 5; i++) {
    const skillCode = `kd_teil_${i + 1}`
    const fallback = kdSource[i] ?? kdSource[0]
    const info = resolveSkill(skillCode, fallback)
    if (!info) continue
    const n = (i + 1) as 1 | 2 | 3 | 4 | 5
    result[`kd${n}Tag`]       = info.tag
    result[`kd${n}Monat`]     = info.monat
    result[`kd${n}Jahr`]      = info.jahr
    result[`kd${n}Initialen`] = info.initials
    result[`kd${n}PadiNr`]    = info.padi
  }

  // KD Quick Review: only from skill record (no natural course-day fallback)
  const qrRec = skillMap.get('kd_quick_review')
  if (qrRec?.completed_on) {
    const { tag, monat, jahr } = splitDate(qrRec.completed_on)
    const { initials, padi } = infoForInstructor(qrRec.instructor_id)
    result.kdQrTag      = tag
    result.kdQrMonat    = monat
    result.kdQrJahr     = jahr
    result.kdQrInitialen = initials
    result.kdQrPadiNr   = padi
  }

  // OW Tauchgänge 1–4: prefer skill record, fall back to see day N
  for (let i = 0; i < 4; i++) {
    const skillCode = `ow_${i + 1}`
    const fallback = seeDays[i]
    const info = resolveSkill(skillCode, fallback)
    if (!info) continue
    const n = (i + 1) as 1 | 2 | 3 | 4
    result[`ow${n}Tag`]   = info.tag
    result[`ow${n}Monat`] = info.monat
    result[`ow${n}Jahr`]  = info.jahr
    if (n !== 2) {
      // ow2Initialen is unmapped (PDF field is a long label name, not reliably fillable)
      result[`ow${n}Initialen`] = info.initials
    }
    result[`ow${n}PadiNr`] = info.padi
  }

  // Assessment — only from skill records
  const swimRec = skillMap.get('assessment_swim')
  if (swimRec?.completed_on) {
    const { tag, monat, jahr } = splitDate(swimRec.completed_on)
    const { initials, padi } = infoForInstructor(swimRec.instructor_id)
    result.assessSwimTag      = tag
    result.assessSwimMonat    = monat
    result.assessSwimJahr     = jahr
    result.assessSwimInitialen = initials
    result.assessSwimPadiNr   = padi
  }
  const floatRec = skillMap.get('assessment_float')
  if (floatRec?.completed_on) {
    const { tag, monat, jahr } = splitDate(floatRec.completed_on)
    const { initials, padi } = infoForInstructor(floatRec.instructor_id)
    result.assessFloatTag      = tag
    result.assessFloatMonat    = monat
    result.assessFloatJahr     = jahr
    result.assessFloatInitialen = initials
    result.assessFloatPadiNr   = padi
  }

  // CW Flex — only from skill records (no natural date fallback)
  const cwFlexMap: Array<{ code: string; tagKey: keyof PadiReferralData; monatKey: keyof PadiReferralData; jahrKey: keyof PadiReferralData; initKey: keyof PadiReferralData; padiKey: keyof PadiReferralData }> = [
    { code: 'cw_flex_inflator',         tagKey: 'cwFlexInflatorTag',    monatKey: 'cwFlexInflatorMonat',    jahrKey: 'cwFlexInflatorJahr',    initKey: 'cwFlexInflatorInitialen',    padiKey: 'cwFlexInflatorPadiNr'    },
    { code: 'cw_flex_band',             tagKey: 'cwFlexBandTag',        monatKey: 'cwFlexBandMonat',        jahrKey: 'cwFlexBandJahr',        initKey: 'cwFlexBandInitialen',        padiKey: 'cwFlexBandPadiNr'        },
    { code: 'cw_flex_weight_off_surf',  tagKey: 'cwFlexWeightSurfTag',  monatKey: 'cwFlexWeightSurfMonat',  jahrKey: 'cwFlexWeightSurfJahr',  initKey: 'cwFlexWeightSurfInitialen',  padiKey: 'cwFlexWeightSurfPadiNr'  },
    { code: 'cw_flex_emergency_weight', tagKey: 'cwFlexEmergWeightTag', monatKey: 'cwFlexEmergWeightMonat', jahrKey: 'cwFlexEmergWeightJahr', initKey: 'cwFlexEmergWeightInitialen', padiKey: 'cwFlexEmergWeightPadiNr' },
    { code: 'cw_flex_prep_gear',        tagKey: 'cwFlexPrepGearTag',    monatKey: 'cwFlexPrepGearMonat',    jahrKey: 'cwFlexPrepGearJahr',    initKey: 'cwFlexPrepGearInitialen',    padiKey: 'cwFlexPrepGearPadiNr'    },
    { code: 'cw_flex_snorkel',          tagKey: 'cwFlexSnorkelTag',     monatKey: 'cwFlexSnorkelMonat',     jahrKey: 'cwFlexSnorkelJahr',     initKey: 'cwFlexSnorkelInitialen',     padiKey: 'cwFlexSnorkelPadiNr'     },
    { code: 'cw_flex_drysuit_orient',   tagKey: 'cwFlexDrysuitTag',     monatKey: 'cwFlexDrysuitMonat',     jahrKey: 'cwFlexDrysuitJahr',     initKey: 'cwFlexDrysuitInitialen',     padiKey: 'cwFlexDrysuitPadiNr'     },
  ]
  for (const m of cwFlexMap) {
    const rec = skillMap.get(m.code)
    if (!rec?.completed_on) continue
    const { tag, monat, jahr } = splitDate(rec.completed_on)
    const { initials, padi } = infoForInstructor(rec.instructor_id)
    ;(result as Record<string, string>)[m.tagKey as string]   = tag
    ;(result as Record<string, string>)[m.monatKey as string] = monat
    ;(result as Record<string, string>)[m.jahrKey as string]  = jahr
    ;(result as Record<string, string>)[m.initKey as string]  = initials
    ;(result as Record<string, string>)[m.padiKey as string]  = padi
  }

  // OW Flex — only from skill records (TG number + initials + PADI)
  const owFlexMap: Array<{ code: string; tgKey: keyof PadiReferralData; initKey: keyof PadiReferralData; padiKey: keyof PadiReferralData }> = [
    { code: 'ow_flex_cramp',            tgKey: 'owFlexCrampTg',            initKey: 'owFlexCrampInit',            padiKey: 'owFlexCrampPadi'            },
    { code: 'ow_flex_tow',              tgKey: 'owFlexTowTg',              initKey: 'owFlexTowInit',              padiKey: 'owFlexTowPadi'              },
    { code: 'ow_flex_dsmb',             tgKey: 'owFlexDsmbTg',             initKey: 'owFlexDsmbInit',             padiKey: 'owFlexDsmbPadi'             },
    { code: 'ow_flex_compass_straight', tgKey: 'owFlexCompassStraightTg',  initKey: 'owFlexCompassStraightInit',  padiKey: 'owFlexCompassStraightPadi'  },
    { code: 'ow_flex_snorkel_reg',      tgKey: 'owFlexSnorkelRegTg',       initKey: 'owFlexSnorkelRegInit',       padiKey: 'owFlexSnorkelRegPadi'       },
    { code: 'ow_flex_weight_drop',      tgKey: 'owFlexWeightDropTg',       initKey: 'owFlexWeightDropInit',       padiKey: 'owFlexWeightDropPadi'       },
    { code: 'ow_flex_scuba_off_surf',   tgKey: 'owFlexScubaOffTg',         initKey: 'owFlexScubaOffInit',         padiKey: 'owFlexScubaOffPadi'         },
    { code: 'ow_flex_weight_off_surf',  tgKey: 'owFlexWeightOffTg',        initKey: 'owFlexWeightOffInit',        padiKey: 'owFlexWeightOffPadi'        },
    { code: 'ow_flex_uw_compass',       tgKey: 'owFlexUwCompassTg',        initKey: 'owFlexUwCompassInit',        padiKey: 'owFlexUwCompassPadi'        },
    { code: 'ow_flex_cesa',             tgKey: 'owFlexCesaTg',             initKey: 'owFlexCesaInit',             padiKey: 'owFlexCesaPadi'             },
  ]
  for (const m of owFlexMap) {
    const rec = skillMap.get(m.code)
    if (!rec?.tg_number) continue
    const { initials, padi } = infoForInstructor(rec.instructor_id)
    ;(result as Record<string, string>)[m.tgKey as string]   = String(rec.tg_number)
    ;(result as Record<string, string>)[m.initKey as string] = initials
    ;(result as Record<string, string>)[m.padiKey as string] = padi
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
