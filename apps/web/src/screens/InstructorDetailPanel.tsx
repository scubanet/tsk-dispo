/**
 * InstructorDetailPanel — Foundation-based rewrite.
 *
 * Layout:
 *   Header: Avatar (padiLevelColor) + Name + meta line + WhatsApp + Edit
 *   Tabs: Übersicht | Skills | Einsätze | Zertifikate | Saldo
 *   Tab panels:
 *     overview     — Field list + BrevetsView (cert-first)
 *     skills       — Pill grid
 *     assignments  — list of past/upcoming assignments (clickable)
 *     certs        — issued-cert stats from v_instructor_certifications_by_level
 *     saldo        — total + correction button + movements list
 */

import { useEffect, useMemo, useState } from 'react'
import { useNavigate, useOutletContext } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import {
  Avatar,
  Tabs,
  Pill,
  EmptyState,
  Icon,
  BrevetsView,
  padiLevelColor,
  chf,
  dateMedium,
} from '@/foundation'
import { WhatsAppButton } from '@/components/WhatsAppButton'
import { supabase } from '@/lib/supabase'
import { waDirectUrl, tplDirect } from '@/lib/whatsapp'
import type { OutletCtx } from '@/layout/AppShell'
import { InstructorEditSheet } from './InstructorEditSheet'
import { CorrectionSheet } from './CorrectionSheet'
import { fetchCertifications } from '@/lib/queries'
import type { Certification } from '@/types/foundation'

type Tab = 'overview' | 'skills' | 'assignments' | 'certs' | 'saldo'

interface CertStat {
  level_code: string
  level_label: string
  count: number
  most_recent: string | null
}

interface Skill { code: string; label: string; category: string | null }

interface AssignmentRow {
  id: string
  role: string
  courses: { id: string; title: string; start_date: string; status: string } | null
}

interface Movement {
  id: string
  date: string
  amount_chf: number | string
  kind: string
  description: string | null
  ref_assignment_id: string | null
  course_assignments?: { courses?: { status: string } | null } | null
}

interface Instructor {
  id: string
  name: string
  initials: string
  color: string
  padi_level: string
  padi_nr: string | null
  email: string | null
  phone: string | null
  opening_balance_chf: number
  excel_saldo_chf: number
}

