// apps/web/src/screens/contacts/sidebar/sections/SourceAuditSection.tsx
//
// Phase G Phase 3 Task 12 — SourceAuditSection: read-only Quelle + Owner + IDs.
// Default-closed SidebarSection. Keine Edits. UUIDs werden auf erste 8 Zeichen
// + Ellipse gekürzt, damit sie den Sidebar nicht brechen.
import { SidebarSection } from '../SidebarSection'
import type { ContactWithProperties } from '@/types/contactProperties'

interface Props {
  contact: ContactWithProperties
}

const DASH = '—'

function truncateId(value: string | null): string {
  if (!value) return DASH
  if (value.length <= 8) return value
  return `${value.slice(0, 8)}…`
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

export function SourceAuditSection({ contact }: Props) {
  return (
    <SidebarSection id="audit" title="Quelle & Audit">
      <Row label="Quelle" value={contact.source ?? DASH} />
      <Row label="Owner ID" value={truncateId(contact.owner_id)} />
      <Row label="Contact ID" value={truncateId(contact.id)} />
    </SidebarSection>
  )
}
