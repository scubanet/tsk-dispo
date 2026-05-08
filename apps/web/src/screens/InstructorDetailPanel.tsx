import { useEffect, useState } from 'react'
import { useNavigate, useOutletContext } from 'react-router-dom'
import clsx from 'clsx'
import { format } from 'date-fns'
import { de, enGB } from 'date-fns/locale'
import { useTranslation } from 'react-i18next'
import { Avatar, padiLevelColor } from '@/foundation'
import { Chip } from '@/components/Chip'
import { Icon } from '@/components/Icon'
import { WhatsAppButton } from '@/components/WhatsAppButton'
import { supabase } from '@/lib/supabase'
import { chf } from '@/lib/format'
import { waDirectUrl, tplDirect } from '@/lib/whatsapp'
import type { OutletCtx } from '@/layout/AppShell'
import { InstructorEditSheet } from './InstructorEditSheet'
import { CorrectionSheet } from './CorrectionSheet'
import { BrevetsView } from '@/foundation'
import { fetchCertifications } from '@/lib/queries'
import type { Certification } from '@/types/foundation'

type Tab = 'overview' | 'skills' | 'assignments' | 'saldo' | 'certs'

interface CertStat {
  level_code: string
  level_label: string
  count: number
  most_recent: string | null
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
  const { t, i18n } = useTranslation()
  const dfLocale = i18n.resolvedLanguage === 'en' ? enGB : de
  const TABS: { value: Tab; label: string }[] = [
    { value: 'overview',    label: t('instructor_detail.tab_overview') },
    { value: 'skills',      label: t('instructor_detail.tab_skills') },
    { value: 'assignments', label: t('instructor_detail.tab_assignments') },
    { value: 'certs',       label: t('instructor_detail.tab_certs') },
    { value: 'saldo',       label: t('instructor_detail.tab_saldo') },
  ]
  const { user } = useOutletContext<OutletCtx>()
  const navigate = useNavigate()
  const [inst, setInst] = useState<Instructor | null>(null)
  const [tab, setTab] = useState<Tab>('overview')
  const [skills, setSkills] = useState<any[]>([])
  const [assignments, setAssignments] = useState<any[]>([])
  const [movements, setMovements] = useState<any[]>([])
  const [certStats, setCertStats] = useState<CertStat[]>([])
  const [brevets, setBrevets] = useState<Certification[]>([])
  const [editOpen, setEditOpen] = useState(false)
  const [correctionOpen, setCorrectionOpen] = useState(false)
  const [editMovementId, setEditMovementId] = useState<string | null>(null)
  const [refreshTick, setRefreshTick] = useState(0)

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
      .then(({ data }) => setSkills((data ?? []).map((d: any) => d.skills).filter(Boolean)))

    supabase
      .from('course_assignments')
      .select('id, role, courses(id, title, start_date, status)')
      .eq('instructor_id', instructorId)
      .then(({ data }) => {
        const sorted = (data ?? []).sort((a: any, b: any) =>
          (b.courses?.start_date ?? '').localeCompare(a.courses?.start_date ?? ''),
        )
        setAssignments(sorted)
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
        // Vergütungen nur anzeigen, wenn Kurs auf 'completed'.
        // Übertrag/Korrektur (ohne ref_assignment_id) immer.
        const visible = (data ?? []).filter((m: any) => {
          if (!m.ref_assignment_id) return true
          return m.course_assignments?.courses?.status === 'completed'
        })
        setMovements(visible)
      })

    // Zertifikat-Statistik (aus v_instructor_certifications_by_level View)
    supabase
      .from('v_instructor_certifications_by_level')
      .select('level_code, level_label, count, most_recent')
      .eq('instructor_id', instructorId)
      .order('count', { ascending: false })
      .then(({ data }) => setCertStats((data ?? []) as CertStat[]))

