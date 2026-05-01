import { useEffect, useMemo, useState } from 'react'
import { useNavigate, useOutletContext } from 'react-router-dom'
import {
  addDays,
  addMonths,
  addWeeks,
  eachDayOfInterval,
  endOfMonth,
  endOfWeek,
  format,
  isSameDay,
  isSameMonth,
  startOfMonth,
  startOfWeek,
  subMonths,
  subWeeks,
} from 'date-fns'
import { de } from 'date-fns/locale'
import { Topbar } from '@/components/Topbar'
import { Icon } from '@/components/Icon'
import { SegmentedControl } from '@/components/SegmentedControl'
import { fetchCoursesInRange, fetchAssignmentsForCourses, type CourseRow } from '@/lib/queries'
import { CourseEditSheet } from './CourseEditSheet'
import type { OutletCtx } from '@/layout/AppShell'

type Mode = 'week' | 'month'

const TYPE_COLORS: Record<string, string> = {
  OWD: '#0A84FF',
  AOWD: '#5856D6',
  DSD: '#34C759',
  BUBB: '#34C759',
  DRY: '#30B0C7',
  DM: '#AF52DE',
  EFR: '#FF9500',
  EFRI: '#FF9500',
  RESC: '#FF3B30',
  EAN: '#5AC8FA',
  IDC: '#FF2D55',
}

function colorForType(code?: string): string {
  if (!code) return '#8E8E93'
  if (TYPE_COLORS[code]) return TYPE_COLORS[code]
  if (code.startsWith('SPEI_')) return '#AF52DE'   // alle SPEIs in lila
  if (code.startsWith('SPEC_')) return '#30B0C7'   // alle Specialties in türkis
  return '#8E8E93'
}

/** All dates a course occupies (start + zero or more additional). */
function courseDates(c: CourseRow): string[] {
  return [c.start_date, ...(c.additional_dates ?? [])]
}

/** Returns courses whose ANY date matches the given day. */
function coursesOnDay(all: CourseRow[], day: Date): CourseRow[] {
  return all.filter((c) =>
    courseDates(c).some((d) => d && isSameDay(new Date(d), day)),
  )
}

export function CalendarScreen() {
  const navigate = useNavigate()
  const { user } = useOutletContext<OutletCtx>()
  const isDispatcher = user.role === 'dispatcher'
  const [mode, setMode] = useState<Mode>('month')
  const [anchor, setAnchor] = useState<Date>(new Date())
  const [courses, setCourses] = useState<CourseRow[]>([])
  const [hauptByCourse, setHauptByCourse] = useState<Set<string>>(new Set())
  const [editOpen, setEditOpen] = useState(false)
  const [refreshTick, setRefreshTick] = useState(0)

  const range = useMemo(() => {
    if (mode === 'week') {
      const start = startOfWeek(anchor, { weekStartsOn: 1 })
      const end = addDays(start, 6)
      return { start, end }
    }
    return { start: startOfMonth(anchor), end: endOfMonth(anchor) }
  }, [anchor, mode])

  useEffect(() => {
    fetchCoursesInRange(
      format(range.start, 'yyyy-MM-dd'),
      format(range.end, 'yyyy-MM-dd'),
    ).then(async (cs) => {
      setCourses(cs)
      const ids = cs.map((c) => c.id)
      const assignments = await fetchAssignmentsForCourses(ids)
      const withHaupt = new Set(
        assignments.filter((a) => a.role === 'haupt').map((a) => a.course_id),
      )
      setHauptByCourse(withHaupt)
    })
  }, [range, refreshTick])

  function prev() {
    setAnchor((d) => (mode === 'week' ? subWeeks(d, 1) : subMonths(d, 1)))
  }
  function next() {
    setAnchor((d) => (mode === 'week' ? addWeeks(d, 1) : addMonths(d, 1)))
  }
  function today() { setAnchor(new Date()) }

  const title = mode === 'week'
    ? `KW ${format(range.start, 'w')} · ${format(range.start, 'd. MMM', { locale: de })} – ${format(range.end, 'd. MMM yyyy', { locale: de })}`
    : format(anchor, 'MMMM yyyy', { locale: de })

  return (
    <>
      <Topbar title="Kalender" subtitle={title}>
        <SegmentedControl
          value={mode}
          options={[
            { value: 'week', label: 'Woche' },
            { value: 'month', label: 'Monat' },
          ]}
          onChange={setMode}
        />
        <button className="btn-icon" onClick={prev}><Icon name="chevron-left" size={14} /></button>
        <button className="btn-secondary btn" onClick={today}>Heute</button>
        <button className="btn-icon" onClick={next}><Icon name="chevron-right" size={14} /></button>
        {isDispatcher && (
          <button className="btn" onClick={() => setEditOpen(true)}>
            <Icon name="plus" size={14} /> Neuer Kurs
          </button>
        )}
      </Topbar>

      <CourseEditSheet
        open={editOpen}
        onClose={() => setEditOpen(false)}
        onSaved={() => setRefreshTick((t) => t + 1)}
        courseId={null}
      />

      <div className="scroll" style={{ flex: 1, padding: 16, overflow: 'auto' }}>
        {mode === 'week' ? (
          <WeekView
            range={range}
            courses={courses}
            hauptByCourse={hauptByCourse}
            onClickCourse={(id) => navigate(`/kurse/${id}`)}
          />
        ) : (
          <MonthView
            anchor={anchor}
            courses={courses}
            hauptByCourse={hauptByCourse}
            onClickCourse={(id) => navigate(`/kurse/${id}`)}
          />
        )}

        <div className="caption-2" style={{ marginTop: 12, padding: '0 4px', display: 'flex', gap: 16, alignItems: 'center', flexWrap: 'wrap' }}>
          <span style={{ display: 'inline-flex', gap: 6, alignItems: 'center' }}>
            <span style={{ display: 'inline-block', width: 12, height: 12, borderRadius: 2, background: '#FF3B3022', borderLeft: '2px solid #FF3B30' }} />
            ohne Haupt-Instructor
          </span>
          <span style={{ display: 'inline-flex', gap: 6, alignItems: 'center' }}>
            <span style={{ display: 'inline-block', width: 12, height: 12, borderRadius: 2, background: 'var(--accent-soft)' }} />
            heute
          </span>
        </div>
      </div>
    </>
  )
}

