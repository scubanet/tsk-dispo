import { useEffect, useState } from 'react'
import { Sheet } from '@/components/Sheet'
import { Icon } from '@/components/Icon'
import { supabase } from '@/lib/supabase'

interface Form {
  first_name: string
  last_name: string
  email: string
  phone: string
  birthday: string
  padi_nr: string
  level: string
  notes: string
  active: boolean
}

const LEVELS = [
  'Anfänger',
  'Scuba Diver',
  'OWD',
  'AOWD',
  'Rescue Diver',
  'Master Scuba Diver',
  'DM',
  'AI',
  'OWSI',
  'MSDT',
  'IDC Staff',
  'MI',
  'CD',
] as const

interface Props {
  open: boolean
  onClose: () => void
  onSaved: (newId?: string) => void
  /** When set, edits an existing student. Otherwise creates new. */
  studentId?: string | null
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

const EMPTY: Form = {
  first_name: '',
  last_name: '',
  email: '',
  phone: '',
  birthday: '',
  padi_nr: '',
  level: 'Anfänger',
  notes: '',
  active: true,
}

export function StudentEditSheet({ open, onClose, onSaved, studentId }: Props) {
  const isEdit = !!studentId
  const [form, setForm] = useState<Form>(EMPTY)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!open) return
    setError(null)
    if (studentId) {
      supabase
        .from('students')
        .select('first_name, last_name, name, email, phone, birthday, padi_nr, level, notes, active')
        .eq('id', studentId)
        .single()
        .then(({ data }) => {
          if (!data) return
          // Fallback: legacy Daten ohne first/last → aus name splitten
          const first = (data as any).first_name?.trim() || (data.name ?? '').split(' ')[0] || ''
          const last  = (data as any).last_name?.trim()  || (data.name ?? '').split(' ').slice(1).join(' ') || ''
          setForm({
            first_name: first,
            last_name: last,
            email: data.email ?? '',
            phone: data.phone ?? '',
            birthday: data.birthday ?? '',
            padi_nr: data.padi_nr ?? '',
            level: data.level ?? 'Anfänger',
            notes: data.notes ?? '',
            active: !!data.active,
          })
        })
    } else {
      setForm(EMPTY)
    }
  }, [open, studentId])

  function set<K extends keyof Form>(k: K, v: Form[K]) {
    setForm((prev) => ({ ...prev, [k]: v }))
  }

  async function save() {
    if (!form.first_name.trim()) return
    setSaving(true)
    setError(null)
    const payload = {
      first_name: form.first_name.trim(),
      last_name: form.last_name.trim(),
      email: form.email.trim() || null,
      phone: form.phone.trim() || null,
      birthday: form.birthday || null,
      padi_nr: form.padi_nr.trim() || null,
      level: form.level || 'Anfänger',
      notes: form.notes.trim() || null,
      active: form.active,
    }
    if (isEdit) {
      const { error: updErr } = await supabase
        .from('students')
        .update(payload)
        .eq('id', studentId!)
      if (updErr) { setError(updErr.message); setSaving(false); return }
      setSaving(false); onSaved(); onClose()
    } else {
      const { data: created, error: insErr } = await supabase
        .from('students')
        .insert(payload)
        .select('id')
        .single()
      if (insErr) { setError(insErr.message); setSaving(false); return }
      setSaving(false); onSaved(created?.id); onClose()
    }
  }

  async function deleteStudent() {
    if (!isEdit) return
    if (!confirm('Schüler wirklich löschen? Falls er bereits Kursen zugewiesen ist, wird das Löschen blockiert — markier ihn dann lieber als inaktiv.')) return
    setSaving(true)
    const { error: delErr } = await supabase.from('students').delete().eq('id', studentId!)
    setSaving(false)
    if (delErr) { setError(delErr.message); return }
    onSaved()
    onClose()
  }

  return (
    <Sheet open={open} onClose={onClose} title={isEdit ? 'Schüler bearbeiten' : 'Neuer Schüler'} width={520}>
      <div style={{ display: 'grid', gap: 14 }}>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
          <div>
            <Label>Vorname</Label>
            <input
              value={form.first_name}
              onChange={(e) => set('first_name', e.target.value)}
              style={inputStyle}
            />
          </div>
          <div>
            <Label>Nachname</Label>
            <input
              value={form.last_name}
              onChange={(e) => set('last_name', e.target.value)}
              style={inputStyle}
            />
          </div>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
          <div>
            <Label>Email</Label>
            <input
              type="email"
              value={form.email}
              onChange={(e) => set('email', e.target.value)}
              placeholder="name@example.ch"
              style={inputStyle}
            />
          </div>
          <div>
            <Label>Telefon / WhatsApp</Label>
            <input
              value={form.phone}
              onChange={(e) => set('phone', e.target.value)}
              placeholder="+41 …"
              style={inputStyle}
            />
          </div>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
          <div>
            <Label>Geburtstag</Label>
            <input
              type="date"
              value={form.birthday}
              onChange={(e) => set('birthday', e.target.value)}
              style={inputStyle}
            />
          </div>
          <div>
            <Label>PADI-Nr (falls vorhanden)</Label>
            <input
              value={form.padi_nr}
              onChange={(e) => set('padi_nr', e.target.value)}
              placeholder="optional"
              style={inputStyle}
            />
          </div>
        </div>

        <div>
          <Label>Aktueller Level</Label>
          <select value={form.level} onChange={(e) => set('level', e.target.value)} style={inputStyle}>
            {LEVELS.map((l) => <option key={l} value={l}>{l}</option>)}
          </select>
          <div className="caption-2" style={{ marginTop: 4 }}>
            Der höchste bisher erreichte Tauchschein-Level. Updaten wenn ein neuer Schein erworben wird.
          </div>
        </div>

        <div>
          <Label>Notizen (medizinisch, Allergien, etc.)</Label>
          <textarea
            value={form.notes}
            onChange={(e) => set('notes', e.target.value)}
            rows={3}
            style={{ ...inputStyle, resize: 'vertical' }}
          />
        </div>

        <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
          <input
            id="active"
            type="checkbox"
            checked={form.active}
            onChange={(e) => set('active', e.target.checked)}
          />
          <label htmlFor="active">Aktiv (erscheint in Anmelde-Vorschlägen)</label>
        </div>

        {error && <div className="chip chip-red">{error}</div>}

        <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
          {isEdit && (
            <button
              className="btn-secondary btn"
              onClick={deleteStudent}
              disabled={saving}
              style={{ color: '#FF3B30' }}
            >
              <Icon name="x" size={12} /> Löschen
            </button>
          )}
          <button className="btn-secondary btn" onClick={onClose}>Abbrechen</button>
          <button
            className="btn"
            onClick={save}
            disabled={saving || !form.first_name.trim()}
            style={{ flex: 1 }}
          >
            {saving ? 'Speichere…' : isEdit ? 'Speichern' : 'Anlegen'}
          </button>
        </div>
      </div>
    </Sheet>
  )
}

function Label({ children }: { children: string }) {
  return <div className="caption-2" style={{ marginBottom: 4 }}>{children.toUpperCase()}</div>
}
