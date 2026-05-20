/**
 * InstructorTab — Stammdaten des contact_instructor Sidecars.
 * Sichtbar wenn contact.roles enthält 'instructor'.
 *
 * Felder: PADI-Level, PADI-Pro-Nr, Stundensatz/Tagessatz,
 * Hire/Termination-Date, Emergency-Contact, interne Notizen, Active.
 */

import { useTranslation } from 'react-i18next'
import type { ContactWithSidecars } from '@/types/contacts'
import { InlineTextField } from '@/foundation/patterns/InlineTextField'
import { InlineSelectField } from '@/foundation/patterns/InlineSelectField'
import { updateInstructorField } from '@/lib/contactQueries'

interface Props {
  contact: ContactWithSidecars
  onUpdated: () => void
}

/**
 * padi_level enum values — kanonische PADI-Hierarchie (vom Divemaster bis Course Director),
 * plus Nicht-Pro-Slots. Enum hat zusätzlich Legacy-Werte aus Migration 0001 ('Instructor',
 * 'Staff Instructor', 'Andere Funktion'), die wir in 0087 auf die neuen Pendants mappen.
 */
const PADI_LEVELS = [
  { value: 'DM',              label: 'DM (Divemaster)' },
  { value: 'AI',              label: 'AI (Assistant Instructor)' },
  { value: 'OWSI',            label: 'OWSI (Open Water Scuba Instructor)' },
  { value: 'MSDT',            label: 'MSDT (Master Scuba Diver Trainer)' },
  { value: 'IDC Staff',       label: 'IDC Staff Instructor' },
  { value: 'MI',              label: 'MI (Master Instructor)' },
  { value: 'CD',              label: 'CD (Course Director)' },
  { value: 'Shop Staff',      label: 'Shop Staff' },
  { value: 'Andere Funktion', label: 'Andere Funktion' },
]

export function InstructorTab({ contact, onUpdated }: Props) {
  const { t } = useTranslation()
  const inst = contact.instructor

  async function save<K extends Parameters<typeof updateInstructorField>[1]>(
    field: K,
    value: Parameters<typeof updateInstructorField<K>>[2],
  ) {
    await updateInstructorField(contact.id, field, value)
    onUpdated()
  }

  return (
    <div className="contact-tab-body">
      {/* ── PADI ─────────────────────────────────── */}
      <section className="contact-section">
        <h2 className="contact-section__title">{t('contacts.section_padi')}</h2>
        <InlineSelectField
          label={t('contacts.field_padi_level')}
          value={inst?.padi_level}
          options={PADI_LEVELS}
          allowEmpty
          onCommit={async (v) => save('padi_level', v || null)}
        />
        <InlineTextField
          label={t('contacts.field_padi_pro_number')}
          value={inst?.padi_pro_number}
          onCommit={async (v) => save('padi_pro_number', v || null)}
          placeholder={t('contacts.padi_pro_placeholder')}
        />
      </section>

      {/* ── Vergütung ────────────────────────────── */}
      <section className="contact-section">
        <h2 className="contact-section__title">{t('contacts.section_compensation')}</h2>
        <InlineTextField
          label={t('contacts.field_hourly_rate')}
          value={inst?.hourly_rate_chf?.toString() ?? null}
          onCommit={async (v) => {
            const num = v.trim() === '' ? null : Number(v)
            if (num !== null && Number.isNaN(num)) return
            await save('hourly_rate_chf', num)
          }}
          placeholder={t('contacts.rate_placeholder')}
        />
        <InlineTextField
          label={t('contacts.field_daily_rate')}
          value={inst?.daily_rate_chf?.toString() ?? null}
          onCommit={async (v) => {
            const num = v.trim() === '' ? null : Number(v)
            if (num !== null && Number.isNaN(num)) return
            await save('daily_rate_chf', num)
          }}
          placeholder={t('contacts.rate_placeholder')}
        />
      </section>

      {/* ── Anstellung ───────────────────────────── */}
      <section className="contact-section">
        <h2 className="contact-section__title">{t('contacts.section_employment')}</h2>
        <InlineSelectField
          label={t('contacts.field_active')}
          value={inst?.active ? 'true' : 'false'}
          options={[
            { value: 'true', label: t('contacts.active_yes') },
            { value: 'false', label: t('contacts.active_no') },
          ]}
          onCommit={async (v) => save('active', v === 'true')}
        />
        <InlineTextField
          label={t('contacts.field_hire_date')}
          value={inst?.hire_date}
          onCommit={async (v) => save('hire_date', v || null)}
          placeholder="YYYY-MM-DD"
        />
        <InlineTextField
          label={t('contacts.field_termination_date')}
          value={inst?.termination_date}
          onCommit={async (v) => save('termination_date', v || null)}
          placeholder="YYYY-MM-DD"
        />
      </section>

      {/* ── Notfallkontakt ───────────────────────── */}
      <section className="contact-section">
        <h2 className="contact-section__title">{t('contacts.section_emergency')}</h2>
        <InlineTextField
          label={t('contacts.field_emergency_name')}
          value={inst?.emergency_contact_name}
          onCommit={async (v) => save('emergency_contact_name', v || null)}
        />
        <InlineTextField
          label={t('contacts.field_emergency_phone')}
          value={inst?.emergency_contact_phone}
          onCommit={async (v) => save('emergency_contact_phone', v || null)}
        />
      </section>

      {/* ── Interne Notizen ──────────────────────── */}
      <section className="contact-section">
        <h2 className="contact-section__title">{t('contacts.section_notes_internal')}</h2>
        <InlineTextField
          label={t('contacts.field_notes_internal')}
          value={inst?.notes_internal}
          onCommit={async (v) => save('notes_internal', v || null)}
          multiline
          placeholder={t('contacts.notes_internal_placeholder')}
        />
      </section>
    </div>
  )
}
