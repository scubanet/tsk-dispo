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
}

const EMPTY: Form = {
  channel: 'note',
  direction: 'outbound',
  occurred_on: '',
  subject: '',
  body: '',
  duration_minutes: '',
  outcome: '',
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

interface Props {
  open: boolean
  onClose: () => void
  onSaved: () => void
  contactId: string
  /** When set, edits an existing entry. */
  entryId?: string | null
  /** Default-Assessor (instructor_id) zum Setzen von created_by */
  createdById?: string | null
}

export function CommunicationEditSheet({ open, onClose, onSaved, contactId, entryId, createdById }: Props) {
  const isEdit = !!entryId
  const [form, setForm] = useState<Form>(EMPTY)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!open) return
    setError(null)
    if (entryId) {
      supabase
        .from('communication_entries')
        .select('channel, direction, occurred_on, subject, body, duration_minutes, outcome')
        .eq('id', entryId)
        .single()
        .then(({ data }) => {
          if (!data) return
          const d = data as any
          setForm({
            channel: d.channel ?? 'note',
            direction: d.direction ?? 'outbound',
            occurred_on: d.occurred_on ? toLocal(d.occurred_on) : '',
            subject: d.subject ?? '',
            body: d.body ?? '',
            duration_minutes: d.duration_minutes != null ? String(d.duration_minutes) : '',
            outcome: d.outcome ?? '',
          })
        })
    } else {
      setForm({ ...EMPTY, occurred_on: nowLocal() })
    }
  }, [open, entryId])

  function set<K extends keyof Form>(k: K, v: Form[K]) {
    setForm((prev) => ({ ...prev, [k]: v }))
  }

  async function save() {
    setSaving(true)
    setError(null)
    const payload = {
      contact_id: contactId,
      channel: form.channel,
      direction: form.direction,
      occurred_on: form.occurred_on ? new Date(form.occurred_on).toISOString() : new Date().toISOString(),
      subject: form.subject.trim() || null,
      body: form.body.trim() || null,
      duration_minutes: form.duration_minutes ? Number(form.duration_minutes) : null,
      outcome: form.outcome.trim() || null,
      created_by: createdById ?? null,
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

        <Field label="Datum & Uhrzeit">
          <input
            type="datetime-local"
            value={form.occurred_on}
            onChange={(e) => set('occurred_on', e.target.value)}
            style={inputStyle}
          />
        </Field>

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
