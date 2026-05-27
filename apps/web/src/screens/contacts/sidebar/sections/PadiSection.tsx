// apps/web/src/screens/contacts/sidebar/sections/PadiSection.tsx
//
// Phase G Phase 3 Task 11 — PadiSection: PADI-Level / Pro-Nummer / Member-Status.
// Role-gated: nur Instructor-Sidecar hat PADI-Felder. Wenn instructor === null
// → komplett null returnieren (kein Render, anders als Dash-Pattern).
// Default-closed SidebarSection.
import { SidebarSection } from '../SidebarSection'
import { EditableField } from '../EditableField'
import { useContactFieldMutation } from '@/hooks/useContactFieldMutation'
import type { ContactWithProperties } from '@/types/contactProperties'

interface Props {
  contact: ContactWithProperties
}

export function PadiSection({ contact }: Props) {
  const mutate = useContactFieldMutation(contact.id)

  if (contact.instructor === null) return null

  return (
    <SidebarSection id="padi" title="PADI">
      <EditableField
        label="PADI-Level"
        value={contact.instructor.padi_level}
        onSave={(next) => mutate.mutateAsync({
          table: 'contact_instructor', field: 'padi_level', value: next,
        })}
      />
      <EditableField
        label="Pro-Nummer"
        value={contact.instructor.padi_pro_number}
        onSave={(next) => mutate.mutateAsync({
          table: 'contact_instructor', field: 'padi_pro_number', value: next,
        })}
      />
      <EditableField
        label="Member-Status"
        value={contact.instructor.member_status}
        onSave={(next) => mutate.mutateAsync({
          table: 'contact_instructor', field: 'member_status', value: next,
        })}
      />
    </SidebarSection>
  )
}