export function InstructorDetailPanel({ instructorId }: { instructorId: string }) {
  const { t } = useTranslation()
  const { user } = useOutletContext<OutletCtx>()
  const navigate = useNavigate()
  const [inst, setInst] = useState<Instructor | null>(null)
  const [tab, setTab] = useState<Tab>('overview')
  const [skills, setSkills] = useState<Skill[]>([])
  const [assignments, setAssignments] = useState<AssignmentRow[]>([])
  const [movements, setMovements] = useState<Movement[]>([])
  const [certStats, setCertStats] = useState<CertStat[]>([])
  const [brevets, setBrevets] = useState<Certification[]>([])
  const [editOpen, setEditOpen] = useState(false)
  const [correctionOpen, setCorrectionOpen] = useState(false)
  const [editMovementId, setEditMovementId] = useState<string | null>(null)
  const [refreshTick, setRefreshTick] = useState(0)

  const isStaff =
    user.role === 'dispatcher' || user.role === 'cd' || user.role === 'owner'

  useEffect(() => {
    supabase
      .from('instructors')
      .select('id, name, initials, color, padi_level, padi_nr, email, phone, opening_balance_chf, excel_saldo_chf')
      .eq('id', instructorId)
      .single()
      .then(({ data }) => setInst(data as Instructor | null))

    supabase
      .from('instructor_skills')
      .select('skills(code, label, category)')
      .eq('instructor_id', instructorId)
      .then(({ data }) =>
        setSkills(
          ((data ?? []) as unknown as Array<{ skills: Skill | Skill[] | null }>)
            .flatMap((d) => (Array.isArray(d.skills) ? d.skills : d.skills ? [d.skills] : []))
            .filter((s): s is Skill => !!s),
        ),
      )

    supabase
      .from('course_assignments')
      .select('id, role, courses(id, title, start_date, status)')
      .eq('instructor_id', instructorId)
      .then(({ data }) => {
        const list = ((data ?? []) as unknown as AssignmentRow[]).slice().sort((a, b) =>
          (b.courses?.start_date ?? '').localeCompare(a.courses?.start_date ?? ''),
        )
        setAssignments(list)
      })

    supabase
      .from('account_movements')
      .select(`
        id, date, amount_chf, kind, description, breakdown_json, ref_assignment_id,
        course_assignments:ref_assignment_id (
          courses ( status )
        )
      `)
      .eq('instructor_id', instructorId)
      .order('date', { ascending: false })
      .then(({ data }) => {
        const visible = ((data ?? []) as unknown as Movement[]).filter((m) => {
          // Vergütungen müssen IMMER eine ref_assignment_id haben — orphane
          // (NULL) sind ein Datenkonsistenz-Bug und werden ausgeblendet.
          if (m.kind === 'vergütung') {
            return m.ref_assignment_id != null
              && m.course_assignments?.courses?.status === 'completed'
          }
          // übertrag/korrektur sind immer manuell → immer anzeigen.
          if (!m.ref_assignment_id) return true
          return m.course_assignments?.courses?.status === 'completed'
        })
        setMovements(visible)
      })

    supabase
      .from('v_instructor_certifications_by_level')
      .select('level_code, level_label, count, most_recent')
      .eq('instructor_id', instructorId)
      .order('count', { ascending: false })
      .then(({ data }) => setCertStats((data ?? []) as CertStat[]))

    fetchCertifications(instructorId).then(setBrevets)
  }, [instructorId, refreshTick])

  const balance = useMemo(
    () => movements.reduce((sum, m) => sum + Number(m.amount_chf), 0),
    [movements],
  )

  if (!inst) {
    return (
      <div className="atoll-cockpit__loading">{t('common.loading')}</div>
    )
  }

  const tabs = [
    { id: 'overview' as const, label: t('instructor_detail.tab_overview') },
    { id: 'skills' as const, label: t('instructor_detail.tab_skills'), count: skills.length },
    { id: 'assignments' as const, label: t('instructor_detail.tab_assignments'), count: assignments.length },
    { id: 'certs' as const, label: t('instructor_detail.tab_certs') },
    { id: 'saldo' as const, label: t('instructor_detail.tab_saldo') },
  ]

  const totalCerts = certStats.reduce((s, c) => s + c.count, 0)

  return (
    <div className="atoll-detail">
      {/* Header */}
      <header className="atoll-detail__head">
        <Avatar
          id={instructorId}
          name={inst.name}
          size="lg"
          color={padiLevelColor(inst.padi_level)}
        />
        <div className="atoll-detail__head-main">
          <div className="atoll-detail__name">{inst.name}</div>
          <div className="atoll-detail__head-meta">
            <Pill tone="pro" size="sm">{inst.padi_level}</Pill>
            {inst.padi_nr && (
              <span className="atoll-myprofile__padi-nr">PADI {inst.padi_nr}</span>
            )}
            {inst.email && <span className="atoll-detail__contact">{inst.email}</span>}
          </div>
        </div>
        {isStaff && inst.phone && (
          <WhatsAppButton
            url={waDirectUrl(inst.phone, tplDirect({ to_name: inst.name.split(' ')[0], message: '' }))}
            label={t('instructor_detail.message')}
          />
        )}
        {isStaff && (
          <button type="button" className="atoll-btn" onClick={() => setEditOpen(true)}>
            <Icon.Settings size={14} /> {t('common.edit')}
          </button>
        )}
      </header>

      <Tabs<Tab>
        tabs={tabs}
        active={tab}
        onChange={setTab}
        ariaLabel={inst.name}
        panels={{
          overview: (
            <div className="atoll-detail__overview">
              <div className="atoll-detail__fields">
                <Field label={t('instructor_edit.label_padi_level')} value={inst.padi_level} />
                <Field label={t('instructor_edit.label_padi_nr', 'PADI-Nummer')} value={inst.padi_nr || '—'} />
                <Field label={t('student_edit.label_email')} value={inst.email || '—'} />
                <Field label={t('instructor_detail.opening_2026')} value={chf(inst.opening_balance_chf)} />
                <Field label={t('instructor_detail.excel_saldo')} value={chf(inst.excel_saldo_chf)} />
                <Field label={t('instructor_detail.current_app_balance')} value={chf(balance)} />
                <Field label={t('instructor_detail.skill_count')} value={String(skills.length)} />
                <Field
                  label={t('instructor_detail.assignments_year', { year: new Date().getFullYear() })}
                  value={String(assignments.length)}
                />
              </div>

              {brevets.length > 0 && <BrevetsView certifications={brevets} />}
            </div>
          ),
          skills: skills.length === 0 ? (
            <EmptyState
              icon={<Icon.Brevet size={20} />}
              title={t('instructor_detail.no_skills')}
            />
          ) : (
            <div className="atoll-myprofile__skills">
              {skills.map((s) => (
                <Pill key={s.code} tone="brand" size="sm">{s.label}</Pill>
              ))}
            </div>
          ),
          assignments: assignments.length === 0 ? (
            <EmptyState
              icon={<Icon.Calendar size={20} />}
              title={t('instructor_detail.no_assignments')}
            />
          ) : (
            <div className="atoll-detail__list">
              {assignments.map((a) => {
                const c = a.courses
                if (!c) return null
                return (
                  <button
                    key={a.id}
                    type="button"
                    className="atoll-detail__row"
                    onClick={() => navigate(`/kurse/${c.id}`)}
                  >
                    <div className="atoll-detail__row-main">
                      <div className="atoll-detail__row-title">{c.title}</div>
                      <div className="atoll-detail__row-meta tabular-nums">
                        {dateMedium(c.start_date)}
                      </div>
                    </div>
                    <div className="atoll-detail__row-pills">
                      <Pill tone="brand" size="sm">{a.role}</Pill>
                      <Pill
                        tone={
                          c.status === 'confirmed' ? 'success' :
                          c.status === 'tentative' ? 'warning' :
                          c.status === 'completed' ? 'pro' : 'danger'
                        }
                        size="sm"
                      >
                        {c.status}
                      </Pill>
                    </div>
                    <Icon.ChevronRight size={16} className="atoll-orgs__chevron" aria-hidden />
                  </button>
                )
              })}
            </div>
          ),
          certs: (
            <div>
              <div className="atoll-detail__certs-head">
                <div className="atoll-cockpit__card-title">{t('instructor_detail.certs_title')}</div>
                <div className="atoll-cockpit__card-sub" style={{ margin: 0 }}>
                  {t('student_detail.total_count', { count: totalCerts })}
                </div>
              </div>
              {certStats.length === 0 ? (
                <EmptyState
                  icon={<Icon.Brevet size={20} />}
                  title={t('instructor_detail.certs_empty_hint')}
                />
              ) : (
                <div className="atoll-detail__list">
                  {certStats.map((c) => (
                    <div key={c.level_code} className="atoll-detail__cert-row">
                      <Pill tone="brand" size="sm">{c.level_code}</Pill>
                      <div className="atoll-detail__row-main">
                        <div className="atoll-detail__row-title">{c.level_label}</div>
                        {c.most_recent && (
                          <div className="atoll-detail__row-meta tabular-nums">
                            {t('instructor_detail.last_cert', {
                              date: dateMedium(c.most_recent),
                            })}
                          </div>
                        )}
                      </div>
                      <span className="atoll-detail__cert-count tabular-nums">{c.count}</span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          ),
          saldo: (
            <div className="atoll-detail__saldo">
              <div className="atoll-detail__saldo-head">
                <div
                  className={`atoll-detail__saldo-total tabular-nums${balance < 0 ? ' atoll-detail__saldo-total--neg' : ''}`}
                >
                  {chf(balance)}
                </div>
                {isStaff && (
                  <button
                    type="button"
                    className="atoll-btn"
                    onClick={() => setCorrectionOpen(true)}
                  >
                    <Icon.Plus size={14} /> {t('instructor_detail.book_correction')}
                  </button>
                )}
              </div>
              <div className="atoll-cockpit__card-sub" style={{ margin: 0 }}>
                {t('instructor_detail.balance_summary', { count: movements.length })}
              </div>
              <div className="atoll-detail__list">
                {movements.map((m) => {
                  const editable = isStaff && (m.kind === 'korrektur' || m.kind === 'übertrag')
                  const negative = Number(m.amount_chf) < 0
                  return (
                    <button
                      key={m.id}
                      type="button"
                      className="atoll-detail__row"
                      onClick={() => {
                        if (!editable) return
                        setEditMovementId(m.id)
                        setCorrectionOpen(true)
                      }}
                      disabled={!editable}
                      title={
                        editable
                          ? t('common.click_to_edit')
                          : m.kind === 'vergütung'
                          ? t('instructor_detail.movement_readonly_tooltip')
                          : ''
                      }
                    >
                      <div className="atoll-detail__row-main">
                        <div className="atoll-detail__row-title">
                          {m.description || m.kind}
                        </div>
                        <div className="atoll-detail__row-meta tabular-nums">
                          {dateMedium(m.date)} · {m.kind}
                        </div>
                      </div>
                      <span
                        className={`atoll-detail__row-amount tabular-nums${negative ? ' atoll-detail__row-amount--neg' : ''}`}
                      >
                        {chf(Number(m.amount_chf))}
                      </span>
                      {editable && <Icon.Settings size={14} aria-hidden />}
                    </button>
                  )
                })}
              </div>
            </div>
          ),
        }}
      />

      <InstructorEditSheet
        instructorId={instructorId}
        open={editOpen}
        onClose={() => setEditOpen(false)}
        onSaved={() => setRefreshTick((tick) => tick + 1)}
        currentUserAuthId={user.authUserId}
      />

      <CorrectionSheet
        open={correctionOpen}
        onClose={() => {
          setCorrectionOpen(false)
          setEditMovementId(null)
        }}
        onSaved={() => setRefreshTick((tick) => tick + 1)}
        defaultInstructorId={instructorId}
        movementId={editMovementId}
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
