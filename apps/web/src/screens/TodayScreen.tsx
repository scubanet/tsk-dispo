/**
 * TodayScreen — Foundation-based rewrite (Tag 4 cutover).
 *
 * Layout:
 *   PageHeader (title + subtitle + actions)
 *   ┌─ KpiGrid ──────────────────────────────────────────────┐
 *   │  Hero: today's date + count                            │
 *   │  Stat: confirmed / total                               │
 *   │  Stat: active instructors                              │
 *   │  Stat: assignments this week                           │
 *   └────────────────────────────────────────────────────────┘
 *   ┌─ Today's courses ────────┐  ┌─ Next 7 days ────────────┐
 *   │  CourseRow × N           │  │  CourseRow × 8 (compact) │
 *   └──────────────────────────┘  └──────────────────────────┘
 *
 * Dispatcher/CD see the full dashboard. Instructors see their personal view.
 */

import { useEffect, useMemo, useState } from 'react'
import { addDays, isSameDay, isWithinInterval, startOfDay } from 'date-fns'
import { useTranslation } from 'react-i18next'
import { useNavigate, useOutletContext } from 'react-router-dom'
import {
  PageHeader,
  KpiGrid,
  KpiCard,
  CourseRow,
  EmptyState,
  Pill,
  Icon,
  dateLong,
  dateShort,
  toISODate,
} from '@/foundation'
import { WhatsAppButton } from '@/components/WhatsAppButton'
import { tplDailyDigest, waGroupShareUrl } from '@/lib/whatsapp'
import {
  fetchCoursesInRange,
  fetchAssignmentsForCourses,
  fetchKpis,
  fetchMyAssignments,
  type CourseRow as CourseRowData,
  type AssignmentRow,
  type Kpis,
  type MyAssignment,
} from '@/lib/queries'
import type { OutletCtx } from '@/layout/AppShell'
import type { CourseType } from '@/types/foundation'

export function TodayScreen() {
  const { user } = useOutletContext<OutletCtx>()
  if (user.role === 'dispatcher' || user.role === 'cd' || user.role === 'owner') {
    return <DispatcherToday />
  }
  return <InstructorToday />
}

// ──────────────────────── Helpers ────────────────────────

/**
 * Map the legacy `course_type.code` string to the foundation `CourseType` union.
 * Falls through gracefully — unknown codes render as a generic course.
 */
function asCourseType(code: string | undefined | null): CourseType {
  if (!code) return 'OWD'
  if (code.startsWith('SPEI_')) {
    return { type: 'SPEI', specialty: code.slice(5) as never }
  }
  if (code.startsWith('SP_')) {
    return { type: 'SPECIALTY', specialty: code.slice(3) as never }
  }
  // Direct codes
  return code as CourseType
}

function courseDates(c: CourseRowData): Date[] {
  return [c.start_date, ...(c.additional_dates ?? [])]
    .filter(Boolean)
    .map((d) => new Date(d))
}

// ──────────────────────── Dispatcher view ────────────────────────

