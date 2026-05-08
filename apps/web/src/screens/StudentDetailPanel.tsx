import { useEffect, useState } from 'react'
import { useNavigate, useOutletContext } from 'react-router-dom'
import { format } from 'date-fns'
import { de, enGB } from 'date-fns/locale'
import { useTranslation } from 'react-i18next'
import { Avatar } from '@/components/Avatar'
import { Chip } from '@/components/Chip'
import { Icon } from '@/components/Icon'
import { WhatsAppButton } from '@/components/WhatsAppButton'
import { supabase } from '@/lib/supabase'
import { initialsFromName } from '@/lib/format'
import {
  fetchStudentCourses,
  fetchStudentCertifications,
  fetchCertifications,
  type CourseParticipant,
  type Student,
  type StudentCertification,
} from '@/lib/queries'
import type { Certification } from '@/types/foundation'
import { BrevetsView } from '@/foundation'
import { waDirectUrl, tplDirect } from '@/lib/whatsapp'
import type { OutletCtx } from '@/layout/AppShell'
import { StudentEditSheet } from './StudentEditSheet'
import { CertificationEditSheet } from './CertificationEditSheet'
import { CommunicationEditSheet, CHANNELS } from './cd/CommunicationEditSheet'
import { IntakeChecklistSheet } from './cd/IntakeChecklistSheet'

interface CommEntry {
  id: string
  channel: string
  direction: string
  occurred_on: string
  subject: string | null
  body: string | null
  duration_minutes: number | null
  outcome: string | null
  created_by_instructor: { id: string; name: string } | null
}

interface IntakeStatus {
  instructor_status: string | null
  min_age_confirmed: boolean
  medical_received: boolean
  medical_doctor_signed: boolean
  medical_signed_on: string | null
  certified_diver_since: string | null
  efr_kind: string | null
  efr_completed_on: string | null
  non_padi_certs_seen: boolean
  logbook_seen: boolean
  liability_signed: boolean
  safe_diving_signed: boolean
  checked_on: string | null
}

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

