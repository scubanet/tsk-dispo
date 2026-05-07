import { useEffect, useMemo, useState } from 'react'
import { format, addDays, isSameDay, isWithinInterval, startOfDay } from 'date-fns'
import { de, enGB } from 'date-fns/locale'
import { useTranslation } from 'react-i18next'
import { useNavigate, useOutletContext } from 'react-router-dom'
import { Topbar } from '@/components/Topbar'
import { Icon } from '@/components/Icon'
import { Avatar } from '@/components/Avatar'
import { Chip } from '@/components/Chip'
import { WhatsAppButton } from '@/components/WhatsAppButton'
import { tplDailyDigest, waGroupShareUrl } from '@/lib/whatsapp'
import {
  fetchCoursesInRange,
  fetchAssignmentsForCourses,
  fetchKpis,
  fetchMyAssignments,
  type CourseRow,
  type AssignmentRow,
  type Kpis,
  type MyAssignment,
} from '@/lib/queries'
import type { OutletCtx } from '@/layout/AppShell'

export function TodayScreen() {
  const { user } = useOutletContext<OutletCtx>()
  if ((user.role === 'dispatcher' || user.role === 'cd')) return <DispatcherToday />
  return <InstructorToday />
}

function DispatcherToday() {
  const { t, i18n } = useTranslation()
  const dfLocale = i18n.resolvedLanguage === 'en' ? enGB : de
  const { user } = useOutletContext<OutletCtx>()
  const navigate = useNavigate()
  const [kpis, setKpis] = useState<Kpis | null>(null)
  /** All candidate courses (start_date in [today-60d .. today+7d]) — filtered client-side. */
  const [candidates, setCandidates] = useState<CourseRow[]>([])
  const [assignments, setAssignments] = useState<AssignmentRow[]>([])

  useEffect(() => {
    const startStr = format(startOfDay(new Date()), 'yyyy-MM-dd')
    const weekEnd = format(addDays(new Date(), 7), 'yyyy-MM-dd')
    Promise.all([
      fetchKpis(),
      // Lower bound is widened by 60d inside fetchCoursesInRange, so courses
      // that started weeks ago but have an additional_date today are included.
      fetchCoursesInRange(startStr, weekEnd),
    ]).then(async ([k, all]) => {
      setKpis(k)
      setCandidates(all)
      const ids = all.map((c) => c.id)
      const a = await fetchAssignmentsForCourses(ids)
      setAssignments(a)
    })
  }, [])

  const todayDate = startOfDay(new Date())
  const weekEndDate = addDays(todayDate, 7)

  /** Returns the union of start_date and additional_dates for a course. */
  function courseDates(c: CourseRow): Date[] {
    return [c.start_date, ...(c.additional_dates ?? [])]
      .filter(Boolean)
      .map((d) => new Date(d))
  }

  const today = useMemo(
    () =>
      candidates
        .filter((c) => c.status !== 'completed' && c.status !== 'cancelled')
        .filter((c) => courseDates(c).some((d) => isSameDay(d, todayDate))),
    [candidates],
  )

  const thisWeek = useMemo(
    () =>
      candidates
        .filter((c) => c.status !== 'completed' && c.status !== 'cancelled')
        .filter((c) =>
          courseDates(c).some((d) =>
            isWithinInterval(d, { start: todayDate, end: weekEndDate }),
          ),
        )
        // Sort by earliest matching date inside the interval
        .sort((a, b) => {
          const aDate = courseDates(a).find((d) =>
            isWithinInterval(d, { start: todayDate, end: weekEndDate }),
          )
          const bDate = courseDates(b).find((d) =>
            isWithinInterval(d, { start: todayDate, end: weekEndDate }),
          )
          return (aDate?.getTime() ?? 0) - (bDate?.getTime() ?? 0)
        }),
    [candidates],
  )

  const todayLabel = format(new Date(), 'EEEE, d. MMMM', { locale: dfLocale })
  const weekCount = thisWeek.length

  // WhatsApp daily digest — uses today's courses + their haupt-instructor
  const digestEntries = today.map((c) => {
    const a = assignments.filter((x) => x.course_id === c.id)
    return {
      type_code: c.course_type?.code ?? '—',
      haupt_name: a.find((x) => x.role === 'haupt')?.instructor?.name,
      location: null,
    }
  })
  const digestUrl = waGroupShareUrl(tplDailyDigest(new Date(), digestEntries))

  return (
    <>
      <Topbar
        title={(user.role === 'dispatcher' || user.role === 'cd') ? t('nav.today') : t('today.greeting', { name: user.name.split(' ')[0] })}
        subtitle={t('today.topbar_subtitle', { date: todayLabel, count: weekCount })}
      >
        <WhatsAppButton url={digestUrl} label={t('today.daily_digest')} />
        <button className="btn-icon" title={t('today.notifications')}><Icon name="bell" size={16} /></button>
        {(user.role === 'dispatcher' || user.role === 'cd') && (
          <button className="btn"><Icon name="plus" size={14} /> {t('courses.new_course')}</button>
        )}
      </Topbar>

      <div className="screen-fade scroll" style={{ flex: 1, padding: '20px 24px 28px' }}>
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: '1.4fr 1fr 1fr 1fr',
            gap: 14,
            marginBottom: 16,
          }}
        >
          <div className="tile-now">
            <div
              style={{
                fontSize: 12,
                opacity: 0.85,
                letterSpacing: '.02em',
                textTransform: 'uppercase',
                fontWeight: 600,
              }}
            >
              {todayLabel}
            </div>
            <div
              style={{
                fontSize: 26,
                fontWeight: 700,
                marginTop: 8,
                letterSpacing: '-.02em',
                position: 'relative',
                zIndex: 1,
              }}
            >
              {today.length === 0
                ? t('today.no_courses_today')
                : t('today.subtitle', { count: today.length })}
            </div>
            <div style={{ fontSize: 13, opacity: 0.9, marginTop: 4, position: 'relative', zIndex: 1 }}>
              {t('today.participants_total', { count: today.reduce((sum, c) => sum + (c.num_participants || 0), 0) })}
            </div>
          </div>

          {kpis && (
            <>
              <StatCard num={kpis.confirmedCourses} total={kpis.totalCourses} label={t('today.kpi_confirmed')} />
              <StatCard num={kpis.instructorCount} label={t('today.kpi_active_instructors')} />
              <StatCard num={kpis.assignmentsThisWeek} label={t('today.kpi_assignments_from_today')} />
            </>
          )}
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: 14 }}>
          <div className="glass card">
            <div className="title-3" style={{ marginBottom: 10 }}>{t('today.todays_courses')}</div>
            {today.length === 0 ? (
              <div className="caption">{t('today.empty_day')}</div>
            ) : (
              <div className="timeline">
                {today.map((c) => {
                  const a = assignments.filter((x) => x.course_id === c.id)
                  return (
                    <Session
                      key={c.id}
                      course={c}
                      assignments={a}
                      onClick={() => navigate(`/kurse/${c.id}`)}
                    />
                  )
                })}
              </div>
            )}
          </div>

          <div className="glass card">
            <div className="title-3" style={{ marginBottom: 10 }}>{t('today.next_week')}</div>
            {thisWeek.length === 0 ? (
              <div className="caption">{t('today.no_next_week')}</div>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                {thisWeek.slice(0, 8).map((c) => {
                  // Find the earliest date of this course that falls inside the week interval
                  const relevantDate = courseDates(c).find((d) =>
                    isWithinInterval(d, { start: todayDate, end: weekEndDate }),
                  )
                  return (
                  <div
                    key={c.id}
                    onClick={() => navigate(`/kurse/${c.id}`)}
                    style={{
                      display: 'flex',
                      gap: 10,
                      padding: '6px 4px',
                      borderBottom: '0.5px solid var(--separator)',
                      cursor: 'pointer',
                      borderRadius: 6,
                      transition: 'background .12s',
                    }}
                    onMouseEnter={(e) => (e.currentTarget.style.background = 'rgba(0,0,0,.04)')}
                    onMouseLeave={(e) => (e.currentTarget.style.background = 'transparent')}
                  >
                    <div className="mono caption" style={{ width: 50, flexShrink: 0 }}>
                      {relevantDate ? format(relevantDate, 'd. MMM', { locale: dfLocale }) : '—'}
                    </div>
                    <div style={{ flex: 1, fontSize: 13 }}>
                      <div style={{ fontWeight: 500 }}>{c.title}</div>
                    </div>
                  </div>
                  )
                })}
              </div>
            )}
          </div>
        </div>
      </div>
    </>
  )
}

