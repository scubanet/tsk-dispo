import { useEffect, useState } from 'react'
import { format } from 'date-fns'
import { de } from 'date-fns/locale'
import clsx from 'clsx'
import { useNavigate, useOutletContext } from 'react-router-dom'
import { Avatar } from '@/components/Avatar'
import { Chip } from '@/components/Chip'
import { Icon } from '@/components/Icon'
import { WhatsAppButton } from '@/components/WhatsAppButton'
import { tplNewCourse, tplCancellation, waGroupShareUrl } from '@/lib/whatsapp'
import {
  fetchAllCourses,
  fetchCourseAssignments,
  fetchCourseParticipants,
  type CourseDetail,
  type AssignmentRow,
  type CourseParticipant,
} from '@/lib/queries'
import { initialsFromName } from '@/lib/format'
import { CourseEditSheet } from './CourseEditSheet'
import { AssignmentEditSheet } from './AssignmentEditSheet'
import { EnrollStudentSheet } from './EnrollStudentSheet'
import { StudentEditSheet } from './StudentEditSheet'
import type { OutletCtx } from '@/layout/AppShell'

type Tab = 'overview' | 'assignments' | 'participants' | 'notes'

const TABS: { value: Tab; label: string }[] = [
  { value: 'overview',     label: 'Übersicht' },
  { value: 'assignments',  label: 'TL/DM' },
  { value: 'participants', label: 'Teilnehmer' },
  { value: 'notes',        label: 'Notizen' },
]

