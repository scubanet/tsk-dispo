import { useEffect, useState } from 'react'
import { format } from 'date-fns'
import { de } from 'date-fns/locale'
import clsx from 'clsx'
import { Avatar } from '@/components/Avatar'
import { Chip } from '@/components/Chip'
import { fetchAllCourses, fetchCourseAssignments, type CourseDetail, type AssignmentRow } from '@/lib/queries'

type Tab = 'overview' | 'assignments' | 'notes'

const TABS: { value: Tab; label: string }[] = [
  { value: 'overview',     label: 'Übersicht' },
  { value: 'assignments',  label: 'Zuweisungen' },
  { value: 'notes',        label: 'Notizen' },
]

export function CourseDetailPanel({ courseId }: { courseId: string }) {
  const [course, setCourse] = useState<CourseDetail | null>(null)
  const [assignments, setAssignments] = useState<AssignmentRow[]>([])
  const [tab, setTab] = useState<Tab>('overview')

  useEffect(() => {
    fetchAllCourses().then((all) => setCourse(all.find((c) => c.id === courseId) ?? null))
    fetchCourseAssignments(courseId).then(setAssignments)
  }, [courseId])

  if (!course) return <div style={{ padding: 40 }} className="caption">Lade…</div>

  const tone =
    course.status === 'cancelled' ? 'red' :
    course.status === 'tentative' ? 'orange' : 'green'

  return (
    <div className="screen-fade" style={{ padding: '20px 24px 40px' }}>
      <div style={{ display: 'flex', gap: 12, alignItems: 'baseline', marginBottom: 4 }}>
        <div className="title-1" style={{ flex: 1 }}>{course.title}</div>
        <Chip tone={tone}>{course.status}</Chip>
      </div>
      <div className="caption" style={{ marginBottom: 20 }}>
        {course.course_type?.label ?? '—'} ·{' '}
        {format(new Date(course.start_date), 'EEEE, d. MMMM yyyy', { locale: de })}
      </div>

      <div className="seg" style={{ marginBottom: 20 }}>
        {TABS.map((t) => (
          <button
            key={t.value}
            className={clsx(tab === t.value && 'active')}
            onClick={() => setTab(t.value)}
          >
            {t.label}
          </button>
        ))}
      </div>

      {tab === 'overview' && (
        <div style={{ display: 'grid', gap: 14 }}>
          <Field label="Kurstyp" value={`${course.course_type?.code ?? '—'} · ${course.course_type?.label ?? '—'}`} />
          <Field label="Startdatum" value={format(new Date(course.start_date), 'd. MMMM yyyy', { locale: de })} />
          {course.additional_dates.length > 0 && (
            <Field
              label="Zusatzdaten"
              value={course.additional_dates
                .map((d) => format(new Date(d), 'd. MMM', { locale: de }))
                .join(' · ')}
            />
          )}
          <Field label="Teilnehmer" value={String(course.num_participants)} />
          <Field label="Pool gebucht" value={course.pool_booked ? 'Ja' : 'Nein'} />
        </div>
      )}

      {tab === 'assignments' && (
        <div style={{ display: 'grid', gap: 10 }}>
          {assignments.length === 0 ? (
            <div className="caption">Noch keine Zuweisungen.</div>
          ) : (
            assignments.map((a) => (
              <div
                key={a.id}
                className="glass-thin"
                style={{
                  padding: 12,
                  borderRadius: 12,
                  display: 'flex',
                  alignItems: 'center',
                  gap: 12,
                }}
              >
                {a.instructor && (
                  <Avatar initials={a.instructor.initials} color={a.instructor.color} />
                )}
                <div style={{ flex: 1 }}>
                  <div style={{ fontWeight: 500 }}>{a.instructor?.name ?? '—'}</div>
                  <div className="caption">{a.instructor?.padi_level} · {a.role}</div>
                </div>
                {a.confirmed ? (
                  <Chip tone="green">bestätigt</Chip>
                ) : (
                  <Chip tone="orange">offen</Chip>
                )}
              </div>
            ))
          )}
        </div>
      )}

      {tab === 'notes' && (
        <div>
          <div className="title-3" style={{ marginBottom: 8 }}>Info</div>
          <div className="caption" style={{ marginBottom: 18, whiteSpace: 'pre-wrap' }}>
            {course.info || '—'}
          </div>
          <div className="title-3" style={{ marginBottom: 8 }}>Notizen</div>
          <div className="caption" style={{ whiteSpace: 'pre-wrap' }}>
            {course.notes || '—'}
          </div>
        </div>
      )}
    </div>
  )
}

function Field({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <div className="caption-2">{label.toUpperCase()}</div>
      <div style={{ fontSize: 14 }}>{value}</div>
    </div>
  )
}
