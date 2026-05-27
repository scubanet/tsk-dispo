// apps/web/src/screens/contacts/ContactDetailPanelV2.tsx
//
// Phase G Phase 2/3 — 3-Pane Detail-Panel-Variante hinter crm_v2-Flag.
// Layout: [ Liste in Parent ] [ Header + TimelineFeed ] [ PropertiesSidebar ]
// Phase 3 Task 14: Sidebar collapse/expand-Toggle (localStorage-persistiert).
import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { ContactDetailHeader } from './ContactDetailHeader'
import { TimelineFeed } from './timeline/TimelineFeed'
import { PropertiesSidebar } from './sidebar/PropertiesSidebar'
import { useSidebarToggle } from '@/hooks/useSidebarToggle'
import type { ContactRole } from '@/types/contacts'

interface Props {
  contactId: string
  onClose: () => void
}

interface ContactSummary {
  id: string
  display_name: string
  roles: ContactRole[]
}

const SIDEBAR_KEY = 'contactDetail.sidebarOpen'

export function ContactDetailPanelV2({ contactId, onClose }: Props) {
  // Minimal contact-summary fetch — Phase 3 ersetzt das durch eine
  // umfassendere Hook die alle Properties lädt. Für Phase 2 reicht Name + Roles.
  const contact = useQuery({
    queryKey: ['contact-summary', contactId],
    queryFn: async (): Promise<ContactSummary> => {
      const { data, error } = await supabase
        .from('contacts')
        .select('id, display_name')
        .eq('id', contactId)
        .single()
      if (error) throw new Error(error.message)
      // Roles separat (Phase 3 in Sidebar-Section).
      return { id: data.id, display_name: data.display_name, roles: [] }
    },
    enabled: !!contactId,
  })

  const [sidebarOpen, toggleSidebar] = useSidebarToggle(SIDEBAR_KEY, true)

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
      <div style={{ display: 'flex', flex: 1, minHeight: 0 }}>
        {/* Center: Header + Timeline */}
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', minWidth: 0 }}>
          <ContactDetailHeader
            contactId={contactId}
            displayName={contact.data?.display_name ?? '…'}
            roles={contact.data?.roles ?? []}
            onEdit={() => { /* öffnet existing edit-sheet — Phase 3 nachrüsten */ }}
            onClose={onClose}
          />
          <div style={{ flex: 1, minHeight: 0 }}>
            <TimelineFeed contactId={contactId} />
          </div>
        </div>
        {/* Properties-Sidebar (Phase 3) — collapsible via Toggle */}
        <aside
          data-testid="properties-sidebar"
          data-open={sidebarOpen}
          style={{
            width: sidebarOpen ? 280 : 32,
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
    </div>
  )
}
