/**
 * SaldiScreen — Foundation-based rewrite.
 *
 * Layout:
 *   PageHeader (search action)
 *   ┌─ KpiGrid (3) ───────────────────────────────────────────┐
 *   │  Hero: Total App-Saldo                                  │
 *   │  Stat: # Instructors                                     │
 *   │  Alert: # mit |Δ| > 50 CHF (warning oder ok)             │
 *   └─────────────────────────────────────────────────────────┘
 *   ┌─ Card: Saldi-Tabelle ───────────────────────────────────┐
 *   │   FilterTabBar (sort: Name / App / |Δ|)                 │
 *   │   table — Name | App-Saldo | Excel | Δ                  │
 *   └─────────────────────────────────────────────────────────┘
 */

import { useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import {
  PageHeader,
  KpiGrid,
  KpiCard,
  FilterTabBar,
  SearchInput,
  EmptyState,
  Icon,
  chf,
} from '@/foundation'
import { supabase } from '@/lib/supabase'

interface Row {
  instructor_id: string
  name: string
  app_balance: number
  excel_saldo: number
  diff: number
}

type SortKey = 'name' | 'app_balance' | 'diff'

export function SaldiScreen() {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const [rows, setRows] = useState<Row[]>([])
  const [search, setSearch] = useState('')
  const [sortBy, setSortBy] = useState<SortKey>('diff')

  useEffect(() => {
    supabase
      .from('v_saldo_diff')
      .select('*')
      .then(({ data }) => {
        setRows(
          ((data ?? []) as Array<{
            instructor_id: string
            name: string
            app_balance: number | string | null
            excel_saldo: number | string | null
            diff: number | string | null
          }>).map((d) => ({
            instructor_id: d.instructor_id,
            name: d.name,
            app_balance: Number(d.app_balance ?? 0),
            excel_saldo: Number(d.excel_saldo ?? 0),
            diff: Number(d.diff ?? 0),
          })),
        )
      })
  }, [])

  const filtered = useMemo(() => {
    let arr = rows
    if (search) {
      arr = arr.filter((r) => r.name.toLowerCase().includes(search.toLowerCase()))
    }
    arr = [...arr].sort((a, b) => {
      switch (sortBy) {
        case 'name': return a.name.localeCompare(b.name)
        case 'app_balance': return b.app_balance - a.app_balance
        case 'diff': return Math.abs(b.diff) - Math.abs(a.diff)
      }
    })
    return arr
  }, [rows, search, sortBy])

  const total = rows.length || 1
  const within50 = rows.filter((r) => Math.abs(r.diff) <= 50).length
  const ratio = ((within50 / total) * 100).toFixed(0)
  const totalAppBalance = rows.reduce((s, r) => s + r.app_balance, 0)
  const offCount = rows.length - within50
  const allWithin50 = offCount === 0

  const sortTabs = [
    { id: 'name' as const, label: t('balances.col_name') },
    { id: 'app_balance' as const, label: t('balances.sort_app_balance') },
    { id: 'diff' as const, label: t('balances.sort_diff') },
  ]

  return (
    <div className="atoll-screen">
      <PageHeader
        title={t('nav.balances')}
        subtitle={t('balances.topbar_subtitle', { count: rows.length, sum: chf(totalAppBalance) })}
        actions={
          <SearchInput
            value={search}
            onChange={setSearch}
            ariaLabel={t('common.search')}
            placeholder={t('common.search') + '…'}
          />
        }
      />

      <div className="atoll-screen__body">
        <KpiGrid columns={3} gap="md">
          <KpiCard
            variant="hero"
            label={t('nav.balances')}
            value={chf(totalAppBalance)}
            sub={t('balances.topbar_subtitle', { count: rows.length, sum: '' })
              .replace(/·\s*$/, '')
              .trim()}
          />
          <KpiCard
            variant="stat"
            label={t('balances.compare_title')}
            value={
              <>
                {within50}
                <span className="atoll-kpi__total"> / {rows.length}</span>
              </>
            }
            sub={`${ratio}%`}
          />
          <KpiCard
            variant={allWithin50 ? 'stat' : 'alert'}
            alertTone={offCount > 0 ? 'warning' : undefined}
            label={t('balances.sort_diff')}
            value={offCount}
            sub={allWithin50 ? t('balances.compare_summary', { within: within50, total, ratio }) : undefined}
          />
        </KpiGrid>

        <section className="atoll-cockpit__card">
          <div className="atoll-saldi__toolbar">
            <FilterTabBar<SortKey>
              tabs={sortTabs}
              active={sortBy}
              onChange={setSortBy}
              ariaLabel={t('balances.compare_title')}
            />
          </div>

          {filtered.length === 0 ? (
            <EmptyState
              icon={<Icon.Info size={20} />}
              title={t('courses.no_matches')}
            />
          ) : (
            <table className="atoll-saldi__table">
              <thead>
                <tr>
                  <th align="left">{t('balances.col_name')}</th>
                  <th align="right">{t('balances.col_app')}</th>
                  <th align="right">{t('balances.col_excel')}</th>
                  <th align="right">Δ</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map((r) => {
                  const off = Math.abs(r.diff) > 50
                  return (
                    <tr
                      key={r.instructor_id}
                      onClick={() => navigate(`/tldm/${r.instructor_id}`)}
                      className="atoll-saldi__row"
                    >
                      <td>{r.name}</td>
                      <td align="right" className="tabular-nums">{chf(r.app_balance)}</td>
                      <td align="right" className="tabular-nums atoll-saldi__excel">{chf(r.excel_saldo)}</td>
                      <td
                        align="right"
                        className={`tabular-nums${off ? ' atoll-saldi__diff--off' : ' atoll-saldi__diff'}`}
                      >
                        {chf(r.diff)}
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          )}
        </section>
      </div>
    </div>
  )
}
