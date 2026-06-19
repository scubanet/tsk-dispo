import { useEffect, useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Sheet } from '@/components/Sheet'
import { Icon } from '@/components/Icon'
import {
  POOL_LOCATIONS,
  type CourseDateType,
  type PoolLocation,
} from '@/lib/queries'
import { useActiveInstructors } from '@/hooks/useActiveInstructors'
import {
  useCourseTypeOptions,
  useCourseForEdit,
  useCourseDatesForEdit,
  useScheduleConflicts,
  useCreateCourse,
  useUpdateCourse,
  useDeleteCourse,
} from '@/hooks/useCourseEdit'

/** Local form-state row representing one date of the course */
interface DateEntry {
  date: string
  type: CourseDateType  // primary type — abgeleitet aus den Booleans (für Calendar-Anzeige)
  has_theory: boolean
  has_pool: boolean
  has_lake: boolean
  pool_location: PoolLocation | null
  pool_reserved: boolean
  // Per-Type-Zeiten ("HH:MM" oder "")
  theory_from: string
  theory_to: string
  pool_from: string
  pool_to: string
  lake_from: string
  lake_to: string
}

/** "HH:MM:SS" oder "HH:MM" → "HH:MM" für <input type="time"> */
function normalizeTime(t: string | null | undefined): string {
  if (!t) return ''
  return t.length >= 5 ? t.slice(0, 5) : t
}

