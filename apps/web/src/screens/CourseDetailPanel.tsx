import { useEffect, useState } from 'react'
import { format } from 'date-fns'
import { de, enGB } from 'date-fns/locale'
import clsx from 'clsx'
import { useTranslation } from 'react-i18next'
import { useOutletContext } from 'react-router-dom'
import { Avatar, Pill, Icon as FdIcon, dateLong, padiLevelColor } from '@/foundation'
import { ContactDetailPanel } from './contacts/ContactDetailPanel'
import type { TabKey } from './contacts/ContactDetailPanel'
import { WhatsAppButton } from '@/components/WhatsAppButton'
import { tplNewCourse, tplCancellation, waGroupShareUrl } from '@/lib/whatsapp'
import {
  fetchAllCourses,
  fetchCourseAssignments,
  fetchCourseParticipants,
  fetchCourseDates,
  POOL_LOCATIONS,
  type CourseDetail,
  type AssignmentRow,
  type CourseParticipant,
  type CourseDate,
} from '@/lib/queries'
import { CourseEditSheet } from './CourseEditSheet'
import { AssignmentEditSheet } from './AssignmentEditSheet'
import { EnrollStudentSheet } from './EnrollStudentSheet'
import { StudentEditSheet } from './StudentEditSheet'
import { PrCheckOffSheet, type ScoreSchema } from './PrCheckOffSheet'
import { SkillCheckTab } from './SkillCheckTab'
import { IntakeChecklistSheet } from './cd/IntakeChecklistSheet'
import { supabase } from '@/lib/supabase'
import type { OutletCtx } from '@/layout/AppShell'
import {
  generatePadiReferralPdf,
  downloadPdf,
  splitE164Phone,
  fetchInstructorBlockForCourse,
  buildCourseAutofillData,
} from '@/lib/padiReferralFill'
import type { PadiReferralData } from '@/lib/padiReferralFieldMap'

type Tab = 'overview' | 'assignments' | 'participants' | 'notes' | 'prs' | 'skillcheck'

// Mapping: course_type.code → pr_catalogs.course_type
// Hinweis: DM ist kein originärer CD-Kurs, sondern dient als Recruiting-Kanal
// für DM-Kandidat:innen die später in den IDC eingeführt werden sollen.
// IDC/SPEI/EFRI sind die eigentlichen Pro-Level-Kurse die der CD leitet.
const CD_COURSE_PREFIXES: Array<{ catalog: string; match: (c: string) => boolean }> = [
  { catalog: 'DM',   match: (c) => c === 'DM' },
  { catalog: 'IDC',  match: (c) => c === 'IDC' },
  { catalog: 'EFRI', match: (c) => c === 'EFRI' },
  { catalog: 'SPEI', match: (c) => c.startsWith('SPEI') },
]
function catalogForCourse(code?: string | null): string | null {
  if (!code) return null
  return CD_COURSE_PREFIXES.find((p) => p.match(code))?.catalog ?? null
}

interface PrSkill {
  code: string
  title: string
  isActive?: boolean
  repeatable?: boolean
  showAssistantToggle?: boolean
  /** Skills mit gleichem pairGroup werden zusammengefasst — der Schnitt der Scores muss ≥ pairAverageThreshold sein */
  pairGroup?: number
}
interface PrSlot {
  code: string
  order: number
  title: string
  kind: string
  scoreSchema: string
  passThreshold?: number
  minRequired?: number
  /** 'minOnePassed' = Slot gilt als bestanden sobald MIN. 1 Skill ≥ Threshold von einem Kandidaten erreicht ist
   *  'minOnePairPassed' = Slot gilt als bestanden sobald MIN. 1 Pärchen (gruppiert via pairGroup) Schnitt ≥ pairAverageThreshold erreicht */
  passRule?: string
  /** Threshold für pairGroup-Schnitte bei minOnePairPassed */
  pairAverageThreshold?: number
  skills: PrSkill[]
}
interface PrPrereqCert { kind: string; minMonthsAgo?: number; maxMonthsAgo?: number; note?: string }
interface PrCatalog {
  course_type: string
  language: string
  version: string
  data: {
    course: string
    title: string
    version: string
    prerequisites: {
      minAge?: number
      requiredCerts?: PrPrereqCert[]
      requiredELearning?: { kind: string; minProgressPercent?: number; knowledgeReviewsRequired?: boolean; examRequired?: boolean } | null
    }
    slots: PrSlot[]
  }
}
interface PrRecord {
  id: string
  student_id: string
  pr_code: string
  status: string
  score: number | null
  pass: boolean | null
  assessed_on: string | null
  assessed_by_text: string | null
  notes: string | null
  with_assistant: boolean | null
}

