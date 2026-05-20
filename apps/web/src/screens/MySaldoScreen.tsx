/**
 * MySaldoScreen — Foundation-based rewrite (instructor view).
 *
 * Layout:
 *   PageHeader
 *   ┌─ Hero KpiCard: current balance + sub-stats (opening / payments / corr.) ─┐
 *   ┌─ Movements list (expandable cards with breakdown table) ─────────────────┐
 */

import { useState } from 'react'
import { useOutletContext } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import {
  PageHeader,
  EmptyState,
  Pill,
  Icon,
  chf,
  dateMedium,
} from '@/foundation'
import { useMyMovements } from '@/hooks/useMyMovements'
import type { OutletCtx } from '@/layout/AppShell'

export function MySaldoScreen() {
  const { t } = useTranslation()
  const { user } = useOutletContext<OutletCtx>()
  const { data: movements = [] } = useMyMovements(user.instructorId)
  const [expandedId, setExpandedId] = useState<string | null>(null)

  if (!user.instructorId) {
    return (
      <div className="atoll-screen">
        <PageHeader title={t('nav.my_balance')} />
        <div className="atoll-screen__body">
          <EmptyState
            icon={<Icon.Info size={20} />}
            title={t('my_balance.no_link_title')}
            body={t('my_balance.no_link_desc')}
          />
        </div>
      </div>
    )
  }

  const balance = movements.reduce((s, m) => s + Number(m.amount_chf), 0)
  const compTotal = movements
    .filter((m) => m.kind === 'vergütung')
    .reduce((s, m) => s + Number(m.amount_chf), 0)
  const opening = movements
    .filter((m) => m.kind === 'übertrag')
    .reduce((s, m) => s + Number(m.amount_chf), 0)
  const corrections = movements
    .filter((m) => m.kind === 'korrektur')
    .reduce((s, m) => s + Number(m.amount_chf), 0)

  return (
    <div className="atoll-screen">
      <PageHeader
        title={t('nav.my_balance')}
        subtitle={t('my_balance.movement_count', { count: movements.length })}
      />

      <div className="atoll-screen__body">
        {/* Hero balance — Foundation hero KPI variant. */}
        <section className="atoll-mysaldo__hero">
          <div className="atoll-mysaldo__hero-label">{t('my_balance.current_balance')}</div>
          <div className="atoll-mysaldo__hero-value tabular-nums">{chf(balance)}</div>
          <div className="atoll-mysaldo__hero-substats">
            <SubStat label={t('my_balance.opening')} value={chf(opening)} />
            <SubStat label={t('my_balance.payments')} value={chf(compTotal)} />
            {corrections !== 0 && (
              <SubStat label={t('my_balance.corrections')} value={chf(corrections)} />
            )}
          </div>
        </section>

        <h2 className="atoll-cockpit__card-title">{t('my_balance.movements')}</h2>

        {movements.length === 0 ? (
          <EmptyState
            icon={<Icon.Info size={20} />}
            title={t('my_balance.no_movements')}
          />
        ) : (
          <div className="atoll-mysaldo__list">
            {movements.map((m) => {
              const expanded = expandedId === m.id
              const negative = Number(m.amount_chf) < 0
              const tone =
                m.kind === 'vergütung' ? 'success' :
                m.kind === 'übertrag' ? 'neutral' :
                'warning'
              return (
                <button
                  key={m.id}
                  type="button"
                  className="atoll-mysaldo__row"
                  onClick={() => setExpandedId(expanded ? null : m.id)}
                  aria-expanded={expanded}
                >
                  <div className="atoll-mysaldo__row-head">
                    <div className="atoll-mysaldo__row-main">
                      <div className="atoll-mysaldo__row-desc">
                        {m.description || m.kind}
                      </div>
                      <div className="atoll-mysaldo__row-meta">
                        <span className="tabular-nums">{dateMedium(m.date)}</span>
                        <Pill tone={tone} size="sm">{m.kind}</Pill>
                      </div>
                    </div>
                    <div
                      className={`atoll-mysaldo__row-amount tabular-nums${negative ? ' atoll-mysaldo__row-amount--neg' : ''}`}
                    >
                      {chf(m.amount_chf)}
                    </div>
                  </div>

                  {expanded && m.breakdown_json && (
                    <div className="atoll-mysaldo__breakdown">
                      <div className="atoll-mysaldo__breakdown-title">
                        {t('my_balance.calculation')}
                      </div>
                      <BreakdownTable breakdown={m.breakdown_json} t={t} />
                    </div>
                  )}
                </button>
              )
            })}
          </div>
        )}
      </div>
    </div>
  )
}

function SubStat({ label, value }: { label: string; value: string }) {
  return (
    <div className="atoll-mysaldo__substat">
      <div className="atoll-mysaldo__substat-value tabular-nums">{value}</div>
      <div className="atoll-mysaldo__substat-label">{label}</div>
    </div>
  )
}

function BreakdownTable({
  breakdown,
  t,
}: {
  breakdown: Record<string, unknown>
  t: (key: string) => string
}) {
  const rows = [
    [t('my_balance.bd_course_type'), breakdown.course_type_code as string],
    [t('my_balance.bd_role'), breakdown.role as string],
    [t('my_balance.bd_padi_level'), breakdown.padi_level as string],
    [t('my_balance.bd_theory_h'), breakdown.theory_h],
    [t('my_balance.bd_pool_h'), breakdown.pool_h],
    [t('my_balance.bd_lake_h'), breakdown.lake_h],
    [t('my_balance.bd_total_h'), breakdown.total_h],
    [t('my_balance.bd_share'), `${((Number(breakdown.share) || 0) * 100).toFixed(0)}%`],
    [t('my_balance.bd_hourly_rate'), `CHF ${breakdown.hourly_rate}`],
  ].filter((r) => r[1] !== undefined && r[1] !== null && r[1] !== '')

  return (
    <table className="atoll-mysaldo__breakdown-table">
      <tbody>
        {rows.map(([k, v]) => (
          <tr key={String(k)}>
            <td>{String(k)}</td>
            <td align="right" className="tabular-nums">{String(v)}</td>
          </tr>
        ))}
      </tbody>
    </table>
  )
}