function StatCard({
  num,
  total,
  label,
}: {
  num: number
  total?: number
  label: string
}) {
  return (
    <div className="glass card stat-card">
      <div className="stat-num">
        {num}
        {total != null && <span className="caption" style={{ marginLeft: 4 }}> / {total}</span>}
      </div>
      <div className="stat-label">{label}</div>
    </div>
  )
}

function InstructorToday() {
  const { t, i18n } = useTranslation()
  const dfLocale = i18n.resolvedLanguage === 'en' ? enGB : de
  const { user } = useOutletContext<OutletCtx>()
  const navigate = useNavigate()
  const [mine, setMine] = useState<MyAssignment[]>([])

  useEffect(() => {
    if (!user.instructorId) return
    fetchMyAssignments(user.instructorId).then(setMine)
  }, [user.instructorId])

  const today = startOfDay(new Date())
  const todays = mine.filter(
    (m) => m.course && isSameDay(new Date(m.course.start_date), today),
  )
  const upcoming = mine
    .filter((m) => m.course && new Date(m.course.start_date) > today)
    .slice(0, 8)
  const todayLabel = format(today, 'EEEE, d. MMMM', { locale: dfLocale })

  return (
    <>
      <Topbar
        title={t('today.greeting', { name: user.name.split(' ')[0] })}
        subtitle={t('today.instructor_topbar_subtitle', { date: todayLabel, count: mine.length, year: 2026 })}
      />

      <div className="screen-fade scroll" style={{ flex: 1, padding: '20px 24px 28px' }}>
        <div className="tile-now" style={{ marginBottom: 16 }}>
          <div
            style={{
              fontSize: 12, opacity: 0.85,
              letterSpacing: '.02em', textTransform: 'uppercase',
              fontWeight: 600,
            }}
          >
            {todayLabel}
          </div>
          <div
            style={{
              fontSize: 26, fontWeight: 700, marginTop: 8,
              letterSpacing: '-.02em', position: 'relative', zIndex: 1,
            }}
          >
            {todays.length === 0
              ? t('today.no_assignments_today')
              : t('today.assignments_today', { count: todays.length })}
          </div>
        </div>

        {todays.length > 0 && (
          <div className="glass card" style={{ marginBottom: 16 }}>
            <div className="title-3" style={{ marginBottom: 10 }}>{t('today.header_today')}</div>
            <div style={{ display: 'grid', gap: 8 }}>
              {todays.map((a) =>
                a.course ? (
                  <div
                    key={a.id}
                    className="glass-thin"
                    style={{
                      padding: 12,
                      borderRadius: 12,
                      cursor: 'pointer',
                      borderLeft: `3px solid var(--accent)`,
                    }}
                    onClick={() => navigate(`/kurse/${a.course?.id}`)}
                  >
                    <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                      <div style={{ fontWeight: 600 }}>{a.course.title}</div>
                      <Chip tone={a.role === 'haupt' ? 'accent' : 'neutral'}>{a.role}</Chip>
                    </div>
                    {a.course.info && (
                      <div className="caption" style={{ marginTop: 4 }}>{a.course.info}</div>
                    )}
                  </div>
                ) : null
              )}
            </div>
          </div>
        )}

        <div className="glass card">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10 }}>
            <div className="title-3">{t('today.upcoming_assignments')}</div>
            <button className="btn-ghost btn" onClick={() => navigate('/einsaetze')}>
              {t('today.see_all')} <Icon name="chevron-right" size={12} />
            </button>
          </div>
          {upcoming.length === 0 ? (
            <div className="caption">{t('today.no_upcoming')}</div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
              {upcoming.map((a) =>
                a.course ? (
                  <div
                    key={a.id}
                    onClick={() => navigate(`/kurse/${a.course?.id}`)}
                    style={{
                      display: 'flex',
                      gap: 10,
                      padding: '8px 0',
                      borderBottom: '0.5px solid var(--separator)',
                      cursor: 'pointer',
                    }}
                  >
                    <div className="mono caption" style={{ width: 60, flexShrink: 0 }}>
                      {format(new Date(a.course.start_date), 'd. MMM', { locale: dfLocale })}
                    </div>
                    <div style={{ flex: 1, fontSize: 13 }}>
                      <div style={{ fontWeight: 500 }}>{a.course.title}</div>
                      <div className="caption">
                        {a.course.course_type?.code} · {a.role}
                      </div>
                    </div>
                    {a.confirmed ? (
                      <Chip tone="green">✓</Chip>
                    ) : (
                      <Chip tone="orange">{t('my_assignments.open')}</Chip>
                    )}
                  </div>
                ) : null
              )}
            </div>
          )}
        </div>
      </div>
    </>
  )
}

