/**
 * CDPipelineScreen — Foundation-based rewrite.
 *
 * Layout:
 *   PageHeader
 *   ┌─ 5-column kanban (lead / qualified / opportunity / customer / lost) ─┐
 *   │  each col: Foundation card with header (label · count) + person cards │
 *   └────────────────────────────────────────────────────────────────────────┘
 */

import { useMemo, useState } from 'react'
import { useOutletContext } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import {
  PageHeader,
  EmptyState,
  Avatar,
  Pill,
  Icon,
} from '@/foundation'
import { usePipelineContacts } from '@/hooks/usePipelineContacts'
import type { OutletCtx } from '@/layout/AppShell'
import { ContactDetailPanel } from '../contacts/ContactDetailPanel'

interface Row {
  id: string
  first_name: string | null
  last_name: string | null
  pipeline_stage: string
  stage_changed_on: string
}

const COL_CODES = ['lead', 'qualified', 'opportunity', 'customer', 'lost'] as const
type ColCode = (typeof COL_CODES)[number]

const COL_TONE: Record<ColCode, 'neutral' | 'info' | 'warning' | 'success' | 'danger'> = {
  lead: 'neutral',
  qualified: 'info',
  opportunity: 'warning',
  customer: 'success',
  lost: 'danger',
}

export function CDPipelineScreen() {
  const { t } = useTranslation()
  const { user } = useOutletContext<OutletCtx>()
  const { data: raw = [], isLoading: loading } = usePipelineContacts()
  const [selectedId, setSelectedId] = useState<string | null>(null)

  // Filter out null pipeline_stage rows; the kanban only renders staged contacts.
  const rows = useMemo<Row[]>(
    () =>
      raw
        .filter(
          (r): r is Row =>
            r.pipeline_stage !== null && r.stage_changed_on !== null,
        )
        .map((r) => ({
          id: r.id,
          first_name: r.first_name,
          last_name: r.last_name,
          pipeline_stage: r.pipeline_stage as string,
          stage_changed_on: r.stage_changed_on as string,
        })),
    [raw],
  )

  const cols = useMemo(
    () =>
      COL_CODES.map((code) => ({
        code,
        label:
          code === 'customer'
            ? t('cd_pipeline.col_customer')
            : t(`student_edit.stage_${code}`),
        items: rows.filter((r) => r.pipeline_stage === code),
      })),
    [rows, t],
  )

  if (user.role !== 'cd') {
    return (
      <div className="atoll-screen">
        <PageHeader title={t('nav.pipeline')} />
        <div className="atoll-screen__body">
          <EmptyState
            icon={<Icon.Info size={20} />}
            title={t('cd_pipeline.no_access_title')}
            body={t('cd_pipeline.no_access_desc')}
          />
        </div>
      </div>
    )
  }

  return (
    <div className="atoll-screen">
      <PageHeader title={t('nav.pipeline')} subtitle={t('cd_pipeline.subtitle')} />

      <div className="atoll-screen__body">
        {loading ? (
          <div className="atoll-cockpit__loading">{t('common.loading')}</div>
        ) : (
          <div className="atoll-pipeline__cols">
            {cols.map((col) => (
              <section key={col.code} className="atoll-cockpit__card atoll-pipeline__col">
                <header className="atoll-pipeline__col-head">
                  <Pill tone={COL_TONE[col.code]} size="sm">
                    {col.label}
                  </Pill>
                  <span className="atoll-pipeline__count tabular-nums">{col.items.length}</span>
                </header>
                <div className="atoll-pipeline__items">
                  {col.items.length === 0 ? (
                    <div className="atoll-pipeline__empty">—</div>
                  ) : (
                    col.items.map((it) => {
                      const name =
                        [it.first_name, it.last_name].filter(Boolean).join(' ') || '—'
                      return (
                        <button
                          key={it.id}
                          type="button"
                          className="atoll-pipeline__person"
                          onClick={() => setSelectedId(it.id)}
                        >
                          <Avatar id={it.id} name={name} size="sm" />
                          <span className="atoll-pipeline__person-name">{name}</span>
                        </button>
                      )
                    })
                  )}
                </div>
              </section>
            ))}
          </div>
        )}
      </div>

      <ContactDetailPanel
        contactId={selectedId}
        open={!!selectedId}
        initialTab="student"
        onClose={() => setSelectedId(null)}
      />
    </div>
  )
}