    // Cert-first: load brevets from `certifications` table for BrevetsView.
    fetchCertifications(instructorId).then(setBrevets)
  }, [instructorId, refreshTick])

  if (!inst) return <div style={{ padding: 40 }} className="caption">{t('common.loading')}</div>

  const balance = movements.reduce((sum, m) => sum + Number(m.amount_chf), 0)

  return (
    <div className="screen-fade" style={{ padding: '20px 24px 40px' }}>
      <div style={{ display: 'flex', gap: 16, alignItems: 'center', marginBottom: 20 }}>
        <Avatar
          id={instructorId}
          name={inst.name}
          size="lg"
          color={padiLevelColor(inst.padi_level)}
        />
        <div style={{ flex: 1 }}>
          <div className="title-1">{inst.name}</div>
          <div className="caption">
            {[inst.padi_level, inst.padi_nr ? `PADI ${inst.padi_nr}` : null, inst.email]
              .filter(Boolean)
              .join(' · ') || '—'}
          </div>
        </div>
        {(user.role === 'dispatcher' || user.role === 'cd') && inst.phone && (
          <WhatsAppButton
            url={waDirectUrl(inst.phone, tplDirect({ to_name: inst.name.split(' ')[0], message: '' }))}
            label={t('instructor_detail.message')}
          />
        )}
        {(user.role === 'dispatcher' || user.role === 'cd') && (
          <button className="btn-secondary btn" onClick={() => setEditOpen(true)}>
            <Icon name="settings" size={14} /> {t('common.edit')}
          </button>
        )}
      </div>

      <InstructorEditSheet
        instructorId={instructorId}
        open={editOpen}
        onClose={() => setEditOpen(false)}
        onSaved={() => setRefreshTick((t) => t + 1)}
        currentUserAuthId={user.authUserId}
      />

      <CorrectionSheet
        open={correctionOpen}
        onClose={() => {
          setCorrectionOpen(false)
          setEditMovementId(null)
        }}
        onSaved={() => setRefreshTick((t) => t + 1)}
        defaultInstructorId={instructorId}
        movementId={editMovementId}
      />

      <div className="seg" style={{ marginBottom: 20 }}>
        {TABS.map((tabDef) => (
          <button
            key={tabDef.value}
            className={clsx(tab === tabDef.value && 'active')}
            onClick={() => setTab(tabDef.value)}
          >
            {tabDef.label}
          </button>
        ))}
      </div>

      {tab === 'overview' && (
        <div style={{ display: 'grid', gap: 24 }}>
          <div style={{ display: 'grid', gap: 12 }}>
            <Field label={t('instructor_edit.label_padi_level')} value={inst.padi_level} />
            <Field label={t('instructor_edit.label_padi_nr', 'PADI-Nummer')} value={inst.padi_nr || '—'} />
            <Field label={t('student_edit.label_email')} value={inst.email || '—'} />
            <Field label={t('instructor_detail.opening_2026')} value={chf(inst.opening_balance_chf)} />
            <Field label={t('instructor_detail.excel_saldo')} value={chf(inst.excel_saldo_chf)} />
            <Field label={t('instructor_detail.current_app_balance')} value={chf(balance)} />
            <Field label={t('instructor_detail.skill_count')} value={String(skills.length)} />
            <Field label={t('instructor_detail.assignments_year', { year: 2026 })} value={String(assignments.length)} />
          </div>

          {/* Cert-first brevet display (Foundation) */}
          {brevets.length > 0 && <BrevetsView certifications={brevets} />}
        </div>
      )}

      {tab === 'skills' && (
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
          {skills.length === 0 ? (
            <div className="caption">{t('instructor_detail.no_skills')}</div>
          ) : (
            skills.map((s) => <Chip key={s.code} tone="accent">{s.label}</Chip>)
          )}
        </div>
      )}

      {tab === 'assignments' && (
        <div style={{ display: 'grid', gap: 8 }}>
          {assignments.length === 0 ? (
            <div className="caption">{t('instructor_detail.no_assignments')}</div>
          ) : (
            assignments.map((a) => {
              const courseId = a.courses?.id
              const clickable = !!courseId
              return (
                <div
                  key={a.id}
                  className="glass-thin"
                  role={clickable ? 'button' : undefined}
                  tabIndex={clickable ? 0 : undefined}
                  onClick={() => clickable && navigate(`/kurse/${courseId}`)}
                  onKeyDown={(e) => {
                    if (clickable && (e.key === 'Enter' || e.key === ' ')) {
                      e.preventDefault()
                      navigate(`/kurse/${courseId}`)
                    }
                  }}
                  style={{
                    padding: 12,
                    borderRadius: 12,
                    cursor: clickable ? 'pointer' : 'default',
                    transition: 'transform 0.08s ease',
                  }}
                  onMouseEnter={(e) => clickable && (e.currentTarget.style.transform = 'translateY(-1px)')}
                  onMouseLeave={(e) => clickable && (e.currentTarget.style.transform = 'translateY(0)')}
                  title={clickable ? t('instructor_detail.open_course') : undefined}
                >
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <span style={{ fontWeight: 500 }}>{a.courses?.title ?? '—'}</span>
                    <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
                      <Chip tone="accent">{a.role}</Chip>
                      {clickable && (
                        <Icon name="chevron-right" size={14} className="caption" />
                      )}
                    </div>
                  </div>
                  <div className="caption" style={{ marginTop: 4, display: 'flex', gap: 8, alignItems: 'center' }}>
                    {a.courses?.start_date && format(new Date(a.courses.start_date), 'd. MMM yyyy', { locale: dfLocale })}
                    <Chip tone={a.courses?.status === 'confirmed' ? 'green' : a.courses?.status === 'tentative' ? 'orange' : 'red'}>
                      {a.courses?.status}
                    </Chip>
                  </div>
                </div>
              )
            })
          )}
        </div>
      )}

      {tab === 'certs' && (
        <div>
          <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 12 }}>
            <div className="title-2">{t('instructor_detail.certs_title')}</div>
            <div className="caption">
              {t('student_detail.total_count', { count: certStats.reduce((s, c) => s + c.count, 0) })}
            </div>
          </div>
          {certStats.length === 0 ? (
            <div className="caption">
              {t('instructor_detail.certs_empty_hint')}
            </div>
          ) : (
            <div style={{ display: 'grid', gap: 8 }}>
              {certStats.map((c) => (
                <div
                  key={c.level_code}
                  className="glass-thin"
                  style={{ padding: 12, borderRadius: 12, display: 'flex', alignItems: 'center', gap: 12 }}
                >
                  <Chip tone="accent">{c.level_code}</Chip>
                  <div style={{ flex: 1 }}>
                    <div style={{ fontWeight: 500 }}>{c.level_label}</div>
                    {c.most_recent && (
                      <div className="caption-2">
                        {t('instructor_detail.last_cert', { date: format(new Date(c.most_recent), 'd. MMM yyyy', { locale: dfLocale }) })}
                      </div>
                    )}
                  </div>
                  <div className="title-2 mono" style={{ fontWeight: 700 }}>{c.count}</div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {tab === 'saldo' && (
        <>
          <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', marginBottom: 12 }}>
            <div
              className="title-1 mono"
              style={{ color: balance < 0 ? '#FF3B30' : 'var(--ink)' }}
            >
              {chf(balance)}
            </div>
            {(user.role === 'dispatcher' || user.role === 'cd') && (
              <button className="btn-secondary btn" onClick={() => setCorrectionOpen(true)}>
                <Icon name="plus" size={14} /> {t('instructor_detail.book_correction')}
              </button>
            )}
          </div>
          <div className="caption" style={{ marginBottom: 12 }}>
            {t('instructor_detail.balance_summary', { count: movements.length })}
          </div>
          <div style={{ display: 'grid', gap: 6 }}>
            {movements.map((m) => {
              const editable = (user.role === 'dispatcher' || user.role === 'cd') && (m.kind === 'korrektur' || m.kind === 'übertrag')
              return (
                <div
                  key={m.id}
                  className="glass-thin"
                  style={{
                    padding: 10,
                    borderRadius: 10,
                    display: 'flex',
                    gap: 12,
                    alignItems: 'center',
                    cursor: editable ? 'pointer' : 'default',
                  }}
                  onClick={() => {
                    if (!editable) return
                    setEditMovementId(m.id)
                    setCorrectionOpen(true)
                  }}
                  title={editable ? t('common.click_to_edit') : m.kind === 'vergütung' ? t('instructor_detail.movement_readonly_tooltip') : ''}
                >
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontSize: 13, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                      {m.description || m.kind}
                    </div>
                    <div className="caption-2">
                      {format(new Date(m.date), 'd. MMM yyyy', { locale: dfLocale })} · {m.kind}
                    </div>
                  </div>
                  <div
                    className="mono"
                    style={{ fontWeight: 600, color: Number(m.amount_chf) < 0 ? '#FF3B30' : 'inherit' }}
                  >
                    {chf(m.amount_chf)}
                  </div>
                  {editable && (
                    <Icon name="settings" size={14} />
                  )}
                </div>
              )
            })}
          </div>
        </>
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
