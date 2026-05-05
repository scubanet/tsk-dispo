import { useEffect, useState } from 'react'
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

const INSTRUCTOR_STATUS = [
  { code: '',                    label: '— bitte wählen —' },
  { code: 'divemaster',           label: 'PADI Divemaster' },
  { code: 'assistant_instructor', label: 'PADI Assistant Instructor' },
  { code: 'padi_instructor',      label: 'PADI Instructor' },
  { code: 'other_org_6m',         label: '≥ 6 Mt. Tauchlehrer anderer Org (Crossover)' },
  { code: 'none',                 label: 'Keine Lehrer-Vorqualifikation' },
]

const EFR_KIND = [
  { code: '',                     label: '— bitte wählen —' },
  { code: 'primary_secondary',     label: 'EFR Primary & Secondary (≤24 Mt.)' },
  { code: 'efri',                  label: 'Aktiver EFR Instructor' },
  { code: 'hlw_instructor_other',  label: 'HLW/Erste-Hilfe-Instructor anderer Org' },
]

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
  studentId: string
  checkedById?: string | null
}

export function IntakeChecklistSheet({ open, onClose, onSaved, studentId, checkedById }: Props) {
  const [form, setForm] = useState<Form>(EMPTY)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [hasRow, setHasRow] = useState(false)

  useEffect(() => {
    if (!open) return
    setError(null)
    supabase
      .from('intake_checklists')
      .select('*')
      .eq('student_id', studentId)
      .maybeSingle()
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
  }, [open, studentId])

  function set<K extends keyof Form>(k: K, v: Form[K]) {
    setForm((prev) => ({ ...prev, [k]: v }))
  }

  async function save() {
    setSaving(true)
    setError(null)
    const payload = {
      student_id: studentId,
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
    const { error: e } = hasRow
      ? await supabase.from('intake_checklists').update(payload).eq('student_id', studentId)
      : await supabase.from('intake_checklists').insert(payload)
    if (e) { setError(e.message); setSaving(false); return }
    setSaving(false)
    onSaved()
    onClose()
  }

  return (
    <Sheet open={open} onClose={onClose} title="Intake-Checkliste" width={620}>
      <div style={{ display: 'grid', gap: 16 }}>
        <Section title="1. Lehrer-Status (PADI IDC Pre-Req 1)">
          <Field label="Status">
            <select value={form.instructor_status} onChange={(e) => set('instructor_status', e.target.value)} style={inputStyle}>
              {INSTRUCTOR_STATUS.map((s) => <option key={s.code} value={s.code}>{s.label}</option>)}
            </select>
          </Field>
        </Section>

        <Section title="2. Mindestalter (≥ 18)">
          <Toggle
            label="Mindestalter 18 bestätigt"
            checked={form.min_age_confirmed}
            onChange={(v) => set('min_age_confirmed', v)}
          />
        </Section>

        <Section title="3. Medical Statement (Arzt-Attest, ≤ 12 Monate, zwingend)">
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <Toggle label="Medical erhalten" checked={form.medical_received} onChange={(v) => set('medical_received', v)} />
            <Toggle label="Vom Arzt unterschrieben" checked={form.medical_doctor_signed} onChange={(v) => set('medical_doctor_signed', v)} />
          </div>
          <Field label="Datum Arzt-Attest">
            <input type="date" value={form.medical_signed_on} onChange={(e) => set('medical_signed_on', e.target.value)} style={inputStyle} />
          </Field>
          <Field label="Notizen Medical">
            <textarea value={form.medical_notes} onChange={(e) => set('medical_notes', e.target.value)} rows={2} style={{ ...inputStyle, resize: 'vertical' }} />
          </Field>
        </Section>

        <Section title="4. Brevetierter Taucher (≥ 6 Monate)">
          <Field label="Erst-Brevetierung">
            <input type="date" value={form.certified_diver_since} onChange={(e) => set('certified_diver_since', e.target.value)} style={inputStyle} />
          </Field>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 120px', gap: 12 }}>
            <Toggle label="Logbuch gesehen" checked={form.logbook_seen} onChange={(v) => set('logbook_seen', v)} />
            <Field label="TG-Anzahl">
              <input type="number" min={0} value={form.logbook_dives_count} onChange={(e) => set('logbook_dives_count', e.target.value)} style={inputStyle} placeholder="z.B. 60" />
            </Field>
          </div>
        </Section>

        <Section title="5. Erste Hilfe / HLW (≤ 24 Monate)">
          <Field label="Qualifikation">
            <select value={form.efr_kind} onChange={(e) => set('efr_kind', e.target.value)} style={inputStyle}>
              {EFR_KIND.map((k) => <option key={k.code} value={k.code}>{k.label}</option>)}
            </select>
          </Field>
          <Field label="Datum Abschluss / aktuelle Zertifizierung">
            <input type="date" value={form.efr_completed_on} onChange={(e) => set('efr_completed_on', e.target.value)} style={inputStyle} />
          </Field>
        </Section>

        <Section title="6. Kopien qualifizierender nicht-PADI Brevets">
          <Toggle
            label="Brevets-Kopien erhalten"
            checked={form.non_padi_certs_seen}
            onChange={(v) => set('non_padi_certs_seen', v)}
          />
          <Field label="Welche (z.B. SDI OWD/AOWD/Rescue/DM)">
            <input value={form.non_padi_certs_notes} onChange={(e) => set('non_padi_certs_notes', e.target.value)} style={inputStyle} />
          </Field>
        </Section>

        <Section title="Releases">
          <Toggle label="Liability Release unterschrieben" checked={form.liability_signed} onChange={(v) => set('liability_signed', v)} />
          <Toggle label="Safe Diving Practices unterschrieben" checked={form.safe_diving_signed} onChange={(v) => set('safe_diving_signed', v)} />
        </Section>

        <Section title="Allgemein">
          <Field label="Notizen">
            <textarea value={form.notes} onChange={(e) => set('notes', e.target.value)} rows={3} style={{ ...inputStyle, resize: 'vertical' }} />
          </Field>
          <Field label="Geprüft am">
            <input type="date" value={form.checked_on} onChange={(e) => set('checked_on', e.target.value)} style={inputStyle} />
          </Field>
        </Section>

        {error && <div className="chip chip-red">{error}</div>}

        <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
          <button className="btn-secondary btn" onClick={onClose}>Abbrechen</button>
          <button className="btn" onClick={save} disabled={saving} style={{ flex: 1 }}>
            {saving ? 'Speichere…' : <><Icon name="check" size={12} /> Speichern</>}
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
