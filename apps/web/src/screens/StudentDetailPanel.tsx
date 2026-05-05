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
import {
  fetchStudentCourses,
  fetchStudentCertifications,
  type CourseParticipant,
  type Student,
  type StudentCertification,
} from '@/lib/queries'
import { waDirectUrl, tplDirect } from '@/lib/whatsapp'
import type { OutletCtx } from '@/layout/AppShell'
import { StudentEditSheet } from './StudentEditSheet'
import { CertificationEditSheet } from './CertificationEditSheet'

interface CdInfo {
  address: string | null
  postal_code: string | null
  city: string | null
  country: string | null
  photo_url: string | null
  pipeline_stage: string
  lead_source: string | null
  tags: string[] | null
  languages: string[] | null
  organization_id: string | null
  organization_role: string | null
  is_candidate: boolean
  organization?: { id: string; name: string } | null
}

const STAGE_LABEL: Record<string, string> = {
  none: 'Kein',
  lead: 'Lead',
  qualified: 'Qualifiziert',
  opportunity: 'Opportunity',
  candidate: 'Kandidat',
  customer: 'Kandidat', // Legacy
  lost: 'Verloren',
}

const STAGE_TONE: Record<string, string> = {
  none: 'rgba(255,255,255,.10)',
  lead: 'rgba(0,122,255,.20)',
  qualified: 'rgba(255,204,0,.20)',
  opportunity: 'rgba(255,149,0,.20)',
  candidate: 'rgba(52,199,89,.20)',
  customer: 'rgba(52,199,89,.20)', // Legacy
  lost: 'rgba(255,69,58,.18)',
}