export function CourseDetailPanel({ courseId }: { courseId: string }) {
  const { t, i18n } = useTranslation()
  const dfLocale = i18n.resolvedLanguage === 'en' ? enGB : de
  const BASE_TABS: { value: Tab; label: string }[] = [
    { value: 'overview',     label: t('course_detail.tab_overview') },
    { value: 'assignments',  label: t('course_detail.tab_assignments') },
    { value: 'participants', label: t('course_detail.tab_participants') },
    { value: 'notes',        label: t('course_detail.tab_notes') },
  ]
  const { user } = useOutletContext<OutletCtx>()
  const isDispatcher = user.role === 'dispatcher' || user.role === 'cd'
  const [course, setCourse] = useState<CourseDetail | null>(null)
  const [assignments, setAssignments] = useState<AssignmentRow[]>([])
  const [participants, setParticipants] = useState<CourseParticipant[]>([])
  const [courseDates, setCourseDates] = useState<CourseDate[]>([])
  const [tab, setTab] = useState<Tab>('overview')
  const [editCourseOpen, setEditCourseOpen] = useState(false)
  const [editAssignmentOpen, setEditAssignmentOpen] = useState(false)
  const [editingAssignment, setEditingAssignment] = useState<AssignmentRow | null>(null)
  const [enrollOpen, setEnrollOpen] = useState(false)
  const [editingParticipation, setEditingParticipation] = useState<CourseParticipant | null>(null)
  const [newStudentOpen, setNewStudentOpen] = useState(false)
  const [refreshTick, setRefreshTick] = useState(0)
  const [catalog, setCatalog] = useState<PrCatalog | null>(null)
  const [prRecords, setPrRecords] = useState<PrRecord[]>([])
  const [intakeForCpId, setIntakeForCpId] = useState<string | null>(null)
  const [selectedContactId, setSelectedContactId] = useState<string | null>(null)
  const [contactInitialTab, setContactInitialTab] = useState<TabKey>('overview')
  const [padiGeneratingId, setPadiGeneratingId] = useState<string | null>(null)

  function openInstructorContact(id: string) {
    setSelectedContactId(id)
    setContactInitialTab('saldo')
  }
  function openParticipantContact(id: string) {
    setSelectedContactId(id)
    setContactInitialTab('overview')
  }

  async function handlePadiReferral(p: CourseParticipant) {
    if (!p.student) return
    setPadiGeneratingId(p.id)
    try {
      const diveCenterNr = localStorage.getItem('atoll.padi_dive_center_nr') ?? ''

      // Load full contact (addresses, phones, gender, birth_date) — student-row only has basics
      const { data: fullContact } = await supabase
        .from('contacts')
        .select('id, first_name, last_name, birth_date, gender, primary_email, phones, addresses')
        .eq('id', p.student.id)
        .maybeSingle()

      // Parse birth date from contacts.birth_date (fallback to student.birthday)
      let studentBirthTag: string | undefined
      let studentBirthMonat: string | undefined
      let studentBirthJahr: string | undefined
      const bd = (fullContact?.birth_date as string | null | undefined)
        ?? (p.student as { birthday?: string | null }).birthday
      if (bd) {
        const parts = bd.split('-')
        if (parts.length === 3) {
          studentBirthJahr  = parts[0]
          studentBirthMonat = parts[1]
          studentBirthTag   = parts[2]
        }
      }

      // Gender: contacts.gender → 'M' / 'W' for PADI form
      let studentGender: 'M' | 'W' | undefined
      const g = (fullContact?.gender ?? '').toString().toLowerCase()
      if (g === 'm' || g === 'male' || g === 'männlich') studentGender = 'M'
      else if (g === 'f' || g === 'w' || g === 'weiblich' || g === 'female') studentGender = 'W'

      // Address: prefer contacts.addresses (primary first), else nothing
      const primaryAddr = Array.isArray(fullContact?.addresses)
        ? (fullContact!.addresses as any[]).find((a) => a?.primary) ?? (fullContact!.addresses as any[])[0]
        : null
      const studentStreet = primaryAddr?.street ?? undefined
      const studentCityPostal =
        primaryAddr
          ? [primaryAddr.postal, primaryAddr.city].filter(Boolean).join(' ')
          : undefined
      const studentCountry = primaryAddr?.country ?? undefined

      // Phones: contacts.phones[] is an array of typed entries.
      //   privat = label 'home' OR 'mobile' OR primary
      //   beruflich = label 'work'
      const phones = Array.isArray(fullContact?.phones) ? (fullContact!.phones as any[]) : []
      const privatPhone = phones.find((p) => p?.label === 'home')
        ?? phones.find((p) => p?.label === 'mobile')
        ?? phones.find((p) => p?.primary)
        ?? phones[0]
      const beruflichPhone = phones.find((p) => p?.label === 'work')
      const privatSplit = splitE164Phone(privatPhone?.e164 ?? p.student.phone)
      const beruflichSplit = beruflichPhone ? splitE164Phone(beruflichPhone.e164) : { prefix: '', number: '' }

      // Look up instructor block and course auto-fill data in parallel
      const [instBlock, autofill] = await Promise.all([
        fetchInstructorBlockForCourse(courseId),
        buildCourseAutofillData(courseId, p.id),
      ])

      // Today for date fields and filename
      const today = new Date().toISOString().slice(0, 10)
      const [yyyy, mm, dd] = today.split('-')

      const studentName = fullContact
        ? [fullContact.first_name, fullContact.last_name].filter(Boolean).join(' ') || p.student.name
        : p.student.name

      const data: PadiReferralData = {
        // Course-derived auto-fill (CW, KD, OW dates + instructors)
        ...autofill,
        // Student block
        studentName,
        studentBirthTag,
        studentBirthMonat,
        studentBirthJahr,
        studentGender,
        studentStreet,
        studentCityPostal,
        studentCountry,
        studentEmail: fullContact?.primary_email ?? p.student.email ?? undefined,
        studentPhonePrivatPrefix: privatSplit.prefix || undefined,
        studentPhonePrivatNumber: privatSplit.number || undefined,
        studentPhoneBeruflichPrefix: beruflichSplit.prefix || undefined,
        studentPhoneBeruflichNumber: beruflichSplit.number || undefined,
        // Instructor block 1
        inst1DiveCenterNr: diveCenterNr || undefined,
        inst1DatumTag: dd,
        inst1DatumMonat: mm,
        inst1DatumJahr: yyyy,
        ...(instBlock && {
          inst1Name:        instBlock.name,
          inst1PadiNr:      instBlock.padiPro ?? undefined,
          inst1Email:       instBlock.email ?? undefined,
          inst1PhonePrefix: instBlock.phonePrefix || undefined,
          inst1PhoneNumber: instBlock.phoneNumber || undefined,
        }),
      }

      const bytes = await generatePadiReferralPdf(data)
      const safeName = p.student.name.replace(/\s+/g, '-')
      downloadPdf(bytes, `PADI-Referral-${safeName}-${today}.pdf`)
    } catch (err) {
      console.error('PADI referral generation failed', err)
    } finally {
      setPadiGeneratingId(null)
    }
  }

  function refresh() {
    setRefreshTick((t) => t + 1)
  }

  useEffect(() => {
    fetchAllCourses().then((all) => setCourse(all.find((c) => c.id === courseId) ?? null))
    fetchCourseAssignments(courseId).then(setAssignments)
    fetchCourseParticipants(courseId)
    .then(setParticipants)
    .catch((err) => console.error('[course-detail] fetchCourseParticipants failed', err))
    fetchCourseDates(courseId).then(setCourseDates)
  }, [courseId, refreshTick])

  // CD: Catalog + PR-Records laden, sobald Course bekannt + Catalog identifiziert
  const courseTypeCode = course?.course_type?.code ?? null
  const catalogKind = catalogForCourse(courseTypeCode)
  const isCdCourse = !!catalogKind
  const isCD = user.role === 'cd'

  useEffect(() => {
    if (!isCD || !catalogKind) return
    supabase
      .from('pr_catalogs')
      .select('course_type, language, version, data')
      .eq('course_type', catalogKind)
      .eq('language', 'de')
      .eq('active', true)
      .maybeSingle()
      .then(({ data }) => setCatalog((data as unknown as PrCatalog | null) ?? null))
    supabase
      .from('performance_records')
      .select('id, student_id, pr_code, status, score, pass, assessed_on, assessed_by_text, notes, with_assistant')
      .eq('course_id', courseId)
      .then(({ data }) => setPrRecords((data ?? []) as PrRecord[]))
  }, [courseId, refreshTick, isCD, catalogKind])

  if (!course) return <div style={{ padding: 40 }} className="caption">{t('common.loading')}</div>

  // SkillCheck-Tab nur bei OWD / OWD_DRY
  const isOwdCourse = courseTypeCode === 'OWD' || courseTypeCode === 'OWD_DRY'

  // PR-Tab nur wenn CD + CD-Kurs + Catalog vorhanden
  const visibleTabs: { value: Tab; label: string }[] = [
    ...BASE_TABS,
    ...(isOwdCourse ? [{ value: 'skillcheck' as Tab, label: t('course_detail.tab_skillcheck') }] : []),
    ...(isCD && isCdCourse ? [{ value: 'prs' as Tab, label: t('course_detail.tab_prs') }] : []),
  ]

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

  const statusTone =
    course.status === 'cancelled' ? 'danger' :
    course.status === 'tentative' ? 'warning' :
    course.status === 'completed' ? 'pro' : 'success'

  return (
    <div className="atoll-detail">
      <header className="atoll-detail__head">
        <div className="atoll-detail__head-main">
          <div className="atoll-detail__name">{course.title}</div>
          <div className="atoll-detail__head-meta">
            <span>{course.course_type?.label ?? '—'}</span>
            <span aria-hidden>·</span>
            <span className="tabular-nums">{dateLong(course.start_date)}</span>
            {course.additional_dates.length > 0 && (
              <span>· +{t('course_detail.additional_days', { count: course.additional_dates.length })}</span>
            )}
          </div>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 6, alignItems: 'flex-end' }}>
          <Pill tone={statusTone} size="sm">{course.status}</Pill>
          <WhatsAppButton
            url={course.status === 'cancelled' ? cancelUrl : announceUrl}
            label={course.status === 'cancelled' ? t('course_detail.post_cancellation') : t('course_detail.announce_in_group')}
          />
        </div>
        {isDispatcher && (
          <button type="button" className="atoll-btn" onClick={() => setEditCourseOpen(true)}>
            <FdIcon.Settings size={14} /> {t('common.edit')}
          </button>
        )}
      </header>

      <div className="atoll-tabs">
        <div role="tablist" aria-label={course.title} className="atoll-tabs__strip">
          {visibleTabs.map((tabDef) => {
            const count =
              tabDef.value === 'assignments' ? assignments.length :
              tabDef.value === 'participants' ? participants.length :
              undefined
            const isActive = tab === tabDef.value
            return (
              <button
                key={tabDef.value}
                type="button"
                role="tab"
                aria-selected={isActive}
                tabIndex={isActive ? 0 : -1}
                className={clsx('atoll-tabs__tab', isActive && 'atoll-tabs__tab--active')}
                onClick={() => setTab(tabDef.value)}
              >
                <span>{tabDef.label}</span>
                {count !== undefined && (
                  <span className="atoll-tabs__count tabular-nums">{count}</span>
                )}
              </button>
            )
          })}
        </div>
      </div>
      <div style={{ height: 16 }} />

      {tab === 'overview' && (
        <div style={{ display: 'grid', gap: 14 }}>
          <Field label={t('course_detail.field_type')} value={`${course.course_type?.code ?? '—'} · ${course.course_type?.label ?? '—'}`} />
          <Field
            label={t('course_detail.field_participants')}
            value={
              course.num_participants > 0 && course.num_participants !== participants.length
                ? t('course_detail.participants_enrolled_planned', { enrolled: participants.length, planned: course.num_participants })
                : t('course_detail.participants_enrolled', { count: participants.length })
            }
          />

          <div>
            <div className="atoll-detail__field-label small-caps">
              {t('course_detail.section_course_dates', { count: courseDates.length || 1 })}
            </div>
            <div style={{ display: 'grid', gap: 6, marginTop: 6 }}>
              {(courseDates.length > 0
                ? courseDates
                : [{ id: 'fallback', date: course.start_date, type: 'theorie' as const, pool_location: null }] as any
              ).map((cd: any) => {
                const poolMeta = POOL_LOCATIONS.find((p) => p.value === cd.pool_location)
                const hasTheory = cd.has_theory != null ? !!cd.has_theory : cd.type === 'theorie'
                const hasPool   = cd.has_pool   != null ? !!cd.has_pool   : cd.type === 'pool'
                const hasLake   = cd.has_lake   != null ? !!cd.has_lake   : cd.type === 'see'
                const hm = (s: string | null | undefined) => (s ? s.slice(0, 5) : '')
                const timeRange = (from: string | null | undefined, to: string | null | undefined) =>
                  from || to ? ` ${hm(from)}–${hm(to)}` : ''
                return (
                  <div key={cd.id} className="atoll-coursedetail__date-row">
                    <span className="atoll-coursedetail__date tabular-nums">
                      {format(new Date(cd.date), 'EEE, d. MMM', { locale: dfLocale })}
                    </span>
                    {hasTheory && (
                      <Pill tone="neutral" size="sm">
                        📚 {t('course_edit.type_theory')}{timeRange(cd.theory_from, cd.theory_to)}
                      </Pill>
                    )}
                    {hasPool && (
                      <Pill
                        tone={cd.pool_reserved ? 'success' : 'warning'}
                        size="sm"
                      >
                        🏊 {poolMeta?.label ?? cd.pool_location ?? t('course_edit.type_pool')}
                        {timeRange(cd.pool_from, cd.pool_to)}
                        {cd.pool_reserved ? ' ✓' : ' …'}
                      </Pill>
                    )}
                    {hasLake && (
                      <Pill tone="success" size="sm">
                        🌊 {t('course_edit.type_lake')}{timeRange(cd.lake_from, cd.lake_to)}
                      </Pill>
                    )}
                  </div>
                )
              })}
            </div>
          </div>
        </div>
      )}

      {tab === 'assignments' && (
        <div className="atoll-detail__list" style={{ paddingTop: 0 }}>
          {isDispatcher && (
            <button
              type="button"
              className="atoll-btn atoll-btn--primary"
              onClick={() => {
                setEditingAssignment(null)
                setEditAssignmentOpen(true)
              }}
              style={{ alignSelf: 'flex-start', marginBottom: 4 }}
            >
              <FdIcon.Plus size={14} /> {t('course_detail.assign_tldm')}
            </button>
          )}

          {assignments.length === 0 ? (
            <div className="atoll-cockpit__card-sub">{t('course_detail.no_assignments')}</div>
          ) : (
            assignments.map((a) => {
              const dates = (a as { assigned_for_dates?: string[] }).assigned_for_dates
              const partial = dates && dates.length > 0
              return (
                <button
                  key={a.id}
                  type="button"
                  className="atoll-detail__row"
                  onClick={() => {
                    if (!isDispatcher) return
                    setEditingAssignment(a)
                    setEditAssignmentOpen(true)
                  }}
                  disabled={!isDispatcher}
                >
                  {a.instructor && (
                    <button
                      type="button"
                      style={{ background: 'transparent', border: 'none', padding: 0, cursor: 'pointer' }}
                      onClick={(e) => {
                        e.stopPropagation()
                        openInstructorContact(a.instructor!.id)
                      }}
                    >
                      <Avatar
                        id={a.instructor.id}
                        name={a.instructor.name}
                        size="md"
                        color={padiLevelColor(a.instructor.padi_level)}
                      />
                    </button>
                  )}
                  <div className="atoll-detail__row-main">
                    <button
                      type="button"
                      className="atoll-detail__row-title"
                      style={{
                        background: 'transparent',
                        border: 'none',
                        padding: 0,
                        textAlign: 'left',
                        cursor: 'pointer',
                        color: 'inherit',
                        fontFamily: 'inherit',
                        fontSize: 'inherit',
                        fontWeight: 'inherit',
                      }}
                      onClick={(e) => {
                        e.stopPropagation()
                        if (a.instructor) openInstructorContact(a.instructor.id)
                      }}
                    >
                      {a.instructor?.name ?? '—'}
                    </button>
                    <div className="atoll-detail__row-meta">
                      {a.instructor?.padi_level} · {a.role}
                    </div>
                  </div>
                  <div className="atoll-detail__row-pills">
                    {partial && (
                      <Pill tone="pro" size="sm">
                        {t('course_detail.days_partial', { selected: dates!.length, total: allDates.length })}
                      </Pill>
                    )}
                    <Pill tone={a.confirmed ? 'success' : 'warning'} size="sm">
                      {a.confirmed ? t('my_assignments.confirmed') : t('my_assignments.open')}
                    </Pill>
                  </div>
                  {isDispatcher && <FdIcon.ChevronRight size={16} className="atoll-orgs__chevron" aria-hidden />}
                </button>
              )
            })
          )}
        </div>
      )}

      {tab === 'participants' && (
        <div className="atoll-detail__list" style={{ paddingTop: 0 }}>
          {isDispatcher && (
            <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginBottom: 4 }}>
              <button
                type="button"
                className="atoll-btn atoll-btn--primary"
                onClick={() => {
                  setEditingParticipation(null)
                  setEnrollOpen(true)
                }}
              >
                <FdIcon.Plus size={14} /> {t('course_detail.enroll_student')}
              </button>
              <div className="atoll-cockpit__card-sub" style={{ margin: 0 }}>
                {t('course_detail.enrolled_certified_summary', {
                  enrolled: participants.filter((p) => p.status === 'enrolled').length,
                  certified: participants.filter((p) => p.status === 'certified').length,
                })}
              </div>
            </div>
          )}

          {participants.length === 0 ? (
            <div className="atoll-cockpit__card-sub">{t('course_detail.no_participants')}</div>
          ) : (
            participants.map((p) => {
              const statusTone =
                p.status === 'certified' ? 'success' :
                p.status === 'dropped' ? 'danger' : 'warning'
              return (
                <div key={p.id} className="atoll-detail__row" style={{ cursor: 'default' }}>
                  {p.student && (
                    <Avatar
                      id={p.student.id}
                      name={p.student.name}
                      size="sm"
                      color="var(--brand-blue)"
                    />
                  )}
                  <div className="atoll-detail__row-main">
                    <button
                      type="button"
                      className="atoll-detail__row-title atoll-detail__row-title--link"
                      disabled={!p.student}
                      onClick={(e) => {
                        e.stopPropagation()
                        if (p.student) openParticipantContact(p.student.id)
                      }}
                      title={p.student ? p.student.name : undefined}
                    >
                      {p.student?.name ?? '—'}
                    </button>
                    <div className="atoll-detail__row-meta">
                      {p.student?.email ?? '—'}
                    </div>
                  </div>
                  <div className="atoll-detail__row-pills">
                    {p.certificate_nr && (
                      <Pill tone="success" size="sm">
                        {t('course_detail.cert_short', { nr: p.certificate_nr })}
                      </Pill>
                    )}
                    {isDispatcher && (
                      <button
                        type="button"
                        className="atoll-btn"
                        style={{ height: 26, padding: '0 10px', fontSize: 'var(--text-meta)' }}
                        onClick={(e) => {
                          e.stopPropagation()
                          setIntakeForCpId(p.id)
                        }}
                        title={t('course_detail.intake_tooltip')}
                      >
                        {t('course_detail.intake')}
                      </button>
                    )}
                    {(courseTypeCode === 'OWD' || courseTypeCode === 'OWD_DRY') && (
                      <button
                        type="button"
                        className="atoll-btn"
                        style={{ height: 26, padding: '0 10px', fontSize: 'var(--text-meta)' }}
                        disabled={padiGeneratingId === p.id}
                        onClick={(e) => {
                          e.stopPropagation()
                          void handlePadiReferral(p)
                        }}
                        title="PADI Referral PDF"
                      >
                        <FdIcon.Document size={12} />
                        {padiGeneratingId === p.id
                          ? t('course_detail.padi_referral_generating')
                          : t('course_detail.padi_referral_button')}
                      </button>
                    )}
                    <Pill tone={statusTone} size="sm">
                      {p.status === 'enrolled' ? t('course_detail.status_enrolled') :
                       p.status === 'certified' ? t('course_detail.status_certified') :
                       t('course_detail.status_dropped')}
                    </Pill>
                    {isDispatcher && (
                      <button
                        type="button"
                        className="atoll-btn"
                        style={{ height: 26, padding: '0 10px' }}
                        onClick={() => {
                          setEditingParticipation(p)
                          setEnrollOpen(true)
                        }}
                      >
                        <FdIcon.Settings size={12} />
                      </button>
                    )}
                  </div>
                </div>
              )
            })
          )}
        </div>
      )}

      <EnrollStudentSheet
        open={enrollOpen}
        onClose={() => setEnrollOpen(false)}
        onSaved={refresh}
        courseId={courseId}
        courseTypeCode={courseTypeCode}
        existingParticipation={editingParticipation as any}
        alreadyEnrolledStudentIds={participants.map((p) => p.student_id)}
        onNewStudent={() => setNewStudentOpen(true)}
      />

      <StudentEditSheet
        open={newStudentOpen}
        onClose={() => setNewStudentOpen(false)}
        showCdFields={user.role === 'cd'}
        onSaved={() => {
          setNewStudentOpen(false)
          // Re-open the enroll sheet so the dispatcher can finish picking the new student
          setEnrollOpen(true)
        }}
        studentId={null}
      />

      {tab === 'notes' && (
        <div className="atoll-detail__overview">
          <div>
            <h2 className="atoll-cockpit__card-title">{t('course_detail.section_info')}</h2>
            <div className="atoll-coursedetail__notes">{course.info || '—'}</div>
          </div>
          <div>
            <h2 className="atoll-cockpit__card-title">{t('course_detail.section_notes')}</h2>
            <div className="atoll-coursedetail__notes">{course.notes || '—'}</div>
          </div>
        </div>
      )}

      {tab === 'skillcheck' && (
        <SkillCheckTab
          courseId={courseId}
          participants={participants}
          assignments={assignments}
          courseDates={courseDates}
        />
      )}

      {tab === 'prs' && (
        <PrTab
          catalog={catalog}
          records={prRecords}
          participants={participants}
          courseId={courseId}
          assessorName={user.name}
          firstCourseDate={course.start_date}
          onSaved={refresh}
        />
      )}

      <CourseEditSheet
        open={editCourseOpen}
        onClose={() => setEditCourseOpen(false)}
        onSaved={refresh}
        courseId={courseId}
      />

      <IntakeChecklistSheet
        open={!!intakeForCpId}
        onClose={() => setIntakeForCpId(null)}
        onSaved={refresh}
        courseParticipantId={intakeForCpId}
        checkedById={user.instructorId}
      />

      <AssignmentEditSheet
        open={editAssignmentOpen}
        onClose={() => setEditAssignmentOpen(false)}
        onSaved={refresh}
        courseId={courseId}
        allDates={allDates}
        existingAssignment={editingAssignment as any}
      />

      <ContactDetailPanel
        contactId={selectedContactId}
        open={!!selectedContactId}
        initialTab={contactInitialTab}
        onClose={() => setSelectedContactId(null)}
      />
    </div>
  )
}

