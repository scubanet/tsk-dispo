// apps/web/src/screens/contacts/sidebar/sections/KeyDatesSection.tsx
//
// STUB für Phase G Phase 3 Task 5 — wird in Task 10 ersetzt durch die echte
// Section (Birthday/Created/Updated/Last-Contact).
import type { ContactWithProperties } from '@/types/contactProperties'

interface Props {
  contact: ContactWithProperties
}

export function KeyDatesSection({ contact: _contact }: Props) {
  return (
    <div data-testid="section-stub-keydates" style={{ padding: 8, color: '#888', fontSize: 12 }}>
      KeyDatesSection-Stub (Task 10)
    </div>
  )
}
