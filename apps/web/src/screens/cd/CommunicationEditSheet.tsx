import { useEffect, useState } from 'react'
import { Sheet } from '@/components/Sheet'
import { Icon } from '@/components/Icon'
import { supabase } from '@/lib/supabase'

export const CHANNELS = [
  { code: 'email',    label: 'Email',    icon: 'tag'      as const },
  { code: 'phone',    label: 'Telefon',  icon: 'users'    as const },
  { code: 'whatsapp', label: 'WhatsApp', icon: 'tag'      as const },
  { code: 'meeting',  label: 'Meeting',  icon: 'calendar' as const },
  { code: 'note',     label: 'Notiz',    icon: 'tag'      as const },
  { code: 'other',    label: 'Andere',   icon: 'tag'      as const },
]

export const DIRECTIONS = [
  { code: 'outbound', label: 'Ausgehend' },
  { code: 'inbound',  label: 'Eingehend' },
]

interface Form {
  channel: string
  direction: string
  occurred_on: string  // ISO datetime-local
  subject: string
  body: string
  duration_minutes: string
  outcome: string
  created_by: string  // instructor_id; '' = nicht erfasst
}

interface InstructorOption {
  id: string
  name: string
  active: boolean
}

const EMPTY: Form = {
  channel: 'note',
  direction: 'outbound',
  occurred_on: '',
  subject: '',
  body: '',
  duration_minutes: '',
  outcome: '',
  created_by: '',
}

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

interface PersonOption {
  id: string
  name: string
  is_student?: boolean
  is_candidate?: boolean
}

interface Props {
  open: boolean
  onClose: () => void
  onSaved: () => void
  /** Wenn gesetzt: Touchpoint hängt direkt an dieser Person. Sonst Person-Picker im Sheet. */
  contactId?: string | null
  /** When set, edits an existing entry. */
  entryId?: string | null
  /** Default-Assessor (instructor_id) zum Setzen von created_by */
  createdById?: string | null
}

