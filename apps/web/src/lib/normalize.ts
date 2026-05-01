/**
 * Normalize Excel status strings (with whitespace + case variations)
 * to canonical course_status enum values.
 */
const STATUS_MAP: Record<string, 'confirmed' | 'tentative' | 'cancelled'> = {
  sicher:  'confirmed',
  evtl:    'tentative',
  'evtl.': 'tentative',
  cxl:     'cancelled',
}

export function normalizeStatus(raw: string): 'confirmed' | 'tentative' | 'cancelled' | null {
  const key = raw.trim().toLowerCase()
  return STATUS_MAP[key] ?? null
}

export function normalizeCourseCode(raw: string): string {
  return raw.trim().toUpperCase()
}
