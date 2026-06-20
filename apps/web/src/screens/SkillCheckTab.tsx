/**
 * SkillCheckTab — PADI OWD Skill-Check matrix.
 *
 * Shows a section-grouped, collapsible table:
 *   Rows    = PADI OWD skills
 *   Columns = course participants
 *   Cells   = completion status (empty / done) with click-to-edit popover
 *
 * Filter chips "Alle" / "Heute" restrict visible rows to those relevant for
 * today's course-day type (pool → CW, see → OW, theorie → KD).
 */

import { useEffect, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { CHDateField } from '@/components/CHFields'
import { supabase } from '@/lib/supabase'
import { PADI_OWD_SKILLS, SECTION_LABELS_DE, SECTION_LABELS_EN, type PadiSkillDef, type PadiSkillSection } from '@/lib/padiOwdSkills'
import type { CourseParticipant, AssignmentRow, CourseDate } from '@/lib/queries'

// ─── Types ──────────────────────────────────────────────────────────────────

interface SkillRecord {
  id: string
  course_id: string
  participant_id: string
  skill_code: string
  completed_on: string | null
  tg_number: number | null
  quiz_passed: boolean | null
  video_watched: boolean | null
  instructor_id: string | null
  notes: string | null
}

interface InstructorOption {
  id: string
  name: string
  initials: string
}

interface PopoverState {
  participantId: string
  skillCode: string
  anchorRect: DOMRect
}

interface EditState {
  date: string
  tgNumber: string
  quizPassed: boolean
  videoWatched: boolean
  instructorId: string
  notes: string
}

// ─── Helpers ────────────────────────────────────────────────────────────────

function todayISO(): string {
  return new Date().toISOString().slice(0, 10)
}

/** Returns which sections are relevant for today based on course date types */
function sectionsForToday(courseDates: CourseDate[]): PadiSkillSection[] | null {
  const today = todayISO()
  const todayDate = courseDates.find((d) => d.date === today)
  if (!todayDate) return null

  const sections: PadiSkillSection[] = []
  const hasPool    = todayDate.has_pool    ?? todayDate.type === 'pool'
  const hasLake    = todayDate.has_lake    ?? todayDate.type === 'see'
  const hasTheory  = todayDate.has_theory  ?? todayDate.type === 'theorie'

  if (hasPool) {
    sections.push('cw_dive', 'assessment', 'cw_flex')
  }
  if (hasLake) {
    sections.push('ow_dive', 'ow_flex')
  }
  if (hasTheory) {
    sections.push('kd')
  }
  return sections.length > 0 ? sections : null
}

// ─── Cell popover editor ─────────────────────────────────────────────────────

function CellPopover({
  skill,
  record,
  instructors,
  defaultInstructorId,
  onSave,
  onClear,
  onClose,
  anchorRect,
}: {
  skill: PadiSkillDef
  record: SkillRecord | undefined
  instructors: InstructorOption[]
  defaultInstructorId: string
  onSave: (state: EditState) => Promise<void>
  onClear: () => Promise<void>
  onClose: () => void
  anchorRect: DOMRect
}) {
  const { t } = useTranslation()
  const [edit, setEdit] = useState<EditState>(() => ({
    date: record?.completed_on ?? todayISO(),
    tgNumber: record?.tg_number != null ? String(record.tg_number) : '',
    quizPassed: record?.quiz_passed ?? false,
    videoWatched: record?.video_watched ?? false,
    instructorId: record?.instructor_id ?? defaultInstructorId,
    notes: record?.notes ?? '',
  }))
  const [saving, setSaving] = useState(false)
  const ref = useRef<HTMLDivElement>(null)

  // Position relative to viewport
  const viewH = window.innerHeight
  const spaceBelow = viewH - anchorRect.bottom
  const above = spaceBelow < 220

  const style: React.CSSProperties = {
    position: 'fixed',
    left: Math.min(anchorRect.left, window.innerWidth - 280),
    zIndex: 2000,
    width: 260,
    background: 'var(--bg-card)',
    border: '1px solid var(--border-primary)',
    borderRadius: 10,
    boxShadow: 'var(--shadow-popover)',
    padding: '12px 14px',
    display: 'grid',
    gap: 10,
    fontSize: 13,
    color: 'var(--text-primary)',
  }
  if (above) {
    style.bottom = viewH - anchorRect.top + 4
  } else {
    style.top = anchorRect.bottom + 4
  }

  // Close on outside click
  useEffect(() => {
    function handler(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) {
        onClose()
      }
    }
    document.addEventListener('mousedown', handler, true)
    return () => document.removeEventListener('mousedown', handler, true)
  }, [onClose])

  const tgOptions = skill.tgNumberOptions ?? [1, 2, 3, 4]

  async function handleSave() {
    setSaving(true)
    try { await onSave(edit) } finally { setSaving(false) }
  }

  async function handleClear() {
    setSaving(true)
    try { await onClear() } finally { setSaving(false) }
  }

  return (
    <div ref={ref} style={style} onClick={(e) => e.stopPropagation()}>
      <div style={{ fontWeight: 600, fontSize: 12, color: 'var(--text-secondary)', marginBottom: 2 }}>
        {skill.label_de}
      </div>

      {skill.hasDate && (
        <label style={{ display: 'grid', gap: 'var(--space-1)' }}>
          <span style={{ fontSize: 11, color: 'var(--text-tertiary)' }}>
            {t('padi_skill_check.label_date')}
          </span>
          <CHDateField
            value={edit.date}
            onChange={(v) => setEdit((s) => ({ ...s, date: v }))}
            style={{ fontSize: 13, background: '#FFFFFF', border: '1px solid var(--border-primary)', borderRadius: 6, padding: '6px 8px', color: 'var(--text-primary)', outline: 'none' }}
          />
        </label>
      )}

      {skill.hasTgNumber && (
        <label style={{ display: 'grid', gap: 'var(--space-1)' }}>
          <span style={{ fontSize: 11, color: 'var(--text-tertiary)' }}>
            {t('padi_skill_check.label_tg_number')}
          </span>
          <div style={{ display: 'flex', gap: 6 }}>
            {tgOptions.map((n) => (
              <button
                key={n}
                type="button"
                onClick={() => setEdit((s) => ({ ...s, tgNumber: String(n) }))}
                style={{
                  flex: 1,
                  padding: '6px 0',
                  borderRadius: 6,
                  border: '1px solid var(--border-primary)',
                  background: edit.tgNumber === String(n) ? 'var(--brand-blue)' : '#FFFFFF',
                  color: edit.tgNumber === String(n) ? '#FFFFFF' : 'var(--text-primary)',
                  cursor: 'pointer',
                  fontSize: 13,
                  fontWeight: edit.tgNumber === String(n) ? 600 : 400,
                }}
              >
                TG {n}
              </button>
            ))}
          </div>
        </label>
      )}

      {(skill.hasQuiz || skill.hasVideo) && (
        <div style={{ display: 'flex', gap: 'var(--space-3)' }}>
          {skill.hasQuiz && (
            <label style={{ display: 'flex', alignItems: 'center', gap: 6, cursor: 'pointer' }}>
              <input
                type="checkbox"
                checked={edit.quizPassed}
                onChange={(e) => setEdit((s) => ({ ...s, quizPassed: e.target.checked }))}
              />
              <span style={{ fontSize: 12 }}>{t('padi_skill_check.label_quiz')}</span>
            </label>
          )}
          {skill.hasVideo && (
            <label style={{ display: 'flex', alignItems: 'center', gap: 6, cursor: 'pointer' }}>
              <input
                type="checkbox"
                checked={edit.videoWatched}
                onChange={(e) => setEdit((s) => ({ ...s, videoWatched: e.target.checked }))}
              />
              <span style={{ fontSize: 12 }}>{t('padi_skill_check.label_video')}</span>
            </label>
          )}
        </div>
      )}

      {instructors.length > 0 && (
        <label style={{ display: 'grid', gap: 'var(--space-1)' }}>
          <span style={{ fontSize: 11, color: 'var(--text-tertiary)' }}>
            {t('padi_skill_check.label_instructor')}
          </span>
          <select
            value={edit.instructorId}
            onChange={(e) => setEdit((s) => ({ ...s, instructorId: e.target.value }))}
            style={{ fontSize: 13, background: '#FFFFFF', border: '1px solid var(--border-primary)', borderRadius: 6, padding: '6px 8px', color: 'var(--text-primary)', outline: 'none' }}
          >
            <option value="">{t('padi_skill_check.no_instructor')}</option>
            {instructors.map((i) => (
              <option key={i.id} value={i.id}>{i.name}</option>
            ))}
          </select>
        </label>
      )}

      <div style={{ display: 'flex', gap: 6, marginTop: 2 }}>
        <button
          type="button"
          className="atoll-btn atoll-btn--primary"
          style={{ flex: 1, height: 30, fontSize: 13 }}
          disabled={saving}
          onClick={handleSave}
        >
          {saving ? '…' : t('padi_skill_check.save')}
        </button>
        {record && (
          <button
            type="button"
            className="atoll-btn"
            style={{ height: 30, fontSize: 13, color: 'var(--danger, #ff453a)' }}
            disabled={saving}
            onClick={handleClear}
          >
            {t('padi_skill_check.clear')}
          </button>
        )}
      </div>
    </div>
  )
}

