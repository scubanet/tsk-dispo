import { useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
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
import { fetchCoursesInRange, type CourseRow } from '@/lib/queries'

type Mode = 'week' | 'month'

const TYPE_COLORS: Record<string, string> = {
  OWD: '#0A84FF',
  AOWD: '#5856D6',
  DSD: '#34C759',
  BUBB: '#34C759',
  DRY: '#30B0C7',
  DM: '#AF52DE',
  EFR: '#FF9500',
  RESC: '#FF3B30',
  EAN: '#5AC8FA',
}

function colorForType(code?: string): string {
  if (!code) return '#8E8E93'
  return TYPE_COLORS[code] ?? '#8E8E93'
}

export function CalendarScreen() {
  const navigate = useNavigate()
  const [mode, setMode] = useState<Mode>('week')
  const [anchor, setAnchor] = useState<Date>(new Date())
  const [courses, setCourses] = useState<CourseRow[]>([])

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
    ).then(setCourses)
  }, [range])

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
      </Topbar>

      <div className="scroll" style={{ flex: 1, padding: 16, overflow: 'auto' }}>
        {mode === 'week' ? (
          <WeekView range={range} courses={courses} onClickCourse={(id) => navigate(`/kurse/${id}`)} />
        ) : (
          <MonthView anchor={anchor} courses={courses} onClickCourse={(id) => navigate(`/kurse/${id}`)} />
        )}
      </div>
    </>
  )
}

function WeekView({
  range,
  courses,
  onClickCourse,
}: {
  range: { start: Date; end: Date }
  courses: CourseRow[]
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
          const dayCourses = courses.filter((c) => isSameDay(new Date(c.start_date), d))
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
              {dayCourses.map((c) => (
                <div
                  key={c.id}
                  onClick={() => onClickCourse(c.id)}
                  style={{
                    background: 'var(--surface-strong)',
                    borderLeft: `3px solid ${colorForType(c.course_type?.code)}`,
                    borderRadius: 8,
                    padding: '6px 8px',
                    fontSize: 11,
                    cursor: 'pointer',
                    opacity: c.status === 'cancelled' ? 0.5 : 1,
                    textDecoration: c.status === 'cancelled' ? 'line-through' : 'none',
                  }}
                >
                  <div style={{ fontWeight: 600 }}>{c.course_type?.code}</div>
                  <div style={{ fontSize: 10.5, color: 'var(--ink-2)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {c.title}
                  </div>
                </div>
              ))}
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
  onClickCourse,
}: {
  anchor: Date
  courses: CourseRow[]
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
          const dayCourses = courses.filter((c) => isSameDay(new Date(c.start_date), d))
          const inMonth = isSameMonth(d, anchor)
          return (
            <div
              key={d.toISOString()}
              style={{
                padding: 8,
                minHeight: 100,
                borderRight: '0.5px solid var(--separator)',
                borderTop: '0.5px solid var(--separator)',
                opacity: inMonth ? 1 : 0.4,
                background: isSameDay(d, new Date()) ? 'var(--accent-soft)' : undefined,
              }}
            >
              <div style={{ fontWeight: 600, fontSize: 12, marginBottom: 4 }}>
                {format(d, 'd', { locale: de })}
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 3 }}>
                {dayCourses.slice(0, 3).map((c) => (
                  <div
                    key={c.id}
                    onClick={() => onClickCourse(c.id)}
                    style={{
                      fontSize: 10,
                      padding: '2px 6px',
                      borderRadius: 4,
                      background: colorForType(c.course_type?.code) + '22',
                      color: colorForType(c.course_type?.code),
                      cursor: 'pointer',
                      overflow: 'hidden',
                      textOverflow: 'ellipsis',
                      whiteSpace: 'nowrap',
                      fontWeight: 600,
                      opacity: c.status === 'cancelled' ? 0.5 : 1,
                    }}
                  >
                    {c.course_type?.code}
                  </div>
                ))}
                {dayCourses.length > 3 && (
                  <div className="caption-2">+{dayCourses.length - 3} mehr</div>
                )}
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}
