import { useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Sheet } from '@/components/Sheet'
import { Icon } from '@/components/Icon'
import { supabase } from '@/lib/supabase'

interface Form {
  // 1. Instructor-Status
  instructor_status: string
  // 2. Mindestalter
  min_age_confirmed: boolean
  // 3. Medical
  medical_received: boolean
  medical_signed: boolean
  medical_signed_on: string  // ISO date
  medical_doctor_required: boolean
  medical_doctor_signed: boolean
  medical_notes: string
  // 4. Brevetierter Taucher seit ≥ 6 Mt
  certified_diver_since: string  // ISO date
  // 5. EFR
  efr_kind: string
  efr_completed_on: string
  // 6. Nicht-PADI Brevets
  non_padi_certs_seen: boolean
  non_padi_certs_notes: string
  // Sonstiges
  logbook_seen: boolean
  logbook_dives_count: string
  id_seen: boolean
  id_kind: string
  insurance_proof: boolean
  insurance_provider: string
  insurance_valid_to: string
  liability_signed: boolean
  safe_diving_signed: boolean
  notes: string
  checked_on: string
}

const EMPTY: Form = {
  instructor_status: '',
  min_age_confirmed: false,
  medical_received: false,
  medical_signed: false,
  medical_signed_on: '',
  medical_doctor_required: false,
  medical_doctor_signed: false,
  medical_notes: '',
  certified_diver_since: '',
  efr_kind: '',
  efr_completed_on: '',
  non_padi_certs_seen: false,
  non_padi_certs_notes: '',
  logbook_seen: false,
  logbook_dives_count: '',
  id_seen: false,
  id_kind: '',
  insurance_proof: false,
  insurance_provider: '',
  insurance_valid_to: '',
  liability_signed: false,
  safe_diving_signed: false,
  notes: '',
  checked_on: '',
}

const INSTRUCTOR_STATUS_CODES = ['divemaster', 'assistant_instructor', 'padi_instructor', 'other_org_6m', 'none'] as const
const EFR_KIND_CODES = ['primary_secondary', 'efri', 'hlw_instructor_other'] as const

const inputStyle = {
  padding: '8px 10px',
  borderRadius: 8,
  border: '0.5px solid var(--hairline)',
  background: 'var(--surface-strong)',
  color: 'var(--ink)',
  font: 'inherit',
  fontSize: 13.5,
  width: '100%',
}

interface Props {
  open: boolean
  onClose: () => void
  onSaved: () => void
  /** Wenn gesetzt: Intake-Checkliste an einer konkreten Kurs-Teilnahme. (preferred) */
  courseParticipantId?: string | null
  /** Legacy: Intake auf Schüler-Ebene (1:1). Nur wenn kein courseParticipantId. */
  studentId?: string | null
  checkedById?: string | null
}

