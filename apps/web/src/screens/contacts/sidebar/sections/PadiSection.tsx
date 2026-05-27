// apps/web/src/screens/contacts/sidebar/sections/PadiSection.tsx
//
// STUB für Phase G Phase 3 Task 5 — wird in Task 11 ersetzt durch die echte
// Section (PADI-Level/Pro-Nr/Member-Status, role-gated auf Instructor|Student).
import type { ContactWithProperties } from '@/types/contactProperties'

interface Props {
  contact: ContactWithProperties
}

export function PadiSection({ contact: _contact }: Props) {
  return (
    <div data-testid="section-stub-padi" style={{ padding: 8, color: '#888', fontSize: 12 }}>
      PadiSection-Stub (Task 11)
    </div>
  )
}
