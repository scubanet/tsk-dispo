// apps/web/src/screens/contacts/sidebar/sections/OrgRelationsSection.tsx
//
// STUB für Phase G Phase 3 Task 5 — wird in Task 8 ersetzt durch die echte
// Section (Org-Memberships via contact_relationships).
import type { ContactWithProperties } from '@/types/contactProperties'

interface Props {
  contact: ContactWithProperties
}

export function OrgRelationsSection({ contact: _contact }: Props) {
  return (
    <div data-testid="section-stub-org" style={{ padding: 8, color: '#888', fontSize: 12 }}>
      OrgRelationsSection-Stub (Task 8)
    </div>
  )
}