export function IntakeChecklistSheet({ open, onClose, onSaved, courseParticipantId, studentId, checkedById }: Props) {
  const { t } = useTranslation()
  const placeholderChoose = `— ${t('enroll.please_choose')} —`
  const INSTRUCTOR_STATUS = [
    { code: '', label: placeholderChoose },
    ...INSTRUCTOR_STATUS_CODES.map((code) => ({ code, label: t(`intake.instructor_status_${code}`) })),
  ]
  const EFR_KIND = [
    { code: '', label: placeholderChoose },
    ...EFR_KIND_CODES.map((code) => ({ code, label: t(`intake.efr_kind_${code}`) })),
  ]
  const useCourseParticipant = !!courseParticipantId
  const [form, setForm] = useState<Form>(EMPTY)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [hasRow, setHasRow] = useState(false)

  useEffect(() => {
    if (!open) return
    setError(null)
    let q = supabase.from('intake_checklists').select('*')
    if (useCourseParticipant) {
      q = q.eq('course_participant_id', courseParticipantId!)
    } else if (studentId) {
      q = q.eq('student_id', studentId).is('course_participant_id', null)
    }
    q.maybeSingle()
      .then(({ data }) => {
        if (data) {
          const d = data as any
          setHasRow(true)
          setForm({
            instructor_status: d.instructor_status ?? '',
            min_age_confirmed: !!d.min_age_confirmed,
            medical_received: !!d.medical_received,
            medical_signed: !!d.medical_signed,
            medical_signed_on: d.medical_signed_on ?? '',
            medical_doctor_required: !!d.medical_doctor_required,
            medical_doctor_signed: !!d.medical_doctor_signed,
            medical_notes: d.medical_notes ?? '',
            certified_diver_since: d.certified_diver_since ?? '',
            efr_kind: d.efr_kind ?? '',
            efr_completed_on: d.efr_completed_on ?? '',
            non_padi_certs_seen: !!d.non_padi_certs_seen,
            non_padi_certs_notes: d.non_padi_certs_notes ?? '',
            logbook_seen: !!d.logbook_seen,
            logbook_dives_count: d.logbook_dives_count != null ? String(d.logbook_dives_count) : '',
            id_seen: !!d.id_seen,
            id_kind: d.id_kind ?? '',
            insurance_proof: !!d.insurance_proof,
            insurance_provider: d.insurance_provider ?? '',
            insurance_valid_to: d.insurance_valid_to ?? '',
            liability_signed: !!d.liability_signed,
            safe_diving_signed: !!d.safe_diving_signed,
            notes: d.notes ?? '',
            checked_on: d.checked_on ?? '',
          })
        } else {
          setHasRow(false)
          setForm({ ...EMPTY, checked_on: new Date().toISOString().slice(0, 10) })
        }
      })
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, studentId, courseParticipantId])

  function set<K extends keyof Form>(k: K, v: Form[K]) {
    setForm((prev) => ({ ...prev, [k]: v }))
  }

  async function save() {
    setSaving(true)
    setError(null)
    const payload: Record<string, unknown> = {
      // Entweder course_participant_id (preferred) oder student_id (Legacy)
      course_participant_id: useCourseParticipant ? courseParticipantId : null,
      student_id: useCourseParticipant ? null : studentId,
      instructor_status: form.instructor_status || null,
      min_age_confirmed: form.min_age_confirmed,
      medical_received: form.medical_received,
      medical_signed: form.medical_signed,
      medical_signed_on: form.medical_signed_on || null,
      medical_doctor_required: form.medical_doctor_required,
      medical_doctor_signed: form.medical_doctor_signed,
      medical_notes: form.medical_notes.trim() || null,
      certified_diver_since: form.certified_diver_since || null,
      efr_kind: form.efr_kind || null,
      efr_completed_on: form.efr_completed_on || null,
      non_padi_certs_seen: form.non_padi_certs_seen,
      non_padi_certs_notes: form.non_padi_certs_notes.trim() || null,
      logbook_seen: form.logbook_seen,
      logbook_dives_count: form.logbook_dives_count ? Number(form.logbook_dives_count) : null,
      id_seen: form.id_seen,
      id_kind: form.id_kind || null,
      insurance_proof: form.insurance_proof,
      insurance_provider: form.insurance_provider.trim() || null,
      insurance_valid_to: form.insurance_valid_to || null,
      liability_signed: form.liability_signed,
      safe_diving_signed: form.safe_diving_signed,
      notes: form.notes.trim() || null,
      checked_by_id: checkedById ?? null,
      checked_on: form.checked_on || null,
    }
    let updateQ = supabase.from('intake_checklists').update(payload)
    if (useCourseParticipant) {
      updateQ = updateQ.eq('course_participant_id', courseParticipantId!)
    } else {
      updateQ = updateQ.eq('student_id', studentId!).is('course_participant_id', null)
    }
    const { error: e } = hasRow
      ? await updateQ
      : await supabase.from('intake_checklists').insert(payload)
    if (e) { setError(e.message); setSaving(false); return }
    setSaving(false)
    onSaved()
    onClose()
  }

  return (
    <Sheet open={open} onClose={onClose} title={t('intake.title')} width={620}>
      <div style={{ display: 'grid', gap: 16 }}>
        <Section title={t('intake.section_1_instructor_status')}>
          <Field label={t('intake.field_status')}>
            <select value={form.instructor_status} onChange={(e) => set('instructor_status', e.target.value)} style={inputStyle}>
              {INSTRUCTOR_STATUS.map((s) => <option key={s.code} value={s.code}>{s.label}</option>)}
            </select>
          </Field>
        </Section>

        <Section title={t('intake.section_2_min_age')}>
          <Toggle
            label={t('intake.toggle_min18_confirmed')}
            checked={form.min_age_confirmed}
            onChange={(v) => set('min_age_confirmed', v)}
          />
        </Section>

        <Section title={t('intake.section_3_medical')}>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <Toggle label={t('intake.toggle_medical_received')} checked={form.medical_received} onChange={(v) => set('medical_received', v)} />
            <Toggle label={t('intake.toggle_medical_doctor_signed')} checked={form.medical_doctor_signed} onChange={(v) => set('medical_doctor_signed', v)} />
          </div>
          <Field label={t('intake.field_medical_signed_on')}>
            <input type="date" value={form.medical_signed_on} onChange={(e) => set('medical_signed_on', e.target.value)} style={inputStyle} />
          </Field>
          <Field label={t('intake.field_medical_notes')}>
            <textarea value={form.medical_notes} onChange={(e) => set('medical_notes', e.target.value)} rows={2} style={{ ...inputStyle, resize: 'vertical' }} />
          </Field>
        </Section>

        <Section title={t('intake.section_4_diver_6mo')}>
          <Field label={t('intake.field_first_cert')}>
            <input type="date" value={form.certified_diver_since} onChange={(e) => set('certified_diver_since', e.target.value)} style={inputStyle} />
          </Field>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 120px', gap: 12 }}>
            <Toggle label={t('intake.toggle_logbook_seen')} checked={form.logbook_seen} onChange={(v) => set('logbook_seen', v)} />
            <Field label={t('intake.field_dive_count')}>
              <input type="number" min={0} value={form.logbook_dives_count} onChange={(e) => set('logbook_dives_count', e.target.value)} style={inputStyle} placeholder={t('intake.dive_count_placeholder')} />
            </Field>
          </div>
        </Section>

        <Section title={t('intake.section_5_first_aid')}>
          <Field label={t('intake.field_qualification')}>
            <select value={form.efr_kind} onChange={(e) => set('efr_kind', e.target.value)} style={inputStyle}>
              {EFR_KIND.map((k) => <option key={k.code} value={k.code}>{k.label}</option>)}
            </select>
          </Field>
          <Field label={t('intake.field_efr_completed_on')}>
            <input type="date" value={form.efr_completed_on} onChange={(e) => set('efr_completed_on', e.target.value)} style={inputStyle} />
          </Field>
        </Section>

        <Section title={t('intake.section_6_other_certs')}>
          <Toggle
            label={t('intake.toggle_certs_received')}
            checked={form.non_padi_certs_seen}
            onChange={(v) => set('non_padi_certs_seen', v)}
          />
          <Field label={t('intake.field_certs_which')}>
            <input value={form.non_padi_certs_notes} onChange={(e) => set('non_padi_certs_notes', e.target.value)} style={inputStyle} />
          </Field>
        </Section>

        <Section title={t('intake.section_releases')}>
          <Toggle label={t('intake.toggle_liability')} checked={form.liability_signed} onChange={(v) => set('liability_signed', v)} />
          <Toggle label={t('intake.toggle_safe_diving')} checked={form.safe_diving_signed} onChange={(v) => set('safe_diving_signed', v)} />
        </Section>

        <Section title={t('intake.section_general')}>
          <Field label={t('cert_edit.label_notes')}>
            <textarea value={form.notes} onChange={(e) => set('notes', e.target.value)} rows={3} style={{ ...inputStyle, resize: 'vertical' }} />
          </Field>
          <Field label={t('intake.field_checked_on')}>
            <input type="date" value={form.checked_on} onChange={(e) => set('checked_on', e.target.value)} style={inputStyle} />
          </Field>
        </Section>

        {error && <div className="chip chip-red">{error}</div>}

        <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
          <button className="btn-secondary btn" onClick={onClose}>{t('common.cancel')}</button>
          <button className="btn" onClick={save} disabled={saving} style={{ flex: 1 }}>
            {saving ? t('common.saving') : <><Icon name="check" size={12} /> {t('common.save')}</>}
          </button>
        </div>
      </div>
    </Sheet>
  )
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div style={{ display: 'grid', gap: 10 }}>
      <div className="caption-2" style={{ fontWeight: 600, opacity: 0.8, letterSpacing: '.04em' }}>
        {title.toUpperCase()}
      </div>
      {children}
    </div>
  )
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <div className="caption-2" style={{ marginBottom: 4 }}>{label.toUpperCase()}</div>
      {children}
    </div>
  )
}

function Toggle({ label, checked, onChange }: { label: string; checked: boolean; onChange: (v: boolean) => void }) {
  return (
    <label
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: 8,
        padding: '6px 10px',
        borderRadius: 8,
        border: '0.5px solid var(--hairline)',
        background: checked ? 'rgba(52,199,89,.16)' : 'transparent',
        cursor: 'pointer',
        userSelect: 'none',
        fontSize: 13,
      }}
    >
      <input type="checkbox" checked={checked} onChange={(e) => onChange(e.target.checked)} style={{ cursor: 'pointer' }} />
      {label}
    </label>
  )
}
