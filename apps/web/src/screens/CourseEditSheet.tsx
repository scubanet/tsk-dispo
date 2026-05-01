import { useEffect, useState } from 'react'
import { Sheet } from '@/components/Sheet'
import { Icon } from '@/components/Icon'
import { supabase } from '@/lib/supabase'

interface CourseType { id: string; code: string; label: string }
interface Instructor { id: string; name: string; padi_level: string }
interface Conflict {
  conflicting_course_id: string
  conflicting_course_title: string
  conflicting_role: string
}

interface Props {
  open: boolean
  onClose: () => void
  onCreated: () => void
}

const inputStyle = {
  padding: '8px 10px',
  borderRadius: 8,
  border: '0.5px solid var(--hairline)',
  background: 'var(--surface-strong)',
  color: 'var(--ink)',
  font: 'inherit',
  fontSize: 13.5,
}

export function CourseEditSheet({ open, onClose, onCreated }: Props) {
  const [types, setTypes] = useState<CourseType[]>([])
  const [instructors, setInstructors] = useState<Instructor[]>([])
  const [typeId, setTypeId] = useState('')
  const [title, setTitle] = useState('')
  const [startDate, setStartDate] = useState(new Date().toISOString().slice(0, 10))
  const [haupt, setHaupt] = useState('')
  const [conflicts, setConflicts] = useState<Conflict[]>([])
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    if (!open) return
    supabase
      .from('course_types')
      .select('id, code, label')
      .eq('active', true)
      .order('code')
      .then(({ data }) => setTypes((data ?? []) as CourseType[]))
    supabase
      .from('instructors')
      .select('id, name, padi_level')
      .eq('active', true)
      .order('name')
      .then(({ data }) => setInstructors((data ?? []) as Instructor[]))
  }, [open])

  useEffect(() => {
    if (!haupt || !startDate) {
      setConflicts([])
      return
    }
    supabase
      .rpc('conflict_check', {
        p_instructor_id: haupt,
        p_dates: [startDate],
      })
      .then(({ data }) => setConflicts((data ?? []) as Conflict[]))
  }, [haupt, startDate])

  async function save() {
    if (!typeId || !title || !startDate) return
    setSaving(true)
    const { data: course, error } = await supabase
      .from('courses')
      .insert({ type_id: typeId, title, status: 'tentative', start_date: startDate })
      .select('id')
      .single()
    if (error || !course) {
      alert('Speichern fehlgeschlagen: ' + (error?.message ?? 'unbekannt'))
      setSaving(false)
      return
    }
    if (haupt) {
      await supabase.from('course_assignments').insert({
        course_id: course.id,
        instructor_id: haupt,
        role: 'haupt',
      })
    }
    setSaving(false)
    onCreated()
    onClose()
    // reset
    setTypeId(''); setTitle(''); setHaupt('')
  }

  return (
    <Sheet open={open} onClose={onClose} title="Neuer Kurs">
      <div style={{ display: 'grid', gap: 14 }}>
        <div>
          <Label>Kurstyp</Label>
          <select
            value={typeId}
            onChange={(e) => setTypeId(e.target.value)}
            style={{ ...inputStyle, width: '100%' }}
          >
            <option value="">— wählen —</option>
            {types.map((t) => (
              <option key={t.id} value={t.id}>{t.code} · {t.label}</option>
            ))}
          </select>
        </div>

        <div>
          <Label>Titel</Label>
          <input
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder='z.B. "OWD GK15"'
            style={{ ...inputStyle, width: '100%' }}
          />
        </div>

        <div>
          <Label>Startdatum</Label>
          <input
            type="date"
            value={startDate}
            onChange={(e) => setStartDate(e.target.value)}
            style={{ ...inputStyle, width: '100%' }}
          />
        </div>

        <div>
          <Label>Haupt-Instructor</Label>
          <select
            value={haupt}
            onChange={(e) => setHaupt(e.target.value)}
            style={{ ...inputStyle, width: '100%' }}
          >
            <option value="">— wählen —</option>
            {instructors.map((i) => (
              <option key={i.id} value={i.id}>{i.name} ({i.padi_level})</option>
            ))}
          </select>
        </div>

        {conflicts.length > 0 && (
          <div
            className="chip-orange"
            style={{
              padding: 12,
              borderRadius: 12,
              display: 'flex',
              gap: 10,
              alignItems: 'flex-start',
              fontSize: 13,
            }}
          >
            <Icon name="bell" size={16} />
            <div>
              <strong>Konflikt:</strong> Instructor ist bereits zugewiesen für
              {' '}<em>"{conflicts[0].conflicting_course_title}"</em> als {conflicts[0].conflicting_role}.
              <div className="caption-2" style={{ marginTop: 4 }}>
                Du kannst trotzdem speichern — die App blockiert nicht.
              </div>
            </div>
          </div>
        )}

        <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
          <button className="btn-secondary btn" onClick={onClose}>Abbrechen</button>
          <button
            className="btn"
            onClick={save}
            disabled={saving || !typeId || !title || !startDate}
            style={{ flex: 1 }}
          >
            {saving ? 'Speichere…' : 'Speichern'}
          </button>
        </div>
      </div>
    </Sheet>
  )
}

function Label({ children }: { children: string }) {
  return <div className="caption-2" style={{ marginBottom: 4 }}>{children.toUpperCase()}</div>
}
