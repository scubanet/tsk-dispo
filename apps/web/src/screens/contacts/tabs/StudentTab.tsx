/**
 * StudentTab — pipeline, tauchen, and candidate data.
 * Visible for contacts with student or candidate roles.
 */

import type { ContactWithSidecars } from '@/types/contacts'
import { InlineTextField } from '@/foundation/compounds/InlineTextField'
import { InlineSelectField } from '@/foundation/compounds/InlineSelectField'
import { updateStudentField } from '@/lib/contactQueries'

const PIPELINE_STAGES = [
  { value: 'lead', label: 'Lead' },
  { value: 'qualified', label: 'Qualifiziert' },
  { value: 'opportunity', label: 'Opportunity' },
  { value: 'customer', label: 'Kunde' },
  { value: 'candidate', label: 'Kandidat' },
  { value: 'lost', label: 'Verloren' },
]

interface Props {
  contact: ContactWithSidecars
  onUpdated: () => void
}

export function StudentTab({ contact, onUpdated }: Props) {
  const student = contact.student

  async function saveStudent<K extends Parameters<typeof updateStudentField>[1]>(
    field: K,
    value: Parameters<typeof updateStudentField<K>>[2],
  ) {
    await updateStudentField(contact.id, field, value)
    onUpdated()
  }

  return (
    <div className="contact-tab-body">
      {/* ── Pipeline ─────────────────────────────── */}
      <section className="contact-section">
        <h2 className="contact-section__title">Pipeline</h2>
        <InlineSelectField
          label="Pipeline-Phase"
          value={student?.pipeline_stage}
          options={PIPELINE_STAGES}
          allowEmpty
          onCommit={async (v) => saveStudent('pipeline_stage', v || null)}
        />
        <InlineTextField
          label="Lead-Quelle"
          value={student?.lead_source}
          onCommit={async (v) => saveStudent('lead_source', v || null)}
          placeholder="z. B. Empfehlung, Website"
        />
      </section>

      {/* ── Tauchen ──────────────────────────────── */}
      <section className="contact-section">
        <h2 className="contact-section__title">Tauchen</h2>
        <InlineTextField
          label="Höchstes Brevet"
          value={student?.highest_brevet}
          onCommit={async (v) => saveStudent('highest_brevet', v || null)}
          placeholder="z. B. OWD, AOWD, Rescue"
        />
        <InlineTextField
          label="Intake-Status"
          value={student?.intake_status}
          onCommit={async (v) => saveStudent('intake_status', v || null)}
        />
        <InlineTextField
          label="Versicherung"
          value={student?.insurance_provider}
          onCommit={async (v) => saveStudent('insurance_provider', v || null)}
          placeholder="z. B. DAN"
        />
        <InlineTextField
          label="Ärztliches Attest"
          value={student?.medical_clearance_at}
          onCommit={async (v) => saveStudent('medical_clearance_at', v || null)}
          placeholder="JJJJ-MM-TT"
        />
      </section>
    </div>
  )
}