// ─── Main component ───────────────────────────────────────────────────────────

export function SkillCheckTab({
  courseId,
  participants,
  assignments,
  courseDates,
}: {
  courseId: string
  participants: CourseParticipant[]
  assignments: (AssignmentRow & { assigned_for_dates?: string[] })[]
  courseDates: CourseDate[]
}) {
  const { t, i18n } = useTranslation()
  const isDE = i18n.resolvedLanguage !== 'en'

  const [records, setRecords] = useState<SkillRecord[]>([])
  const [instructors, setInstructors] = useState<InstructorOption[]>([])
  const [filter, setFilter] = useState<'all' | 'today'>('all')
  const [collapsed, setCollapsed] = useState<Set<PadiSkillSection>>(new Set())
  const [popover, setPopover] = useState<PopoverState | null>(null)
  const [loading, setLoading] = useState(true)

  const activeParticipants = participants.filter((p) => p.status !== 'dropped' && p.student)

  // Default instructor = haupt TL for today (or first haupt)
  const today = todayISO()
  const hauptAssignment = assignments.find((a) => {
    if (a.role !== 'haupt') return false
    const dates = (a as any).assigned_for_dates as string[] | null
    if (dates && dates.length > 0) return dates.includes(today)
    return true
  }) ?? assignments.find((a) => a.role === 'haupt')
  const defaultInstructorId = hauptAssignment?.instructor?.id ?? ''

  // Load all skill records for this course
  useEffect(() => {
    setLoading(true)
    supabase
      .from('padi_skill_records')
      .select('id, course_id, participant_id, skill_code, completed_on, tg_number, quiz_passed, video_watched, instructor_id, notes')
      .eq('course_id', courseId)
      .then(({ data }) => {
        setRecords((data ?? []) as SkillRecord[])
        setLoading(false)
      })
  }, [courseId])

  // Load instructors assigned to this course
  useEffect(() => {
    const ids = assignments
      .map((a) => a.instructor?.id)
      .filter((id): id is string => !!id)
    if (ids.length === 0) return
    // Phase J Etappe 3b: contacts JOIN contact_instructor (initials seit 0091)
    supabase
      .from('contacts')
      .select('id, display_name, last_name, first_name, instructor:contact_instructor!inner(initials)')
      .in('id', ids)
      .then(({ data }) => {
        const rows = (data ?? []).map((c: unknown) => {
          const row = c as {
            id: string
            display_name: string | null
            last_name: string | null
            first_name: string | null
            instructor: { initials: string | null } | null
          }
          return {
            id: row.id,
            name: row.display_name ?? [row.last_name, row.first_name].filter(Boolean).join(', '),
            initials: row.instructor?.initials ?? '',
          }
        })
        setInstructors(rows)
      })
  }, [assignments])

  // Build record lookup: `${participantId}::${skillCode}` → record
  const recordMap = new Map<string, SkillRecord>()
  for (const r of records) {
    recordMap.set(`${r.participant_id}::${r.skill_code}`, r)
  }

  // Filter: today mode restricts sections to those relevant for today
  const todaySections = sectionsForToday(courseDates)
  const visibleSkills = filter === 'today' && todaySections
    ? PADI_OWD_SKILLS.filter((s) => todaySections.includes(s.section))
    : PADI_OWD_SKILLS

  // Group by section
  const sections: PadiSkillSection[] = ['cw_dive', 'assessment', 'cw_flex', 'kd', 'ow_dive', 'ow_flex']
  const skillsBySection = new Map<PadiSkillSection, PadiSkillDef[]>()
  for (const s of sections) {
    const filtered = visibleSkills.filter((sk) => sk.section === s)
    if (filtered.length > 0) skillsBySection.set(s, filtered)
  }

  function toggleSection(section: PadiSkillSection) {
    setCollapsed((prev) => {
      const next = new Set(prev)
      if (next.has(section)) next.delete(section)
      else next.add(section)
      return next
    })
  }

  function openPopover(e: React.MouseEvent<HTMLButtonElement>, participantId: string, skillCode: string) {
    e.stopPropagation()
    const rect = (e.currentTarget as HTMLElement).getBoundingClientRect()
    setPopover({ participantId, skillCode, anchorRect: rect })
  }

  function closePopover() {
    setPopover(null)
  }

  async function handleSave(participantId: string, skillCode: string, state: EditState) {
    const skill = PADI_OWD_SKILLS.find((s) => s.code === skillCode)!
    const existing = recordMap.get(`${participantId}::${skillCode}`)

    const payload = {
      course_id: courseId,
      participant_id: participantId,
      skill_code: skillCode,
      completed_on: skill.hasDate && state.date ? state.date : null,
      tg_number: skill.hasTgNumber && state.tgNumber ? parseInt(state.tgNumber) : null,
      quiz_passed: skill.hasQuiz ? state.quizPassed : null,
      video_watched: skill.hasVideo ? state.videoWatched : null,
      instructor_id: state.instructorId || null,
      notes: state.notes || null,
    }

    if (existing) {
      await supabase
        .from('padi_skill_records')
        .update(payload)
        .eq('id', existing.id)
      setRecords((prev) =>
        prev.map((r) => (r.id === existing.id ? { ...r, ...payload, id: existing.id } : r))
      )
    } else {
      const { data } = await supabase
        .from('padi_skill_records')
        .insert(payload)
        .select()
        .single()
      if (data) setRecords((prev) => [...prev, data as SkillRecord])
    }
    closePopover()
  }

  async function handleClear(participantId: string, skillCode: string) {
    const existing = recordMap.get(`${participantId}::${skillCode}`)
    if (!existing) return
    await supabase.from('padi_skill_records').delete().eq('id', existing.id)
    setRecords((prev) => prev.filter((r) => r.id !== existing.id))
    closePopover()
  }

  // Completion count per participant
  function doneCount(participantId: string): number {
    return records.filter((r) => r.participant_id === participantId).length
  }

  const sectionLabels = isDE ? SECTION_LABELS_DE : SECTION_LABELS_EN

  if (loading) {
    return <div className="atoll-cockpit__loading">{t('common.loading')}</div>
  }

  return (
    <div style={{ display: 'grid', gap: 0 }}>
      {/* Filter chips */}
      <div style={{ display: 'flex', gap: 'var(--space-2)', marginBottom: 'var(--space-3)', alignItems: 'center' }}>
        <button
          type="button"
          className={filter === 'all' ? 'atoll-btn atoll-btn--primary' : 'atoll-btn'}
          style={{ height: 28, padding: '0 12px', fontSize: 12 }}
          onClick={() => setFilter('all')}
        >
          {t('padi_skill_check.filter_all')}
        </button>
        <button
          type="button"
          className={filter === 'today' ? 'atoll-btn atoll-btn--primary' : 'atoll-btn'}
          style={{ height: 28, padding: '0 12px', fontSize: 12 }}
          onClick={() => setFilter('today')}
        >
          {t('padi_skill_check.filter_today')}
        </button>
        {filter === 'today' && !todaySections && (
          <span style={{ fontSize: 12, color: 'var(--text-tertiary)' }}>
            {t('padi_skill_check.no_course_today')}
          </span>
        )}
      </div>

      {/* Matrix table */}
      <div style={{ overflowX: 'auto', WebkitOverflowScrolling: 'touch' }}>
        <table style={{ borderCollapse: 'collapse', width: '100%', tableLayout: 'auto' }}>
          <thead>
            <tr>
              <th style={{ textAlign: 'left', padding: '4px 8px', fontSize: 11, color: 'var(--text-tertiary)', fontWeight: 500, whiteSpace: 'nowrap', minWidth: 180, position: 'sticky', left: 0, background: 'var(--surface)', zIndex: 1 }}>
                {t('padi_skill_check.col_skill')}
              </th>
              {activeParticipants.map((p) => (
                <th key={p.id} style={{ textAlign: 'center', padding: '4px 6px', fontSize: 11, color: 'var(--text-tertiary)', fontWeight: 500, whiteSpace: 'nowrap' }}>
                  <div>{p.student?.name?.split(' ')[0] ?? '—'}</div>
                  <div style={{ fontSize: 10, color: 'var(--text-tertiary)', opacity: 0.7 }}>
                    {doneCount(p.id)}/{PADI_OWD_SKILLS.length}
                  </div>
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {sections.map((section) => {
              const sectionSkills = skillsBySection.get(section)
              if (!sectionSkills) return null
              const isCollapsed = collapsed.has(section)
              return (
                <>
                  {/* Section header row */}
                  <tr key={`section-${section}`}>
                    <td
                      colSpan={activeParticipants.length + 1}
                      style={{ padding: '12px 8px 4px', borderTop: '1px solid var(--border-secondary)' }}
                    >
                      <button
                        type="button"
                        onClick={() => toggleSection(section)}
                        style={{
                          background: 'none',
                          border: 'none',
                          cursor: 'pointer',
                          color: 'var(--text-secondary)',
                          fontWeight: 600,
                          fontSize: 11,
                          textTransform: 'uppercase',
                          letterSpacing: '0.06em',
                          padding: 0,
                          display: 'flex',
                          alignItems: 'center',
                          gap: 6,
                        }}
                      >
                        <span style={{ fontSize: 10, opacity: 0.6, transform: isCollapsed ? 'none' : 'rotate(90deg)', display: 'inline-block', transition: 'transform .15s' }}>▶</span>
                        {sectionLabels[section]}
                        <span style={{ fontSize: 10, color: 'var(--text-tertiary)', fontWeight: 400, textTransform: 'none', letterSpacing: 0 }}>
                          ({sectionSkills.length})
                        </span>
                      </button>
                    </td>
                  </tr>

                  {!isCollapsed && sectionSkills.map((skill) => (
                    <tr key={skill.code} style={{ borderBottom: '1px solid var(--border-secondary)' }}>
                      <td style={{ padding: '6px 8px', fontSize: 12, color: 'var(--text-primary)', whiteSpace: 'nowrap', maxWidth: 240, overflow: 'hidden', textOverflow: 'ellipsis', position: 'sticky', left: 0, background: 'var(--bg-card)', zIndex: 1 }}>
                        {skill.label_de}
                      </td>
                      {activeParticipants.map((p) => {
                        const record = recordMap.get(`${p.id}::${skill.code}`)
                        const isDone = !!record
                        const isOpen = popover?.participantId === p.id && popover?.skillCode === skill.code
                        return (
                          <td key={p.id} style={{ textAlign: 'center', padding: '4px 8px' }}>
                            <button
                              type="button"
                              onClick={(e) => openPopover(e, p.id, skill.code)}
                              title={isDone
                                ? [record.completed_on, instructors.find((i) => i.id === record.instructor_id)?.name].filter(Boolean).join(' · ')
                                : t('padi_skill_check.cell_empty_hint')
                              }
                              style={{
                                width: 28,
                                height: 28,
                                borderRadius: 6,
                                border: isOpen
                                  ? '2px solid var(--brand-blue)'
                                  : isDone
                                  ? '2px solid var(--brand-blue)'
                                  : '1.5px solid var(--border-primary)',
                                background: isDone
                                  ? 'var(--brand-blue-50)'
                                  : '#FFFFFF',
                                cursor: 'pointer',
                                display: 'inline-flex',
                                alignItems: 'center',
                                justifyContent: 'center',
                                fontSize: 14,
                                fontWeight: 600,
                                color: isDone ? 'var(--brand-blue)' : 'var(--text-tertiary)',
                                transition: 'background .1s, border-color .1s, transform .1s',
                              }}
                              onMouseEnter={(e) => {
                                if (!isDone && !isOpen) {
                                  e.currentTarget.style.borderColor = 'var(--brand-blue)'
                                  e.currentTarget.style.background = 'var(--brand-blue-50)'
                                }
                              }}
                              onMouseLeave={(e) => {
                                if (!isDone && !isOpen) {
                                  e.currentTarget.style.borderColor = 'var(--border-primary)'
                                  e.currentTarget.style.background = '#FFFFFF'
                                }
                              }}
                            >
                              {isDone ? (skill.hasTgNumber ? (record.tg_number ? `${record.tg_number}` : '✓') : '✓') : ''}
                            </button>
                          </td>
                        )
                      })}
                    </tr>
                  ))}
                </>
              )
            })}
          </tbody>
        </table>
      </div>

      {/* Cell popover */}
      {popover && (() => {
        const skill = PADI_OWD_SKILLS.find((s) => s.code === popover.skillCode)
        if (!skill) return null
        const record = recordMap.get(`${popover.participantId}::${popover.skillCode}`)
        return (
          <CellPopover
            skill={skill}
            record={record}
            instructors={instructors}
            defaultInstructorId={defaultInstructorId}
            onSave={(state) => handleSave(popover.participantId, popover.skillCode, state)}
            onClear={() => handleClear(popover.participantId, popover.skillCode)}
            onClose={closePopover}
            anchorRect={popover.anchorRect}
          />
        )
      })()}
    </div>
  )
}
