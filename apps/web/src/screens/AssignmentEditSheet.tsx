import { useEffect, useState } from 'react'
import { format } from 'date-fns'
import { de } from 'date-fns/locale'
import { Sheet } from '@/components/Sheet'
import { Icon } from '@/components/Icon'
import { supabase } from '@/lib/supabase'

interface Instructor { id: string; name: string; padi_level: string }
interface Conflict {
  conflicting_course_id: string
  conflicting_course_title: string
  conflicting_role: string
}

interface ExistingAssignment {
  id: string
  instructor_id: string
  role: 'haupt' | 'assist' | 'dmt'
  confirmed: boolean
  assigned_for_dates: string[]
}

interface Props {
  open: boolean
  onClose: () => void
  onSaved: () => void
  courseId: string
  /** All possible course dates (start + additional) */
  allDates: string[]
  /** When set, edits this existing assignment. Otherwise creates new. */
  existingAssignment?: ExistingAssignment | null
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

const ROLES = [
  { value: 'haupt',  label: 'Haupt' },
  { value: 'assist', label: 'Assistent' },
  { value: 'dmt',    label: 'DMT' },
] as const

export function AssignmentEditSheet({ open, onClose, onSaved, courseId, allDates, existingAssignment }: Props) {
  const isEdit = !!existingAssignment

  const [instructors, setInstructors] = useState<Instructor[]>([])
  const [instructorId, setInstructorId] = useState('')
  const [role, setRole] = useState<'haupt' | 'assist' | 'dmt'>('assist')
  const [confirmed, setConfirmed] = useState(false)
  /** Empty array means "all dates" */
  const [selectedDates, setSelectedDates] = useState<Set<string>>(new Set())
  const [conflicts, setConflicts] = useState<Conflict[]>([])
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!open) return
    setError(null)

    supabase
      .from('instructors')
      .select('id, name, padi_level')
      .eq('active', true)
      .order('last_name')
      .order('first_name')
      .then(({ data }) => setInstructors((data ?? []) as Instructor[]))

