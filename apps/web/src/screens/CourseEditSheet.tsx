import { useEffect, useState } from 'react'
import { format } from 'date-fns'
import { de } from 'date-fns/locale'
import { Sheet } from '@/components/Sheet'
import { Icon } from '@/components/Icon'
import { Chip } from '@/components/Chip'
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
  onSaved: () => void
  /** When set, edits this existing course. Otherwise creates a new one. */
  courseId?: string | null
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

const STATUSES = [
  { value: 'tentative', label: 'evtl.' },
  { value: 'confirmed', label: 'sicher' },
  { value: 'cancelled', label: 'CXL' },
] as const

export function CourseEditSheet({ open, onClose, onSaved, courseId }: Props) {
  const isEdit = !!courseId

  const [types, setTypes] = useState<CourseType[]>([])
  const [instructors, setInstructors] = useState<Instructor[]>([])

  const [typeId, setTypeId] = useState('')
  const [title, setTitle] = useState('')
  const [status, setStatus] = useState<'tentative' | 'confirmed' | 'cancelled'>('tentative')
  const [startDate, setStartDate] = useState(new Date().toISOString().slice(0, 10))
  const [additionalDates, setAdditionalDates] = useState<string[]>([])
  const [numParticipants, setNumParticipants] = useState(0)
  const [poolBooked, setPoolBooked] = useState(false)
  const [info, setInfo] = useState('')
  const [notes, setNotes] = useState('')

  // Only used for "create" — assigns a Haupt-Instructor immediately
  const [haupt, setHaupt] = useState('')
  const [conflicts, setConflicts] = useState<Conflict[]>([])

  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!open) return
    setError(null)

    supabase.from('course_types').select('id, code, label').eq('active', true).order('code')
      .then(({ data }) => setTypes((data ?? []) as CourseType[]))

    supabase.from('instructors').select('id, name, padi_level').eq('active', true).order('name')
      .then(({ data }) => setInstructors((data ?? []) as Instructor[]))

    if (courseId) {
      supabase
        .from('courses')
        .select('type_id, title, status, start_date, additional_dates, num_participants, pool_booked, info, notes')
        .eq('id', courseId)
        .single()
        .then(({ data }) => {
          if (!data) return
          setTypeId(data.type_id)
          setTitle(data.title)
          setStatus(data.status as typeof status)
          setStartDate(data.start_date)
          setAdditionalDates((data.additional_dates as string[]) ?? [])
          setNumParticipants(data.num_participants)
          setPoolBooked(data.pool_booked)
          setInfo(data.info ?? '')
          setNotes(data.notes ?? '')
        })
    } else {
      // Reset for create mode
      setTypeId(''); setTitle(''); setStatus('tentative')
      setStartDate(new Date().toISOString().slice(0, 10))
      setAdditionalDates([]); setNumParticipants(0); setPoolBooked(false)
      setInfo(''); setNotes(''); setHaupt('')
    }
  }, [open, courseId])

  // Conflict check (only for create + when haupt selected)
  useEffect(() => {
    if (isEdit || !haupt || !startDate) {
      setConflicts([])
      return
    }
    const allDates = [startDate, ...additionalDates].filter(Boolean)
    supabase
      .rpc('conflict_check', { p_instructor_id: haupt, p_dates: allDates })
      .then(({ data }) => setConflicts((data ?? []) as Conflict[]))
  }, [haupt, startDate, additionalDates, isEdit])

  function addDate() {
    setAdditionalDates((prev) => [...prev, ''])
  }
  function setDateAt(idx: number, value: string) {
    setAdditionalDates((prev) => prev.map((d, i) => (i === idx ? value : d)))
  }
  function removeDateAt(idx: number) {
    setAdditionalDates((prev) => prev.filter((_, i) => i !== idx))
  }

  async function save() {
    if (!typeId || !title || !startDate) return
    setSaving(true)
    setError(null)

    const cleanedDates = additionalDates.filter((d) => d && d !== startDate)

    if (isEdit) {
      const { error: updErr } = await supabase
        .from('courses')
        .update({
          type_id: typeId,
          title: title.trim(),
          status,
          start_date: startDate,
          additional_dates: cleanedDates,
          num_participants: numParticipants,
          pool_booked: poolBooked,
          info: info.trim() || null,
          notes: notes.trim() || null,
        })
        .eq('id', courseId!)
      if (updErr) {
        setError(updErr.message); setSaving(false); return
      }
    } else {
      const { data: course, error: insErr } = await supabase
        .from('courses')
        .insert({
          type_id: typeId,
          title: title.trim(),
          status,
          start_date: startDate,
          additional_dates: cleanedDates,
          num_participants: numParticipants,
          pool_booked: poolBooked,
          info: info.trim() || null,
          notes: notes.trim() || null,
        })
        .select('id')
        .single()
      if (insErr || !course) {
        setError(insErr?.message ?? 'Fehler'); setSaving(false); return
      }
      if (haupt) {
        await supabase.from('course_assignments').insert({
          course_id: course.id,
          instructor_id: haupt,
          role: 'haupt',
        })
      }
    }

    setSaving(false)
    onSaved()
    onClose()
  }

  return (
    <Sheet
      open={open}
      onClose={onClose}
      title={isEdit ? 'Kurs bearbeiten' : 'Neuer Kurs'}
      width={580}
    >
      <div style={{ display: 'grid', gap: 14 }}>
        <div>
          <Label>Kurstyp</Label>
          <select value={typeId} onChange={(e) => setTypeId(e.target.value)} style={inputStyle}>
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
            style={inputStyle}
          />
        </div>

        <div>
          <Label>Status</Label>
          <div className="seg">
            {STATUSES.map((s) => (
              <button
                key={s.value}
                type="button"
                className={status === s.value ? 'active' : undefined}
                onClick={() => setStatus(s.value as typeof status)}
              >
                {s.label}
              </button>
            ))}
          </div>
        </div>

        <div>
          <Label>Startdatum</Label>
          <input
            type="date"
            value={startDate}
            onChange={(e) => setStartDate(e.target.value)}
            style={inputStyle}
          />
        </div>

        <div>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 4 }}>
            <Label>Zusatzdaten (Folgetage)</Label>
            <button type="button" className="btn-ghost btn" onClick={addDate} style={{ padding: '0 8px', height: 24 }}>
              <Icon name="plus" size={12} /> Tag
            </button>
          </div>
          {additionalDates.length === 0 ? (
            <div className="caption-2">Eintägiger Kurs — keine Folgetage.</div>
          ) : (
            <div style={{ display: 'grid', gap: 6 }}>
              {additionalDates.map((d, i) => (
                <div key={i} style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
                  <input
                    type="date"
                    value={d}
                    onChange={(e) => setDateAt(i, e.target.value)}
                    style={{ ...inputStyle, flex: 1 }}
                  />
                  <button
                    type="button"
                    className="btn-icon"
                    onClick={() => removeDateAt(i)}
                    title="Entfernen"
                  >
                    <Icon name="x" size={12} />
                  </button>
                </div>
              ))}
            </div>
          )}
          {(additionalDates.length > 0 || true) && (
            <div className="caption-2" style={{ marginTop: 6 }}>
              {1 + additionalDates.filter((d) => d).length} Tag(e) gesamt
            </div>
          )}
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
          <div>
            <Label># Teilnehmer</Label>
            <input
              type="number"
              min={0}
              value={numParticipants}
              onChange={(e) => setNumParticipants(Math.max(0, Number(e.target.value) || 0))}
              style={inputStyle}
            />
          </div>
          <div>
            <Label>Pool gebucht</Label>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, height: 36 }}>
              <input
                id="pool"
                type="checkbox"
                checked={poolBooked}
                onChange={(e) => setPoolBooked(e.target.checked)}
              />
              <label htmlFor="pool">{poolBooked ? 'Ja' : 'Nein'}</label>
            </div>
          </div>
        </div>

        <div>
          <Label>Info (öffentliche Notiz, z.B. Treffpunkt)</Label>
          <textarea
            value={info}
            onChange={(e) => setInfo(e.target.value)}
            rows={2}
            style={{ ...inputStyle, resize: 'vertical' }}
          />
        </div>

        <div>
          <Label>Notizen (intern)</Label>
          <textarea
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            rows={2}
            style={{ ...inputStyle, resize: 'vertical' }}
          />
        </div>

        {!isEdit && (
          <>
            <div>
              <Label>Haupt-Instructor (initial zuweisen)</Label>
              <select value={haupt} onChange={(e) => setHaupt(e.target.value)} style={inputStyle}>
                <option value="">— später zuweisen —</option>
                {instructors.map((i) => (
                  <option key={i.id} value={i.id}>{i.name} ({i.padi_level})</option>
                ))}
              </select>
              <div className="caption-2" style={{ marginTop: 4 }}>
                Weitere TL/DM und Termine kannst du nach dem Anlegen im Kurs-Detail hinzufügen.
              </div>
            </div>

            {conflicts.length > 0 && (
              <div
                className="chip-orange"
                style={{ padding: 12, borderRadius: 12, display: 'flex', gap: 10, alignItems: 'flex-start', fontSize: 13 }}
              >
                <Icon name="bell" size={16} />
                <div>
                  <strong>Konflikt:</strong> Instructor ist bereits zugewiesen für{' '}
                  <em>"{conflicts[0].conflicting_course_title}"</em> als {conflicts[0].conflicting_role}.
                  <div className="caption-2" style={{ marginTop: 4 }}>
                    Du kannst trotzdem speichern.
                  </div>
                </div>
              </div>
            )}
          </>
        )}

        {error && <div className="chip chip-red">{error}</div>}

        <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
          <button className="btn-secondary btn" onClick={onClose}>Abbrechen</button>
          <button
            className="btn"
            onClick={save}
            disabled={saving || !typeId || !title || !startDate}
            style={{ flex: 1 }}
          >
            {saving ? 'Speichere…' : isEdit ? 'Änderungen speichern' : 'Anlegen'}
          </button>
        </div>
      </div>
    </Sheet>
  )
}

function Label({ children }: { children: string }) {
  return <div className="caption-2" style={{ marginBottom: 4 }}>{children.toUpperCase()}</div>
}
