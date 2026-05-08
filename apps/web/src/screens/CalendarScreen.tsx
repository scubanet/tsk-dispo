/**
 * CalendarScreen — Foundation-based rewrite.
 *
 * Layout:
 *   PageHeader
 *     ├── FilterTabBar (week / month)
 *     ├── ← / Heute / →
 *     └── + Neuer Kurs (dispatcher)
 *   ┌─ Foundation card ───────────────────────────────────────┐
 *   │  WeekView OR MonthView                                  │
 *   └─────────────────────────────────────────────────────────┘
 *   Legend (no haupt / tentative / cancelled / today)
 *
 * Colors come from foundation tokens via `courseTypeColor()` — no more
 * hand-rolled hex. Status overrides (no haupt / tentative) use semantic
 * tokens (red / amber).
 */

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
  type Locale,
} from 'date-fns'
import { de, enGB } from 'date-fns/locale'
import { useTranslation } from 'react-i18next'
import {
  PageHeader,
  FilterTabBar,
  Icon,
  courseTypeColor,
  toISODate,
} from '@/foundation'
import type { CourseType } from '@/types/foundation'
import { fetchCoursesInRange, fetchAssignmentsForCourses, type CourseRow } from '@/lib/queries'
import { CourseEditSheet } from './CourseEditSheet'
import type { OutletCtx } from '@/layout/AppShell'

type Mode = 'week' | 'month'

/** Map legacy course-type-code string → foundation `CourseType`. */
function asCourseType(code: string | undefined | null): CourseType {
  if (!code) return 'OWD'
  if (code.startsWith('SPEI_')) return { type: 'SPEI', specialty: code.slice(5) as never }
  if (code.startsWith('SP_')) return { type: 'SPECIALTY', specialty: code.slice(3) as never }
  return code as CourseType
}

interface SlotStyle {
  bg: string
  border: string
  text: string
  prefix: string
  tooltip: string
  isTentative: boolean
}

/**
 * Visual priority: no-haupt > tentative > normal.
 * Cancelled is handled separately via opacity + line-through.
 */