function WeekView({
  range,
  courses,
  hauptByCourse,
  onClickCourse,
}: {
  range: { start: Date; end: Date }
  courses: CourseRow[]
  hauptByCourse: Set<string>
  onClickCourse: (id: string) => void
}) {
  const days = eachDayOfInterval(range)
  return (
    <div className="glass card" style={{ padding: 0 }}>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', borderBottom: '0.5px solid var(--hairline)' }}>
        {days.map((d) => (
          <div
            key={d.toISOString()}
            style={{
              padding: 12,
              textAlign: 'center',
              borderRight: '0.5px solid var(--separator)',
              background: isSameDay(d, new Date()) ? 'var(--accent-soft)' : undefined,
            }}
          >
            <div style={{ fontWeight: 600, fontSize: 13 }}>
              {format(d, 'EEE', { locale: de })}
            </div>
            <div className="caption">{format(d, 'd. MMM', { locale: de })}</div>
          </div>
        ))}
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', minHeight: 400 }}>
        {days.map((d) => {
          const dayCourses = coursesOnDay(courses, d)
          return (
            <div
              key={d.toISOString()}
              style={{
                padding: 8,
                borderRight: '0.5px solid var(--separator)',
                display: 'flex',
                flexDirection: 'column',
                gap: 6,
                minHeight: 200,
              }}
            >
              {dayCourses.map((c) => {
                const allDates = courseDates(c)
                const isMultiDay = allDates.length > 1
                const dayIndex = allDates.findIndex((dt) => dt && isSameDay(new Date(dt), d))
                const noHaupt = !hauptByCourse.has(c.id) && c.status !== 'cancelled'
                const baseColor = colorForType(c.course_type?.code)
                return (
                  <div
                    key={c.id}
                    onClick={() => onClickCourse(c.id)}
                    style={{
                      background: noHaupt ? '#FF3B3022' : 'var(--surface-strong)',
                      borderLeft: `3px solid ${noHaupt ? '#FF3B30' : baseColor}`,
                      borderRadius: 8,
                      padding: '6px 8px',
                      fontSize: 11,
                      cursor: 'pointer',
                      opacity: c.status === 'cancelled' ? 0.5 : 1,
                      textDecoration: c.status === 'cancelled' ? 'line-through' : 'none',
                    }}
                    title={noHaupt ? 'Kein Haupt-Instructor zugewiesen' : c.title}
                  >
                    <div
                      style={{
                        fontWeight: 600,
                        fontSize: 11.5,
                        overflow: 'hidden',
                        textOverflow: 'ellipsis',
                        whiteSpace: 'nowrap',
                        color: noHaupt ? '#c4302a' : 'inherit',
                      }}
                    >
                      {noHaupt && '⚠ '}{c.title}
                    </div>
                    <div
                      className="caption-2"
                      style={{
                        marginTop: 2,
                        display: 'flex',
                        gap: 6,
                        alignItems: 'center',
                      }}
                    >
                      <span
                        style={{
                          background: baseColor + '22',
                          color: baseColor,
                          padding: '0 6px',
                          borderRadius: 4,
                          fontWeight: 600,
                          fontSize: 9.5,
                        }}
                      >
                        {c.course_type?.code ?? '—'}
                      </span>
                      {isMultiDay && (
                        <span style={{ fontSize: 9.5, color: 'var(--ink-3)' }}>
                          Tag {dayIndex + 1}/{allDates.length}
                        </span>
                      )}
                    </div>
                  </div>
                )
              })}
            </div>
          )
        })}
      </div>
    </div>
  )
}

