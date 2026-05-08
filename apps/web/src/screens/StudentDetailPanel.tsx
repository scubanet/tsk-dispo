/**
 * StudentDetailPanel — Foundation-based rewrite.
 *
 * Layout:
 *   Header: Avatar + Name + level pill + meta + WhatsApp + Edit
 *   Tabs:
 *     overview      — contact + address + organization + tags/languages
 *     brevets       — BrevetsView (+ legacy certs while edit-sheet still legacy)
 *     courses       — TSK history grouped by status
 *     intake        — checklist (CD-only)
 *     comms         — touchpoint log (CD-only)
 */

import { useEffect, useState } from 'react'
import { useNavigate, useOutletContext } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import {
  Avatar,
  Tabs,
  Pill,
  EmptyState,
  Icon,
  BrevetsView,
  dateMedium,
  dateTimeShort,
} from '@/foundation'
import { WhatsAppButton } from '@/components/WhatsAppButton'
import { supabase } from '@/lib/supabase'
import {
  fetchStudentCourses,
  fetchStudentCertifications,
  fetchCertifications,
  type CourseParticipant,
  type Student,
  type StudentCertification,
} from '@/lib/queries'
import type { Certification } from '@/types/foundation'
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

const STAGE_TONE: Record<string, 'neutral' | 'info' | 'warning' | 'success' | 'danger'> = {
  none: 'neutral',
  lead: 'neutral',
  qualified: 'info',
  opportunity: 'warning',
  candidate: 'success',
  customer: 'success',
  lost: 'danger',
}

type Tab = 'overview' | 'brevets' | 'courses' | 'intake' | 'comms'

