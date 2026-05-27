// apps/web/src/screens/contacts/sidebar/sections/KeyDatesSection.tsx
//
// Phase G Phase 3 Task 10 — KeyDatesSection: read-only Datums-Liste.
// Zeigt Geburtsdatum (+ Alter), Erstellt, Zuletzt geändert, Letzte Bewegung.
// Default-closed SidebarSection, kein Edit.
import { SidebarSection } from '../SidebarSection'
import type { ContactWithProperties } from '@/types/contactProperties'

interface Props {
  contact: ContactWithProperties
}

const DASH = '—'

function formatDate(value: string | null): string {
  if (!value) return DASH
  const d = new Date(value)
  if (Number.isNaN(d.getTime())) return DASH
  return d.toLocaleDateString('de-CH')
}

function computeAge(birthDate: string | null): number | null {
  if (!birthDate) return null
  const b = new Date(birthDate)
  if (Number.isNaN(b.getTime())) return null
  const now = new Date()
  let age = now.getFullYear() - b.getFullYear()
  const m = now.getMonth() - b.getMonth()
  if (m < 0 || (m === 0 && now.getDate() < b.getDate())) age -= 1
  return age
}

interface RowProps {
  label: string
  value: string
}

function Row({ label, value }: RowProps) {
  return (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        gap: 2,
        padding: '6px 0',
      }}
    >
      <div
        style={{
          fontSize: 11,
          color: 'var(--text-tertiary, #888)',
          letterSpacing: 0.2,
        }}
      >
        {label}
      </div>
      <div
        style={{
          fontSize: 13,
          color: 'var(--text-primary, #222)',
          padding: '4px 6px',
        }}
      >
        {value}
      </div>
    </div>
  )
}

export function KeyDatesSection({ contact }: Props) {
  const age = computeAge(contact.birth_date)
  const birthDateText = contact.birth_date
    ? `${formatDate(contact.birth_date)}${age !== null ? ` (${age})` : ''}`
    : DASH

  return (
    <SidebarSection id="keydates" title="Wichtige Daten">
      <Row label="Geburtsdatum" value={birthDateText} />
      <Row label="Erstellt" value={formatDate(contact.created_at)} />
      <Row label="Zuletzt geändert" value={formatDate(contact.updated_at)} />
      <Row label="Letzte Bewegung" value={formatDate(contact.last_movement_date)} />
    </SidebarSection>
  )
}
