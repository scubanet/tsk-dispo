/**
 * Number formatting — Swiss conventions.
 *
 *   Thousand separator: apostrophe (1'234'567)
 *   Decimal separator:  period (12.50)
 *   Currency:           CHF prefix
 *
 * All UI-facing numbers MUST go through these helpers — never `toString()`.
 * They guarantee the foundation tabular-numbers layout works.
 */

const LOCALE = 'de-CH'

// ──────────────────────── Money ────────────────────────

export function chf(n: number | null | undefined): string {
  const v = Number(n ?? 0)
  return new Intl.NumberFormat(LOCALE, {
    style: 'currency',
    currency: 'CHF',
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(v)
}

/**
 * CHF without the currency symbol — for tables where the column is labelled.
 */
export function chfPlain(n: number | null | undefined): string {
  const v = Number(n ?? 0)
  return new Intl.NumberFormat(LOCALE, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(v)
}

// ──────────────────────── Counts ────────────────────────

export function int(n: number | null | undefined): string {
  const v = Math.round(Number(n ?? 0))
  return new Intl.NumberFormat(LOCALE).format(v)
}

export function decimal(n: number | null | undefined, fractionDigits = 1): string {
  const v = Number(n ?? 0)
  return new Intl.NumberFormat(LOCALE, {
    minimumFractionDigits: fractionDigits,
    maximumFractionDigits: fractionDigits,
  }).format(v)
}

// ──────────────────────── Percent ────────────────────────

export function percent(n: number | null | undefined, fractionDigits = 0): string {
  const v = Number(n ?? 0)
  return new Intl.NumberFormat(LOCALE, {
    style: 'percent',
    minimumFractionDigits: fractionDigits,
    maximumFractionDigits: fractionDigits,
  }).format(v)
}

// ──────────────────────── Initials ────────────────────────

export function initialsFromName(name: string | null | undefined): string {
  if (!name) return '?'
  return name
    .split(/\s+/)
    .map((p) => p[0])
    .filter(Boolean)
    .slice(0, 2)
    .join('')
    .toUpperCase()
}
