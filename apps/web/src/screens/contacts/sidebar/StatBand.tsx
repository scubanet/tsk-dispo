// apps/web/src/screens/contacts/sidebar/StatBand.tsx
//
// Phase G Phase 3 Task 13 — 4-Tile Stat-Band als Top-Element der Sidebar.
// Tiles: Saldo / Aktive Kurse / Letzter Kontakt / Nächste Action.
import type { ContactWithProperties } from '@/types/contactProperties'

interface Props {
  contact: ContactWithProperties
}

const DASH = '—'

/**
 * Übersetzt einen ISO-Zeitstempel in eine deutsche relative Zeit-Phrase
 * gemessen am aktuellen `Date.now()`.
 */
export function relativeTime(iso: string): string {
  const then = new Date(iso).getTime()
  const now = Date.now()
  const diffMs = now - then
  const hour = 1000 * 60 * 60
  const day = hour * 24
  const week = day * 7

  if (diffMs < hour) return 'gerade eben'
  if (diffMs < day) {
    const h = Math.floor(diffMs / hour)
    return `vor ${h} Std`
  }
  if (diffMs < week) {
    const d = Math.floor(diffMs / day)
    return `vor ${d} ${d === 1 ? 'Tag' : 'Tagen'}`
  }
  if (diffMs < day * 30) {
    const w = Math.floor(diffMs / week)
    return `vor ${w} ${w === 1 ? 'Woche' : 'Wochen'}`
  }
  return new Date(iso).toLocaleDateString('de-CH')
}

const labelStyle: React.CSSProperties = {
  fontSize: 10,
  textTransform: 'uppercase',
  letterSpacing: 0.3,
  color: 'var(--text-tertiary, #888)',
  marginBottom: 2,
}

const valueStyle: React.CSSProperties = {
  fontSize: 16,
  fontWeight: 600,
  color: 'var(--text-primary, #222)',
  whiteSpace: 'nowrap',
  overflow: 'hidden',
  textOverflow: 'ellipsis',
}

interface TileProps {
  label: string
  value: React.ReactNode
}

function Tile({ label, value }: TileProps) {
  return (
    <div>
      <div style={labelStyle}>{label}</div>
      <div style={valueStyle}>{value}</div>
    </div>
  )
}

export function StatBand({ contact }: Props) {
  // Saldo
  const balance = contact.balance_chf
  let balanceNode: React.ReactNode
  if (balance === null || balance === undefined) {
    balanceNode = DASH
  } else {
    const positive = balance >= 0
    const color = positive
      ? 'var(--color-success, #2a7c2a)'
      : 'var(--color-text-danger, #c0392b)'
    balanceNode = (
      <span
        data-variant={positive ? 'positive' : 'negative'}
        style={{ ...valueStyle, color }}
      >{`CHF ${balance.toFixed(2)}`}</span>
    )
  }

  // Letzter Kontakt
  const lastNode: React.ReactNode = contact.last_movement_date
    ? relativeTime(contact.last_movement_date)
    : DASH

  // Aktive Kurse — TODO Phase 3.x: useContactStats hook (active courses count)
  const activeCoursesNode: React.ReactNode = DASH

  // Nächste Action — TODO Phase 3.x: nächste offene Task aus contact_events
  const nextActionNode: React.ReactNode = DASH

  return (
    <div
      data-testid="stat-band"
      style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(4, 1fr)',
        gap: 8,
        padding: 12,
        borderBottom: '1px solid var(--border-subtle, #eee)',
      }}
    >
      <Tile label="Saldo" value={balanceNode} />
      <Tile label="Aktive Kurse" value={activeCoursesNode} />
      <Tile label="Letzter Kontakt" value={lastNode} />
      <Tile label="Nächste Action" value={nextActionNode} />
    </div>
  )
}
