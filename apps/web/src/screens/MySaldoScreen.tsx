import { useEffect, useState } from 'react'
import { useOutletContext } from 'react-router-dom'
import { format } from 'date-fns'
import { de, enGB } from 'date-fns/locale'
import { useTranslation } from 'react-i18next'
import { Topbar } from '@/components/Topbar'
import { Chip } from '@/components/Chip'
import { EmptyState } from '@/components/EmptyState'
import { fetchMyMovements, type MyMovement } from '@/lib/queries'
import { chf } from '@/lib/format'
import type { OutletCtx } from '@/layout/AppShell'

export function MySaldoScreen() {
  const { t, i18n } = useTranslation()
  const dfLocale = i18n.resolvedLanguage === 'en' ? enGB : de
  const { user } = useOutletContext<OutletCtx>()
  const [movements, setMovements] = useState<MyMovement[]>([])
  const [expandedId, setExpandedId] = useState<string | null>(null)

  useEffect(() => {
    if (!user.instructorId) return
    fetchMyMovements(user.instructorId).then(setMovements)
  }, [user.instructorId])

  if (!user.instructorId) {
    return (
      <>
        <Topbar title={t('nav.my_balance')} />
        <EmptyState
          icon="wallet"
          title={t('my_balance.no_link_title')}
          description={t('my_balance.no_link_desc')}
        />
      </>
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
    <>
      <Topbar title={t('nav.my_balance')} subtitle={t('my_balance.movement_count', { count: movements.length })} />

      <div className="screen-fade scroll" style={{ flex: 1, padding: '20px 24px 40px' }}>
        <div className="tile-now" style={{ marginBottom: 16 }}>
          <div
            style={{
              fontSize: 12,
              opacity: 0.85,
              letterSpacing: '.02em',
              textTransform: 'uppercase',
              fontWeight: 600,
            }}
          >
            {t('my_balance.current_balance')}
          </div>
          <div
            className="mono"
            style={{
              fontSize: 38,
              fontWeight: 700,
              marginTop: 8,
              letterSpacing: '-.02em',
              position: 'relative',
              zIndex: 1,
            }}
          >
            {chf(balance)}
          </div>
          <div style={{ display: 'flex', gap: 18, marginTop: 18, position: 'relative', zIndex: 1 }}>
            <SubStat label={t('my_balance.opening')} value={chf(opening)} />
            <Divider />
            <SubStat label={t('my_balance.payments')} value={chf(compTotal)} />
            {corrections !== 0 && (
              <>
                <Divider />
                <SubStat label={t('my_balance.corrections')} value={chf(corrections)} />
              </>
            )}
          </div>
        </div>

        <div className="title-3" style={{ marginBottom: 8 }}>{t('my_balance.movements')}</div>

        {movements.length === 0 ? (
          <EmptyState icon="wallet" title={t('my_balance.no_movements')} />
        ) : (
          <div style={{ display: 'grid', gap: 6 }}>
            {movements.map((m) => {
              const expanded = expandedId === m.id
              const negative = Number(m.amount_chf) < 0
              return (
                <div
                  key={m.id}
                  className="glass-thin"
                  style={{ padding: 12, borderRadius: 12, cursor: 'pointer' }}
                  onClick={() => setExpandedId(expanded ? null : m.id)}
                >
                  <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ fontSize: 13, fontWeight: 500, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                        {m.description || m.kind}
                      </div>
                      <div className="caption-2" style={{ marginTop: 2, display: 'flex', gap: 8, alignItems: 'center' }}>
                        {format(new Date(m.date), 'd. MMM yyyy', { locale: dfLocale })}
                        <Chip tone={
                          m.kind === 'vergütung' ? 'accent' :
                          m.kind === 'übertrag'  ? 'neutral' : 'orange'
                        }>
                          {m.kind}
                        </Chip>
                      </div>
                    </div>
                    <div
                      className="mono"
                      style={{
                        fontWeight: 600,
                        color: negative ? '#FF3B30' : 'inherit',
                      }}
                    >
                      {chf(m.amount_chf)}
                    </div>
                  </div>

                  {expanded && m.breakdown_json && (
                    <div
                      style={{
                        marginTop: 12,
                        padding: 12,
                        background: 'rgba(0,0,0,.04)',
                        borderRadius: 8,
                      }}
                    >
                      <div className="caption-2" style={{ marginBottom: 6 }}>{t('my_balance.calculation')}</div>
                      <BreakdownTable breakdown={m.breakdown_json} t={t} />
                    </div>
                  )}
                </div>
              )
            })}
          </div>
        )}
      </div>
    </>
  )
}

function SubStat({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <div className="mono" style={{ fontSize: 18, fontWeight: 700 }}>{value}</div>
      <div style={{ fontSize: 11, opacity: 0.85 }}>{label}</div>
    </div>
  )
}

function Divider() {
  return <div style={{ width: 0.5, background: 'rgba(255,255,255,.3)' }} />
}

function BreakdownTable({ breakdown, t }: { breakdown: Record<string, unknown>; t: (key: string) => string }) {
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
    <table style={{ fontSize: 12, width: '100%' }}>
      <tbody>
        {rows.map(([k, v]) => (
          <tr key={String(k)}>
            <td className="caption" style={{ padding: '2px 0' }}>{String(k)}</td>
            <td align="right" className="mono" style={{ padding: '2px 0' }}>{String(v)}</td>
          </tr>
        ))}
      </tbody>
    </table>
  )
}