function Session({
  course,
  assignments,
  onClick,
}: {
  course: CourseRow
  assignments: AssignmentRow[]
  onClick?: () => void
}) {
  const { t } = useTranslation()
  const tone =
    course.status === 'cancelled' ? 'red' :
    course.status === 'tentative' ? 'orange' :
    course.status === 'completed' ? 'purple' : 'accent'
  return (
    <>
      <div className="tl-time">{course.course_type?.code ?? '—'}</div>
      <div
        className="tl-event"
        onClick={onClick}
        style={onClick ? { cursor: 'pointer' } : undefined}
      >
        <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12 }}>
          <div style={{ minWidth: 0 }}>
            <div style={{ fontWeight: 600, fontSize: 14 }}>{course.title}</div>
            <div className="caption" style={{ marginTop: 3 }}>
              {course.num_participants > 0 && t('today.participants_short', { count: course.num_participants })}
            </div>
          </div>
          <Chip tone={tone}>{course.status}</Chip>
        </div>
        <div style={{ display: 'flex', gap: 6, marginTop: 10, alignItems: 'center' }}>
          {assignments.map((a) =>
            a.instructor ? (
              <div key={a.id} title={`${a.instructor.name} (${a.role})`}>
                <Avatar
                  initials={a.instructor.initials}
                  color={a.instructor.color}
                  size="sm"
                />
              </div>
            ) : null,
          )}
          <span className="caption" style={{ marginLeft: 4 }}>
            {t('today.instructor_count', { count: assignments.length })}
          </span>
        </div>
      </div>
    </>
  )
}