/** Liefert primary type aus den Booleans — Pool > See > Theorie (Wassertage haben Vorrang in Anzeige) */
function derivePrimaryType(d: { has_pool: boolean; has_lake: boolean; has_theory: boolean }): CourseDateType {
  if (d.has_pool) return 'pool'
  if (d.has_lake) return 'see'
  return 'theorie'
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

const STATUS_VALUES = ['tentative', 'confirmed', 'completed', 'cancelled'] as const

export function CourseEditSheet({ open, onClose, onSaved, courseId }: Props) {
  const { t } = useTranslation()
  const isEdit = !!courseId
  const STATUSES: ReadonlyArray<{ value: typeof STATUS_VALUES[number]; label: string }> = [
    { value: 'tentative', label: t('course_edit.status_tentative') },
    { value: 'confirmed', label: t('course_edit.status_confirmed') },
    { value: 'completed', label: t('course_edit.status_completed') },
    { value: 'cancelled', label: t('course_edit.status_cancelled') },
  ]

  const { data: types = [] } = useCourseTypeOptions()
  const { data: instructorRows = [] } = useActiveInstructors()
  const instructors = useMemo(
    () => instructorRows.map(({ id, name, padi_level }) => ({ id, name, padi_level })),
    [instructorRows],
  )
  const { data: existingCourse } = useCourseForEdit(isEdit ? courseId : null)
  const { data: existingDates = [] } = useCourseDatesForEdit(isEdit ? courseId : null)

  const createCourse = useCreateCourse()
  const updateCourse = useUpdateCourse()
  const deleteCourseMutation = useDeleteCourse()
  const saving = createCourse.isPending || updateCourse.isPending || deleteCourseMutation.isPending

  const [typeId, setTypeId] = useState('')
  const [title, setTitle] = useState('')
  const [status, setStatus] = useState<'tentative' | 'confirmed' | 'completed' | 'cancelled'>('tentative')
  const [dates, setDates] = useState<DateEntry[]>([
    { date: new Date().toISOString().slice(0, 10), type: 'theorie', has_theory: true, has_pool: false, has_lake: false, pool_location: null, pool_reserved: false, theory_from: '', theory_to: '', pool_from: '', pool_to: '', lake_from: '', lake_to: '' },
  ])
  const [numParticipants, setNumParticipants] = useState(0)
  const [info, setInfo] = useState('')
  const [notes, setNotes] = useState('')

  // Only used for "create" — assigns a Haupt-Instructor immediately
  const [haupt, setHaupt] = useState('')

  const [error, setError] = useState<string | null>(null)

  // Reset form state when opening the sheet in create mode.
  useEffect(() => {
    if (!open || courseId) return
    setError(null)

    setTypeId(''); setTitle(''); setStatus('tentative')
    setDates([{ date: new Date().toISOString().slice(0, 10), type: 'theorie', has_theory: true, has_pool: false, has_lake: false, pool_location: null, pool_reserved: false, theory_from: '', theory_to: '', pool_from: '', pool_to: '', lake_from: '', lake_to: '' }])
    setNumParticipants(0)
    setInfo(''); setNotes(''); setHaupt('')
  }, [open, courseId])

  // Hydrate form state when entering edit-mode / opening sheet.
  useEffect(() => {
    if (!open || !courseId) return
    setError(null)

    if (!existingCourse) return

    setTypeId(existingCourse.type_id)
    setTitle(existingCourse.title)
    setStatus(existingCourse.status)
    setNumParticipants(existingCourse.num_participants)
    setInfo(existingCourse.info ?? '')
    setNotes(existingCourse.notes ?? '')

    // Combine course_dates rows with start_date + additional_dates as fallback.
    interface CDMeta {
      type: CourseDateType
      pool: PoolLocation | null
      reserved: boolean
      theory: boolean
      lake: boolean
      poolFlag: boolean
      theory_from: string
      theory_to: string
      pool_from: string
      pool_to: string
      lake_from: string
      lake_to: string
    }
    const cdMap = new Map<string, CDMeta>()
    for (const cd of existingDates) {
      // Falls Booleans schon gesetzt sind (Migration durch), nimm sie. Sonst aus type ableiten.
      const theory = cd.has_theory != null ? !!cd.has_theory : cd.type === 'theorie'
      const poolFlag = cd.has_pool != null ? !!cd.has_pool : cd.type === 'pool'
      const lake = cd.has_lake != null ? !!cd.has_lake : cd.type === 'see'
      cdMap.set(cd.date, {
        type: cd.type,
        pool: cd.pool_location,
        reserved: !!cd.pool_reserved,
        theory, poolFlag, lake,
        theory_from: normalizeTime(cd.theory_from),
        theory_to:   normalizeTime(cd.theory_to),
        pool_from:   normalizeTime(cd.pool_from),
        pool_to:     normalizeTime(cd.pool_to),
        lake_from:   normalizeTime(cd.lake_from),
        lake_to:     normalizeTime(cd.lake_to),
      })
    }

    const allDateStrings = [existingCourse.start_date, ...(existingCourse.additional_dates ?? [])].filter(Boolean)
    const merged: DateEntry[] = allDateStrings.map((d) => {
      const meta = cdMap.get(d)
      return {
        date: d,
        type: meta?.type ?? 'theorie',
        has_theory: meta?.theory ?? true,
        has_pool: meta?.poolFlag ?? false,
        has_lake: meta?.lake ?? false,
        pool_location: meta?.pool ?? null,
        pool_reserved: meta?.reserved ?? false,
        theory_from: meta?.theory_from ?? '',
        theory_to:   meta?.theory_to   ?? '',
        pool_from:   meta?.pool_from   ?? '',
        pool_to:     meta?.pool_to     ?? '',
        lake_from:   meta?.lake_from   ?? '',
        lake_to:     meta?.lake_to     ?? '',
      }
    })

    setDates(merged.length > 0 ? merged : [
      { date: existingCourse.start_date, type: 'theorie', has_theory: true, has_pool: false, has_lake: false, pool_location: null, pool_reserved: false, theory_from: '', theory_to: '', pool_from: '', pool_to: '', lake_from: '', lake_to: '' },
    ])
  }, [open, courseId, existingCourse, existingDates])

  // Conflict check — live useQuery driven by haupt + dates, gated to create mode.
  const conflictDates = useMemo(() => dates.map((d) => d.date).filter(Boolean), [dates])
  const { data: conflicts = [] } = useScheduleConflicts(
    !isEdit ? haupt || null : null,
    conflictDates,
  )

  function addDate() {
    setDates((prev) => [
      ...prev,
      { date: '', type: 'theorie', has_theory: true, has_pool: false, has_lake: false, pool_location: null, pool_reserved: false, theory_from: '', theory_to: '', pool_from: '', pool_to: '', lake_from: '', lake_to: '' },
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
        // Wenn has_pool deaktiviert → pool_location und pool_reserved löschen
        if (patch.has_pool === false) {
          next.pool_location = null
          next.pool_reserved = false
        }
        // primary type abgeleitet halten
        next.type = derivePrimaryType(next)
        return next
      }),
    )
  }

  async function deleteCourse() {
    if (!courseId) return
    if (!confirm(t('course_edit.confirm_delete'))) return
    setError(null)
    try {
      await deleteCourseMutation.mutateAsync(courseId)
      onSaved()
      onClose()
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : t('course_edit.error_unknown')
      setError(t('course_edit.error_delete') + msg)
    }
  }

  async function save() {
    if (!typeId) {
      setError(t('course_edit.error_type_required'))
      return
    }
    if (!title.trim()) {
      setError(t('course_edit.error_title_required'))
      return
    }
    const valid = dates.filter((d) => d.date)
    if (valid.length === 0) {
      setError(t('course_edit.error_at_least_one_date'))
      return
    }
    setError(null)

    // Sort chronologically.
    const sorted = [...valid].sort((a, b) => a.date.localeCompare(b.date))
    const startDate = sorted[0].date
    const additional = sorted.slice(1).map((d) => d.date)

    const courseInput = {
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
    }
    const dateRows = sorted.map((d) => ({
      date: d.date,
      type: derivePrimaryType(d),
      has_theory: d.has_theory,
      has_pool: d.has_pool,
      has_lake: d.has_lake,
      pool_location: d.has_pool ? d.pool_location : null,
      pool_reserved: d.has_pool ? d.pool_reserved : false,
      theory_from: d.has_theory ? (d.theory_from || null) : null,
      theory_to:   d.has_theory ? (d.theory_to   || null) : null,
      pool_from:   d.has_pool   ? (d.pool_from   || null) : null,
      pool_to:     d.has_pool   ? (d.pool_to     || null) : null,
      lake_from:   d.has_lake   ? (d.lake_from   || null) : null,
      lake_to:     d.has_lake   ? (d.lake_to     || null) : null,
    }))

    try {
      if (isEdit) {
        await updateCourse.mutateAsync({
          courseId: courseId!,
          course: courseInput,
          dateRows,
        })
      } else {
        await createCourse.mutateAsync({
          course: courseInput,
          dateRows,
          hauptInstructorId: haupt || null,
        })
      }
      onSaved()
      onClose()
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t('common.error'))
    }
  }

  const isMultiDay = dates.length > 1

  return (
    <Sheet
      open={open}
      onClose={onClose}
      title={isEdit ? t('course_edit.title_edit') : t('course_edit.title_new')}
      width={620}
    >
      <div style={{ display: 'grid', gap: 14 }}>
        <div>
          <Label>{t('course_edit.label_type')}</Label>
          <select value={typeId} onChange={(e) => setTypeId(e.target.value)} style={inputStyle}>
            <option value="">— {t('course_edit.choose')} —</option>
            {types.map((ct) => (
              <option key={ct.id} value={ct.id}>{ct.code} · {ct.label}</option>
            ))}
          </select>
        </div>

        <div>
          <Label>{t('course_edit.label_title')}</Label>
          <input
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder={t('course_edit.title_placeholder')}
            style={inputStyle}
          />
        </div>

        <div>
          <Label>{t('course_edit.label_status')}</Label>
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
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 'var(--space-1)' }}>
            <Label>{t('course_edit.label_dates')}</Label>
            <button type="button" className="btn-ghost btn" onClick={addDate} style={{ padding: '0 8px', height: 24 }}>
              <Icon name="plus" size={12} /> {t('course_edit.add_day')}
            </button>
          </div>
          <div className="caption-2" style={{ marginBottom: 'var(--space-2)' }}>
            {isMultiDay ? t('course_edit.days_count', { count: dates.length }) : t('course_edit.single_day')} · {t('course_edit.dates_hint')}
          </div>

          <div style={{ display: 'grid', gap: 10 }}>
            {dates.map((d, i) => (
              <div
                key={i}
                className="glass-thin"
                style={{ padding: 10, borderRadius: 10, display: 'grid', gap: 6 }}
              >
                <div style={{ display: 'grid', gridTemplateColumns: '1fr auto auto auto 32px', gap: 6, alignItems: 'center' }}>
                  <input
                    type="date"
                    value={d.date}
                    onChange={(e) => updateDate(i, { date: e.target.value })}
                    style={inputStyle}
                  />
                  <TypeToggle label={`📚 ${t('course_edit.type_theory')}`} checked={d.has_theory} onChange={(v) => updateDate(i, { has_theory: v })} />
                  <TypeToggle label={`🏊 ${t('course_edit.type_pool')}`}   checked={d.has_pool}   onChange={(v) => updateDate(i, { has_pool: v })} />
                  <TypeToggle label={`🌊 ${t('course_edit.type_lake')}`}    checked={d.has_lake}   onChange={(v) => updateDate(i, { has_lake: v })} />
                  <button
                    type="button"
                    className="btn-icon"
                    onClick={() => removeDateAt(i)}
                    title={t('course_edit.remove_day')}
                    disabled={dates.length === 1}
                  >
                    <Icon name="x" size={12} />
                  </button>
                </div>
                {(d.has_theory || d.has_pool || d.has_lake) && (
                  <div style={{ display: 'flex', gap: 'var(--space-2)', flexWrap: 'wrap', fontSize: 12 }}>
                    {d.has_theory && (
                      <TimeRange
                        emoji="📚"
                        label={t('course_edit.type_theory')}
                        from={d.theory_from}
                        to={d.theory_to}
                        onFrom={(v) => updateDate(i, { theory_from: v })}
                        onTo={(v) => updateDate(i, { theory_to: v })}
                      />
                    )}
                    {d.has_pool && (
                      <TimeRange
                        emoji="🏊"
                        label={t('course_edit.type_pool')}
                        from={d.pool_from}
                        to={d.pool_to}
                        onFrom={(v) => updateDate(i, { pool_from: v })}
                        onTo={(v) => updateDate(i, { pool_to: v })}
                      />
                    )}
                    {d.has_lake && (
                      <TimeRange
                        emoji="🌊"
                        label={t('course_edit.type_lake')}
                        from={d.lake_from}
                        to={d.lake_to}
                        onFrom={(v) => updateDate(i, { lake_from: v })}
                        onTo={(v) => updateDate(i, { lake_to: v })}
                      />
                    )}
                  </div>
                )}
                {d.has_pool && (
                  <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
                    <select
                      value={d.pool_location ?? ''}
                      onChange={(e) =>
                        updateDate(i, {
                          pool_location: (e.target.value || null) as PoolLocation | null,
                        })
                      }
                      style={{ ...inputStyle, flex: 1 }}
                    >
                      <option value="">{t('course_edit.pool_choose')}</option>
                      {POOL_LOCATIONS.map((p) => (
                        <option key={p.value} value={p.value}>{p.label}</option>
                      ))}
                    </select>
                    <label
                      style={{
                        display: 'inline-flex',
                        alignItems: 'center',
                        gap: 'var(--space-1)',
                        padding: '4px 8px',
                        borderRadius: 6,
                        border: '0.5px solid var(--hairline)',
                        background: d.pool_reserved ? 'rgba(52,199,89,.18)' : 'transparent',
                        cursor: 'pointer',
                        fontSize: 11.5,
                        whiteSpace: 'nowrap',
                      }}
                      title={t('course_edit.pool_reserved_tooltip')}
                    >
                      <input
                        type="checkbox"
                        checked={d.pool_reserved}
                        onChange={(e) => updateDate(i, { pool_reserved: e.target.checked })}
                        style={{ cursor: 'pointer' }}
                      />
                      {t('course_edit.reserved_short')}
                    </label>
                  </div>
                )}
              </div>
            ))}
          </div>
        </div>

        <div>
          <Label>{t('course_edit.label_participants')}</Label>
          <input
            type="number"
            min={0}
            value={numParticipants}
            onChange={(e) => setNumParticipants(Math.max(0, Number(e.target.value) || 0))}
            style={inputStyle}
          />
        </div>

        <div>
          <Label>{t('course_edit.label_info')}</Label>
          <textarea
            value={info}
            onChange={(e) => setInfo(e.target.value)}
            rows={2}
            style={{ ...inputStyle, resize: 'vertical' }}
          />
        </div>

        <div>
          <Label>{t('course_edit.label_notes')}</Label>
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
              <Label>{t('course_edit.label_haupt_instructor')}</Label>
              <select value={haupt} onChange={(e) => setHaupt(e.target.value)} style={inputStyle}>
                <option value="">— {t('course_edit.assign_later')} —</option>
                {instructors.map((i) => (
                  <option key={i.id} value={i.id}>{i.name} ({i.padi_level})</option>
                ))}
              </select>
              <div className="caption-2" style={{ marginTop: 'var(--space-1)' }}>
                {t('course_edit.haupt_hint')}
              </div>
            </div>

            {conflicts.length > 0 && (
              <div
                className="chip-orange"
                style={{ padding: 'var(--space-3)', borderRadius: 12, display: 'flex', gap: 10, alignItems: 'flex-start', fontSize: 13 }}
              >
                <Icon name="bell" size={16} />
                <div>
                  <strong>{t('course_edit.conflict')}:</strong> {t('course_edit.conflict_text', {
                    title: conflicts[0].conflicting_course_title,
                    role: conflicts[0].conflicting_role,
                  })}
                  <div className="caption-2" style={{ marginTop: 'var(--space-1)' }}>
                    {t('course_edit.conflict_hint')}
                  </div>
                </div>
              </div>
            )}
          </>
        )}

        {error && <div className="chip chip-red">{error}</div>}

        <div style={{ display: 'flex', gap: 'var(--space-2)', marginTop: 'var(--space-2)' }}>
          {isEdit && (
            <button
              type="button"
              className="btn-danger btn"
              onClick={deleteCourse}
              disabled={saving}
              title={t('course_edit.delete_tooltip')}
            >
              <Icon name="x" size={12} /> {t('common.delete')}
            </button>
          )}
          <button className="btn-secondary btn" onClick={onClose}>{t('common.cancel')}</button>
          <button
            className="btn"
            onClick={save}
            disabled={saving}
            style={{ flex: 1 }}
          >
            {saving ? t('common.saving') : isEdit ? t('course_edit.save_changes') : t('course_edit.create')}
          </button>
        </div>
      </div>
    </Sheet>
  )
}

