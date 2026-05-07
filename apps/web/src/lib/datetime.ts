/**
 * Locale-neutral date/time formatting.
 *
 * The format stays the same in DE and EN — only the month name changes:
 *   DE: "7. Mai 2026, 14:30"     EN: "7 May 2026, 14:30"
 *
 * 24-hour time always (no AM/PM in either locale, even though EN traditionally uses 12h).
 *
 * Pulls the active language from i18next so callers don't have to thread it.
 */
import i18n from '@/i18n'

type DateInput = Date | string | number | null | undefined

function toDate(d: DateInput): Date | null {
  if (d == null) return null
  if (d instanceof Date) return isNaN(d.getTime()) ? null : d
  const parsed = new Date(d)
  return isNaN(parsed.getTime()) ? null : parsed
}

function activeLocale(): string {
  // de-CH puts the day-dot before the month and uses 24h — same shape as the EN format we want.
  // For EN we want "7 May 2026" (no comma between day and month → en-GB).
  const lng = (i18n.resolvedLanguage ?? 'de').split('-')[0]
  return lng === 'en' ? 'en-GB' : 'de-CH'
}

export function formatDate(d: DateInput): string {
  const date = toDate(d)
  if (!date) return ''
  return new Intl.DateTimeFormat(activeLocale(), {
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  }).format(date)
}

export function formatDateShort(d: DateInput): string {
  const date = toDate(d)
  if (!date) return ''
  // 7 May 2026 / 7. Mai 2026 — but with abbreviated month
  return new Intl.DateTimeFormat(activeLocale(), {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  }).format(date)
}

export function formatTime(d: DateInput): string {
  const date = toDate(d)
  if (!date) return ''
  return new Intl.DateTimeFormat(activeLocale(), {
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).format(date)
}

export function formatDateTime(d: DateInput): string {
  const date = toDate(d)
  if (!date) return ''
  const datePart = formatDate(date)
  const timePart = formatTime(date)
  return `${datePart}, ${timePart}`
}

export function formatWeekday(d: DateInput, style: 'long' | 'short' = 'long'): string {
  const date = toDate(d)
  if (!date) return ''
  return new Intl.DateTimeFormat(activeLocale(), { weekday: style }).format(date)
}

/**
 * Relative-time helper for things like "tomorrow", "in 3 days".
 * Falls back to absolute date if outside ±7 days.
 */
export function formatRelative(d: DateInput): string {
  const date = toDate(d)
  if (!date) return ''
  const now = new Date()
  const oneDayMs = 24 * 60 * 60 * 1000
  const diffDays = Math.round((date.getTime() - now.getTime()) / oneDayMs)
  if (Math.abs(diffDays) <= 7) {
    const rtf = new Intl.RelativeTimeFormat(activeLocale(), { numeric: 'auto' })
    return rtf.format(diffDays, 'day')
  }
  return formatDate(date)
}
