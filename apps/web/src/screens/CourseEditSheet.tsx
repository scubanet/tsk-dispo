import { useEffect, useState } from 'react'
import { Sheet } from '@/components/Sheet'
import { Icon } from '@/components/Icon'
import { supabase } from '@/lib/supabase'
import {
  POOL_LOCATIONS,
  COURSE_DATE_TYPES,
  type CourseDateType,
  type PoolLocation,
} from '@/lib/queries'

interface CourseType { id: string; code: string; label: string }
interface Instructor { id: string; name: string; padi_level: string }
interface Conflict {
  conflicting_course_id: string
  conflicting_course_title: string
  conflicting_role: string
}

/** Local form-state row representing one date of the course */
interface DateEntry {
  date: string
  type: CourseDateType
  pool_location: PoolLocation | null
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
  { value: 'completed', label: 'abgeschlossen' },
  { value: 'cancelled', label: 'CXL' },
] as const

export function CourseEditSheet({ open, onClose, onSaved, courseId }: Props) {
  const isEdit = !!courseId

  const [types, setTypes] = useState<CourseType[]>([])
  const [instructors, setInstructors] = useState<Instructor[]>([])

  const [typeId, setTypeId] = useState('')
  const [title, setTitle] = useState('')
  const [status, setStatus] = useState<'tentative' | 'confirmed' | 'completed' | 'cancelled'>('tentative')
  const [dates, setDates] = useState<DateEntry[]>([
    { date: new Date().toISOString().slice(0, 10), type: 'theorie', pool_location: null },
  ])
  const [numParticipants, setNumParticipants] = useState(0)
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

    supabase.from('instructors').select('id, name, padi_level').eq('active', true).order('last_name').order('first_name')
      .then(({ data }) => setInstructors((data ?? []) as Instructor[]))

    if (courseId) {
      Promise.all([
        supabase
          .from('courses')
          .select('type_id, title, status, start_date, additional_dates, num_participants, info, notes')
          .eq('id', courseId)
          .single(),
        supabase
          .from('course_dates')
          .select('date, type, pool_location')
          .eq('course_id', courseId)
          .order('date'),
      ]).then(([courseRes, datesRes]) => {
        const c = courseRes.data
        if (!c) return
        setTypeId(c.type_id)
        setTitle(c.title)
        setStatus(c.status as typeof status)
        setNumParticipants(c.num_participants)
        setInfo(c.info ?? '')
        setNotes(c.notes ?? '')

        // Combine course_dates rows with start_date + additional_dates as fallback
        const cdMap = new Map<string, { type: CourseDateType; pool: PoolLocation | null }>()
        for (const cd of datesRes.data ?? []) {
          cdMap.set(cd.date, { type: cd.type as CourseDateType, pool: cd.pool_location as PoolLocation | null })
        }

        const allDateStrings = [c.start_date, ...((c.additional_dates as string[]) ?? [])].filter(Boolean)
        const merged: DateEntry[] = allDateStrings.map((d) => {
          const meta = cdMap.get(d)
          return {
            date: d,
            type: meta?.type ?? 'theorie',
            pool_location: meta?.pool ?? null,
          }
        })

        setDates(merged.length > 0 ? merged : [
          { date: c.start_date, type: 'theorie', pool_location: null },
        ])
      })
    } else {
      // Reset for create mode
      setTypeId(''); setTitle(''); setStatus('tentative')
      setDates([{ date: new Date().toISOString().slice(0, 10), type: 'theorie', pool_location: null }])
      setNumParticipants(0)
      setInfo(''); setNotes(''); setHaupt('')
    }
  }, [open, courseId])

  // Conflict check (only for create + when haupt selected)
  useEffect(() => {
    if (isEdit || !haupt) {
      setConflicts([])
      return
    }
    const allDates = dates.map((d) => d.date).filter(Boolean)
    if (allDates.length === 0) {
      setConflicts([])
      return
    }
    supabase
      .rpc('conflict_check', { p_instructor_id: haupt, p_dates: allDates })
      .then(({ data }) => setConflicts((data ?? []) as Conflict[]))
  }, [haupt, dates, isEdit])

  function addDate() {
    setDates((prev) => [
      ...prev,
      { date: '', type: 'theorie', pool_location: null },
    ])
  }
  function removeDateAt(idx: number) {
    setDates((prev) => prev.filter((_, i) => i !== idx))
  }
  function updateDate(idx: number, patch: Partial<DateEntry>) {
    setDates((prev) =>
      prev.map((d, i) => {
        if (i !== idx) return d
        const next = { ...d, ...patch }
        // If type changes away from 'pool', clear pool_location
        if (patch.type && patch.type !== 'pool') next.pool_location = null
        return next
      }),
    )
  }

  async function deleteCourse() {
    if (!courseId) return
    if (!confirm(
      `Kurs wirklich komplett löschen?\n\n• Alle Zuteilungen (TL/DM) werden entfernt\n• Alle Kursdaten + Schüler-Anmeldungen werden entfernt\n• Vergütungs-Buchungen zu diesem Kurs werden gelöscht\n\nDiese Aktion ist NICHT umkehrbar. Falls du den Kurs nur aus der Planung nehmen willst, setze ihn stattdessen auf "CXL" (abgesagt).`
    )) return

    setSaving(true)
    setError(null)

    try {
      // 1. Vergütungs-Bewegungen zu Assignments dieses Kurses löschen
      //    (sonst bleiben sie als verwaiste Buchungen mit ref_assignment_id=NULL übrig)
      const { data: assignments } = await supabase
        .from('course_assignments')
        .select('id')
        .eq('course_id', courseId)
      const assignmentIds = (assignments ?? []).map((a) => a.id)

      if (assignmentIds.length > 0) {
        const { error: delMovErr } = await supabase
          .from('account_movements')
          .delete()
          .eq('kind', 'vergütung')
          .in('ref_assignment_id', assignmentIds)
        if (delMovErr) {
          setError('Fehler beim Aufräumen der Vergütungs-Buchungen: ' + delMovErr.message)
          setSaving(false)
          return
        }
      }

      // 2. Kurs löschen — assignments, dates, participants kaskadieren automatisch
      const { error: delErr } = await supabase
        .from('courses')
        .delete()
        .eq('id', courseId)
      if (delErr) {
        setError('Fehler beim Löschen: ' + delErr.message)
        setSaving(false)
        return
      }

      setSaving(false)
      onSaved()
      onClose()
    } catch (e: any) {
      setError(e?.message || 'Unbekannter Fehler')
      setSaving(false)
    }
  }

  async function save() {
    if (!typeId || !title) return
    const valid = dates.filter((d) => d.date)
    if (valid.length === 0) {
      setError('Mindestens ein Datum erforderlich.')
      return
    }
    // Sort chronologically
    const sorted = [...valid].sort((a, b) => a.date.localeCompare(b.date))
    const startDate = sorted[0].date
    const additional = sorted.slice(1).map((d) => d.date)

    setSaving(true)
    setError(null)

    let savedCourseId = courseId

    if (isEdit) {
      const { error: updErr } = await supabase
        .from('courses')
        .update({
          type_id: typeId,
          title: title.trim(),
          status,
          start_date: startDate,
          additional_dates: additional,
          num_participants: numParticipants,
          // pool_booked is implied by any date with type='pool' — kept for backward compat
          pool_booked: sorted.some((d) => d.type === 'pool'),
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
          additional_dates: additional,
          num_participants: numParticipants,
          pool_booked: sorted.some((d) => d.type === 'pool'),
          info: info.trim() || null,
          notes: notes.trim() || null,
        })
        .select('id')
        .single()
      if (insErr || !course) {
        setError(insErr?.message ?? 'Fehler'); setSaving(false); return
      }
      savedCourseId = course.id

      if (haupt) {
        await supabase.from('course_assignments').insert({
          course_id: savedCourseId,
          instructor_id: haupt,
          role: 'haupt',
        })
      }
    }

    // Sync course_dates: delete existing and re-insert (idempotent rebuild)
    if (savedCourseId) {
      await supabase.from('course_dates').delete().eq('course_id', savedCourseId)
      const rows = sorted.map((d) => ({
        course_id: savedCourseId,
        date: d.date,
        type: d.type,
        pool_location: d.type === 'pool' ? d.pool_location : null,
      }))
      if (rows.length > 0) {
        const { error: cdErr } = await supabase.from('course_dates').insert(rows)
        if (cdErr) {
          setError('Datums-Details konnten nicht gespeichert werden: ' + cdErr.message)
          setSaving(false)
          return
        }
      }
    }

    setSaving(false)
    onSaved()
    onClose()
  }

  const isMultiDay = dates.length > 1

  return (
    <Sheet
      open={open}
      onClose={onClose}
      title={isEdit ? 'Kurs bearbeiten' : 'Neuer Kurs'}
      width={620}
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
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 4 }}>
            <Label>Kursdaten · Theorie / Pool / See</Label>
            <button type="button" className="btn-ghost btn" onClick={addDate} style={{ padding: '0 8px', height: 24 }}>
              <Icon name="plus" size={12} /> Tag
            </button>
          </div>
          <div className="caption-2" style={{ marginBottom: 8 }}>
            {isMultiDay ? `${dates.length} Tage` : 'Eintägiger Kurs'} · pro Datum den Typ wählen, bei Pool-Tagen den Pool angeben.
          </div>

          <div style={{ display: 'grid', gap: 6 }}>
            {dates.map((d, i) => (
              <div
                key={i}
                style={{
                  display: 'grid',
                  gridTemplateColumns: '1fr 130px 130px 32px',
                  gap: 6,
                  alignItems: 'center',
                }}
              >
                <input
                  type="date"
                  value={d.date}
                  onChange={(e) => updateDate(i, { date: e.target.value })}
                  style={inputStyle}
                />
                <select
                  value={d.type}
                  onChange={(e) => updateDate(i, { type: e.target.value as CourseDateType })}
                  style={inputStyle}
                >
                  {COURSE_DATE_TYPES.map((t) => (
                    <option key={t.value} value={t.value}>{t.emoji} {t.label}</option>
                  ))}
                </select>
                {d.type === 'pool' ? (
                  <select
                    value={d.pool_location ?? ''}
                    onChange={(e) =>
                      updateDate(i, {
                        pool_location: (e.target.value || null) as PoolLocation | null,
                      })
                    }
                    style={inputStyle}
                  >
                    <option value="">Pool wählen</option>
                    {POOL_LOCATIONS.map((p) => (
                      <option key={p.value} value={p.value}>{p.label}</option>
                    ))}
                  </select>
                ) : (
                  <div className="caption-2" style={{ textAlign: 'center', alignSelf: 'center' }}>—</div>
                )}
                <button
                  type="button"
                  className="btn-icon"
                  onClick={() => removeDateAt(i)}
                  title="Tag entfernen"
                  disabled={dates.length === 1}
                >
                  <Icon name="x" size={12} />
                </button>
              </div>
            ))}
          </div>
        </div>

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
          {isEdit && (
            <button
              type="button"
              className="btn-secondary btn"
              onClick={deleteCourse}
              disabled={saving}
              style={{ color: '#FF3B30' }}
              title="Kurs komplett entfernen"
            >
              <Icon name="x" size={12} /> Löschen
            </button>
          )}
          <button className="btn-secondary btn" onClick={onClose}>Abbrechen</button>
          <button
            className="btn"
            onClick={save}
            disabled={saving || !typeId || !title || dates.filter((d) => d.date).length === 0}
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
