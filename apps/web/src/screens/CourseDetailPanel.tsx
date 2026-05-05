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
  fetchCourseDates,
  POOL_LOCATIONS,
  COURSE_DATE_TYPES,
  type CourseDetail,
  type AssignmentRow,
  type CourseParticipant,
  type CourseDate,
} from '@/lib/queries'
import { initialsFromName } from '@/lib/format'
import { CourseEditSheet } from './CourseEditSheet'
import { AssignmentEditSheet } from './AssignmentEditSheet'
import { EnrollStudentSheet } from './EnrollStudentSheet'
import { StudentEditSheet } from './StudentEditSheet'
import { PrCheckOffSheet, type ScoreSchema } from './PrCheckOffSheet'
import { supabase } from '@/lib/supabase'
import type { OutletCtx } from '@/layout/AppShell'

type Tab = 'overview' | 'assignments' | 'participants' | 'notes' | 'prs'

const BASE_TABS: { value: Tab; label: string }[] = [
  { value: 'overview',     label: 'Übersicht' },
  { value: 'assignments',  label: 'TL/DM' },
  { value: 'participants', label: 'Teilnehmer' },
  { value: 'notes',        label: 'Notizen' },
]

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
}
interface PrSlot {
  code: string
  order: number
  title: string
  kind: string
  scoreSchema: string
  passThreshold?: number
  minRequired?: number
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
}

