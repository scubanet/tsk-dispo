// apps/web/src/screens/contacts/sidebar/sections/RolesStatusSection.tsx
//
// Phase G Phase 3 — RolesStatusSection: role-aware Section (Student + Instructor).
// Student-Sidecar → Pipeline-Stage / Intake-Status / Brevet (Inline-Edit).
// Instructor-Sidecar → Aktiv-Toggle (Button, kein EditableField — boolean).
// Wenn weder Student noch Instructor → leerer Body mit Dash für UI-Symmetrie.
import { useState } from 'react'
import { SidebarSection } from '../SidebarSection'
import { EditableField } from '../EditableField'
import { useContactFieldMutation } from '@/hooks/useContactFieldMutation'
import type { ContactWithProperties } from '@/types/contactProperties'

interface Props {
  contact: ContactWithProperties
}

const PIPELINE_STAGES = ['lead', 'qualified', 'opportunity', 'customer', 'candidate', 'lost']

export function RolesStatusSection({ contact }: Props) {
  const mutate = useContactFieldMutation(contact.id)
  const [toggling, setToggling] = useState(false)

  const hasAny = contact.student !== null || contact.instructor !== null

  async function toggleActive() {
    if (!contact.instructor || toggling) return
    setToggling(true)
    try {
      await mutate.mutateAsync({
        table: 'contact_instructor',
        field: 'active',
        value: !contact.instructor.active,
      })
    } finally {
      setToggling(false)
    }
  }

  return (
    <SidebarSection id="roles" title="Rollen & Status" defaultOpen>
      {!hasAny && (
        <div style={{ color: 'var(--text-tertiary, #888)', fontSize: 13, padding: '4px 0' }}>—</div>
      )}

      {contact.student && (
        <>
          <EditableField
            label="Pipeline-Stage"
            value={contact.student.pipeline_stage}
            validate={v => (v && !PIPELINE_STAGES.includes(v) ? `Erlaubt: ${PIPELINE_STAGES.join(', ')}` : null)}
            placeholder={PIPELINE_STAGES.join(' / ')}
            onSave={(next) => mutate.mutateAsync({
              table: 'contact_student', field: 'pipeline_stage', value: next,
            })}
          />
          <EditableField
            label="Intake-Status"
            value={contact.student.intake_status}
            onSave={(next) => mutate.mutateAsync({
              table: 'contact_student', field: 'intake_status', value: next,
            })}
          />
          <EditableField
            label="Brevet"
            value={contact.student.highest_brevet}
            placeholder="z.B. OWD, AOWD, Rescue"
            onSave={(next) => mutate.mutateAsync({
              table: 'contact_student', field: 'highest_brevet', value: next,
            })}
          />
        </>
      )}

      {contact.instructor && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 2, padding: '6px 0' }}>
          <div style={{ fontSize: 11, color: 'var(--text-tertiary, #888)', letterSpacing: 0.2 }}>
            Status
          </div>
          <button
            type="button"
            onClick={() => void toggleActive()}
            disabled={toggling}
            style={{
              font: 'inherit',
              fontSize: 13,
              padding: '4px 6px',
              margin: 0,
              border: '1px solid var(--border-strong, #ccc)',
              borderRadius: 4,
              background: 'transparent',
              textAlign: 'left',
              cursor: toggling ? 'wait' : 'pointer',
              color: contact.instructor.active
                ? 'var(--text-primary, #222)'
                : 'var(--text-tertiary, #888)',
              width: 'fit-content',
            }}
          >
            {contact.instructor.active ? 'Aktiv ✓' : 'Inaktiv —'}
          </button>
        </div>
      )}
    </SidebarSection>
  )
}
