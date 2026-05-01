import { format as fmt, formatDistanceToNow } from 'date-fns'
import { de } from 'date-fns/locale'

export function chf(n: number | null | undefined): string {
  const v = Number(n ?? 0)
  return new Intl.NumberFormat('de-CH', {
    style: 'currency',
    currency: 'CHF',
    minimumFractionDigits: 2,
  }).format(v)
}

export function chfPlain(n: number | null | undefined): string {
  return Number(n ?? 0).toFixed(2)
}

export function dateShort(d: string | Date): string {
  return fmt(typeof d === 'string' ? new Date(d) : d, 'dd.MM.', { locale: de })
}

export function dateLong(d: string | Date): string {
  return fmt(typeof d === 'string' ? new Date(d) : d, 'EEEE, d. MMMM yyyy', { locale: de })
}

export function relTime(d: string | Date): string {
  return formatDistanceToNow(typeof d === 'string' ? new Date(d) : d, {
    locale: de,
    addSuffix: true,
  })
}

export function initialsFromName(name: string): string {
  return name
    .split(/\s+/)
    .map((p) => p[0])
    .filter(Boolean)
    .slice(0, 2)
    .join('')
    .toUpperCase()
}