export function StudentDetailPanel({ studentId }: { studentId: string }) {
  const { user } = useOutletContext<OutletCtx>()
  const navigate = useNavigate()
  const [student, setStudent] = useState<Student | null>(null)
  const [cdInfo, setCdInfo] = useState<CdInfo | null>(null)
  const [courses, setCourses] = useState<CourseParticipant[]>([])
  const [certifications, setCertifications] = useState<StudentCertification[]>([])
  const [editOpen, setEditOpen] = useState(false)
  const [certOpen, setCertOpen] = useState(false)
  const [editingCert, setEditingCert] = useState<StudentCertification | null>(null)
  const [refreshTick, setRefreshTick] = useState(0)

  const isCD = user.role === 'cd'

  useEffect(() => {
    supabase
      .from('students')
      .select('id, name, email, phone, birthday, padi_nr, level, notes, active, created_at')
      .eq('id', studentId)
      .single()
      .then(({ data }) => setStudent(data as Student | null))
    fetchStudentCourses(studentId).then(setCourses)
    fetchStudentCertifications(studentId).then(setCertifications)

    if (isCD) {
      supabase
        .from('students')
        .select('address, postal_code, city, country, photo_url, pipeline_stage, lead_source, tags, languages, organization_id, organization_role, is_candidate, organization:organizations(id, name)')
        .eq('id', studentId)
        .single()
        .then(({ data }) => setCdInfo(data as unknown as CdInfo | null))
    }
  }, [studentId, refreshTick, isCD])

  if (!student) return <div style={{ padding: 40 }} className="caption">Lade…</div>

  const isDispatcher = user.role === 'dispatcher' || user.role === 'cd'
  const initials = initialsFromName(student.name)
  const certified = courses.filter((c) => c.status === 'certified')
  const enrolled = courses.filter((c) => c.status === 'enrolled')
  const dropped = courses.filter((c) => c.status === 'dropped')

  return (
    <div className="screen-fade" style={{ padding: '20px 24px 40px' }}>
      <div style={{ display: 'flex', gap: 16, alignItems: 'center', marginBottom: 20 }}>
        <Avatar initials={initials} color="#34C759" size="lg" />
        <div style={{ flex: 1 }}>
          <div style={{ display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap' }}>
            <div className="title-1">{student.name}</div>
            <Chip tone="accent">{student.level}</Chip>
          </div>
          <div className="caption" style={{ marginTop: 4 }}>
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
        showCdFields={user.role === 'cd'}
      />

      <CertificationEditSheet
        open={certOpen}
        onClose={() => setCertOpen(false)}
        onSaved={() => setRefreshTick((t) => t + 1)}
        studentId={studentId}
        existing={editingCert}
      />

      <div style={{ display: 'grid', gap: 14, marginBottom: 24 }}>
        <Field label="Email"    value={student.email   || '—'} />
        <Field label="Telefon"  value={student.phone   || '—'} />
        {student.notes && <Field label="Notizen" value={student.notes} />}
      </div>

      {isCD && cdInfo && (
        <>
          {/* CD: Pipeline + Kandidat-Badge prominent */}
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginBottom: 20 }}>
            {cdInfo.is_candidate && (
              <span
                className="caption"
                style={{
                  padding: '4px 12px',
                  borderRadius: 999,
                  background: 'rgba(52,199,89,.20)',
                  fontWeight: 600,
                }}
              >
                Kandidat:in
              </span>
            )}
            {cdInfo.pipeline_stage !== 'none' && (
              <span
                className="caption"
                style={{
                  padding: '4px 12px',
                  borderRadius: 999,
                  background: STAGE_TONE[cdInfo.pipeline_stage] ?? 'rgba(255,255,255,.10)',
                }}
              >
                {STAGE_LABEL[cdInfo.pipeline_stage] ?? cdInfo.pipeline_stage}
              </span>
            )}
            {(cdInfo.tags ?? []).map((t) => (
              <span key={t} className="caption" style={{ padding: '4px 10px', borderRadius: 999, background: 'rgba(255,255,255,.08)' }}>
                #{t}
              </span>
            ))}
            {(cdInfo.languages ?? []).map((l) => (
              <span key={l} className="caption" style={{ padding: '4px 10px', borderRadius: 999, background: 'rgba(88,86,214,.20)' }}>
                {l}
              </span>
            ))}
          </div>

          <div style={{ display: 'grid', gap: 14, marginBottom: 24 }}>
            {(cdInfo.address || cdInfo.city) && (
              <Field
                label="Adresse"
                value={[cdInfo.address, [cdInfo.postal_code, cdInfo.city].filter(Boolean).join(' '), cdInfo.country]
                  .filter(Boolean)
                  .join(', ')}
              />
            )}
            {cdInfo.organization && (
              <Field
                label="Organisation"
                value={`${cdInfo.organization.name}${cdInfo.organization_role ? ` · ${cdInfo.organization_role}` : ''}`}
              />
            )}
            {cdInfo.lead_source && <Field label="Lead-Quelle" value={cdInfo.lead_source} />}
          </div>
        </>
      )}

      {/* Externe / historische Zertifikate */}
      <div style={{ marginBottom: 24 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 8 }}>
          <div className="title-3">
            Tauchscheine{' '}
            <span className="caption">· {certifications.length}</span>
          </div>
          {isDispatcher && (
            <button
              className="btn-secondary btn"
              onClick={() => {
                setEditingCert(null)
                setCertOpen(true)
              }}
            >
              <Icon name="plus" size={12} /> Erfassen
            </button>
          )}
        </div>
        {certifications.length === 0 ? (
          <div className="caption">
            Noch keine Tauchscheine erfasst — auch externe (z.B. OWD aus früheren Schulen) hier eintragen.
          </div>
        ) : (
          <div style={{ display: 'grid', gap: 6 }}>
            {certifications.map((c) => (
              <div
                key={c.id}
                className="glass-thin"
                style={{ padding: 12, borderRadius: 12, cursor: isDispatcher ? 'pointer' : 'default' }}
                onClick={() => {
                  if (!isDispatcher) return
                  setEditingCert(c)
                  setCertOpen(true)
                }}
              >
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontWeight: 500 }}>{c.certification}</div>
                    <div className="caption" style={{ marginTop: 2 }}>
                      {[
                        c.issued_by,
                        c.issued_date ? format(new Date(c.issued_date), 'd. MMM yyyy', { locale: de }) : null,
                        c.certificate_nr ? `Nr. ${c.certificate_nr}` : null,
                      ].filter(Boolean).join(' · ') || '—'}
                    </div>
                    {c.notes && (
                      <div className="caption-2" style={{ marginTop: 2, fontStyle: 'italic' }}>
                        {c.notes}
                      </div>
                    )}
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      <div className="title-3" style={{ marginBottom: 8, display: 'flex', alignItems: 'baseline', gap: 8 }}>
        TSK-Kurs-Historie
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
