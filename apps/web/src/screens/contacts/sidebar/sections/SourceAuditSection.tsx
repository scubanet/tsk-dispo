// apps/web/src/screens/contacts/sidebar/sections/SourceAuditSection.tsx
//
// STUB für Phase G Phase 3 Task 5 — wird in Task 12 ersetzt durch die echte
// Section (Source + Owner + Created/Updated-Audit).
import type { ContactWithProperties } from '@/types/contactProperties'

interface Props {
  contact: ContactWithProperties
}

export function SourceAuditSection({ contact: _contact }: Props) {
  return (
    <div data-testid="section-stub-audit" style={{ padding: 8, color: '#888', fontSize: 12 }}>
      SourceAuditSection-Stub (Task 12)
    </div>
  )
}