function DispatcherToday() {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const [kpis, setKpis] = useState<Kpis | null>(null)
  const [candidates, setCandidates] = useState<CourseRowData[]>([])
  const [assignments, setAssignments] = useState<AssignmentRow[]>([])

  useEffect(() => {
    const startStr = toISODate(startOfDay(new Date()))
    const weekEnd = toISODate(addDays(new Date(), 7))
    Promise.all([fetchKpis(), fetchCoursesInRange(startStr, weekEnd)]).then(
      async ([k, all]) => {
        setKpis(k)
        setCandidates(all)
        const ids = all.map((c) => c.id)
        const a = await fetchAssignmentsForCourses(ids)
        setAssignments(a)
      },
    )
  }, [])

  const todayDate = startOfDay(new Date())
  const weekEndDate = addDays(todayDate, 7)

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

  const todayLabel = dateLong(new Date())
  const todayParticipants = today.reduce((sum, c) => sum + (c.num_participants || 0), 0)

  // WhatsApp daily digest
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
    <div className="atoll-screen">
      <PageHeader
        title={t('nav.today')}
        subtitle={t('today.topbar_subtitle', {
          date: todayLabel,
          count: thisWeek.length,
        })}
        actions={
          <>
            <WhatsAppButton url={digestUrl} label={t('today.daily_digest')} />
            <button
              type="button"
              className="atoll-iconbtn"
              title={t('today.notifications')}
            >
              <Icon.Info size={16} />
            </button>
          </>
        }
      />

      <div className="atoll-screen__body" data-scroll>
        <KpiGrid columns={4} gap="md">
          <KpiCard
            variant="hero"
            label={todayLabel}
            value={
              today.length === 0
                ? t('today.no_courses_today')
                : t('today.subtitle', { count: today.length })
            }
            sub={t('today.participants_total', { count: todayParticipants })}
          />
          {kpis && (
            <>
              <KpiCard
                variant="stat"
                label={t('today.kpi_confirmed')}
                value={
                  <>
                    {kpis.confirmedCourses}
                    <span className="atoll-kpi__total"> / {kpis.totalCourses}</span>
                  </>
                }
              />
              <KpiCard
                variant="stat"
                label={t('today.kpi_active_instructors')}
                value={kpis.instructorCount}
              />
              <KpiCard
                variant="stat"
                label={t('today.kpi_assignments_from_today')}
                value={kpis.assignmentsThisWeek}
              />
            </>
          )}
        </KpiGrid>

        <div className="atoll-today__columns">
          <section className="atoll-today__col atoll-today__col--main">
            <h2 className="atoll-today__col-title">{t('today.todays_courses')}</h2>
            {today.length === 0 ? (
              <EmptyState
                icon={<Icon.Calendar size={20} />}
                title={t('today.empty_day')}
              />
            ) : (
              <div className="atoll-today__list">
                {today.map((c) => {
                  const a = assignments.filter((x) => x.course_id === c.id)
                  const haupt = a.find((x) => x.role === 'haupt')?.instructor?.name
                  return (
                    <CourseRow
                      key={c.id}
                      courseType={asCourseType(c.course_type?.code)}
                      title={c.title}
                      sub={
                        <>
                          {haupt ? `${haupt} · ` : ''}
                          {c.num_participants > 0
                            ? t('today.participants_short', { count: c.num_participants })
                            : ''}
                        </>
                      }
                      meta={statusLabel(c.status, t)}
                      trailing={statusPill(c.status)}
                      onClick={() => navigate(`/kurse/${c.id}`)}
                    />
                  )
                })}
              </div>
            )}
          </section>

          <section className="atoll-today__col">
            <h2 className="atoll-today__col-title">{t('today.next_week')}</h2>
            {thisWeek.length === 0 ? (
              <EmptyState
                icon={<Icon.Calendar size={20} />}
                title={t('today.no_next_week')}
              />
            ) : (
              <div className="atoll-today__list">
                {thisWeek.slice(0, 8).map((c) => {
                  const relevantDate = courseDates(c).find((d) =>
                    isWithinInterval(d, { start: todayDate, end: weekEndDate }),
                  )
                  return (
                    <CourseRow
                      key={c.id}
                      courseType={asCourseType(c.course_type?.code)}
                      title={c.title}
                      meta={relevantDate ? dateShort(relevantDate) : '—'}
                      onClick={() => navigate(`/kurse/${c.id}`)}
                    />
                  )
                })}
              </div>
            )}
          </section>
        </div>
      </div>
    </div>
  )
}

// ──────────────────────── Instructor view ────────────────────────

