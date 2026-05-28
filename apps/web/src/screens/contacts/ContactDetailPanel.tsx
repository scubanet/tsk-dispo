/**
 * ContactDetailPanel — thin flag dispatcher.
 *
 * Phase G Phase 3 (Task 16, Carry-Forward C3): The outer component contains
 * zero hooks so the crm_v2 flag-flip path can never violate the Rules of
 * Hooks. All legacy logic lives in ContactDetailPanelLegacy; V2 logic lives
 * in ContactDetailPanelV2. The TabKey type is re-exported here so existing
 * importers (`import type { TabKey } from '.../ContactDetailPanel'`) keep
 * working unchanged.
 */

import { isFeatureEnabled } from '@/lib/featureFlags'
import { ContactDetailPanelV2 } from './ContactDetailPanelV2'
import { ContactDetailPanelLegacy } from './ContactDetailPanelLegacy'
import type { TabKey } from './ContactDetailPanelLegacy'

export type { TabKey }

interface Props {
  contactId: string | null
  open: boolean
  initialTab?: TabKey
  onClose: () => void
  onSelectContact?: (id: string) => void
}

export function ContactDetailPanel(props: Props) {
  if (isFeatureEnabled('crm_v2') && props.contactId && props.open) {
    return <ContactDetailPanelV2 contactId={props.contactId} onClose={props.onClose} />
  }
  return <ContactDetailPanelLegacy {...props} />
}
