import { useEffect, useState } from 'react'
import { format, addDays, startOfDay } from 'date-fns'
import { de } from 'date-fns/locale'
import { useOutletContext } from 'react-router-dom'
import { Topbar } from '@/components/Topbar'
import { Icon } from '@/components/Icon'
import { Avatar } from '@/components/Avatar'
import { Chip } from '@/components/Chip'
import {
  fetchCoursesInRange,
  fetchAssignmentsForCourses,
  fetchKpis,
  type CourseRow,
  type AssignmentRow,
  type Kpis,
} from '@/lib/queries'
import type { OutletCtx } from '@/layout/AppShell'

export function TodayScreen() {
  const { user } = useOutletContext<OutletCtx>()
  const [kpis, setKpis] = useState<Kpis | null>(null)
  const [today, setToday] = useState<CourseRow[]>([])
  const [thisWeek, setThisWeek] = useState<CourseRow[]>([])
  const [assignments, setAssignments] = useState<AssignmentRow[]>([])

  useEffect(() => {
    const todayStr = format(startOfDay(new Date()), 'yyyy-MM-dd')
    const weekEnd = format(addDays(new Date(), 7), 'yyyy-MM-dd')
    Promise.all([
      fetchKpis(),
      fetchCoursesInRange(todayStr, todayStr),
      fetchCoursesInRange(todayStr, weekEnd),
    ]).then(async ([k, t, w]) => {
      setKpis(k)
      setToday(t)
      setThisWeek(w)
      const ids = [...t, ...w].map((c) => c.id)
      const a = await fetchAssignmentsForCourses(ids)
      setAssignments(a)
    })
  }, [])

  const todayLabel = format(new Date(), 'EEEE, d. MMMM', { locale: de })
  const weekCount = thisWeek.length

  return (
    <>
      <Topbar
        title={user.role === 'dispatcher' ? 'Heute' : `Hi, ${user.name.split(' ')[0]}`}
        subtitle={`${todayLabel} · ${weekCount} Kurse diese Woche`}
      >
        <button className="btn-icon" title="Benachrichtigungen"><Icon name="bell" size={16} /></button>
        {user.role === 'dispatcher' && (
          <button className="btn"><Icon name="plus" size={14} /> Neuer Kurs</button>
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
              {today.length === 0 ? 'Heute keine Kurse' : `${today.length} ${today.length === 1 ? 'Kurs' : 'Kurse'} heute`}
            </div>
            <div style={{ fontSize: 13, opacity: 0.9, marginTop: 4, position: 'relative', zIndex: 1 }}>
              {today.reduce((sum, c) => sum + (c.num_participants || 0), 0)} Teilnehmer insgesamt
            </div>
          </div>

          {kpis && (
            <>
              <StatCard num={kpis.confirmedCourses} total={kpis.totalCourses} label="Bestätigte Kurse" />
              <StatCard num={kpis.instructorCount} label="Aktive Instructors" />
              <StatCard num={kpis.assignmentsThisWeek} label="Einsätze ab heute" />
            </>
          )}
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: 14 }}>
          <div className="glass card">
            <div className="title-3" style={{ marginBottom: 10 }}>Heutige Kurse</div>
            {today.length === 0 ? (
              <div className="caption">Heute frei. ☀️ Genieß den Tag.</div>
            ) : (
              <div className="timeline">
                {today.map((c) => {
                  const a = assignments.filter((x) => x.course_id === c.id)
                  return <Session key={c.id} course={c} assignments={a} />
                })}
              </div>
            )}
          </div>

          <div className="glass card">
            <div className="title-3" style={{ marginBottom: 10 }}>Nächste Woche</div>
            {thisWeek.length === 0 ? (
              <div className="caption">Keine Kurse die nächsten 7 Tage.</div>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                {thisWeek.slice(0, 8).map((c) => (
                  <div
                    key={c.id}
                    style={{
                      display: 'flex',
                      gap: 10,
                      padding: '6px 0',
                      borderBottom: '0.5px solid var(--separator)',
                    }}
                  >
                    <div className="mono caption" style={{ width: 50, flexShrink: 0 }}>
                      {format(new Date(c.start_date), 'd. MMM', { locale: de })}
                    </div>
                    <div style={{ flex: 1, fontSize: 13 }}>
                      <div style={{ fontWeight: 500 }}>{c.title}</div>
                    </div>
                  </div>
                ))}
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

function Session({ course, assignments }: { course: CourseRow; assignments: AssignmentRow[] }) {
  const tone =
    course.status === 'cancelled' ? 'red' :
    course.status === 'tentative' ? 'orange' : 'accent'
  return (
    <>
      <div className="tl-time">{course.course_type?.code ?? '—'}</div>
      <div className="tl-event">
        <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12 }}>
          <div style={{ minWidth: 0 }}>
            <div style={{ fontWeight: 600, fontSize: 14 }}>{course.title}</div>
            <div className="caption" style={{ marginTop: 3 }}>
              {course.num_participants > 0 && `${course.num_participants} TN`}
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
            {assignments.length} Instructor{assignments.length === 1 ? '' : 's'}
          </span>
        </div>
      </div>
    </>
  )
}