function Field({ label, value }: { label: string; value: string }) {
  return (
    <div className="atoll-detail__field">
      <div className="atoll-detail__field-label small-caps">{label}</div>
      <div className="atoll-detail__field-value">{value}</div>
    </div>
  )
}

// =============================================================
// PR-Tab (Phase 4a, read-only Catalog + Status-Matrix)
// =============================================================

function PrTab({
  catalog,
  records,
  participants,
  courseId,
  assessorName,
  firstCourseDate,
  onSaved,
}: {
  catalog: PrCatalog | null
  records: PrRecord[]
  participants: CourseParticipant[]
  courseId: string
  assessorName: string
  firstCourseDate: string
  onSaved: () => void
}) {
  const { t } = useTranslation()
  const [openSkill, setOpenSkill] = useState<{
    code: string
    title: string
    scoreSchema: ScoreSchema
    passThreshold?: number
    showAssistantToggle?: boolean
  } | null>(null)

  if (!catalog) {
    return <div className="atoll-cockpit__loading">{t('pr_tab.loading_catalog')}</div>
  }

  // Status-Lookup pro (student_id, pr_code)
  const lookup = new Map<string, PrRecord>()
  for (const r of records) {
    lookup.set(`${r.student_id}::${r.pr_code}`, r)
  }

  const cands = participants
    .filter((p) => p.status !== 'dropped')
    .filter((p) => !!p.student)
  const totalSkills = catalog.data.slots.reduce((acc, s) => acc + s.skills.length, 0)

  // Coverage-Berechnung pro Kandidat
  const coverageByStudent = new Map<string, { done: number; inProg: number; rem: number }>()
  for (const c of cands) {
    let done = 0, inProg = 0, rem = 0
    for (const slot of catalog.data.slots) {
      for (const sk of slot.skills) {
        const r = lookup.get(`${c.student!.id}::${sk.code}`)
        if (!r) continue
        if (r.status === 'completed' || r.pass === true) done++
        else if (r.status === 'in_progress') inProg++
        else if (r.status === 'remediation') rem++
      }
    }
    coverageByStudent.set(c.student!.id, { done, inProg, rem })
  }

  return (
    <div className="atoll-prtab">
      {/* Header mit Catalog-Info */}
      <section className="atoll-cockpit__card">
        <div className="atoll-prtab__head">
          <div>
            <h2 className="atoll-cockpit__card-title">{catalog.data.title}</h2>
            <p className="atoll-cockpit__card-sub" style={{ margin: 0 }}>
              {catalog.course_type} · v{catalog.version} · {t('pr_tab.slots_skills', { slots: catalog.data.slots.length, skills: totalSkills })}
            </p>
          </div>
        </div>
        {catalog.course_type === 'DM' && (
          <div className="atoll-prtab__hint">{t('pr_tab.dm_hint')}</div>
        )}
      </section>

      {/* Pre-Reqs */}
      {(catalog.data.prerequisites?.requiredCerts?.length || catalog.data.prerequisites?.requiredELearning) && (
        <section className="atoll-cockpit__card">
          <div className="atoll-detail__field-label small-caps" style={{ marginBottom: 6 }}>
            {t('pr_tab.prerequisites')}
          </div>
          <div className="atoll-prtab__prereqs">
            {catalog.data.prerequisites?.minAge && (
              <div>· {t('pr_tab.min_age', { age: catalog.data.prerequisites.minAge })}</div>
            )}
            {catalog.data.prerequisites?.requiredCerts?.map((c) => (
              <div key={c.kind}>
                · {c.kind}
                {c.maxMonthsAgo ? ` ${t('pr_tab.max_months_old', { count: c.maxMonthsAgo })}` : ''}
                {c.minMonthsAgo ? ` ${t('pr_tab.min_months_ago', { count: c.minMonthsAgo })}` : ''}
                {c.note ? ` — ${c.note}` : ''}
              </div>
            ))}
            {catalog.data.prerequisites?.requiredELearning && (
              <div>
                · {catalog.data.prerequisites.requiredELearning.kind} eLearning
                {catalog.data.prerequisites.requiredELearning.minProgressPercent !== undefined &&
                  ` (${catalog.data.prerequisites.requiredELearning.minProgressPercent}%)`}
                {catalog.data.prerequisites.requiredELearning.examRequired && ` · ${t('pr_tab.exam')}`}
              </div>
            )}
          </div>
        </section>
      )}

      {/* Kandidaten-Coverage */}
      {cands.length > 0 && (
        <section>
          <h2 className="atoll-cockpit__card-title" style={{ marginBottom: 8 }}>
            {t('pr_tab.candidates_count', { count: cands.length })}
          </h2>
          <div className="atoll-detail__list" style={{ paddingTop: 0 }}>
            {cands.map((c) => {
              const cov = coverageByStudent.get(c.student!.id) ?? { done: 0, inProg: 0, rem: 0 }
              const pct = totalSkills > 0 ? Math.round((cov.done / totalSkills) * 100) : 0
              const fillTone = pct >= 80 ? 'var(--brand-teal)' : pct >= 40 ? 'var(--brand-amber)' : 'var(--brand-red)'
              return (
                <div key={c.id} className="atoll-detail__row" style={{ cursor: 'default' }}>
                  {c.student && (
                    <Avatar id={c.student.id} name={c.student.name} size="sm" color="var(--brand-blue)" />
                  )}
                  <div className="atoll-detail__row-main">
                    <div className="atoll-detail__row-title">{c.student?.name}</div>
                    <div className="atoll-detail__row-meta">
                      {t('pr_tab.coverage_summary', { done: cov.done, total: totalSkills, pct, in_progress: cov.inProg, remediation: cov.rem })}
                    </div>
                  </div>
                  <div className="atoll-prtab__bar" aria-label={`${pct}%`}>
                    <div className="atoll-prtab__bar-fill" style={{ width: `${pct}%`, background: fillTone }} />
                  </div>
                </div>
              )
            })}
          </div>
        </section>
      )}

      {/* Catalog: Slots + Skills mit Status-Pillen */}
      <div style={{ display: 'grid', gap: 14 }}>
        {catalog.data.slots
          .slice()
          .sort((a, b) => a.order - b.order)
          .map((slot) => {
            const slotClickable = cands.length > 0 && slot.skills.length > 0
            const firstSkill = slot.skills[0]
            const isMinOnePassed = slot.passRule === 'minOnePassed'
            const isMinOnePairPassed = slot.passRule === 'minOnePairPassed'
            const threshold = slot.passThreshold ?? 0
            const pairThreshold = slot.pairAverageThreshold ?? 3.4
            // Coverage über den ganzen Slot (alle Skills × alle Kandidaten)
            const slotTotal = slot.skills.length * cands.length
            const slotDone = slot.skills.reduce((acc, sk) => {
              return acc + cands.filter((c) => {
                const r = lookup.get(`${c.student!.id}::${sk.code}`)
                return r && (r.status === 'completed' || r.pass === true)
              }).length
            }, 0)
            // minOnePassed: Slot ist "bestanden" sobald min. 1 Skill ≥ Threshold von einem Kandidaten existiert
            const minOnePassedAchieved = isMinOnePassed && slot.skills.some((sk) =>
              cands.some((c) => {
                const r = lookup.get(`${c.student!.id}::${sk.code}`)
                return r && r.score != null && Number(r.score) >= threshold
              })
            )
            // minOnePairPassed: Pärchen (Skills mit gleichem pairGroup) muss Schnitt ≥ pairThreshold haben
            // → Slot bestanden sobald MIN. 1 Pärchen für MIN. 1 Kandidat den Schnitt erreicht
            const pairGroups = Array.from(
              new Set(slot.skills.map((sk) => sk.pairGroup).filter((g): g is number => g != null))
            )
            const pairAverages: { group: number; avg: number | null; passed: boolean }[] = pairGroups.map((g) => {
              const skillsInPair = slot.skills.filter((sk) => sk.pairGroup === g)
              // Avg über höchsten Score je Skill (cross-Kandidat); für 1-Kandidat-IDC ist das einfach der Score
              const scores: number[] = []
              for (const sk of skillsInPair) {
                const skillScores = cands
                  .map((c) => lookup.get(`${c.student!.id}::${sk.code}`)?.score)
                  .filter((s): s is number => s != null)
                  .map((s) => Number(s))
                if (skillScores.length > 0) scores.push(Math.max(...skillScores))
              }
              if (scores.length < skillsInPair.length) return { group: g, avg: null, passed: false }
              const avg = scores.reduce((a, b) => a + b, 0) / scores.length
              return { group: g, avg, passed: avg >= pairThreshold }
            })
            const minOnePairAchieved = isMinOnePairPassed && pairAverages.some((p) => p.passed)
            // Slot-Hintergrund je nach Coverage einfärben
            // minOnePassed/minOnePairPassed-Slots werden ausschliesslich grün (wenn Pass-Rule erfüllt)
            // oder neutral — keine Gelb-Stufe bei Fail!
            const slotPassed = isMinOnePassed
              ? minOnePassedAchieved
              : isMinOnePairPassed
                ? minOnePairAchieved
                : (slotTotal > 0 && slotDone === slotTotal)
            const slotPartial = !isMinOnePassed && !isMinOnePairPassed && slotTotal > 0 && slotDone > 0 && slotDone < slotTotal
            const slotState = slotPassed ? 'passed' : slotPartial ? 'partial' : 'open'
            return (
            <div
              key={slot.code}
              className={`atoll-prtab__slot atoll-prtab__slot--${slotState}`}
            >
              <button
                type="button"
                onClick={() => {
                  if (!slotClickable) return
                  setOpenSkill({
                    code: firstSkill.code,
                    title: firstSkill.title,
                    scoreSchema: slot.scoreSchema as ScoreSchema,
                    passThreshold: slot.passThreshold,
                    showAssistantToggle: firstSkill.showAssistantToggle,
                  })
                }}
                disabled={!slotClickable}
                className="atoll-prtab__slot-head"
              >
                <div style={{ flex: 1 }}>
                  <div className="atoll-prtab__slot-title">
                    {slot.order}. {slot.title}
                  </div>
                  <div className="atoll-prtab__slot-meta">
                    {slot.code} · {slot.kind}
                    {slot.scoreSchema === 'score1to5' && slot.passThreshold ? ` · ${t('pr_tab.pass_threshold_5', { value: slot.passThreshold })}` : ''}
                    {slot.scoreSchema === 'score1to5_decimal' && slot.passThreshold ? ` · ${t('pr_tab.pass_threshold_5', { value: slot.passThreshold.toFixed(2) })}` : ''}
                    {slot.scoreSchema === 'percent' && slot.passThreshold ? ` · ${t('pr_tab.pass_threshold_pct', { value: slot.passThreshold })}` : ''}
                    {slot.scoreSchema === 'passFail' ? ` · ${t('pr_tab.pass_fail')}` : ''}
                    {slot.minRequired ? ` · ${t('pr_tab.min_required', { count: slot.minRequired })}` : ''}
                  </div>
                </div>
                {slotTotal > 0 && (
                  <Pill
                    tone={slotPassed ? 'success' : slotPartial ? 'warning' : 'neutral'}
                    size="sm"
                  >
                    {(isMinOnePassed || isMinOnePairPassed)
                      ? (slotPassed ? t('pr_tab.pass_check') : t('pr_tab.open'))
                      : `${slotDone}/${slotTotal}`}
                  </Pill>
                )}
                {slotClickable && (
                  <FdIcon.ChevronRight size={14} className="atoll-orgs__chevron" aria-hidden />
                )}
              </button>

              <div style={{ display: 'grid', gap: 4 }}>
                {slot.skills.map((sk) => {
                  // Aggregate über alle Kandidaten
                  const completeCount = cands.filter((c) => {
                    const r = lookup.get(`${c.student!.id}::${sk.code}`)
                    return r && (r.status === 'completed' || r.pass === true)
                  }).length
                  // Höchster erfasster Score über alle Kandidaten (für score-Schemas)
                  const scoresForSkill = cands
                    .map((c) => lookup.get(`${c.student!.id}::${sk.code}`)?.score)
                    .filter((s): s is number => s != null)
                  const bestScore = scoresForSkill.length > 0
                    ? Math.max(...scoresForSkill.map((s) => Number(s)))
                    : null
                  const isScoreSchema = slot.scoreSchema === 'score1to5' || slot.scoreSchema === 'score1to5_decimal' || slot.scoreSchema === 'percent'
                  const isPassed = bestScore != null && bestScore >= threshold
                  const clickable = cands.length > 0
                  // Score-Pill tone: passed=success, otherwise neutral for minOnePassed
                  // (no yellow/orange on fail), warning for standard schemas
                  const scoreTone = isPassed ? 'success' : isMinOnePassed ? 'neutral' : 'warning'
                  const completeTone =
                    completeCount === cands.length ? 'success' :
                    completeCount > 0 ? 'warning' : 'neutral'
                  return (
                    <button
                      key={sk.code}
                      type="button"
                      disabled={!clickable}
                      onClick={() =>
                        setOpenSkill({
                          code: sk.code,
                          title: sk.title,
                          scoreSchema: slot.scoreSchema as ScoreSchema,
                          passThreshold: slot.passThreshold,
                          showAssistantToggle: sk.showAssistantToggle,
                        })
                      }
                      className="atoll-prtab__skill"
                    >
                      <div className="atoll-prtab__skill-main">
                        <span className="atoll-prtab__skill-code">{sk.code}</span>
                        <span className="atoll-prtab__skill-title">{sk.title}</span>
                        {sk.repeatable && (
                          <span className="atoll-prtab__skill-tag">{t('pr_tab.repeatable')}</span>
                        )}
                      </div>
                      {cands.length > 0 && (
                        isScoreSchema && bestScore != null ? (
                          <Pill tone={scoreTone} size="sm">
                            {slot.scoreSchema === 'score1to5_decimal'
                              ? bestScore.toFixed(2)
                              : slot.scoreSchema === 'percent'
                                ? `${bestScore}%`
                                : bestScore.toString()}
                          </Pill>
                        ) : (
                          <Pill tone={completeTone} size="sm">
                            {completeCount}/{cands.length}
                          </Pill>
                        )
                      )}
                      {clickable && (
                        <FdIcon.ChevronRight size={12} className="atoll-orgs__chevron" aria-hidden />
                      )}
                    </button>
                  )
                })}

                {/* Pärchen-Schnitte (für minOnePairPassed-Slots) */}
                {isMinOnePairPassed && pairAverages.length > 0 && (
                  <div className="atoll-prtab__pairs">
                    {pairAverages.map((p) => (
                      <div
                        key={p.group}
                        className={`atoll-prtab__pair${p.passed ? ' atoll-prtab__pair--passed' : ''}`}
                      >
                        <span className="atoll-prtab__pair-label">{t('pr_tab.pair_label', { group: p.group })}</span>
                        <span className="atoll-prtab__pair-avg tabular-nums">
                          {t('pr_tab.average')}: {p.avg != null ? p.avg.toFixed(2) : '—'}
                          {' / '}{(slot.pairAverageThreshold ?? 3.4).toFixed(2)}
                        </span>
                        <span className="atoll-prtab__pair-status">
                          {p.passed ? t('pr_tab.pass_check') : p.avg != null ? t('pr_tab.below_average') : t('pr_tab.open')}
                        </span>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>
          )})}
      </div>

      <div className="atoll-prtab__tip">{t('pr_tab.tip_click')}</div>

      <PrCheckOffSheet
        open={!!openSkill}
        onClose={() => setOpenSkill(null)}
        onSaved={onSaved}
        courseId={courseId}
        skill={openSkill}
        participants={participants}
        defaultAssessor={assessorName}
        defaultDate={firstCourseDate}
      />
    </div>
  )
}