function Label({ children }: { children: string }) {
  return <div className="caption-2" style={{ marginBottom: 'var(--space-1)' }}>{children.toUpperCase()}</div>
}

function TimeRange({
  emoji,
  label,
  from,
  to,
  onFrom,
  onTo,
}: {
  emoji: string
  label: string
  from: string
  to: string
  onFrom: (v: string) => void
  onTo: (v: string) => void
}) {
  return (
    <div
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 'var(--space-1)',
        padding: '4px 8px',
        borderRadius: 6,
        border: '0.5px solid var(--hairline)',
        background: 'var(--surface-strong)',
      }}
      title={label}
    >
      <span style={{ marginRight: 2 }}>{emoji}</span>
      <input
        type="time"
        value={from}
        onChange={(e) => onFrom(e.target.value)}
        style={{ width: 70, border: 0, background: 'transparent', font: 'inherit', fontSize: 12, color: 'var(--ink)' }}
      />
      <span style={{ opacity: 0.5 }}>–</span>
      <input
        type="time"
        value={to}
        onChange={(e) => onTo(e.target.value)}
        style={{ width: 70, border: 0, background: 'transparent', font: 'inherit', fontSize: 12, color: 'var(--ink)' }}
      />
    </div>
  )
}

function TypeToggle({ label, checked, onChange }: { label: string; checked: boolean; onChange: (v: boolean) => void }) {
  return (
    <label
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 'var(--space-1)',
        padding: '6px 10px',
        borderRadius: 8,
        border: '0.5px solid var(--hairline)',
        background: checked ? 'rgba(0,122,255,.16)' : 'transparent',
        cursor: 'pointer',
        userSelect: 'none',
        fontSize: 12,
        fontWeight: checked ? 600 : 400,
        whiteSpace: 'nowrap',
      }}
    >
      <input
        type="checkbox"
        checked={checked}
        onChange={(e) => onChange(e.target.checked)}
        style={{ cursor: 'pointer' }}
      />
      {label}
    </label>
  )
}