export function StudentDetailPanel({ studentId }: { studentId: string }) {
  const { t } = useTranslation()
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
  const [tab, setTab] = useState<Tab>('overview')

  const isCD = user.role === 'cd'
  const isDispatcher = user.role === 'dispatcher' || user.role === 'cd' || user.role === 'owner'

  useEffect(() => {
    supabase
      .from('people')
      .select('id, name, email, phone, birthday, padi_nr, level, notes, active, created_at, is_student, is_candidate')
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

  if (!student) {
    return <div className="atoll-cockpit__loading">{t('common.loading')}</div>
  }

  const certified = courses.filter((c) => c.status === 'certified')
  const enrolled = courses.filter((c) => c.status === 'enrolled')
  const dropped = courses.filter((c) => c.status === 'dropped')

  const tabs: { id: Tab; label: string; count?: number }[] = [
    { id: 'overview', label: t('instructor_detail.tab_overview') },
    { id: 'brevets', label: t('student_detail.certifications'), count: brevets.length || certifications.length },
    { id: 'courses', label: t('student_detail.tsk_history'), count: courses.length },
  ]
  if (isCD) {
    tabs.push({ id: 'intake', label: t('student_detail.intake_title') })
    tabs.push({ id: 'comms', label: t('nav.communication'), count: communications.length })
  }

  return (
    <div className="atoll-detail">
      {/* Header */}
      <header className="atoll-detail__head">
        <Avatar
          id={student.id}
          name={student.name}
          size="lg"
          color={
            student.is_candidate ? 'var(--brand-red)'
            : student.is_student ? 'var(--brand-blue)'
            : undefined
          }
        />
        <div className="atoll-detail__head-main">
          <div className="atoll-detail__name">{student.name}</div>
          <div className="atoll-detail__head-meta">
            {student.level && <Pill tone="brand" size="sm">{student.level}</Pill>}
            {student.padi_nr && (
              <span className="atoll-myprofile__padi-nr">PADI {student.padi_nr}</span>
            )}
            {student.birthday && (
              <span className="tabular-nums">*{dateMedium(student.birthday)}</span>
            )}
          </div>
        </div>
        {isDispatcher && student.phone && (
          <WhatsAppButton
            url={waDirectUrl(student.phone, tplDirect({ to_name: student.name.split(' ')[0], message: '' }))}
            label="WhatsApp"
          />
        )}
        {isDispatcher && (
          <button type="button" className="atoll-btn" onClick={() => setEditOpen(true)}>
            <Icon.Settings size={14} /> {t('common.edit')}
          </button>
        )}
      </header>

      <Tabs<Tab>
        tabs={tabs}
        active={tab}
        onChange={setTab}
        ariaLabel={student.name}
        panels={{
          overview: (
            <div className="atoll-detail__overview">
              <div className="atoll-detail__fields">
                <Field label={t('student_edit.label_email')} value={student.email || '—'} />
                <Field label={t('student_detail.field_phone')} value={student.phone || '—'} />
                {student.notes && (
                  <Field label={t('student_detail.field_notes')} value={student.notes} />
                )}
              </div>

              {isCD && cdInfo && (
                <>
                  <div className="atoll-detail__head-meta">
                    {cdInfo.is_candidate && (
                      <Pill tone="success" size="sm">{t('student_edit.is_candidate')}</Pill>
                    )}
                    {cdInfo.pipeline_stage !== 'none' && (
                      <Pill
                        tone={STAGE_TONE[cdInfo.pipeline_stage] ?? 'neutral'}
                        size="sm"
                      >
                        {t(`student_edit.stage_${cdInfo.pipeline_stage === 'customer' ? 'candidate' : cdInfo.pipeline_stage}`, { defaultValue: cdInfo.pipeline_stage })}
                      </Pill>
                    )}
                    {(cdInfo.tags ?? []).map((tag) => (
                      <Pill key={tag} tone="neutral" size="sm">#{tag}</Pill>
                    ))}
                    {(cdInfo.languages ?? []).map((l) => (
                      <Pill key={l} tone="pro" size="sm">{l}</Pill>
                    ))}
                  </div>

                  <div className="atoll-detail__fields">
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
                    {cdInfo.lead_source && (
                      <Field label={t('student_edit.label_lead_source')} value={cdInfo.lead_source} />
                    )}
                  </div>
                </>
              )}
            </div>
          ),

          brevets: (
            <div className="atoll-detail__overview">
              {brevets.length > 0 ? (
                <BrevetsView certifications={brevets} />
              ) : (
                <EmptyState
                  icon={<Icon.Brevet size={20} />}
                  title={t('student_detail.no_certifications')}
                />
              )}

              {/* Legacy certs stay until CertificationEditSheet writes to certifications table. */}
              <div className="atoll-detail__legacy-certs">
                <div className="atoll-detail__certs-head">
                  <div className="atoll-cockpit__card-title">
                    {t('student_detail.certifications')}{' '}
                    <span className="atoll-myprofile__count">
                      ({certifications.length}{brevets.length > 0 ? ' legacy' : ''})
                    </span>
                  </div>
                  {isDispatcher && (
                    <button
                      type="button"
                      className="atoll-btn"
                      onClick={() => {
                        setEditingCert(null)
                        setCertOpen(true)
                      }}
                    >
                      <Icon.Plus size={12} /> {t('student_detail.intake_capture')}
                    </button>
                  )}
                </div>
                {certifications.length > 0 && (
                  <div className="atoll-detail__list" style={{ opacity: brevets.length > 0 ? 0.55 : 1 }}>
                    {certifications.map((c) => (
                      <button
                        key={c.id}
                        type="button"
                        className="atoll-detail__row"
                        onClick={() => {
                          if (!isDispatcher) return
                          setEditingCert(c)
                          setCertOpen(true)
                        }}
                        disabled={!isDispatcher}
                      >
                        <div className="atoll-detail__row-main">
                          <div className="atoll-detail__row-title">{c.certification}</div>
                          <div className="atoll-detail__row-meta tabular-nums">
                            {[
                              c.issued_by,
                              c.issued_date ? dateMedium(c.issued_date) : null,
                              c.certificate_nr ? t('student_detail.cert_nr', { nr: c.certificate_nr }) : null,
                            ].filter(Boolean).join(' · ') || '—'}
                          </div>
                          {c.notes && (
                            <div className="atoll-myprofile__avail-note">{c.notes}</div>
                          )}
                        </div>
                      </button>
                    ))}
                  </div>
                )}
              </div>
            </div>
          ),

          courses: courses.length === 0 ? (
            <EmptyState
              icon={<Icon.Calendar size={20} />}
              title={t('student_detail.no_course_assignment')}
            />
          ) : (
            <div className="atoll-detail__overview">
              {enrolled.length > 0 && (
                <CourseSection
                  title={t('student_detail.section_enrolled')}
                  tone="warning"
                  courses={enrolled}
                  onClick={(id) => navigate(`/kurse/${id}`)}
                  t={t}
                />
              )}
              {certified.length > 0 && (
                <CourseSection
                  title={t('student_detail.section_certified')}
                  tone="success"
                  courses={certified}
                  onClick={(id) => navigate(`/kurse/${id}`)}
                  t={t}
                />
              )}
              {dropped.length > 0 && (
                <CourseSection
                  title={t('student_detail.section_dropped')}
                  tone="danger"
                  courses={dropped}
                  onClick={(id) => navigate(`/kurse/${id}`)}
                  t={t}
                />
              )}
            </div>
          ),

          intake: (
            <div className="atoll-detail__overview">
              <div className="atoll-detail__certs-head">
                <div className="atoll-cockpit__card-title">
                  {t('student_detail.intake_title')}
                  {intake?.checked_on && (
                    <span className="atoll-myprofile__count">
                      {' · '}
                      {t('student_detail.intake_last_checked', { date: dateMedium(intake.checked_on) })}
                    </span>
                  )}
                </div>
                {isDispatcher && (
                  <button
                    type="button"
                    className="atoll-btn"
                    onClick={() => setIntakeOpen(true)}
                  >
                    <Icon.Settings size={12} /> {intake ? t('common.edit') : t('student_detail.intake_capture')}
                  </button>
                )}
              </div>
              {intake ? (
                <div className="atoll-myprofile__skills">
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
                <EmptyState
                  icon={<Icon.Info size={20} />}
                  title={t('student_detail.intake_empty_hint')}
                />
              )}
            </div>
          ),

          comms: (
            <div className="atoll-detail__overview">
              <div className="atoll-detail__certs-head">
                <div className="atoll-cockpit__card-title">
                  {t('nav.communication')}{' '}
                  <span className="atoll-myprofile__count">· {communications.length}</span>
                </div>
                {isDispatcher && (
                  <button
                    type="button"
                    className="atoll-btn atoll-btn--primary"
                    onClick={() => {
                      setEditingCommId(null)
                      setCommOpen(true)
                    }}
                  >
                    <Icon.Plus size={12} /> {t('student_detail.new_touchpoint')}
                  </button>
                )}
              </div>
              {communications.length === 0 ? (
                <EmptyState
                  icon={<Icon.Mail size={20} />}
                  title={t('student_detail.no_touchpoints')}
                />
              ) : (
                <div className="atoll-comm__list">
                  {communications.map((c) => {
                    const channel = CHANNELS.find((x) => x.code === c.channel)
                    return (
                      <button
                        key={c.id}
                        type="button"
                        className="atoll-comm__entry"
                        onClick={() => {
                          if (!isDispatcher) return
                          setEditingCommId(c.id)
                          setCommOpen(true)
                        }}
                        disabled={!isDispatcher}
                      >
                        <div className="atoll-comm__entry-head">
                          <Pill
                            tone={c.direction === 'inbound' ? 'brand' : 'success'}
                            size="sm"
                          >
                            {channel?.label ?? c.channel}{c.direction === 'inbound' ? ' ↓' : ' ↑'}
                          </Pill>
                          {c.created_by_instructor && (
                            <Pill tone="pro" size="sm">{c.created_by_instructor.name}</Pill>
                          )}
                          <span className="atoll-comm__entry-time tabular-nums">
                            {dateTimeShort(c.occurred_on)}
                          </span>
                        </div>
                        {c.subject && (
                          <div className="atoll-comm__entry-subject">{c.subject}</div>
                        )}
                        {c.body && <div className="atoll-comm__entry-body">{c.body}</div>}
                        {(c.duration_minutes != null || c.outcome) && (
                          <div className="atoll-comm__entry-meta">
                            {c.duration_minutes != null && (
                              <span>{t('student_detail.minutes', { count: c.duration_minutes })}</span>
                            )}
                            {c.outcome && (
                              <span className="atoll-comm__entry-outcome">→ {c.outcome}</span>
                            )}
                          </div>
                        )}
                      </button>
                    )
                  })}
                </div>
              )}
            </div>
          ),
        }}
      />

      <StudentEditSheet
        open={editOpen}
        onClose={() => setEditOpen(false)}
        onSaved={() => setRefreshTick((tick) => tick + 1)}
        studentId={studentId}
        showCdFields={isCD}
      />

      <CertificationEditSheet
        open={certOpen}
        onClose={() => setCertOpen(false)}
        onSaved={() => setRefreshTick((tick) => tick + 1)}
        studentId={studentId}
        existing={editingCert}
      />

      {isCD && (
        <>
          <CommunicationEditSheet
            open={commOpen}
            onClose={() => setCommOpen(false)}
            onSaved={() => setRefreshTick((tick) => tick + 1)}
            contactId={studentId}
            entryId={editingCommId}
            createdById={user.instructorId}
          />

          <IntakeChecklistSheet
            open={intakeOpen}
            onClose={() => setIntakeOpen(false)}
            onSaved={() => setRefreshTick((tick) => tick + 1)}
            studentId={studentId}
            checkedById={user.instructorId}
          />
        </>
      )}
    </div>
  )
}

// ──────────────────────── helpers ────────────────────────

function Field({ label, value }: { label: string; value: string }) {
  return (
    <div className="atoll-detail__field">
      <div className="atoll-detail__field-label small-caps">{label}</div>
      <div className="atoll-detail__field-value">{value}</div>
    </div>
  )
}

function IntakeChip({ label, ok }: { label: string; ok: boolean }) {
  return (
    <Pill tone={ok ? 'success' : 'neutral'} size="sm">
      {ok ? '✓ ' : '○ '}{label}
    </Pill>
  )
}

function CourseSection({
  title,
  tone,
  courses,
  onClick,
  t,
}: {
  title: string
  tone: 'success' | 'warning' | 'danger'
  courses: CourseParticipant[]
  onClick: (id: string) => void
  t: (key: string, opts?: Record<string, unknown>) => string
}) {
  return (
    <section>
      <Pill tone={tone} size="sm">{title}</Pill>
      <div className="atoll-detail__list" style={{ marginTop: 8 }}>
        {courses.map((p) => {
          if (!p.course) return null
          return (
            <button
              key={p.id}
              type="button"
              className="atoll-detail__row"
              onClick={() => onClick(p.course!.id)}
            >
              <div className="atoll-detail__row-main">
                <div className="atoll-detail__row-title">{p.course.title}</div>
                <div className="atoll-detail__row-meta tabular-nums">
                  {p.course.course_type?.code} · {dateMedium(p.course.start_date)}
                </div>
                {p.certificate_nr && (
                  <div className="atoll-myprofile__avail-note">
                    {t('course_detail.cert_short', { nr: p.certificate_nr })}
                  </div>
                )}
              </div>
              <Icon.ChevronRight size={16} className="atoll-orgs__chevron" aria-hidden />
            </button>
          )
        })}
      </div>
    </section>
  )
}
