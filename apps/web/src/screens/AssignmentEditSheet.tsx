import { useEffect, useMemo, useState } from 'react'
import { format } from 'date-fns'
import { de, enGB } from 'date-fns/locale'
import { useTranslation } from 'react-i18next'
import { Sheet } from '@/components/Sheet'
import { Icon } from '@/components/Icon'
import { useActiveInstructors } from '@/hooks/useActiveInstructors'
import { useScheduleConflicts } from '@/hooks/useCourseEdit'
import {
  useCourseTypeCode,
  useSaveAssignment,
  useDeleteAssignment,
} from '@/hooks/useAssignmentEdit'
import type { AssignmentRoleValue } from '@/lib/queries'

interface ExistingAssignment {
  id: string
  instructor_id: string
  role: AssignmentRoleValue | 'dmt'  // 'dmt' nur als Legacy-Wert beim Lesen
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

export function AssignmentEditSheet({ open, onClose, onSaved, courseId, allDates, existingAssignment }: Props) {
  const { t, i18n } = useTranslation()
  const dfLocale = i18n.resolvedLanguage === 'en' ? enGB : de
  const BASE_ROLES = [
    { value: 'haupt' as const,  label: t('assignment_edit.role_haupt') },
    { value: 'assist' as const, label: t('assignment_edit.role_assist') },
  ]
  const OPFER_ROLE = { value: 'opfer' as const, label: t('assignment_edit.role_opfer') }
  const isEdit = !!existingAssignment

  const { data: instructorRows = [] } = useActiveInstructors()
  const instructors = useMemo(
    () => instructorRows.map(({ id, name, padi_level }) => ({ id, name, padi_level })),
    [instructorRows],
  )
  const { data: courseTypeCode = null } = useCourseTypeCode(courseId)
  const saveMutation = useSaveAssignment()
  const deleteMutation = useDeleteAssignment()
  const saving = saveMutation.isPending || deleteMutation.isPending

  const [instructorId, setInstructorId] = useState('')
  const [role, setRole] = useState<AssignmentRoleValue>('assist')
  const [confirmed, setConfirmed] = useState(false)
  /** Empty array means "all dates" */
  const [selectedDates, setSelectedDates] = useState<Set<string>>(new Set())
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!open) return
    setError(null)
    if (existingAssignment) {
      setInstructorId(existingAssignment.instructor_id)
      // Legacy 'dmt' wird transparent als 'assist' behandelt
      const r: AssignmentRoleValue =
        existingAssignment.role === 'dmt' ? 'assist' : existingAssignment.role
      setRole(r)
      setConfirmed(existingAssignment.confirmed)
      setSelectedDates(new Set(existingAssignment.assigned_for_dates ?? []))
    } else {
      setInstructorId('')
      setRole('assist')
      setConfirmed(false)
      setSelectedDates(new Set())
    }
  }, [open, existingAssignment])

  const isRescueCourse = courseTypeCode === 'RESC'
  const availableRoles = isRescueCourse ? [...BASE_ROLES, OPFER_ROLE] : BASE_ROLES

  // Conflict-check (selected dates ∪ all-mode). Filter out self-collisions
  // with the current course in edit mode.
  const checkDates = useMemo(
    () => (selectedDates.size === 0 ? allDates : [...selectedDates]),
    [selectedDates, allDates],
  )
  const { data: rawConflicts = [] } = useScheduleConflicts(instructorId || null, checkDates)
  const conflicts = useMemo(
    () => rawConflicts.filter((c) => c.conflicting_course_id !== courseId),
    [rawConflicts, courseId],
  )

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
    setError(null)

    // Persist dates: if user selected all, store empty array (means "all")
    const datesToStore =
      selectedDates.size === 0 || selectedDates.size === allDates.length
        ? []
        : [...selectedDates]

    try {
      await saveMutation.mutateAsync({
        assignmentId: existingAssignment?.id ?? null,
        input: {
          course_id: courseId,
          instructor_id: instructorId,
          role,
          confirmed,
          assigned_for_dates: datesToStore,
        },
      })
      onSaved()
      onClose()
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t('common.error'))
    }
  }

  async function deleteAssignment() {
    if (!existingAssignment) return
    if (!confirm(t('assignment_edit.confirm_delete'))) return
    setError(null)
    try {
      await deleteMutation.mutateAsync(existingAssignment.id)
      onSaved()
      onClose()
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t('common.error'))
    }
  }

  return (
    <Sheet
      open={open}
      onClose={onClose}
      title={isEdit ? t('assignment_edit.title_edit') : t('assignment_edit.title_new')}
      width={520}
    >
      <div style={{ display: 'grid', gap: 14 }}>
        <div>
          <Label>{t('assignment_edit.label_person')}</Label>
          <select
            value={instructorId}
            onChange={(e) => setInstructorId(e.target.value)}
            style={inputStyle}
          >
            <option value="">— {t('course_edit.choose')} —</option>
            {instructors.map((i) => (
              <option key={i.id} value={i.id}>{i.name} ({i.padi_level})</option>
            ))}
          </select>
        </div>

        <div>
          <Label>{t('instructor_edit.label_role')}</Label>
          <div className="seg">
            {availableRoles.map((r) => (
              <button
                key={r.value}
                type="button"
                className={role === r.value ? 'active' : undefined}
                onClick={() => setRole(r.value)}
              >
                {r.label}
              </button>
            ))}
          </div>
          {isRescueCourse && role === 'opfer' && (
            <div className="caption-2" style={{ marginTop: 6, color: 'var(--ink-2)' }}>
              {t('assignment_edit.opfer_hint')}
            </div>
          )}
        </div>

        <div>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 6 }}>
            <Label>{t('assignment_edit.label_which_days')}</Label>
            <button
              type="button"
              className="btn-ghost btn"
              onClick={selectAll}
              style={{ padding: '0 8px', height: 24 }}
            >
              {t('assignment_edit.all_days')}
            </button>
          </div>
          <div className="caption-2" style={{ marginBottom: 8 }}>
            {t('assignment_edit.days_hint')}
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
                    {format(new Date(d), 'EEE, d. MMM', { locale: dfLocale })}
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
          <label htmlFor="confirmed">{t('assignment_edit.confirmed_label')}</label>
        </div>

        {conflicts.length > 0 && (
          <div
            className="chip-orange"
            style={{ padding: 12, borderRadius: 12, display: 'flex', gap: 10, alignItems: 'flex-start', fontSize: 13 }}
          >
            <Icon name="bell" size={16} />
            <div>
              <strong>{t('course_edit.conflict')}:</strong> {t('assignment_edit.conflict_text', {
                title: conflicts[0].conflicting_course_title,
                role: conflicts[0].conflicting_role,
              })}
              <div className="caption-2" style={{ marginTop: 4 }}>
                {t('assignment_edit.conflict_hint')}
              </div>
            </div>
          </div>
        )}

        {error && <div className="chip chip-red">{error}</div>}

        <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
          {isEdit && (
            <button
              className="btn-danger btn"
              onClick={deleteAssignment}
              disabled={saving}
            >
              <Icon name="x" size={12} /> {t('assignment_edit.remove')}
            </button>
          )}
          <button className="btn-secondary btn" onClick={onClose}>{t('common.cancel')}</button>
          <button
            className="btn"
            onClick={save}
            disabled={saving || !instructorId}
            style={{ flex: 1 }}
          >
            {saving ? t('common.saving') : isEdit ? t('common.save') : t('assignment_edit.assign')}
          </button>
        </div>
      </div>
    </Sheet>
  )
}

function Label({ children }: { children: string }) {
  return <div className="caption-2" style={{ marginBottom: 4 }}>{children.toUpperCase()}</div>
}