export function CommunicationEditSheet({ open, onClose, onSaved, contactId, entryId, createdById }: Props) {
  const showPicker = !contactId
  const [pickedContactId, setPickedContactId] = useState<string>('')
  const [people, setPeople] = useState<PersonOption[]>([])
  const [pickerSearch, setPickerSearch] = useState('')
  const [instructors, setInstructors] = useState<InstructorOption[]>([])
  const isEdit = !!entryId
  const [form, setForm] = useState<Form>(EMPTY)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!open) return
    setError(null)
    setPickedContactId('')
    if (showPicker) {
      supabase
        .from('people')
        .select('id, name, is_student, is_candidate')
        .order('last_name')
        .order('first_name')
        .then(({ data }) => setPeople((data ?? []) as PersonOption[]))
    }
    supabase
      .from('instructors')
      .select('id, name, active')
      .eq('active', true)
      .order('name')
      .then(({ data }) => setInstructors((data ?? []) as InstructorOption[]))
    if (entryId) {
      supabase
        .from('communication_entries')
        .select('channel, direction, occurred_on, subject, body, duration_minutes, outcome, contact_id, created_by')
        .eq('id', entryId)
        .single()
        .then(({ data }) => {
          if (!data) return
          const d = data as any
          if (showPicker && d.contact_id) setPickedContactId(d.contact_id)
          setForm({
            channel: d.channel ?? 'note',
            direction: d.direction ?? 'outbound',
            occurred_on: d.occurred_on ? toLocal(d.occurred_on) : '',
            subject: d.subject ?? '',
            body: d.body ?? '',
            duration_minutes: d.duration_minutes != null ? String(d.duration_minutes) : '',
            outcome: d.outcome ?? '',
            created_by: d.created_by ?? '',
          })
        })
    } else {
      setForm({ ...EMPTY, occurred_on: nowLocal(), created_by: createdById ?? '' })
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, entryId])

  function set<K extends keyof Form>(k: K, v: Form[K]) {
    setForm((prev) => ({ ...prev, [k]: v }))
  }

  async function save() {
    const finalContactId = contactId ?? pickedContactId
    if (!finalContactId) {
      setError('Bitte eine Person wählen.')
      return
    }
    setSaving(true)
    setError(null)
    const payload = {
      contact_id: finalContactId,
      channel: form.channel,
      direction: form.direction,
      occurred_on: form.occurred_on ? new Date(form.occurred_on).toISOString() : new Date().toISOString(),
      subject: form.subject.trim() || null,
      body: form.body.trim() || null,
      duration_minutes: form.duration_minutes ? Number(form.duration_minutes) : null,
      outcome: form.outcome.trim() || null,
      created_by: form.created_by || createdById || null,
    }
    if (isEdit) {
      const { error: e } = await supabase.from('communication_entries').update(payload).eq('id', entryId!)
      if (e) { setError(e.message); setSaving(false); return }
    } else {
      const { error: e } = await supabase.from('communication_entries').insert(payload)
      if (e) { setError(e.message); setSaving(false); return }
    }
    setSaving(false)
    onSaved()
    onClose()
  }

  async function deleteEntry() {
    if (!isEdit) return
    if (!confirm('Eintrag wirklich löschen?')) return
    setSaving(true)
    const { error: e } = await supabase.from('communication_entries').delete().eq('id', entryId!)
    setSaving(false)
    if (e) { setError(e.message); return }
    onSaved()
    onClose()
  }

  const showDuration = form.channel === 'phone' || form.channel === 'meeting'

  return (
    <Sheet open={open} onClose={onClose} title={isEdit ? 'Touchpoint bearbeiten' : 'Neuer Touchpoint'} width={520}>
      <div style={{ display: 'grid', gap: 14 }}>
        {showPicker && (
          <Field label="Person">
            <input
              value={pickerSearch}
              onChange={(e) => setPickerSearch(e.target.value)}
              placeholder="Name suchen…"
              style={inputStyle}
            />
            <div style={{ marginTop: 6, maxHeight: 180, overflow: 'auto', display: 'grid', gap: 4 }}>
              {people
                .filter((p) => !pickerSearch || p.name.toLowerCase().includes(pickerSearch.toLowerCase()))
                .slice(0, 30)
                .map((p) => (
                  <button
                    key={p.id}
                    type="button"
                    onClick={() => setPickedContactId(p.id)}
                    style={{
                      textAlign: 'left',
                      padding: '6px 10px',
                      borderRadius: 6,
                      border: 0,
                      cursor: 'pointer',
                      background: pickedContactId === p.id ? 'var(--accent-soft)' : 'rgba(120,120,128,.08)',
                      color: pickedContactId === p.id ? 'var(--accent)' : 'var(--ink)',
                      fontWeight: pickedContactId === p.id ? 600 : 400,
                      fontSize: 13,
                    }}
                  >
                    {p.name}
                    {p.is_candidate && <span style={{ marginLeft: 8, opacity: 0.6, fontSize: 11 }}>· Kandidat</span>}
                    {p.is_student && !p.is_candidate && <span style={{ marginLeft: 8, opacity: 0.6, fontSize: 11 }}>· Schüler</span>}
                  </button>
                ))}
            </div>
          </Field>
        )}

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
          <Field label="Kanal">
            <select value={form.channel} onChange={(e) => set('channel', e.target.value)} style={inputStyle}>
              {CHANNELS.map((c) => <option key={c.code} value={c.code}>{c.label}</option>)}
            </select>
          </Field>
          <Field label="Richtung">
            <select value={form.direction} onChange={(e) => set('direction', e.target.value)} style={inputStyle}>
              {DIRECTIONS.map((d) => <option key={d.code} value={d.code}>{d.label}</option>)}
            </select>
          </Field>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
          <Field label="Datum & Uhrzeit">
            <input
              type="datetime-local"
              value={form.occurred_on}
              onChange={(e) => set('occurred_on', e.target.value)}
              style={inputStyle}
            />
          </Field>
          <Field label="Bearbeiter (TSK-Team)">
            <select value={form.created_by} onChange={(e) => set('created_by', e.target.value)} style={inputStyle}>
              <option value="">— wählen —</option>
              {instructors.map((i) => <option key={i.id} value={i.id}>{i.name}</option>)}
            </select>
          </Field>
        </div>

        <Field label="Betreff">
          <input
            value={form.subject}
            onChange={(e) => set('subject', e.target.value)}
            placeholder={form.channel === 'meeting' ? 'z.B. Kennenlern-Gespräch' : 'kurze Beschreibung'}
            style={inputStyle}
          />
        </Field>

        <Field label="Inhalt / Notiz">
          <textarea
            value={form.body}
            onChange={(e) => set('body', e.target.value)}
            rows={4}
            style={{ ...inputStyle, resize: 'vertical' }}
          />
        </Field>

        {showDuration && (
          <Field label="Dauer (Minuten)">
            <input
              type="number"
              min={0}
              value={form.duration_minutes}
              onChange={(e) => set('duration_minutes', e.target.value)}
              placeholder="z.B. 15"
              style={{ ...inputStyle, width: 120 }}
            />
          </Field>
        )}

        <Field label="Outcome / Ergebnis">
          <input
            value={form.outcome}
            onChange={(e) => set('outcome', e.target.value)}
            placeholder="z.B. interessiert, follow-up nötig, kein Interesse, …"
            style={inputStyle}
          />
        </Field>

        {error && <div className="chip chip-red">{error}</div>}

        <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
          {isEdit && (
            <button
              className="btn-secondary btn"
              onClick={deleteEntry}
              disabled={saving}
              style={{ color: '#FF3B30' }}
            >
              <Icon name="x" size={12} /> Löschen
            </button>
          )}
          <button className="btn-secondary btn" onClick={onClose}>Abbrechen</button>
          <button className="btn" onClick={save} disabled={saving} style={{ flex: 1 }}>
            {saving ? 'Speichere…' : isEdit ? 'Speichern' : 'Anlegen'}
          </button>
        </div>
      </div>
    </Sheet>
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

// Helper: ISO → datetime-local Format (yyyy-MM-ddTHH:mm)
function toLocal(iso: string): string {
  const d = new Date(iso)
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`
}
function nowLocal(): string {
  return toLocal(new Date().toISOString())
}