    if (existingAssignment) {
      setInstructorId(existingAssignment.instructor_id)
      setRole(existingAssignment.role)
      setConfirmed(existingAssignment.confirmed)
      setSelectedDates(new Set(existingAssignment.assigned_for_dates ?? []))
    } else {
      setInstructorId('')
      setRole('assist')
      setConfirmed(false)
      setSelectedDates(new Set())
    }
  }, [open, existingAssignment])

  // Conflict-check for selected dates (or all)
  useEffect(() => {
    if (!instructorId) {
      setConflicts([])
      return
    }
    const dates = selectedDates.size === 0 ? allDates : [...selectedDates]
    if (dates.length === 0) {
      setConflicts([])
      return
    }
    supabase
      .rpc('conflict_check', { p_instructor_id: instructorId, p_dates: dates })
      .then(({ data }) => {
        // Filter out conflicts with the same course (in edit mode editing oneself)
        const filtered = ((data ?? []) as Conflict[]).filter(
          (c) => c.conflicting_course_id !== courseId,
        )
        setConflicts(filtered)
      })
  }, [instructorId, selectedDates, allDates, courseId])

  function toggleDate(d: string) {
    setSelectedDates((prev) => {
      const next = new Set(prev)
      if (next.has(d)) next.delete(d); else next.add(d)
      return next
    })
  }
  function selectAll() { setSelectedDates(new Set()) /* empty = "all dates" semantics */ }

  async function save() {
    if (!instructorId) return
    setSaving(true)
    setError(null)

    // Persist dates: if user selected all, store empty array (means "all")
    const datesToStore =
      selectedDates.size === 0 || selectedDates.size === allDates.length
        ? []
        : [...selectedDates]

    if (isEdit) {
      const { error: updErr } = await supabase
        .from('course_assignments')
        .update({
          instructor_id: instructorId,
          role,
          confirmed,
          assigned_for_dates: datesToStore,
        })
        .eq('id', existingAssignment!.id)
      if (updErr) {
        setError(updErr.message); setSaving(false); return
      }
    } else {
      const { error: insErr } = await supabase
        .from('course_assignments')
        .insert({
          course_id: courseId,
          instructor_id: instructorId,
          role,
          confirmed,
          assigned_for_dates: datesToStore,
        })
      if (insErr) {
        setError(insErr.message); setSaving(false); return
      }
    }

    setSaving(false)
    onSaved()
    onClose()
  }

  async function deleteAssignment() {
    if (!existingAssignment) return
    if (!confirm('Diese Zuweisung wirklich entfernen? Die zugehörige Vergütungsbuchung wird automatisch storniert.')) return
    setSaving(true)
    const { error: delErr } = await supabase
      .from('course_assignments')
      .delete()
      .eq('id', existingAssignment.id)
    setSaving(false)
    if (delErr) {
      setError(delErr.message); return
    }
    onSaved()
    onClose()
  }

  return (
    <Sheet
      open={open}
      onClose={onClose}
      title={isEdit ? 'Zuweisung bearbeiten' : 'TL/DM zuweisen'}
      width={520}
    >
      <div style={{ display: 'grid', gap: 14 }}>
        <div>
          <Label>Person</Label>
          <select
            value={instructorId}
            onChange={(e) => setInstructorId(e.target.value)}
            style={inputStyle}
          >
            <option value="">— wählen —</option>
            {instructors.map((i) => (
              <option key={i.id} value={i.id}>{i.name} ({i.padi_level})</option>
            ))}
          </select>
        </div>

        <div>
          <Label>Rolle</Label>
          <div className="seg">
            {ROLES.map((r) => (
              <button
                key={r.value}
                type="button"
                className={role === r.value ? 'active' : undefined}
                onClick={() => setRole(r.value as typeof role)}
              >
                {r.label}
              </button>
            ))}
          </div>
        </div>

        <div>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 6 }}>
            <Label>Welche Tage?</Label>
            <button
              type="button"
              className="btn-ghost btn"
              onClick={selectAll}
              style={{ padding: '0 8px', height: 24 }}
            >
              Alle Tage
            </button>
          </div>
          <div className="caption-2" style={{ marginBottom: 8 }}>
            Leer = ganzer Kurs. Auswahl = nur an diesen Tagen.
          </div>
          <div style={{ display: 'grid', gap: 6 }}>
            {allDates.map((d) => {
              const checked = selectedDates.size === 0 || selectedDates.has(d)
              const isAllMode = selectedDates.size === 0
              return (
                <label
                  key={d}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: 10,
                    padding: '8px 10px',
                    borderRadius: 8,
                    background: checked ? 'var(--accent-soft)' : 'rgba(120,120,128,.08)',
                    cursor: 'pointer',
                  }}
                >
                  <input
                    type="checkbox"
                    checked={checked}
                    onChange={() => {
                      if (isAllMode) {
                        // First click: switch to explicit-list mode with all except this one
                        const next = new Set(allDates)
                        next.delete(d)
                        setSelectedDates(next)
                      } else {
                        toggleDate(d)
                      }
                    }}
                  />
                  <span className="mono caption" style={{ minWidth: 110 }}>
                    {format(new Date(d), 'EEE, d. MMM', { locale: de })}
                  </span>
                </label>
              )
            })}
          </div>
        </div>

        <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
          <input
            id="confirmed"
            type="checkbox"
            checked={confirmed}
            onChange={(e) => setConfirmed(e.target.checked)}
          />
          <label htmlFor="confirmed">Person hat zugesagt (bestätigt)</label>
        </div>

        {conflicts.length > 0 && (
          <div
            className="chip-orange"
            style={{ padding: 12, borderRadius: 12, display: 'flex', gap: 10, alignItems: 'flex-start', fontSize: 13 }}
          >
            <Icon name="bell" size={16} />
            <div>
              <strong>Konflikt:</strong> Person ist an mind. einem dieser Tage bereits zugewiesen für{' '}
              <em>"{conflicts[0].conflicting_course_title}"</em> als {conflicts[0].conflicting_role}.
            </div>
          </div>
        )}

        {error && <div className="chip chip-red">{error}</div>}

        <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
          {isEdit && (
            <button
              className="btn-secondary btn"
              onClick={deleteAssignment}
              disabled={saving}
              style={{ color: '#FF3B30' }}
            >
              <Icon name="x" size={12} /> Entfernen
            </button>
          )}
          <button className="btn-secondary btn" onClick={onClose}>Abbrechen</button>
          <button
            className="btn"
            onClick={save}
            disabled={saving || !instructorId}
            style={{ flex: 1 }}
          >
            {saving ? 'Speichere…' : isEdit ? 'Speichern' : 'Zuweisen'}
          </button>
        </div>
      </div>
    </Sheet>
  )
}

function Label({ children }: { children: string }) {
  return <div className="caption-2" style={{ marginBottom: 4 }}>{children.toUpperCase()}</div>
}
