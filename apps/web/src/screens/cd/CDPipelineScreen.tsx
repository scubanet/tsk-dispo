import { useEffect, useState } from 'react'
import { useOutletContext } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { supabase } from '@/lib/supabase'
import { Topbar } from '@/components/Topbar'
import type { OutletCtx } from '@/layout/AppShell'

interface Row {
  id: string
  first_name: string
  last_name: string
  pipeline_stage: string
  stage_changed_on: string
}

const COL_CODES = ['lead', 'qualified', 'opportunity', 'customer', 'lost'] as const

export function CDPipelineScreen() {
  const { t } = useTranslation()
  const COLS = COL_CODES.map((code) => ({
    code,
    label: code === 'customer' ? t('cd_pipeline.col_customer') : t(`student_edit.stage_${code}`),
  }))
  const { user } = useOutletContext<OutletCtx>()
  const [rows, setRows] = useState<Row[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let cancelled = false
    supabase
      .from('people')
      .select('id, first_name, last_name, pipeline_stage, stage_changed_on')
      .neq('pipeline_stage', 'none')
      .order('stage_changed_on', { ascending: false })
      .then(({ data, error }) => {
        if (cancelled) return
        if (error) console.error('[cd] pipeline load failed', error)
        setRows((data ?? []) as Row[])
        setLoading(false)
      })
    return () => { cancelled = true }
  }, [])

  if (user.role !== 'cd') {
    return (
      <div style={{ padding: 40 }}>
        <div className="title-2">{t('cd_pipeline.no_access_title')}</div>
        <div className="caption">{t('cd_pipeline.no_access_desc')}</div>
      </div>
    )
  }

  return (
    <>
      <Topbar title={t('nav.pipeline')} subtitle={t('cd_pipeline.subtitle')} />
      {loading ? (
        <div style={{ padding: 40 }} className="caption">{t('common.loading')}</div>
      ) : (
        <div style={{ padding: '0 24px 24px', display: 'grid', gridTemplateColumns: `repeat(${COLS.length}, 1fr)`, gap: 12 }}>
          {COLS.map((col) => {
            const items = rows.filter((r) => r.pipeline_stage === col.code)
            return (
              <div key={col.code} className="glass-thin" style={{ padding: 12, borderRadius: 14, minHeight: 240 }}>
                <div style={{ fontSize: 12, fontWeight: 700, opacity: 0.8, marginBottom: 8 }}>
                  {col.label} · {items.length}
                </div>
                <div style={{ display: 'grid', gap: 6 }}>
                  {items.map((it) => (
                    <div key={it.id} className="glass-thin" style={{ padding: 8, borderRadius: 10, fontSize: 12.5 }}>
                      {it.first_name} {it.last_name}
                    </div>
                  ))}
                  {items.length === 0 && (
                    <div className="caption" style={{ opacity: 0.5, fontSize: 11 }}>—</div>
                  )}
                </div>
              </div>
            )
          })}
        </div>
      )}
    </>
  )
}
