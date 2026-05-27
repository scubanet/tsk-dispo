// apps/web/src/screens/contacts/sidebar/PropertiesSidebar.tsx
//
// Phase G Phase 3 — Top-level Properties-Sidebar Container.
// Liest Contact-Daten via useContactWithProperties, rendert StickyTop +
// StatBand + 7 Sections (role-aware: PADI nur bei Instructor/Student).
import { useContactWithProperties } from '@/hooks/useContactWithProperties'
import { StatBand } from './StatBand'
import { ContactSection } from './sections/ContactSection'
import { RolesStatusSection } from './sections/RolesStatusSection'
import { OrgRelationsSection } from './sections/OrgRelationsSection'
import { TagsSection } from './sections/TagsSection'
import { KeyDatesSection } from './sections/KeyDatesSection'
import { PadiSection } from './sections/PadiSection'
import { SourceAuditSection } from './sections/SourceAuditSection'

interface Props {
  contactId: string
}

export function PropertiesSidebar({ contactId }: Props) {
  const { data, isLoading, error } = useContactWithProperties(contactId)

  if (isLoading) {
    return <div style={{ padding: 16, color: 'var(--text-tertiary, #888)', fontSize: 13 }}>Lade Properties…</div>
  }
  if (error || !data) {
    return (
      <div style={{ padding: 16, color: 'var(--color-text-danger, #c0392b)', fontSize: 13 }}>
        Fehler: {error?.message ?? 'kein Contact gefunden'}
      </div>
    )
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', overflowY: 'auto' }}>
      {/* Sticky-Top (Phase 3 Task 13 erweitert dieses zu Avatar + Roles + ⋯-Menü) */}
      <div style={{
        position: 'sticky', top: 0, zIndex: 1,
        background: 'var(--surface-primary, white)',
        padding: '12px 14px',
        borderBottom: '1px solid var(--border-subtle, #eee)',
      }}>
        <div style={{ fontSize: 15, fontWeight: 500 }}>{data.display_name}</div>
        {data.roles.length > 0 && (
          <div style={{ display: 'flex', gap: 4, marginTop: 4, flexWrap: 'wrap' }}>
            {data.roles.map(r => (
              <span key={r} style={{
                padding: '2px 6px', borderRadius: 999,
                background: 'var(--surface-secondary, #f3f3f3)',
                fontSize: 10, color: 'var(--text-secondary, #555)',
              }}>{r}</span>
            ))}
          </div>
        )}
      </div>

      <StatBand contact={data} />
      <ContactSection contact={data} />
      <RolesStatusSection contact={data} />
      <OrgRelationsSection contact={data} />
      <TagsSection contact={data} />
      <KeyDatesSection contact={data} />
      {(data.instructor || data.student) && <PadiSection contact={data} />}
      <SourceAuditSection contact={data} />
    </div>
  )
}
