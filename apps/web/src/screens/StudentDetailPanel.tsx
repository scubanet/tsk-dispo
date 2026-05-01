import { useEffect, useState } from 'react'
import { useNavigate, useOutletContext } from 'react-router-dom'
import { format } from 'date-fns'
import { de } from 'date-fns/locale'
import { Avatar } from '@/components/Avatar'
import { Chip } from '@/components/Chip'
import { Icon } from '@/components/Icon'
import { WhatsAppButton } from '@/components/WhatsAppButton'
import { supabase } from '@/lib/supabase'
import { initialsFromName } from '@/lib/format'
import { fetchStudentCourses, type CourseParticipant, type Student } from '@/lib/queries'
import { waDirectUrl, tplDirect } from '@/lib/whatsapp'
import type { OutletCtx } from '@/layout/AppShell'
import { StudentEditSheet } from './StudentEditSheet'

export function StudentDetailPanel({ studentId }: { studentId: string }) {
  const { user } = useOutletContext<OutletCtx>()
  const navigate = useNavigate()
  const [student, setStudent] = useState<Student | null>(null)
  const [courses, setCourses] = useState<CourseParticipant[]>([])
  const [editOpen, setEditOpen] = useState(false)
  const [refreshTick, setRefreshTick] = useState(0)

  useEffect(() => {
    supabase
      .from('students')
      .select('id, name, email, phone, birthday, padi_nr, notes, active, created_at')
      .eq('id', studentId)
      .single()
      .then(({ data }) => setStudent(data as Student | null))
    fetchStudentCourses(studentId).then(setCourses)
  }, [studentId, refreshTick])

  if (!student) return <div style={{ padding: 40 }} className="caption">Lade…</div>

  const isDispatcher = user.role === 'dispatcher'
  const initials = initialsFromName(student.name)
  const certified = courses.filter((c) => c.status === 'certified')
  const enrolled = courses.filter((c) => c.status === 'enrolled')
  const dropped = courses.filter((c) => c.status === 'dropped')

  return (
    <div className="screen-fade" style={{ padding: '20px 24px 40px' }}>
      <div style={{ display: 'flex', gap: 16, alignItems: 'center', marginBottom: 20 }}>
        <Avatar initials={initials} color="#34C759" size="lg" />
        <div style={{ flex: 1 }}>
          <div className="title-1">{student.name}</div>
          <div className="caption">
            {student.padi_nr ? `PADI ${student.padi_nr}` : 'Kein PADI'}
            {student.birthday && ` · *${format(new Date(student.birthday), 'd. MMM yyyy', { locale: de })}`}
          </div>
        </div>
        {isDispatcher && student.phone && (
          <WhatsAppButton
            url={waDirectUrl(student.phone, tplDirect({ to_name: student.name.split(' ')[0], message: '' }))}
            label="WhatsApp"
          />
        )}
        {isDispatcher && (
          <button className="btn-secondary btn" onClick={() => setEditOpen(true)}>
            <Icon name="settings" size={14} /> Bearbeiten
          </button>
        )}
      </div>

      <StudentEditSheet
        open={editOpen}
        onClose={() => setEditOpen(false)}
        onSaved={() => setRefreshTick((t) => t + 1)}
        studentId={studentId}
      />

      <div style={{ display: 'grid', gap: 14, marginBottom: 24 }}>
        <Field label="Email"    value={student.email   || '—'} />
        <Field label="Telefon"  value={student.phone   || '—'} />
        {student.notes && <Field label="Notizen" value={student.notes} />}
      </div>

      <div className="title-3" style={{ marginBottom: 8, display: 'flex', alignItems: 'baseline', gap: 8 }}>
        Kurs-Historie
        <span className="caption">· {courses.length} insgesamt</span>
      </div>

      {courses.length === 0 ? (
        <div className="caption">Noch keinem Kurs zugewiesen.</div>
      ) : (
        <>
          {enrolled.length > 0 && (
            <Section title="Angemeldet" tone="orange">
              {enrolled.map((p) => (
                <CourseRow key={p.id} p={p} onClick={() => navigate(`/kurse/${p.course?.id}`)} />
              ))}
            </Section>
          )}
          {certified.length > 0 && (
            <Section title="Zertifiziert" tone="green">
              {certified.map((p) => (
                <CourseRow key={p.id} p={p} onClick={() => navigate(`/kurse/${p.course?.id}`)} />
              ))}
            </Section>
          )}
          {dropped.length > 0 && (
            <Section title="Abgebrochen" tone="red">
              {dropped.map((p) => (
                <CourseRow key={p.id} p={p} onClick={() => navigate(`/kurse/${p.course?.id}`)} />
              ))}
            </Section>
          )}
        </>
      )}
    </div>
  )
}

function Section({ title, tone, children }: { title: string; tone: any; children: React.ReactNode }) {
  return (
    <div style={{ marginBottom: 20 }}>
      <div style={{ marginBottom: 8 }}>
        <Chip tone={tone}>{title}</Chip>
      </div>
      <div style={{ display: 'grid', gap: 6 }}>{children}</div>
    </div>
  )
}

function CourseRow({ p, onClick }: { p: CourseParticipant; onClick: () => void }) {
  if (!p.course) return null
  return (
    <div
      className="glass-thin"
      onClick={onClick}
      style={{ padding: 12, borderRadius: 12, cursor: 'pointer' }}
    >
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontWeight: 500 }}>{p.course.title}</div>
          <div className="caption">
            {p.course.course_type?.code} ·{' '}
            {format(new Date(p.course.start_date), 'd. MMM yyyy', { locale: de })}
          </div>
          {p.certificate_nr && (
            <div className="caption-2 mono" style={{ marginTop: 2 }}>
              Zert: {p.certificate_nr}
            </div>
          )}
        </div>
      </div>
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
