// apps/web/src/screens/contacts/ContactDetailPanelV2.tsx
//
// Phase G Phase 2/3 — 3-Pane Detail-Panel-Variante hinter crm_v2-Flag.
// Layout: [ Liste in Parent ] [ Header + TimelineFeed ] [ PropertiesSidebar ]
// Phase 3 Task 14: Sidebar collapse/expand-Toggle (localStorage-persistiert).
import { useState } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { ContactDetailHeader } from './ContactDetailHeader'
import { ContactMoreMenu } from './ContactMoreMenu'
import { TimelineFeed } from './timeline/TimelineFeed'
import { PropertiesSidebar } from './sidebar/PropertiesSidebar'
import { ContactEditSheet } from './ContactEditSheet'
import { useSidebarToggle } from '@/hooks/useSidebarToggle'
import { useContactWithSidecars } from '@/hooks/useContactWithSidecars'

interface Props {
  contactId: string
  onClose: () => void
}

const SIDEBAR_KEY = 'contactDetail.sidebarOpen'

export function ContactDetailPanelV2({ contactId, onClose }: Props) {
  // Load the full contact (+ sidecars). Needed for real role pills AND for the
  // ⋯ action menu (ContactMoreMenu), whose "Rollen verwalten" entry is the only
  // way to set a contact's roles. The earlier summary-only fetch hardcoded
  // roles to [] and never mounted the menu, so roles became unsettable.
  const qc = useQueryClient()
  const { data: contact } = useContactWithSidecars(contactId, true)

  const [sidebarOpen, toggleSidebar] = useSidebarToggle(SIDEBAR_KEY, true)
  const [editOpen, setEditOpen] = useState(false)
  const [showMore, setShowMore] = useState(false)

  // Refresh just this contact after a menu action (role change, archive, …).
  function reload() {
    qc.invalidateQueries({ queryKey: ['contact', 'withSidecars', contactId] })
    qc.invalidateQueries({ queryKey: ['contacts'] })
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
      <div style={{ display: 'flex', flex: 1, minHeight: 0 }}>
        {/* Center: Header + Timeline */}
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', minWidth: 0 }}>
          <div style={{ position: 'relative' }}>
            <ContactDetailHeader
              contactId={contactId}
              displayName={contact?.display_name ?? '…'}
              roles={contact?.roles ?? []}
              onEdit={() => setEditOpen(true)}
              onMore={() => setShowMore(true)}
              onClose={onClose}
            />
            {showMore && contact && (
              <ContactMoreMenu
                contact={contact}
                onChanged={reload}
                onClosed={() => setShowMore(false)}
              />
            )}
          </div>
          <div style={{ flex: 1, minHeight: 0 }}>
            <TimelineFeed contactId={contactId} />
          </div>
        </div>
        {/* Properties-Sidebar (Phase 3) — collapsible via Toggle */}
        <aside
          data-testid="properties-sidebar"
          data-open={sidebarOpen}
          style={{
            width: sidebarOpen ? 340 : 32,
            flexShrink: 0,
            borderLeft: '1px solid var(--border-subtle, #eee)',
            background: 'var(--surface-tertiary, #fafafa)',
            display: 'flex',
            flexDirection: 'column',
            position: 'relative',
            transition: 'width 0.15s ease',
            overflow: 'hidden',
          }}
        >
          <button
            type="button"
            data-testid="sidebar-toggle"
            onClick={toggleSidebar}
            aria-label={sidebarOpen ? 'Sidebar einklappen' : 'Sidebar ausklappen'}
            aria-expanded={sidebarOpen}
            style={{
              position: 'absolute',
              top: 8,
              right: 6,
              zIndex: 2,
              width: 22,
              height: 22,
              padding: 0,
              border: '1px solid var(--border-subtle, #eee)',
              borderRadius: 4,
              background: 'var(--surface-primary, white)',
              cursor: 'pointer',
              fontSize: 12,
              lineHeight: 1,
              color: 'var(--text-secondary, #555)',
            }}
          >
            {sidebarOpen ? '⟶' : '⟵'}
          </button>
          {sidebarOpen && (
            <div style={{ flex: 1, minHeight: 0, paddingTop: 28 }}>
              <PropertiesSidebar contactId={contactId} />
            </div>
          )}
        </aside>
      </div>
      <ContactEditSheet
        contactId={contactId}
        open={editOpen}
        onClose={() => setEditOpen(false)}
      />
    </div>
  )
}
