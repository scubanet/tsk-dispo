/**
 * ContactEditSheet — Drawer-Wrapper, der die Legacy-`OverviewTab` über dem
 * V2-Detail-Panel öffnet, damit Postal-Address, Multi-Email, Multi-Phone &
 * Co. unverändert editierbar bleiben (Phase G — Lücke in V2 schliessen).
 *
 * Verwendung:
 *   <ContactEditSheet contactId={id} open={editOpen} onClose={...} />
 *
 * Die Edit-Logic kommt 1:1 aus `OverviewTab.tsx` (keine Duplikation). Nach
 * dem Speichern werden alle relevanten React-Query-Keys invalidiert, sodass
 * sowohl V2-Sidebar (`contact-properties`) als auch Legacy-Panel
 * (`contact, withSidecars`) und die Adressbuch-Liste (`contacts`) frische
 * Daten ziehen.
 */

import { useQueryClient } from '@tanstack/react-query'
import { Drawer } from '@/foundation/layouts/Drawer'
import { useContactWithSidecars } from '@/hooks/useContactWithSidecars'
import { OverviewTab } from './tabs/OverviewTab'

interface Props {
  contactId: string | null
  open: boolean
  onClose: () => void
}

export function ContactEditSheet({ contactId, open, onClose }: Props) {
  const qc = useQueryClient()
  const { data: contact = null } = useContactWithSidecars(contactId, open)

  function handleUpdated() {
    if (!contactId) return
    // V2-Sidebar (PropertiesSidebar lädt `contact-properties`):
    qc.invalidateQueries({ queryKey: ['contact-properties', contactId] })
    // Legacy-Detail-Panel + dieser Sheet selbst:
    qc.invalidateQueries({ queryKey: ['contact', 'withSidecars', contactId] })
    // Adressbuch-Liste:
    qc.invalidateQueries({ queryKey: ['contacts'] })
  }

  const title = contact ? `${contact.display_name} bearbeiten` : 'Kontakt bearbeiten'

  return (
    <Drawer
      open={open}
      onClose={onClose}
      title={title}
      width={600}
      ariaLabel="Kontakt bearbeiten"
    >
      {!contact ? (
        <div data-testid="contact-edit-loading">Lädt…</div>
      ) : (
        <OverviewTab contact={contact} onUpdated={handleUpdated} />
      )}
    </Drawer>
  )
}