function MonthView({
  anchor,
  courses,
  hauptByCourse,
  onClickCourse,
}: {
  anchor: Date
  courses: CourseRow[]
  hauptByCourse: Set<string>
  onClickCourse: (id: string) => void
}) {
  const start = startOfWeek(startOfMonth(anchor), { weekStartsOn: 1 })
  const end = endOfWeek(endOfMonth(anchor), { weekStartsOn: 1 })
  const days = eachDayOfInterval({ start, end })

  return (
    <div className="glass card" style={{ padding: 0 }}>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', borderBottom: '0.5px solid var(--hairline)' }}>
        {['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'].map((d) => (
          <div key={d} style={{ padding: '10px 8px', textAlign: 'center', fontWeight: 600, fontSize: 12 }}>
            {d}
          </div>
        ))}
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)' }}>
        {days.map((d) => {
          const dayCourses = coursesOnDay(courses, d)
          const inMonth = isSameMonth(d, anchor)
          return (
            <div
              key={d.toISOString()}
              style={{
                padding: 8,
                minHeight: 110,
                borderRight: '0.5px solid var(--separator)',
                borderTop: '0.5px solid var(--separator)',
                opacity: inMonth ? 1 : 0.4,
                background: isSameDay(d, new Date()) ? 'var(--accent-soft)' : undefined,
              }}
            >
              <div style={{ fontWeight: 600, fontSize: 12, marginBottom: 4 }}>
                {format(d, 'd', { locale: de })}
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                {dayCourses.slice(0, 4).map((c) => {
                  const isMultiDay = (c.additional_dates?.length ?? 0) > 0
                  const noHaupt = !hauptByCourse.has(c.id) && c.status !== 'cancelled'
                  const baseColor = colorForType(c.course_type?.code)
                  return (
                    <div
                      key={c.id}
                      onClick={() => onClickCourse(c.id)}
                      title={noHaupt ? `${c.title} — kein Haupt-Instructor` : c.title}
                      style={{
                        fontSize: 10.5,
                        padding: '2px 6px',
                        borderRadius: 4,
                        background: noHaupt ? '#FF3B3022' : baseColor + '22',
                        color: noHaupt ? '#c4302a' : baseColor,
                        cursor: 'pointer',
                        overflow: 'hidden',
                        textOverflow: 'ellipsis',
                        whiteSpace: 'nowrap',
                        fontWeight: 500,
                        opacity: c.status === 'cancelled' ? 0.5 : 1,
                        textDecoration: c.status === 'cancelled' ? 'line-through' : 'none',
                        borderLeft: noHaupt
                          ? `2px solid #FF3B30`
                          : isMultiDay
                            ? `2px solid ${baseColor}`
                            : undefined,
                      }}
                    >
                      {noHaupt && '⚠ '}{c.title}
                    </div>
                  )
                })}
                {dayCourses.length > 4 && (
                  <div className="caption-2">+{dayCourses.length - 4} mehr</div>
                )}
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}
