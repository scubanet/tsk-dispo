// apps/web/src/screens/contacts/ContactDetailHeader.tsx
//
// Phase G Phase 2 Header für ContactDetailPanelV2. Layout:
// [Avatar · Name + Role-Pills] [spacer] [Edit-Button] [⋯-Menü] [✕-Close]
//
// Quick-Actions (Mail/Call/Note/...) leben PHASE 3 in der Properties-Sidebar
// (oder unterhalb des Headers wenn Sidebar collapsed). In Phase 2 nur die
// minimalen Header-Controls. EventComposer in TimelineFeed deckt das Erfassen.
import type { ContactRole } from '@/types/contacts'
import { Avatar } from '@/foundation/primitives/Avatar'

interface Props {
  contactId: string
  displayName: string
  roles: ContactRole[]
  onEdit: () => void
  onClose: () => void
  /**
   * GL-004 fix: opens the ⋯ action menu (role manager, merge, vCard, archive,
   * GDPR). Optional so the header still renders without it, but the V2 panel
   * wires it so "Rollen verwalten" is reachable again — it was documented in the
   * header layout but never implemented, which made roles unsettable.
   */
  onMore?: () => void
}

export function ContactDetailHeader({ contactId, displayName, roles, onEdit, onClose, onMore }: Props) {
  return (
    <header style={{
      display: 'flex', alignItems: 'center', gap: 12,
      padding: '10px 14px',
      borderBottom: '1px solid var(--border-subtle, #eee)',
      background: 'var(--surface-primary, white)',
    }}>
      <Avatar id={contactId} name={displayName} size="md" />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 17, fontWeight: 500 }}>{displayName}</div>
        {roles.length > 0 && (
          <div style={{ display: 'flex', gap: 4, marginTop: 4, flexWrap: 'wrap' }}>
            {roles.map(r => (
              <span
                key={r}
                style={{
                  padding: '2px 8px', borderRadius: 999,
                  background: 'var(--surface-secondary, #f3f3f3)',
                  fontSize: 11, color: 'var(--text-secondary, #555)',
                }}
              >
                {r}
              </span>
            ))}
          </div>
        )}
      </div>
      <button
        type="button"
        onClick={onEdit}
        style={{ padding: '6px 12px' }}
      >
        Bearbeiten
      </button>
      {onMore && (
        <button
          type="button"
          onClick={onMore}
          aria-label="Mehr"
          title="Mehr"
          style={{ padding: '6px 10px', background: 'transparent', border: 'none', cursor: 'pointer', fontSize: 18, lineHeight: 1 }}
        >
          ⋯
        </button>
      )}
      <button
        type="button"
        onClick={onClose}
        aria-label="Schliessen"
        style={{ padding: '6px 10px', background: 'transparent', border: 'none', cursor: 'pointer' }}
      >
        ✕
      </button>
    </header>
  )
}