export function CourseDetailPanel({ courseId }: { courseId: string }) {
  const { user } = useOutletContext<OutletCtx>()
  const navigate = useNavigate()
  const isDispatcher = user.role === 'dispatcher'
  const [course, setCourse] = useState<CourseDetail | null>(null)
  const [assignments, setAssignments] = useState<AssignmentRow[]>([])
  const [participants, setParticipants] = useState<CourseParticipant[]>([])
  const [tab, setTab] = useState<Tab>('overview')
  const [editCourseOpen, setEditCourseOpen] = useState(false)
  const [editAssignmentOpen, setEditAssignmentOpen] = useState(false)
  const [editingAssignment, setEditingAssignment] = useState<AssignmentRow | null>(null)
  const [enrollOpen, setEnrollOpen] = useState(false)
  const [editingParticipation, setEditingParticipation] = useState<CourseParticipant | null>(null)
  const [newStudentOpen, setNewStudentOpen] = useState(false)
  const [refreshTick, setRefreshTick] = useState(0)

  function refresh() {
    setRefreshTick((t) => t + 1)
  }

  useEffect(() => {
    fetchAllCourses().then((all) => setCourse(all.find((c) => c.id === courseId) ?? null))
    fetchCourseAssignments(courseId).then(setAssignments)
    fetchCourseParticipants(courseId).then(setParticipants)
  }, [courseId, refreshTick])

  if (!course) return <div style={{ padding: 40 }} className="caption">Lade…</div>

  const tone =
    course.status === 'cancelled' ? 'red' :
    course.status === 'tentative' ? 'orange' :
    course.status === 'completed' ? 'purple' : 'green'

  const haupt = assignments.find((a) => a.role === 'haupt')
  const announceUrl = waGroupShareUrl(
    tplNewCourse({
      type_code: course.course_type?.code ?? '—',
      title: course.title,
      start_date: course.start_date,
      haupt_name: haupt?.instructor?.name,
      num_participants: course.num_participants,
      info: course.info,
    }),
  )
  const cancelUrl = waGroupShareUrl(
    tplCancellation({
      type_code: course.course_type?.code ?? '—',
      title: course.title,
      was_date: course.start_date,
    }),
  )

  // Build full date list for assignment editor
  const allDates = [course.start_date, ...(course.additional_dates ?? [])].filter(Boolean)

  return (
    <div className="screen-fade" style={{ padding: '20px 24px 40px' }}>
      <div style={{ display: 'flex', gap: 12, alignItems: 'flex-start', marginBottom: 4 }}>
        <div style={{ flex: 1 }}>
          <div className="title-1">{course.title}</div>
          <div className="caption" style={{ marginTop: 4 }}>
            {course.course_type?.label ?? '—'} ·{' '}
            {format(new Date(course.start_date), 'EEEE, d. MMMM yyyy', { locale: de })}
            {course.additional_dates.length > 0 && (
              <> · +{course.additional_dates.length} {course.additional_dates.length === 1 ? 'Tag' : 'Tage'}</>
            )}
          </div>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 6, alignItems: 'flex-end' }}>
          <Chip tone={tone}>{course.status}</Chip>
          {isDispatcher && (
            <button className="btn-secondary btn" onClick={() => setEditCourseOpen(true)}>
              <Icon name="settings" size={14} /> Bearbeiten
            </button>
          )}
          <WhatsAppButton
            url={course.status === 'cancelled' ? cancelUrl : announceUrl}
            label={course.status === 'cancelled' ? 'Storno posten' : 'In Gruppe ankündigen'}
          />
        </div>
      </div>
      <div style={{ height: 16 }} />

      <div className="seg" style={{ marginBottom: 20 }}>
        {TABS.map((t) => (
          <button
            key={t.value}
            className={clsx(tab === t.value && 'active')}
            onClick={() => setTab(t.value)}
          >
            {t.label}
            {t.value === 'assignments' && (
              <span className="caption" style={{ marginLeft: 6 }}>· {assignments.length}</span>
            )}
            {t.value === 'participants' && (
              <span className="caption" style={{ marginLeft: 6 }}>· {participants.length}</span>
            )}
          </button>
        ))}
      </div>

      {tab === 'overview' && (
        <div style={{ display: 'grid', gap: 14 }}>
          <Field label="Kurstyp" value={`${course.course_type?.code ?? '—'} · ${course.course_type?.label ?? '—'}`} />
          <Field label="Startdatum" value={format(new Date(course.start_date), 'd. MMMM yyyy', { locale: de })} />
          {course.additional_dates.length > 0 && (
            <Field
              label={`Zusatzdaten (${course.additional_dates.length})`}
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
          {isDispatcher && (
            <button
              className="btn"
              onClick={() => {
                setEditingAssignment(null)
                setEditAssignmentOpen(true)
              }}
              style={{ alignSelf: 'flex-start' }}
            >
              <Icon name="plus" size={14} /> TL/DM zuweisen
            </button>
          )}

          {assignments.length === 0 ? (
            <div className="caption">Noch keine Zuweisungen.</div>
          ) : (
            assignments.map((a) => {
              const dates = (a as any).assigned_for_dates as string[] | undefined
              const partial = dates && dates.length > 0
              return (
                <div
                  key={a.id}
                  className="glass-thin"
                  style={{
                    padding: 12,
                    borderRadius: 12,
                    display: 'flex',
                    alignItems: 'center',
                    gap: 12,
                    cursor: isDispatcher ? 'pointer' : 'default',
                  }}
                  onClick={() => {
                    if (!isDispatcher) return
                    setEditingAssignment(a)
                    setEditAssignmentOpen(true)
                  }}
                >
                  {a.instructor && (
                    <Avatar initials={a.instructor.initials} color={a.instructor.color} />
                  )}
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontWeight: 500 }}>{a.instructor?.name ?? '—'}</div>
                    <div className="caption" style={{ display: 'flex', gap: 6, alignItems: 'center', flexWrap: 'wrap' }}>
                      {a.instructor?.padi_level} · {a.role}
                      {partial && (
                        <Chip tone="purple">
                          {dates!.length}/{allDates.length} Tage
                        </Chip>
                      )}
                    </div>
                  </div>
                  {a.confirmed ? (
                    <Chip tone="green">bestätigt</Chip>
                  ) : (
                    <Chip tone="orange">offen</Chip>
                  )}
                  {isDispatcher && <Icon name="chevron-right" size={14} />}
                </div>
              )
            })
          )}
        </div>
      )}

      {tab === 'participants' && (
        <div style={{ display: 'grid', gap: 10 }}>
          {isDispatcher && (
            <div style={{ display: 'flex', gap: 8 }}>
              <button
                className="btn"
                onClick={() => {
                  setEditingParticipation(null)
                  setEnrollOpen(true)
                }}
              >
                <Icon name="plus" size={14} /> Schüler anmelden
              </button>
              <div className="caption" style={{ alignSelf: 'center' }}>
                {participants.filter((p) => p.status === 'enrolled').length} angemeldet ·{' '}
                {participants.filter((p) => p.status === 'certified').length} zertifiziert
              </div>
            </div>
          )}

          {participants.length === 0 ? (
            <div className="caption">Noch keine Teilnehmer.</div>
          ) : (
            participants.map((p) => (
              <div
                key={p.id}
                className="glass-thin"
                style={{
                  padding: 12,
                  borderRadius: 12,
                  display: 'flex',
                  alignItems: 'center',
                  gap: 12,
                  cursor: isDispatcher ? 'pointer' : 'default',
                }}
                onClick={() => {
                  if (!isDispatcher) return
                  setEditingParticipation(p)
                  setEnrollOpen(true)
                }}
              >
                {p.student && (
                  <Avatar initials={initialsFromName(p.student.name)} color="#34C759" size="sm" />
                )}
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div
                    style={{ fontWeight: 500, cursor: 'pointer' }}
                    onClick={(e) => {
                      e.stopPropagation()
                      if (p.student) navigate(`/schueler/${p.student.id}`)
                    }}
                  >
                    {p.student?.name ?? '—'}
                  </div>
                  <div className="caption">
                    {[p.student?.padi_nr ? `PADI ${p.student.padi_nr}` : null, p.student?.email]
                      .filter(Boolean)
                      .join(' · ') || '—'}
                  </div>
                </div>
                {p.certificate_nr && (
                  <Chip tone="green">Zert: {p.certificate_nr}</Chip>
                )}
                <Chip
                  tone={
                    p.status === 'certified' ? 'green' :
                    p.status === 'dropped'   ? 'red' : 'orange'
                  }
                >
                  {p.status === 'enrolled' ? 'angemeldet' :
                   p.status === 'certified' ? 'zertifiziert' : 'abgebrochen'}
                </Chip>
                {isDispatcher && <Icon name="chevron-right" size={14} />}
              </div>
            ))
          )}
        </div>
      )}

      <EnrollStudentSheet
        open={enrollOpen}
        onClose={() => setEnrollOpen(false)}
        onSaved={refresh}
        courseId={courseId}
        existingParticipation={editingParticipation as any}
        alreadyEnrolledStudentIds={participants.map((p) => p.student_id)}
        onNewStudent={() => setNewStudentOpen(true)}
      />

      <StudentEditSheet
        open={newStudentOpen}
        onClose={() => setNewStudentOpen(false)}
        onSaved={() => {
          setNewStudentOpen(false)
          // Re-open the enroll sheet so the dispatcher can finish picking the new student
          setEnrollOpen(true)
        }}
        studentId={null}
      />

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

      <CourseEditSheet
        open={editCourseOpen}
        onClose={() => setEditCourseOpen(false)}
        onSaved={refresh}
        courseId={courseId}
      />

      <AssignmentEditSheet
        open={editAssignmentOpen}
        onClose={() => setEditAssignmentOpen(false)}
        onSaved={refresh}
        courseId={courseId}
        allDates={allDates}
        existingAssignment={editingAssignment as any}
      />
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