function InstructorToday() {
  const { t } = useTranslation()
  const { user } = useOutletContext<OutletCtx>()
  const navigate = useNavigate()
  const [mine, setMine] = useState<MyAssignment[]>([])

  useEffect(() => {
    if (!user.instructorId) return
    fetchMyAssignments(user.instructorId).then(setMine)
  }, [user.instructorId])

  const todayDate = startOfDay(new Date())
  const todays = mine.filter(
    (m) => m.course && isSameDay(new Date(m.course.start_date), todayDate),
  )
  const upcoming = mine
    .filter((m) => m.course && new Date(m.course.start_date) > todayDate)
    .slice(0, 8)
  const todayLabel = dateLong(todayDate)

  return (
    <div className="atoll-screen">
      <PageHeader
        title={t('today.greeting', { name: user.name.split(' ')[0] })}
        subtitle={t('today.instructor_topbar_subtitle', {
          date: todayLabel,
          count: mine.length,
          year: new Date().getFullYear(),
        })}
      />

      <div className="atoll-screen__body" data-scroll>
        <KpiGrid columns={2} gap="md">
          <KpiCard
            variant="hero"
            label={todayLabel}
            value={
              todays.length === 0
                ? t('today.no_assignments_today')
                : t('today.assignments_today', { count: todays.length })
            }
          />
          <KpiCard
            variant="stat"
            label={t('today.upcoming_assignments')}
            value={upcoming.length}
          />
        </KpiGrid>

        {todays.length > 0 && (
          <section className="atoll-today__col">
            <h2 className="atoll-today__col-title">{t('today.header_today')}</h2>
            <div className="atoll-today__list">
              {todays.map((a) =>
                a.course ? (
                  <CourseRow
                    key={a.id}
                    courseType={asCourseType(a.course.course_type?.code)}
                    title={a.course.title}
                    sub={a.course.info ?? undefined}
                    trailing={
                      <Pill tone={a.role === 'haupt' ? 'brand' : 'neutral'} size="sm">
                        {a.role}
                      </Pill>
                    }
                    onClick={() => navigate(`/kurse/${a.course?.id}`)}
                  />
                ) : null,
              )}
            </div>
          </section>
        )}

        <section className="atoll-today__col">
          <div className="atoll-today__col-head">
            <h2 className="atoll-today__col-title">{t('today.upcoming_assignments')}</h2>
            <button
              type="button"
              className="atoll-linkbtn"
              onClick={() => navigate('/einsaetze')}
            >
              {t('today.see_all')} <Icon.ChevronRight size={12} />
            </button>
          </div>
          {upcoming.length === 0 ? (
            <EmptyState title={t('today.no_upcoming')} />
          ) : (
            <div className="atoll-today__list">
              {upcoming.map((a) =>
                a.course ? (
                  <CourseRow
                    key={a.id}
                    courseType={asCourseType(a.course.course_type?.code)}
                    title={a.course.title}
                    meta={dateShort(a.course.start_date)}
                    sub={`${a.course.course_type?.code ?? '—'} · ${a.role}`}
                    trailing={
                      a.confirmed ? (
                        <Pill tone="success" size="sm">
                          ✓
                        </Pill>
                      ) : (
                        <Pill tone="warning" size="sm">
                          {t('my_assignments.open')}
                        </Pill>
                      )
                    }
                    onClick={() => navigate(`/kurse/${a.course?.id}`)}
                  />
                ) : null,
              )}
            </div>
          )}
        </section>
      </div>
    </div>
  )
}

// ──────────────────────── Status mappers ────────────────────────

function statusLabel(status: CourseRowData['status'], t: ReturnType<typeof useTranslation>['t']): string {
  switch (status) {
    case 'confirmed': return t('common.confirmed', 'bestätigt')
    case 'tentative': return t('common.tentative', 'tentativ')
    case 'completed': return t('common.completed', 'abgeschlossen')
    case 'cancelled': return t('common.cancelled', 'abgesagt')
  }
}

function statusPill(status: CourseRowData['status']) {
  const tone =
    status === 'cancelled' ? 'danger' :
    status === 'tentative' ? 'warning' :
    status === 'completed' ? 'pro' : 'success'
  return <Pill tone={tone} size="sm">{status}</Pill>
}
