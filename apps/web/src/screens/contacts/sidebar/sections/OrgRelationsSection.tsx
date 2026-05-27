// apps/web/src/screens/contacts/sidebar/sections/OrgRelationsSection.tsx
//
// Phase G Phase 3 Task 8 — OrgRelationsSection: read-only Liste der Org-Memberships.
// Filtert auf works_at-Beziehungen in From-Richtung (contact wirkt bei der Org).
// Add/Edit läuft weiterhin separat über RelationshipsTab/AddRelationshipSheet —
// diese Section ist Display-only.
import { SidebarSection } from '../SidebarSection'
import { useContactRelationships } from '@/hooks/useContactTabs'
import type { ContactWithProperties } from '@/types/contactProperties'
import type { ContactRelationship } from '@/types/contacts'

interface Props {
  contact: ContactWithProperties
}

export function OrgRelationsSection({ contact }: Props) {
  const { data, isLoading, error } = useContactRelationships(contact.id)

  const orgs: ContactRelationship[] = (data ?? []).filter(
    rel => rel.from_contact_id === contact.id && rel.kind === 'works_at',
  )

  return (
    <SidebarSection id="orgs" title="Organisationen">
      {isLoading && (
        <div style={{ color: 'var(--text-tertiary, #888)', fontSize: 13, padding: '4px 0' }}>
          Lädt…
        </div>
      )}

      {error && (
        <div
          role="alert"
          style={{ color: 'var(--danger, #c0392b)', fontSize: 13, padding: '4px 0' }}
        >
          {error.message}
        </div>
      )}

      {!isLoading && !error && orgs.length === 0 && (
        <div style={{ color: 'var(--text-tertiary, #888)', fontSize: 13, padding: '4px 0' }}>—</div>
      )}

      {!isLoading && !error && orgs.length > 0 && (
        <ul style={{ listStyle: 'none', padding: 0, margin: 0, display: 'flex', flexDirection: 'column', gap: 6 }}>
          {orgs.map(rel => (
            <li
              key={rel.id}
              style={{ display: 'flex', flexDirection: 'column', gap: 1, padding: '4px 0' }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                <span style={{ fontSize: 13, fontWeight: 600, color: 'var(--text-primary, #222)' }}>
                  {rel.to_contact?.display_name ?? '—'}
                </span>
                {rel.is_primary && (
                  <span
                    style={{
                      fontSize: 10,
                      textTransform: 'uppercase',
                      letterSpacing: 0.3,
                      padding: '1px 5px',
                      borderRadius: 3,
                      background: 'var(--accent-subtle, #eef)',
                      color: 'var(--accent, #336)',
                    }}
                  >
                    primary
                  </span>
                )}
              </div>
              {rel.role_at_org && (
                <span style={{ fontSize: 12, color: 'var(--text-tertiary, #888)' }}>
                  {rel.role_at_org}
                </span>
              )}
            </li>
          ))}
        </ul>
      )}
    </SidebarSection>
  )
}
