// apps/web/src/screens/contacts/sidebar/sections/ContactSection.tsx
//
// STUB für Phase G Phase 3 Task 5 — wird in Task 6 ersetzt durch die echte
// Section (Email/Phone/WhatsApp/Sprache mit EditableField).
import type { ContactWithProperties } from '@/types/contactProperties'

interface Props {
  contact: ContactWithProperties
}

export function ContactSection({ contact: _contact }: Props) {
  return (
    <div data-testid="section-stub-contact" style={{ padding: 8, color: '#888', fontSize: 12 }}>
      ContactSection-Stub (Task 6)
    </div>
  )
}
