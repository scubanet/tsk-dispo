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

  // Fill all mapped text fields
  for (const [dataKey, pdfFieldName] of Object.entries(FIELD_MAP)) {
    const value = (data as unknown as Record<string, unknown>)[dataKey]
    if (value == null || value === '') continue
    try {
      const field = form.getTextField(pdfFieldName)
      field.setText(String(value))
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
