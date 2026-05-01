import { format } from 'date-fns'
import { de } from 'date-fns/locale'

/**
 * WhatsApp deep-link helpers (Plan 3 Tiefe 1).
 * Generates `https://wa.me/?text=…` URLs that open WhatsApp with a pre-filled message.
 * For DM to a specific number: `https://wa.me/<phone>?text=…` (phone in international format, no +).
 */

function encode(text: string): string {
  return encodeURIComponent(text)
}

export function waGroupShareUrl(text: string): string {
  // Without target → opens WA with chooser, user picks group
  return `https://wa.me/?text=${encode(text)}`
}

export function waDirectUrl(phone: string, text: string): string {
  const cleanPhone = phone.replace(/[^\d]/g, '')
  return `https://wa.me/${cleanPhone}?text=${encode(text)}`
}

// ---------- Templates (Emoji style, per Plan 3 spec) ----------

interface CourseAnnounce {
  type_code: string
  title: string
  start_date: string
  haupt_name?: string
  pool_location?: string | null
  pool_time?: string | null
  num_participants?: number
  info?: string | null
}

export function tplNewCourse(c: CourseAnnounce): string {
  const lines: string[] = []
  lines.push(`🆕 Neuer Kurs · ${c.title}`)
  lines.push(`📅 ${format(new Date(c.start_date), 'EEEE, d. MMM yyyy', { locale: de })}`)
  if (c.haupt_name) lines.push(`👤 ${c.haupt_name} (Haupt)`)
  if (c.pool_location || c.pool_time) {
    lines.push(`🌊 Pool ${c.pool_location ?? ''} ${c.pool_time ?? ''}`.trim())
  }
  if (c.num_participants) lines.push(`👥 ${c.num_participants} Teilnehmer`)
  if (c.info) lines.push(`ℹ️ ${c.info}`)
  return lines.join('\n')
}

interface CancelAnnounce {
  type_code: string
  title: string
  was_date: string
  reason?: string
}

export function tplCancellation(c: CancelAnnounce): string {
  const lines: string[] = []
  lines.push(`❌ Storniert · ${c.title}`)
  lines.push(`📅 War: ${format(new Date(c.was_date), 'd. MMM yyyy', { locale: de })}`)
  if (c.reason) lines.push(`ℹ️ ${c.reason}`)
  return lines.join('\n')
}

interface DigestEntry {
  time?: string
  type_code: string
  haupt_name?: string
  location?: string | null
}

export function tplDailyDigest(date: Date, entries: DigestEntry[]): string {
  const lines: string[] = []
  const dateStr = format(date, 'EEEE d.M.', { locale: de })
  lines.push(`☀️ TSK heute · ${dateStr}`)
  lines.push('')
  if (entries.length === 0) {
    lines.push('Heute keine Kurse. 🤿')
  } else {
    for (const e of entries) {
      const parts = ['🤿']
      if (e.time) parts.push(e.time)
      parts.push(e.type_code)
      if (e.haupt_name) parts.push('·', e.haupt_name)
      if (e.location) parts.push('·', e.location)
      lines.push(parts.join(' '))
    }
  }
  lines.push('')
  lines.push(`✨ ${entries.length} ${entries.length === 1 ? 'Session' : 'Sessions'}`)
  return lines.join('\n')
}

interface DirectMsg {
  to_name: string
  message: string
}

export function tplDirect(c: DirectMsg): string {
  return `Hi ${c.to_name},\n\n${c.message}\n\n– Dominik`
}
