import { useEffect, useState } from 'react'
import { useNavigate, useOutletContext } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { supabase } from '@/lib/supabase'
import { Topbar } from '@/components/Topbar'
import { Icon } from '@/components/Icon'
import { StudentEditSheet } from '../StudentEditSheet'
import type { OutletCtx } from '@/layout/AppShell'

interface Candidate {
  id: string
  first_name: string
  last_name: string
  email: string | null
  phone: string | null
  level: string | null
  pipeline_stage: string
  stage_changed_on: string
  organization_id: string | null
  organization: { id: string; name: string } | null
  is_candidate: boolean
}

const STAGE_DEFS: { code: string; tone: string }[] = [
  { code: 'none',        tone: 'rgba(255,255,255,.10)' },
  { code: 'lead',        tone: 'rgba(0,122,255,.20)' },
  { code: 'qualified',   tone: 'rgba(255,204,0,.20)' },
  { code: 'opportunity', tone: 'rgba(255,149,0,.20)' },
  { code: 'candidate',   tone: 'rgba(52,199,89,.20)' },
  { code: 'lost',        tone: 'rgba(255,69,58,.18)' },
  // Legacy: 'customer' wird wie 'candidate' behandelt
  { code: 'customer',    tone: 'rgba(52,199,89,.20)' },
]

export function CDCandidatesScreen() {
  const { t } = useTranslation()
  const STAGES = STAGE_DEFS.map((s) => ({
    ...s,
    label: s.code === 'customer' ? t('student_edit.stage_candidate') : t(`student_edit.stage_${s.code}`),
  }))
  const { user } = useOutletContext<OutletCtx>()
  const navigate = useNavigate()
  const [rows, setRows] = useState<Candidate[]>([])
  const [search, setSearch] = useState('')
  const [loading, setLoading] = useState(true)
  const [createOpen, setCreateOpen] = useState(false)
  const [refreshTick, setRefreshTick] = useState(0)

  useEffect(() => {
    let cancelled = false
    setLoading(true)
    supabase
      .from('people')
      .select('id, first_name, last_name, email, phone, level, pipeline_stage, stage_changed_on, organization_id, organization:organizations(id, name), is_candidate')
      // Kontakte = jeder mit Pipeline-Stage ODER als Kandidat markiert ODER mit Org-Zuordnung
      .or('is_candidate.eq.true,pipeline_stage.neq.none,organization_id.not.is.null')
      .order('stage_changed_on', { ascending: false })
      .then(({ data, error }) => {
        if (cancelled) return
        if (error) console.error('[cd] candidates load failed', error)
        setRows((data ?? []) as unknown as Candidate[])
        setLoading(false)
      })
    return () => { cancelled = true }
  }, [refreshTick])

  if (user.role !== 'cd') {
    return (
      <div style={{ padding: 40 }}>
        <div className="title-2">{t('cd_pipeline.no_access_title')}</div>
        <div className="caption">{t('cd_pipeline.no_access_desc')}</div>
      </div>
    )
  }

  const filtered = rows.filter((r) => {
    const q = search.toLowerCase().trim()
    if (!q) return true
    return (
      r.first_name.toLowerCase().includes(q) ||
      r.last_name.toLowerCase().includes(q) ||
      (r.email ?? '').toLowerCase().includes(q)
    )
  })

  const byStage = STAGES.map((s) => ({
    ...s,
    count: rows.filter((r) => r.pipeline_stage === s.code).length,
  }))

  return (
    <>
      <Topbar
        title={t('cd_candidates.title')}
        subtitle={t('cd_candidates.subtitle', { total: rows.length, candidates: rows.filter((r) => r.is_candidate).length })}
      >
        <button className="btn" onClick={() => setCreateOpen(true)}>
          <Icon name="plus" size={14} /> {t('courses.new')}
        </button>
      </Topbar>

      <div style={{ padding: '0 24px 16px', display: 'flex', gap: 8, flexWrap: 'wrap' }}>
        {byStage.map((s) => (
          <div
            key={s.code}
            className="glass-thin"
            style={{
              padding: '6px 12px',
              borderRadius: 999,
              fontSize: 12.5,
              display: 'inline-flex',
              alignItems: 'center',
              gap: 6,
              background: s.tone,
            }}
          >
            <span>{s.label}</span>
            <span style={{ opacity: 0.7 }}>{s.count}</span>
          </div>
        ))}
      </div>

      <div style={{ padding: '0 24px 16px' }}>
        <input
          className="input"
          placeholder={t('common.search') + '…'}
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          style={{ width: '100%' }}
        />
      </div>

      {loading ? (
        <div style={{ padding: 40 }} className="caption">{t('common.loading')}</div>
      ) : filtered.length === 0 ? (
        <div style={{ padding: 40 }} className="caption">
          {t('cd_candidates.empty_hint')}
        </div>
      ) : (
        <div style={{ padding: '0 24px 24px', display: 'grid', gap: 6 }}>
          {filtered.map((c) => (
            <button
              key={c.id}
              className="glass-thin"
              onClick={() => navigate(`/schueler/${c.id}`)}
              style={{
                padding: 12,
                borderRadius: 12,
                textAlign: 'left',
                border: 'none',
                cursor: 'pointer',
                color: 'var(--ink)',
                font: 'inherit',
                width: '100%',
                display: 'flex',
                alignItems: 'center',
                gap: 12,
              }}
            >
              <div className="avatar avatar-sm" style={{ background: 'linear-gradient(135deg,#34c759,#00c2a8)' }}>
                {(c.first_name[0] ?? '') + (c.last_name[0] ?? '')}
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontWeight: 600 }}>
                  {c.first_name} {c.last_name}
                </div>
                <div className="caption" style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                  {[
                    c.organization?.name,
                    c.level,
                    c.email,
                  ].filter(Boolean).join(' · ') || '—'}
                </div>
              </div>
              <div
                className="caption"
                style={{
                  padding: '4px 10px',
                  borderRadius: 999,
                  background: STAGES.find((s) => s.code === c.pipeline_stage)?.tone ?? 'rgba(255,255,255,.10)',
                }}
              >
                {STAGES.find((s) => s.code === c.pipeline_stage)?.label ?? c.pipeline_stage}
              </div>
              <span className="caption-2" style={{ opacity: 0.4 }}>›</span>
            </button>
          ))}
        </div>
      )}

      <StudentEditSheet
        open={createOpen}
        onClose={() => setCreateOpen(false)}
        onSaved={(newId) => {
          setRefreshTick((t) => t + 1)
          if (newId) navigate(`/schueler/${newId}`)
        }}
        studentId={null}
        showCdFields={true}
        defaultIsCandidate={true}
        defaultPipelineStage="lead"
      />
    </>
  )
}
