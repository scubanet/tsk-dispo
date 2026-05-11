import { PDFDocument } from 'pdf-lib'
import { FIELD_MAP, type PadiReferralData } from './padiReferralFieldMap'

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
