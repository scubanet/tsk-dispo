/**
 * StudentTab — pipeline, tauchen, and candidate data.
 * Visible for contacts with student or candidate roles.
 */

import { useTranslation } from 'react-i18next'
import type { ContactWithSidecars } from '@/types/contacts'
import { InlineTextField } from '@/foundation/patterns/InlineTextField'
import { InlineSelectField } from '@/foundation/patterns/InlineSelectField'
import { updateStudentField } from '@/lib/contactQueries'

interface Props {
  contact: ContactWithSidecars
  onUpdated: () => void
}

export function StudentTab({ contact, onUpdated }: Props) {
  const { t } = useTranslation()
  const student = contact.student

  const PIPELINE_STAGES = [
    { value: 'lead', label: 'Lead' },
    { value: 'qualified', label: t('contacts.pipeline_qualified') },
    { value: 'opportunity', label: 'Opportunity' },
    { value: 'customer', label: t('contacts.pipeline_customer') },
    { value: 'candidate', label: t('contacts.role_candidate') },
    { value: 'lost', label: t('contacts.pipeline_lost') },
  ]

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
        <h2 className="contact-section__title">{t('contacts.section_pipeline')}</h2>
        <InlineSelectField
          label={t('contacts.field_pipeline_stage')}
          value={student?.pipeline_stage}
          options={PIPELINE_STAGES}
          allowEmpty
          onCommit={async (v) => saveStudent('pipeline_stage', v || null)}
        />
        <InlineTextField
          label={t('contacts.field_lead_source')}
          value={student?.lead_source}
          onCommit={async (v) => saveStudent('lead_source', v || null)}
          placeholder={t('contacts.lead_source_placeholder')}
        />
      </section>

      {/* ── Tauchen ──────────────────────────────── */}
      <section className="contact-section">
        <h2 className="contact-section__title">{t('contacts.section_diving')}</h2>
        <InlineTextField
          label={t('contacts.field_highest_brevet')}
          value={student?.highest_brevet}
          onCommit={async (v) => saveStudent('highest_brevet', v || null)}
          placeholder={t('contacts.highest_brevet_placeholder')}
        />
        <InlineTextField
          label={t('contacts.field_intake_status')}
          value={student?.intake_status}
          onCommit={async (v) => saveStudent('intake_status', v || null)}
        />
        <InlineTextField
          label={t('contacts.field_insurance')}
          value={student?.insurance_provider}
          onCommit={async (v) => saveStudent('insurance_provider', v || null)}
          placeholder={t('contacts.insurance_placeholder')}
        />
        <InlineTextField
          label={t('contacts.field_medical_clearance')}
          value={student?.medical_clearance_at}
          onCommit={async (v) => saveStudent('medical_clearance_at', v || null)}
          placeholder={t('contacts.birth_date_placeholder')}
        />
      </section>
    </div>
  )
}
