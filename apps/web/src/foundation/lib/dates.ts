/**
 * Date helpers — de-CH formatting, ISO parsing, day-of-week.
 *
 * Wrap date-fns to enforce a single locale across the app.
 * All "display" functions return localized German strings.
 */

import { format, formatDistanceToNow, isToday as fnsIsToday, isTomorrow as fnsIsTomorrow, isYesterday as fnsIsYesterday, parseISO } from 'date-fns'
import { de } from 'date-fns/locale'

const LOCALE = de

function asDate(d: string | Date): Date {
  return typeof d === 'string' ? parseISO(d) : d
}

// ──────────────────────── Day labels ────────────────────────

export function dateShort(d: string | Date): string {
  return format(asDate(d), 'dd.MM.', { locale: LOCALE })
}

export function dateMedium(d: string | Date): string {
  return format(asDate(d), 'dd.MM.yyyy', { locale: LOCALE })
}

export function dateLong(d: string | Date): string {
  return format(asDate(d), 'EEEE, d. MMMM yyyy', { locale: LOCALE })
}

export function weekday(d: string | Date): string {
  return format(asDate(d), 'EEEEEE', { locale: LOCALE })   // Mo, Di, Mi
}

export function weekdayLong(d: string | Date): string {
  return format(asDate(d), 'EEEE', { locale: LOCALE })
}

// ──────────────────────── Time labels ────────────────────────

export function timeShort(d: string | Date): string {
  return format(asDate(d), 'HH:mm')
}

export function dateTimeShort(d: string | Date): string {
  return format(asDate(d), 'dd.MM. HH:mm', { locale: LOCALE })
}

// ──────────────────────── Relative ────────────────────────

export function relativeTime(d: string | Date): string {
  return formatDistanceToNow(asDate(d), { locale: LOCALE, addSuffix: true })
}

/**
 * "Heute" / "Morgen" / "Gestern" or weekday name within ±7 days.
 * Falls back to dd.MM. for further dates.
 */
export function relativeDay(d: string | Date): string {
  const date = asDate(d)
  if (fnsIsToday(date)) return 'Heute'
  if (fnsIsTomorrow(date)) return 'Morgen'
  if (fnsIsYesterday(date)) return 'Gestern'
  const diff = Math.abs(date.getTime() - Date.now())
  const days = diff / (1000 * 60 * 60 * 24)
  if (days < 7) return weekdayLong(date)
  return dateShort(date)
}

// ──────────────────────── Predicates ────────────────────────

export const isToday = (d: string | Date) => fnsIsToday(asDate(d))
export const isTomorrow = (d: string | Date) => fnsIsTomorrow(asDate(d))
export const isYesterday = (d: string | Date) => fnsIsYesterday(asDate(d))

// ──────────────────────── ISO helpers ────────────────────────

export function todayISO(): string {
  return format(new Date(), 'yyyy-MM-dd')
}

export function toISODate(d: Date): string {
  return format(d, 'yyyy-MM-dd')
}