export function CourseDetailPanel({ courseId }: { courseId: string }) {
  const { user } = useOutletContext<OutletCtx>()
  const navigate = useNavigate()
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

  function refresh() {
    setRefreshTick((t) => t + 1)
  }

  useEffect(() => {
    fetchAllCourses().then((all) => setCourse(all.find((c) => c.id === courseId) ?? null))
    fetchCourseAssignments(courseId).then(setAssignments)
    fetchCourseParticipants(courseId).then(setParticipants)
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
      .select('id, student_id, pr_code, status, score, pass, assessed_on, assessed_by_text, notes')
      .eq('course_id', courseId)
      .then(({ data }) => setPrRecords((data ?? []) as PrRecord[]))
  }, [courseId, refreshTick, isCD, catalogKind])

  if (!course) return <div style={{ padding: 40 }} className="caption">Lade…</div>

  // PR-Tab nur wenn CD + CD-Kurs + Catalog vorhanden
  const visibleTabs: { value: Tab; label: string }[] = isCD && isCdCourse
    ? [...BASE_TABS, { value: 'prs', label: 'PRs' }]
    : BASE_TABS

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
        {visibleTabs.map((t) => (
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
          <Field label="Teilnehmer" value={String(course.num_participants)} />

          <div>
            <div className="caption-2">KURSDATEN ({courseDates.length || 1})</div>
            <div style={{ display: 'grid', gap: 6, marginTop: 6 }}>
              {(courseDates.length > 0
                ? courseDates
                : [{ id: 'fallback', date: course.start_date, type: 'theorie' as const, pool_location: null }] as any
              ).map((cd: any) => {
                const typeMeta = COURSE_DATE_TYPES.find((t) => t.value === cd.type)
                const poolMeta = POOL_LOCATIONS.find((p) => p.value === cd.pool_location)
                return (
                  <div
                    key={cd.id}
                    style={{
                      display: 'flex',
                      gap: 12,
                      padding: '8px 10px',
                      background: 'rgba(120,120,128,.08)',
                      borderRadius: 8,
                      alignItems: 'center',
                    }}
                  >
                    <span className="mono" style={{ fontSize: 13, fontWeight: 500, minWidth: 110 }}>
                      {format(new Date(cd.date), 'EEE, d. MMM', { locale: de })}
                    </span>
                    <Chip tone={
                      cd.type === 'pool' ? 'accent' :
                      cd.type === 'see'  ? 'green'  : 'neutral'
                    }>
                      {typeMeta?.emoji} {typeMeta?.label ?? cd.type}
                    </Chip>
                    {cd.type === 'pool' && cd.pool_location && (
                      <Chip tone="purple">🏊 {poolMeta?.label ?? cd.pool_location}</Chip>
                    )}
                  </div>
                )
              })}
            </div>
          </div>
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
        showCdFields={user.role === 'cd'}
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
  const [openSkill, setOpenSkill] = useState<{
    code: string
    title: string
    scoreSchema: ScoreSchema
    passThreshold?: number
    showAssistantToggle?: boolean
  } | null>(null)

  if (!catalog) {
    return (
      <div className="caption" style={{ padding: 20 }}>
        Lade PR-Katalog…
      </div>
    )
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
    <div style={{ display: 'grid', gap: 18 }}>
      {/* Header mit Catalog-Info */}
      <div className="glass-thin" style={{ padding: 14, borderRadius: 12, display: 'flex', gap: 12, alignItems: 'center' }}>
        <div style={{ flex: 1 }}>
          <div style={{ fontWeight: 700 }}>{catalog.data.title}</div>
          <div className="caption">
            {catalog.course_type} · v{catalog.version} · {catalog.data.slots.length} Slots, {totalSkills} Skills
          </div>
          {catalog.course_type === 'DM' && (
            <div className="caption-2" style={{ marginTop: 6, opacity: 0.75 }}>
              Hinweis: DM ist kein klassischer CD-Kurs — wird hier geführt um Kandidat:innen für den IDC anzuwerben.
            </div>
          )}
        </div>
      </div>

      {/* Pre-Reqs */}
      {(catalog.data.prerequisites?.requiredCerts?.length || catalog.data.prerequisites?.requiredELearning) && (
        <div className="glass-thin" style={{ padding: 14, borderRadius: 12 }}>
          <div className="caption-2" style={{ marginBottom: 6, opacity: 0.7 }}>VORAUSSETZUNGEN</div>
          <div style={{ display: 'grid', gap: 4, fontSize: 13 }}>
            {catalog.data.prerequisites?.minAge && (
              <div>· Mindestalter {catalog.data.prerequisites.minAge}</div>
            )}
            {catalog.data.prerequisites?.requiredCerts?.map((c) => (
              <div key={c.kind}>
                · {c.kind}
                {c.maxMonthsAgo ? ` (max. ${c.maxMonthsAgo} Mt. alt)` : ''}
                {c.minMonthsAgo ? ` (min. ${c.minMonthsAgo} Mt. her)` : ''}
                {c.note ? ` — ${c.note}` : ''}
              </div>
            ))}
            {catalog.data.prerequisites?.requiredELearning && (
              <div>
                · {catalog.data.prerequisites.requiredELearning.kind} eLearning
                {catalog.data.prerequisites.requiredELearning.minProgressPercent !== undefined &&
                  ` (${catalog.data.prerequisites.requiredELearning.minProgressPercent}%)`}
                {catalog.data.prerequisites.requiredELearning.examRequired && ' · Exam'}
              </div>
            )}
          </div>
        </div>
      )}

      {/* Kandidaten-Coverage */}
      {cands.length > 0 && (
        <div>
          <div className="title-3" style={{ marginBottom: 8 }}>Kandidaten · {cands.length}</div>
          <div style={{ display: 'grid', gap: 6 }}>
            {cands.map((c) => {
              const cov = coverageByStudent.get(c.student!.id) ?? { done: 0, inProg: 0, rem: 0 }
              const pct = totalSkills > 0 ? Math.round((cov.done / totalSkills) * 100) : 0
              return (
                <div key={c.id} className="glass-thin" style={{ padding: 12, borderRadius: 12, display: 'flex', alignItems: 'center', gap: 10 }}>
                  <div className="avatar avatar-sm" style={{ background: 'linear-gradient(135deg,#34c759,#00c2a8)' }}>
                    {c.student?.name.split(' ').map((s) => s[0]).join('').slice(0, 2).toUpperCase()}
                  </div>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontWeight: 500 }}>{c.student?.name}</div>
                    <div className="caption-2">{cov.done}/{totalSkills} abgenommen ({pct}%) · {cov.inProg} laufend · {cov.rem} Remediation</div>
                  </div>
                  <div style={{ width: 100, height: 6, borderRadius: 3, background: 'rgba(255,255,255,.10)', overflow: 'hidden' }}>
                    <div style={{ width: `${pct}%`, height: '100%', background: pct >= 80 ? '#34C759' : pct >= 40 ? '#FFCC00' : '#FF9500' }} />
                  </div>
                </div>
              )
            })}
          </div>
        </div>
      )}

      {/* Catalog: Slots + Skills mit Status-Pillen */}
      <div style={{ display: 'grid', gap: 14 }}>
        {catalog.data.slots
          .slice()
          .sort((a, b) => a.order - b.order)
          .map((slot) => {
            const slotClickable = cands.length > 0 && slot.skills.length > 0
            const firstSkill = slot.skills[0]
            // Coverage über den ganzen Slot (alle Skills × alle Kandidaten)
            const slotTotal = slot.skills.length * cands.length
            const slotDone = slot.skills.reduce((acc, sk) => {
              return acc + cands.filter((c) => {
                const r = lookup.get(`${c.student!.id}::${sk.code}`)
                return r && (r.status === 'completed' || r.pass === true)
              }).length
            }, 0)
            // Slot-Hintergrund je nach Coverage einfärben
            const slotBg =
              slotTotal === 0          ? undefined
              : slotDone === slotTotal ? 'linear-gradient(180deg, rgba(52,199,89,.18), rgba(52,199,89,.06))'
              : slotDone > 0           ? 'linear-gradient(180deg, rgba(255,204,0,.16), rgba(255,204,0,.04))'
              :                          undefined
            const slotBorder =
              slotTotal > 0 && slotDone === slotTotal ? '0.5px solid rgba(52,199,89,.45)'
              : slotTotal > 0 && slotDone > 0          ? '0.5px solid rgba(255,204,0,.40)'
              :                                          undefined
            return (
            <div
              key={slot.code}
              className="glass-thin"
              style={{
                padding: 14,
                borderRadius: 12,
                background: slotBg,
                border: slotBorder,
              }}
            >
              <button
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
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 12,
                  width: '100%',
                  padding: 0,
                  marginBottom: 10,
                  border: 'none',
                  background: 'transparent',
                  textAlign: 'left',
                  cursor: slotClickable ? 'pointer' : 'default',
                  color: 'var(--ink)',
                  font: 'inherit',
                }}
              >
                <div style={{ flex: 1 }}>
                  <div style={{ fontWeight: 700 }}>
                    {slot.order}. {slot.title}
                  </div>
                  <div className="caption-2">
                    {slot.code} · {slot.kind}
                    {slot.scoreSchema === 'score1to5' && slot.passThreshold ? ` · Pass ≥ ${slot.passThreshold}/5` : ''}
                    {slot.scoreSchema === 'score1to5_decimal' && slot.passThreshold ? ` · Pass ≥ ${slot.passThreshold.toFixed(2)}/5` : ''}
                    {slot.scoreSchema === 'percent' && slot.passThreshold ? ` · Pass ≥ ${slot.passThreshold}%` : ''}
                    {slot.scoreSchema === 'passFail' ? ' · Pass/Fail' : ''}
                    {slot.minRequired ? ` · min. ${slot.minRequired}` : ''}
                  </div>
                </div>
                {slotTotal > 0 && (
                  <div
                    className="caption-2"
                    style={{
                      padding: '4px 10px',
                      borderRadius: 999,
                      background: slotDone === slotTotal
                        ? 'rgba(52,199,89,.20)'
                        : slotDone > 0
                          ? 'rgba(255,204,0,.18)'
                          : 'rgba(255,255,255,.06)',
                      fontWeight: 600,
                    }}
                  >
                    {slotDone}/{slotTotal}
                  </div>
                )}
                {slotClickable && (
                  <span className="caption-2" style={{ opacity: 0.4 }}>›</span>
                )}
              </button>

              <div style={{ display: 'grid', gap: 4 }}>
                {slot.skills.map((sk) => {
                  // Aggregate über alle Kandidaten
                  const completeCount = cands.filter((c) => {
                    const r = lookup.get(`${c.student!.id}::${sk.code}`)
                    return r && (r.status === 'completed' || r.pass === true)
                  }).length
                  const clickable = cands.length > 0
                  return (
                    <button
                      key={sk.code}
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
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        gap: 8,
                        padding: '6px 10px',
                        borderRadius: 8,
                        fontSize: 13,
                        background: 'rgba(255,255,255,.04)',
                        border: 'none',
                        textAlign: 'left',
                        cursor: clickable ? 'pointer' : 'default',
                        color: 'var(--ink)',
                        font: 'inherit',
                        width: '100%',
                      }}
                    >
                      <div style={{ flex: 1 }}>
                        <span className="mono" style={{ opacity: 0.5, marginRight: 8, fontSize: 11 }}>{sk.code}</span>
                        {sk.title}
                        {sk.repeatable && (
                          <span className="caption-2" style={{ marginLeft: 8, opacity: 0.6 }}>(repeatable)</span>
                        )}
                      </div>
                      {cands.length > 0 && (
                        <div
                          className="caption-2"
                          style={{
                            padding: '2px 8px',
                            borderRadius: 999,
                            background: completeCount === cands.length
                              ? 'rgba(52,199,89,.20)'
                              : completeCount > 0
                                ? 'rgba(255,204,0,.18)'
                                : 'rgba(255,255,255,.06)',
                          }}
                        >
                          {completeCount}/{cands.length}
                        </div>
                      )}
                      {clickable && (
                        <span className="caption-2" style={{ opacity: 0.4 }}>›</span>
                      )}
                    </button>
                  )
                })}
              </div>
            </div>
          )})}
      </div>

      <div className="caption-2" style={{ opacity: 0.5, padding: '8px 0' }}>
        Tipp: Klick auf einen Skill zum Live Check-Off — Status, Score, Pass/Fail, Datum + Notiz pro Kandidat:in.
      </div>

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
