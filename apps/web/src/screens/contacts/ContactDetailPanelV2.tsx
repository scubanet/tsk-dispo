// apps/web/src/screens/contacts/ContactDetailPanelV2.tsx
//
// Phase G Phase 2 — neue 3-Pane Detail-Panel-Variante hinter crm_v2-Flag.
// Sidebar ist Placeholder bis Phase 3 fertig ist. Layout:
//   [ Liste in Parent ] [ Header ............................. ] [ Sidebar slot ]
//                       [ TimelineFeed (composer + filter + cards) ]
//
import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { ContactDetailHeader } from './ContactDetailHeader'
import { TimelineFeed } from './timeline/TimelineFeed'
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
        {/* Sidebar slot — Phase 3 füllt das mit Properties */}
        <aside
          data-testid="properties-sidebar-placeholder"
          style={{
            width: 280, flexShrink: 0,
            borderLeft: '1px solid var(--border-subtle, #eee)',
            background: 'var(--surface-tertiary, #fafafa)',
            padding: 16,
            color: 'var(--text-tertiary, #888)',
            fontSize: 13,
          }}
        >
          Properties-Sidebar (Phase 3)
        </aside>
      </div>
    </div>
  )
}