// Stage-Label kommt aus i18n: t(`student_edit.stage_${code}`)

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
  const { t, i18n } = useTranslation()
  const dfLocale = i18n.resolvedLanguage === 'en' ? enGB : de
  const { user } = useOutletContext<OutletCtx>()
  const navigate = useNavigate()
  const [student, setStudent] = useState<Student | null>(null)
  const [cdInfo, setCdInfo] = useState<CdInfo | null>(null)
  const [courses, setCourses] = useState<CourseParticipant[]>([])
  const [certifications, setCertifications] = useState<StudentCertification[]>([])
  const [brevets, setBrevets] = useState<Certification[]>([])
  const [editOpen, setEditOpen] = useState(false)
  const [certOpen, setCertOpen] = useState(false)
  const [editingCert, setEditingCert] = useState<StudentCertification | null>(null)
  const [commOpen, setCommOpen] = useState(false)
  const [editingCommId, setEditingCommId] = useState<string | null>(null)
  const [communications, setCommunications] = useState<CommEntry[]>([])
  const [intakeOpen, setIntakeOpen] = useState(false)
  const [intake, setIntake] = useState<IntakeStatus | null>(null)
  const [refreshTick, setRefreshTick] = useState(0)

  const isCD = user.role === 'cd'

  useEffect(() => {
    supabase
      .from('people')
      .select('id, name, email, phone, birthday, padi_nr, level, notes, active, created_at')
      .eq('id', studentId)
      .single()
      .then(({ data }) => setStudent(data as Student | null))
    fetchStudentCourses(studentId).then(setCourses)
    fetchStudentCertifications(studentId).then(setCertifications)
    fetchCertifications(studentId).then(setBrevets)

    if (isCD) {
      supabase
        .from('people')
        .select('address, postal_code, city, country, photo_url, pipeline_stage, lead_source, tags, languages, organization_id, organization_role, is_candidate, organization:organizations(id, name)')
        .eq('id', studentId)
        .single()
        .then(({ data }) => setCdInfo(data as unknown as CdInfo | null))

      supabase
        .from('communication_entries')
        .select('id, channel, direction, occurred_on, subject, body, duration_minutes, outcome, created_by_instructor:instructors!created_by(id, name)')
        .eq('contact_id', studentId)
        .order('occurred_on', { ascending: false })
        .then(({ data }) => setCommunications((data ?? []) as unknown as CommEntry[]))

      supabase
        .from('intake_checklists')
        .select('instructor_status, min_age_confirmed, medical_received, medical_doctor_signed, medical_signed_on, certified_diver_since, efr_kind, efr_completed_on, non_padi_certs_seen, logbook_seen, liability_signed, safe_diving_signed, checked_on')
        .eq('student_id', studentId)
        .maybeSingle()
        .then(({ data }) => setIntake((data as unknown as IntakeStatus | null) ?? null))
    }
  }, [studentId, refreshTick, isCD])

  if (!student) return <div style={{ padding: 40 }} className="caption">{t('common.loading')}</div>

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
            {[
              student.padi_nr ? `PADI ${student.padi_nr}` : null,
              student.birthday ? `*${format(new Date(student.birthday), 'd. MMM yyyy', { locale: dfLocale })}` : null,
            ].filter(Boolean).join(' · ') || '—'}
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
            <Icon name="settings" size={14} /> {t('common.edit')}
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
        <Field label={t('student_edit.label_email')}    value={student.email   || '—'} />
        <Field label={t('student_detail.field_phone')}  value={student.phone   || '—'} />
        {student.notes && <Field label={t('student_detail.field_notes')} value={student.notes} />}
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
                {t('student_edit.is_candidate')}
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
                {t(`student_edit.stage_${cdInfo.pipeline_stage === 'customer' ? 'candidate' : cdInfo.pipeline_stage}`, { defaultValue: cdInfo.pipeline_stage })}
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
                label={t('student_edit.section_address')}
                value={[cdInfo.address, [cdInfo.postal_code, cdInfo.city].filter(Boolean).join(' '), cdInfo.country]
                  .filter(Boolean)
                  .join(', ')}
              />
            )}
            {cdInfo.organization && (
              <Field
                label={t('student_edit.label_organization')}
                value={`${cdInfo.organization.name}${cdInfo.organization_role ? ` · ${cdInfo.organization_role}` : ''}`}
              />
            )}
            {cdInfo.lead_source && <Field label={t('student_edit.label_lead_source')} value={cdInfo.lead_source} />}
          </div>

          {/* Intake-Checkliste (Kompakt-Anzeige + Edit) */}
          <div style={{ marginBottom: 24 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 8 }}>
              <div className="title-3">
                {t('student_detail.intake_title')}
                {intake?.checked_on && (
                  <span className="caption" style={{ marginLeft: 8 }}>
                    · {t('student_detail.intake_last_checked', { date: format(new Date(intake.checked_on), 'd. MMM yyyy', { locale: dfLocale }) })}
                  </span>
                )}
              </div>
              {isDispatcher && (
                <button className="btn-secondary btn" onClick={() => setIntakeOpen(true)}>
                  <Icon name="settings" size={12} /> {intake ? t('common.edit') : t('student_detail.intake_capture')}
                </button>
              )}
            </div>
            {intake ? (
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
                <IntakeChip label={t('student_detail.intake_status')} ok={!!intake.instructor_status} />
                <IntakeChip label={t('student_detail.intake_min18')} ok={intake.min_age_confirmed} />
                <IntakeChip label={t('student_detail.intake_medical')} ok={intake.medical_received && intake.medical_doctor_signed} />
                <IntakeChip label={t('student_detail.intake_diver_6mo')} ok={!!intake.certified_diver_since} />
                <IntakeChip label={t('student_detail.intake_efr')} ok={!!intake.efr_kind} />
                <IntakeChip label={t('student_detail.intake_logbook')} ok={intake.logbook_seen} />
                <IntakeChip label={t('student_detail.intake_liability')} ok={intake.liability_signed} />
                <IntakeChip label={t('student_detail.intake_safe_diving')} ok={intake.safe_diving_signed} />
                <IntakeChip label={t('student_detail.intake_certs')} ok={intake.non_padi_certs_seen} />
              </div>
            ) : (
              <div className="caption">
                {t('student_detail.intake_empty_hint')}
              </div>
            )}
          </div>

          {/* Communication-Log */}
          <div style={{ marginBottom: 24 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 8 }}>
              <div className="title-3">
                {t('nav.communication')}{' '}
                <span className="caption">· {communications.length}</span>
              </div>
              {isDispatcher && (
                <button
                  className="btn-secondary btn"
                  onClick={() => {
                    setEditingCommId(null)
                    setCommOpen(true)
                  }}
                >
                  <Icon name="plus" size={12} /> {t('student_detail.new_touchpoint')}
                </button>
              )}
            </div>
            {communications.length === 0 ? (
              <div className="caption">
                {t('student_detail.no_touchpoints')}
              </div>
            ) : (
              <div style={{ display: 'grid', gap: 6 }}>
                {communications.map((c) => {
                  const channel = CHANNELS.find((x) => x.code === c.channel)
                  return (
                    <div
                      key={c.id}
                      className="glass-thin"
                      style={{ padding: 12, borderRadius: 12, cursor: isDispatcher ? 'pointer' : 'default' }}
                      onClick={() => {
                        if (!isDispatcher) return
                        setEditingCommId(c.id)
                        setCommOpen(true)
                      }}
                    >
                      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                        <div
                          style={{
                            padding: '2px 8px',
                            borderRadius: 999,
                            background: c.direction === 'inbound' ? 'rgba(0,122,255,.20)' : 'rgba(52,199,89,.20)',
                            fontSize: 11,
                            fontWeight: 600,
                          }}
                        >
                          {channel?.label ?? c.channel}
                          {c.direction === 'inbound' ? ' ↓' : ' ↑'}
                        </div>
                        {c.created_by_instructor && (
                          <span className="caption-2" style={{ padding: '2px 8px', borderRadius: 999, background: 'rgba(88,86,214,.20)' }}>
                            {c.created_by_instructor.name}
                          </span>
                        )}
                        <div className="caption-2" style={{ marginLeft: 'auto' }}>
                          {format(new Date(c.occurred_on), 'd. MMM yyyy, HH:mm', { locale: dfLocale })}
                        </div>
                      </div>
                      {c.subject && (
                        <div style={{ fontWeight: 500, marginTop: 6 }}>{c.subject}</div>
                      )}
                      {c.body && (
                        <div className="caption" style={{ marginTop: 4, whiteSpace: 'pre-wrap' }}>
                          {c.body}
                        </div>
                      )}
                      <div style={{ display: 'flex', gap: 12, marginTop: 6 }}>
                        {c.duration_minutes != null && (
                          <span className="caption-2">{t('student_detail.minutes', { count: c.duration_minutes })}</span>
                        )}
                        {c.outcome && (
                          <span className="caption-2" style={{ fontStyle: 'italic' }}>→ {c.outcome}</span>
                        )}
                      </div>
                    </div>
                  )
                })}
              </div>
            )}
          </div>

          <CommunicationEditSheet
            open={commOpen}
            onClose={() => setCommOpen(false)}
            onSaved={() => setRefreshTick((t) => t + 1)}
            contactId={studentId}
            entryId={editingCommId}
            createdById={user.instructorId}
          />

          <IntakeChecklistSheet
            open={intakeOpen}
            onClose={() => setIntakeOpen(false)}
            onSaved={() => setRefreshTick((t) => t + 1)}
            studentId={studentId}
            checkedById={user.instructorId}
          />
        </>
      )}

      {/* ─── Cert-first view (Foundation) — primary brevet display ─── */}
      {brevets.length > 0 && (
        <div style={{ marginBottom: 24 }}>
          <BrevetsView certifications={brevets} />
        </div>
      )}

      {/* ─── Legacy: externe / historische Zertifikate (student_certifications table)
            Kept temporarily for write operations until CertificationEditSheet
            is migrated to write to the `certifications` table. Data migrated
            via 0076 — values are duplicated above in BrevetsView. ─── */}
      <div style={{ marginBottom: 24, opacity: brevets.length > 0 ? 0.6 : 1 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 8 }}>
          <div className="title-3">
            {t('student_detail.certifications')}{' '}
            <span className="caption">· {certifications.length}{brevets.length > 0 ? ' (legacy)' : ''}</span>
          </div>
          {isDispatcher && (
            <button
              className="btn-secondary btn"
              onClick={() => {
                setEditingCert(null)
                setCertOpen(true)
              }}
            >
              <Icon name="plus" size={12} /> {t('student_detail.intake_capture')}
            </button>
          )}
        </div>
        {certifications.length === 0 ? (
          <div className="caption">
            {t('student_detail.no_certifications')}
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
                        c.issued_date ? format(new Date(c.issued_date), 'd. MMM yyyy', { locale: dfLocale }) : null,
                        c.certificate_nr ? t('student_detail.cert_nr', { nr: c.certificate_nr }) : null,
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
        {t('student_detail.tsk_history')}
        <span className="caption">· {t('student_detail.total_count', { count: courses.length })}</span>
      </div>

      {courses.length === 0 ? (
        <div className="caption">{t('student_detail.no_course_assignment')}</div>
      ) : (
        <>
          {enrolled.length > 0 && (
            <Section title={t('student_detail.section_enrolled')} tone="orange">
              {enrolled.map((p) => (
                <CourseRow key={p.id} p={p} onClick={() => navigate(`/kurse/${p.course?.id}`)} dfLocale={dfLocale} t={t} />
              ))}
            </Section>
          )}
          {certified.length > 0 && (
            <Section title={t('student_detail.section_certified')} tone="green">
              {certified.map((p) => (
                <CourseRow key={p.id} p={p} onClick={() => navigate(`/kurse/${p.course?.id}`)} dfLocale={dfLocale} t={t} />
              ))}
            </Section>
          )}
          {dropped.length > 0 && (
            <Section title={t('student_detail.section_dropped')} tone="red">
              {dropped.map((p) => (
                <CourseRow key={p.id} p={p} onClick={() => navigate(`/kurse/${p.course?.id}`)} dfLocale={dfLocale} t={t} />
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

function CourseRow({ p, onClick, dfLocale, t }: {
  p: CourseParticipant
  onClick: () => void
  dfLocale: typeof de
  t: (key: string, opts?: Record<string, unknown>) => string
}) {
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
            {format(new Date(p.course.start_date), 'd. MMM yyyy', { locale: dfLocale })}
          </div>
          {p.certificate_nr && (
            <div className="caption-2 mono" style={{ marginTop: 2 }}>
              {t('course_detail.cert_short', { nr: p.certificate_nr })}
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

function IntakeChip({ label, ok }: { label: string; ok: boolean }) {
  return (
    <span
      className="caption"
      style={{
        padding: '4px 10px',
        borderRadius: 999,
        background: ok ? 'rgba(52,199,89,.20)' : 'rgba(255,255,255,.08)',
        fontWeight: ok ? 600 : 400,
        opacity: ok ? 1 : 0.7,
      }}
    >
      {ok ? '✓' : '○'} {label}
    </span>
  )
}