function statusStyle(
  c: CourseRow,
  hasHaupt: boolean,
  baseColor: string,
  t: (key: string) => string,
): SlotStyle {
  const noHaupt = !hasHaupt && c.status !== 'cancelled'
  if (noHaupt) {
    return {
      bg: 'var(--brand-red-50)',
      border: 'var(--brand-red)',
      text: 'var(--brand-red-800)',
      prefix: '⚠ ',
      tooltip: t('calendar.tooltip_no_haupt'),
      isTentative: false,
    }
  }
  if (c.status === 'tentative') {
    return {
      bg: 'var(--brand-amber-50)',
      border: 'var(--brand-amber)',
      text: 'var(--brand-amber-800)',
      prefix: '? ',
      tooltip: t('calendar.tooltip_tentative'),
      isTentative: true,
    }
  }
  return {
    bg: 'var(--bg-card)',
    border: baseColor,
    text: 'var(--text-primary)',
    prefix: '',
    tooltip: '',
    isTentative: false,
  }
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
  const { t, i18n } = useTranslation()
  const dfLocale = i18n.resolvedLanguage === 'en' ? enGB : de
  const navigate = useNavigate()
  const { user } = useOutletContext<OutletCtx>()
  const isDispatcher =
    user.role === 'dispatcher' || user.role === 'cd' || user.role === 'owner'
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
    fetchCoursesInRange(toISODate(range.start), toISODate(range.end)).then(async (cs) => {
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
    ? `KW ${format(range.start, 'w')} · ${format(range.start, 'd. MMM', { locale: dfLocale })} – ${format(range.end, 'd. MMM yyyy', { locale: dfLocale })}`
    : format(anchor, 'MMMM yyyy', { locale: dfLocale })

  return (
    <div className="atoll-screen">
      <PageHeader
        title={t('nav.calendar')}
        subtitle={title}
        actions={
          <>
            <FilterTabBar<Mode>
              tabs={[
                { id: 'week', label: t('calendar.view_week') },
                { id: 'month', label: t('calendar.view_month') },
              ]}
              active={mode}
              onChange={setMode}
              ariaLabel={t('nav.calendar')}
            />
            <button type="button" className="atoll-iconbtn" onClick={prev} aria-label={t('calendar.prev_week', 'Zurück')}>
              <Icon.ChevronLeft size={14} />
            </button>
            <button type="button" className="atoll-btn" onClick={today}>
              {t('calendar.today')}
            </button>
            <button type="button" className="atoll-iconbtn" onClick={next} aria-label={t('calendar.next_week', 'Weiter')}>
              <Icon.ChevronRight size={14} />
            </button>
            {isDispatcher && (
              <button
                type="button"
                className="atoll-btn atoll-btn--primary"
                onClick={() => setEditOpen(true)}
              >
                <Icon.Plus size={14} /> {t('courses.new_course')}
              </button>
            )}
          </>
        }
      />

      <CourseEditSheet
        open={editOpen}
        onClose={() => setEditOpen(false)}
        onSaved={() => setRefreshTick((tick) => tick + 1)}
        courseId={null}
      />

      <div className="atoll-screen__body">
        <section className="atoll-cockpit__card atoll-cal__card">
          {mode === 'week' ? (
            <WeekView
              range={range}
              courses={courses}
              hauptByCourse={hauptByCourse}
              onClickCourse={(id) => navigate(`/kurse/${id}`)}
              t={t}
              dfLocale={dfLocale}
            />
          ) : (
            <MonthView
              anchor={anchor}
              courses={courses}
              hauptByCourse={hauptByCourse}
              onClickCourse={(id) => navigate(`/kurse/${id}`)}
              t={t}
              dfLocale={dfLocale}
            />
          )}
        </section>

        <Legend t={t} />
      </div>
    </div>
  )
}

// ──────────────────────── Week view ────────────────────────

function WeekView({
  range,
  courses,
  hauptByCourse,
  onClickCourse,
  t,
  dfLocale,
}: {
  range: { start: Date; end: Date }
  courses: CourseRow[]
  hauptByCourse: Set<string>
  onClickCourse: (id: string) => void
  t: (key: string, opts?: Record<string, unknown>) => string
  dfLocale: Locale
}) {
  const days = eachDayOfInterval(range)
  return (
    <div className="atoll-cal__week">
      <div className="atoll-cal__week-head">
        {days.map((d) => (
          <div
            key={d.toISOString()}
            className={`atoll-cal__day-head${isSameDay(d, new Date()) ? ' atoll-cal__day-head--today' : ''}`}
          >
            <div className="atoll-cal__day-name">{format(d, 'EEE', { locale: dfLocale })}</div>
            <div className="atoll-cal__day-date">{format(d, 'd. MMM', { locale: dfLocale })}</div>
          </div>
        ))}
      </div>

      <div className="atoll-cal__week-grid">
        {days.map((d) => {
          const dayCourses = coursesOnDay(courses, d)
          return (
            <div key={d.toISOString()} className="atoll-cal__week-cell">
              {dayCourses.map((c) => {
                const allDates = courseDates(c)
                const isMultiDay = allDates.length > 1
                const dayIndex = allDates.findIndex((dt) => dt && isSameDay(new Date(dt), d))
                const hasHaupt = hauptByCourse.has(c.id)
                const baseColor = courseTypeColor(asCourseType(c.course_type?.code))
                const s = statusStyle(c, hasHaupt, baseColor, t)
                return (
                  <button
                    type="button"
                    key={c.id}
                    onClick={() => onClickCourse(c.id)}
                    className={`atoll-cal__slot${c.status === 'cancelled' ? ' atoll-cal__slot--cancelled' : ''}`}
                    style={{
                      background: s.prefix ? s.bg : 'var(--bg-card)',
                      borderLeft: `3px ${s.isTentative ? 'dashed' : 'solid'} ${s.border}`,
                      color: s.prefix ? s.text : 'var(--text-primary)',
                    }}
                    title={s.tooltip || c.title}
                  >
                    <div className="atoll-cal__slot-title">
                      {s.prefix}{c.title}
                    </div>
                    <div className="atoll-cal__slot-meta">
                      <span
                        className="atoll-cal__slot-pill"
                        style={{ background: `${baseColor}1f`, color: baseColor }}
                      >
                        {c.course_type?.code ?? '—'}
                      </span>
                      {isMultiDay && (
                        <span className="atoll-cal__slot-multiday">
                          {t('calendar.day_of', { current: dayIndex + 1, total: allDates.length })}
                        </span>
                      )}
                    </div>
                  </button>
                )
              })}
            </div>
          )
        })}
      </div>
    </div>
  )
}

// ──────────────────────── Month view ────────────────────────

function MonthView({
  anchor,
  courses,
  hauptByCourse,
  onClickCourse,
  t,
  dfLocale,
}: {
  anchor: Date
  courses: CourseRow[]
  hauptByCourse: Set<string>
  onClickCourse: (id: string) => void
  t: (key: string, opts?: Record<string, unknown>) => string
  dfLocale: Locale
}) {
  const start = startOfWeek(startOfMonth(anchor), { weekStartsOn: 1 })
  const end = endOfWeek(endOfMonth(anchor), { weekStartsOn: 1 })
  const days = eachDayOfInterval({ start, end })
  const monday = startOfWeek(new Date(2024, 0, 1), { weekStartsOn: 1 })
  const weekdays = Array.from({ length: 7 }, (_, i) =>
    format(addDays(monday, i), 'EEEEEE', { locale: dfLocale }),
  )

  return (
    <div className="atoll-cal__month">
      <div className="atoll-cal__month-head">
        {weekdays.map((d) => (
          <div key={d} className="atoll-cal__weekday">{d}</div>
        ))}
      </div>
      <div className="atoll-cal__month-grid">
        {days.map((d) => {
          const dayCourses = coursesOnDay(courses, d)
          const inMonth = isSameMonth(d, anchor)
          const isToday = isSameDay(d, new Date())
          return (
            <div
              key={d.toISOString()}
              className={`atoll-cal__month-cell${inMonth ? '' : ' atoll-cal__month-cell--out'}${isToday ? ' atoll-cal__month-cell--today' : ''}`}
            >
              <div className="atoll-cal__month-day">{format(d, 'd', { locale: dfLocale })}</div>
              <div className="atoll-cal__month-slots">
                {dayCourses.slice(0, 4).map((c) => {
                  const isMultiDay = (c.additional_dates?.length ?? 0) > 0
                  const hasHaupt = hauptByCourse.has(c.id)
                  const baseColor = courseTypeColor(asCourseType(c.course_type?.code))
                  const s = statusStyle(c, hasHaupt, baseColor, t)
                  const showBorder = !!s.prefix || isMultiDay
                  return (
                    <button
                      type="button"
                      key={c.id}
                      onClick={() => onClickCourse(c.id)}
                      title={s.tooltip ? `${c.title} — ${s.tooltip}` : c.title}
                      className={`atoll-cal__month-slot${c.status === 'cancelled' ? ' atoll-cal__slot--cancelled' : ''}`}
                      style={{
                        background: s.prefix ? s.bg : `${baseColor}1f`,
                        color: s.prefix ? s.text : baseColor,
                        borderLeft: showBorder
                          ? `2px ${s.isTentative ? 'dashed' : 'solid'} ${s.border}`
                          : undefined,
                      }}
                    >
                      {s.prefix}{c.title}
                    </button>
                  )
                })}
                {dayCourses.length > 4 && (
                  <div className="atoll-cal__more">
                    {t('calendar.more_count', { count: dayCourses.length - 4 })}
                  </div>
                )}
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}

// ──────────────────────── Legend ────────────────────────

function Legend({ t }: { t: (key: string) => string }) {
  return (
    <div className="atoll-cal__legend">
      <span className="atoll-cal__legend-item">
        <span className="atoll-cal__legend-chip atoll-cal__legend-chip--no-haupt" />
        {t('calendar.legend_no_haupt')}
      </span>
      <span className="atoll-cal__legend-item">
        <span className="atoll-cal__legend-chip atoll-cal__legend-chip--tentative" />
        {t('calendar.legend_tentative')}
      </span>
      <span className="atoll-cal__legend-item atoll-cal__legend-item--cancelled">
        <span className="atoll-cal__legend-chip atoll-cal__legend-chip--cancelled" />
        {t('calendar.legend_cancelled')}
      </span>
      <span className="atoll-cal__legend-item">
        <span className="atoll-cal__legend-chip atoll-cal__legend-chip--today" />
        {t('calendar.legend_today')}
      </span>
    </div>
  )
}
