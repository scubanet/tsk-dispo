/**
 * CockpitScreen — Foundation-based rewrite.
 *
 * Layout:
 *   PageHeader (period switcher as actions)
 *   ┌─ KpiGrid ──────────────────────────────────────────────┐
 *   │  Hero: Auszahlungen CHF                                │
 *   │  Stat: Kurse / Aktive TLs / Aktive Schüler             │
 *   └────────────────────────────────────────────────────────┘
 *   ┌─ Monthly chart card ───────────────────────────────────┐
 *   ┌─ Top instructors card ─────────────────────────────────┐
 *   ┌─ Pipeline ─┐ ┌─ Attention ─┐
 */

import { useEffect, useMemo, useState } from 'react'
import { useOutletContext } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import {
  BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid, Cell,
} from 'recharts'
import {
  PageHeader,
  KpiGrid,
  KpiCard,
  FilterTabBar,
  Avatar,
  Pill,
  EmptyState,
  Icon,
  chf,
  padiLevelColor,
} from '@/foundation'
import { supabase } from '@/lib/supabase'
import type { OutletCtx } from '@/layout/AppShell'

interface KPIs {
  payments_chf: number
  payments_count: number
  courses_in_period: number
  active_instructors_in_period: number
  total_active_instructors: number
  active_students: number
}

interface MonthlyPayment { month: string; total: number }

interface TopInstructor {
  id: string
  name: string
  padi_level: string
  color: string | null
  initials: string | null
  total_chf: number
  course_count: number
}

interface Pipeline { today: number; this_week: number; next_30_days: number }

interface Attention {
  courses_without_haupt: number
  long_tentative: number
  idle_instructors_6w: number
}

interface CockpitData {
  kpis: KPIs
  monthly_payments: MonthlyPayment[]
  top_instructors: TopInstructor[]
  pipeline: Pipeline
  attention: Attention
}

type PeriodKey = 'month' | 'quarter' | 'ytd'

export function CockpitScreen() {
  const { t, i18n } = useTranslation()
  const { user } = useOutletContext<OutletCtx>()
  const [data, setData] = useState<CockpitData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [period, setPeriod] = useState<PeriodKey>('month')

  const range = useMemo(
    () => periodRange(period, i18n.resolvedLanguage ?? 'de'),
    [period, i18n.resolvedLanguage],
  )

  useEffect(() => {
    setLoading(true)
    setError(null)
    supabase
      .rpc('cockpit_data', { p_start: range.start, p_end: range.end })
      .then(({ data, error }) => {
        if (error) { setError(error.message); setLoading(false); return }
        setData(data as CockpitData)
        setLoading(false)
      })
  }, [range.start, range.end])

  const accessAllowed =
    user.role === 'owner' || user.role === 'dispatcher' || user.role === 'cd'

  if (!accessAllowed) {
    return (
      <div className="atoll-screen">
        <PageHeader title={t('cockpit.title')} />
        <div className="atoll-screen__body">
          <EmptyState title={t('cockpit.no_access')} />
        </div>
      </div>
    )
  }

  const periodTabs = [
    { id: 'month' as const, label: t('cockpit.range_month') },
    { id: 'quarter' as const, label: t('cockpit.range_quarter') },
    { id: 'ytd' as const, label: t('cockpit.range_ytd') },
  ]

  return (
    <div className="atoll-screen">
      <PageHeader
        title={t('cockpit.title')}
        subtitle={range.label}
        actions={
          <FilterTabBar<PeriodKey>
            tabs={periodTabs}
            active={period}
            onChange={setPeriod}
            ariaLabel={t('cockpit.title')}
          />
        }
      />

      <div className="atoll-screen__body">
        {loading && !data ? (
          <div className="atoll-cockpit__loading">{t('cockpit.loading')}</div>
        ) : error ? (
          <div className="atoll-cockpit__error">{error}</div>
        ) : data ? (
          <>
            <KpiSection kpis={data.kpis} />
            <MonthlyChart data={data.monthly_payments} />
            <TopInstructorsCard top={data.top_instructors} />
            <BottomGrid pipeline={data.pipeline} attention={data.attention} />
          </>
        ) : null}
      </div>
    </div>
  )
}

// ──────────────────────── Period Helpers ────────────────────────

function periodRange(p: PeriodKey, lang: string): { start: string; end: string; label: string } {
  const now = new Date()
  const y = now.getFullYear()
  const m = now.getMonth()
  const fmt = (d: Date) => d.toISOString().slice(0, 10)
  const dateLocale = lang.startsWith('en') ? 'en-GB' : 'de-CH'

  if (p === 'month') {
    const start = new Date(y, m, 1)
    const end = new Date(y, m + 1, 0)
    return {
      start: fmt(start),
      end: fmt(end),
      label: start.toLocaleDateString(dateLocale, { month: 'long', year: 'numeric' }),
    }
  }
  if (p === 'quarter') {
    const qStart = Math.floor(m / 3) * 3
    const start = new Date(y, qStart, 1)
    const end = new Date(y, qStart + 3, 0)
    return {
      start: fmt(start),
      end: fmt(end),
      label: `Q${Math.floor(qStart / 3) + 1} ${y}`,
    }
  }
  // ytd
  return {
    start: fmt(new Date(y, 0, 1)),
    end: fmt(new Date(y, 11, 31)),
    label: `${y}`,
  }
}

// ──────────────────────── KPI section ────────────────────────

function KpiSection({ kpis }: { kpis: KPIs }) {
  const { t } = useTranslation()
  return (
    <KpiGrid columns={4} gap="md">
      <KpiCard
        variant="hero"
        label={t('cockpit.kpi_payments')}
        value={chf(kpis.payments_chf)}
        sub={t('cockpit.kpi_payments_sub', { count: kpis.payments_count })}
      />
      <KpiCard
        variant="stat"
        label={t('cockpit.kpi_courses')}
        value={kpis.courses_in_period}
        sub={t('cockpit.kpi_courses_sub')}
      />
      <KpiCard
        variant="stat"
        label={t('cockpit.kpi_active_tls')}
        value={
          <>
            {kpis.active_instructors_in_period}
            <span className="atoll-kpi__total"> / {kpis.total_active_instructors}</span>
          </>
        }
        sub={t('cockpit.kpi_active_tls_sub')}
      />
      <KpiCard
        variant="stat"
        label={t('cockpit.kpi_students')}
        value={kpis.active_students}
        sub={t('cockpit.kpi_students_sub')}
      />
    </KpiGrid>
  )
}

// ──────────────────────── Monthly chart ────────────────────────

function MonthlyChart({ data }: { data: MonthlyPayment[] }) {
  const { t, i18n } = useTranslation()
  const dateLocale = i18n.resolvedLanguage?.startsWith('en') ? 'en-GB' : 'de-CH'
  const chartData = data.map((d) => {
    const [y, m] = d.month.split('-').map(Number)
    const date = new Date(y, m - 1, 1)
    return {
      month: date.toLocaleDateString(dateLocale, { month: 'short', year: '2-digit' }),
      total: Number(d.total),
    }
  })
  const currentMonth = new Date().toLocaleDateString(dateLocale, { month: 'short', year: '2-digit' })

  return (
    <section className="atoll-cockpit__card">
      <h2 className="atoll-cockpit__card-title">{t('cockpit.monthly_title')}</h2>
      <p className="atoll-cockpit__card-sub">{t('cockpit.monthly_subtitle')}</p>

      {chartData.length === 0 ? (
        <EmptyState title={t('cockpit.monthly_empty')} />
      ) : (
        <ResponsiveContainer width="100%" height={220}>
          <BarChart data={chartData} margin={{ top: 10, right: 10, bottom: 0, left: -10 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="rgba(0,0,0,.05)" vertical={false} />
            <XAxis
              dataKey="month"
              tick={{ fontSize: 11, fill: 'var(--text-tertiary)' }}
              axisLine={false}
              tickLine={false}
            />
            <YAxis
              tick={{ fontSize: 11, fill: 'var(--text-tertiary)' }}
              axisLine={false}
              tickLine={false}
              tickFormatter={(v) => `${(v / 1000).toFixed(0)}k`}
            />
            <Tooltip
              cursor={{ fill: 'var(--brand-blue-50)' }}
              contentStyle={{
                borderRadius: 10,
                border: '1px solid var(--border-tertiary)',
                background: 'var(--bg-card)',
                boxShadow: 'var(--shadow-popover)',
                fontSize: 13,
              }}
              labelStyle={{ color: 'var(--text-primary)', fontWeight: 500 }}
              formatter={(value: number) => [chf(value), t('cockpit.kpi_total')]}
            />
            <Bar dataKey="total" radius={[6, 6, 0, 0]}>
              {chartData.map((d, i) => (
                <Cell
                  key={i}
                  fill={d.month === currentMonth ? 'var(--brand-blue)' : 'var(--brand-teal)'}
                />
              ))}
            </Bar>
          </BarChart>
        </ResponsiveContainer>
      )}
    </section>
  )
}

// ──────────────────────── Top Instructors ────────────────────────

function TopInstructorsCard({ top }: { top: TopInstructor[] }) {
  const { t } = useTranslation()
  const max = Math.max(...top.map((row) => Number(row.total_chf)), 1)

  return (
    <section className="atoll-cockpit__card">
      <h2 className="atoll-cockpit__card-title">{t('cockpit.top_title')}</h2>
      <p className="atoll-cockpit__card-sub">{t('cockpit.top_subtitle')}</p>

      {top.length === 0 ? (
        <EmptyState title={t('cockpit.top_empty')} />
      ) : (
        <ol className="atoll-cockpit__top-list">
          {top.map((row, i) => (
            <li key={row.id} className="atoll-cockpit__top-row">
              <span className="atoll-cockpit__top-rank tabular-nums">{i + 1}</span>
              <Avatar
                id={row.id}
                name={row.name}
                size="sm"
                color={padiLevelColor(row.padi_level)}
              />
              <div className="atoll-cockpit__top-body">
                <div className="atoll-cockpit__top-head">
                  <span className="atoll-cockpit__top-name">{row.name}</span>
                  <span className="atoll-cockpit__top-amount tabular-nums">{chf(row.total_chf)}</span>
                </div>
                <div
                  className="atoll-cockpit__top-bar"
                  role="progressbar"
                  aria-valuenow={Math.round((Number(row.total_chf) / max) * 100)}
                >
                  <div
                    className="atoll-cockpit__top-bar-fill"
                    style={{ width: `${(Number(row.total_chf) / max) * 100}%` }}
                  />
                </div>
                <div className="atoll-cockpit__top-meta">
                  <Pill tone="pro" size="sm">{row.padi_level}</Pill>
                  <span>{t('cockpit.course_count', { count: row.course_count })}</span>
                </div>
              </div>
            </li>
          ))}
        </ol>
      )}
    </section>
  )
}

// ──────────────────────── Pipeline + Attention ────────────────────────

function BottomGrid({ pipeline, attention }: { pipeline: Pipeline; attention: Attention }) {
  const { t } = useTranslation()
  return (
    <div className="atoll-cockpit__bottom">
      <section className="atoll-cockpit__card">
        <h2 className="atoll-cockpit__card-title">{t('nav.pipeline')}</h2>
        <PipelineRow label={t('cockpit.pipeline_today')} value={pipeline.today} />
        <PipelineRow label={t('cockpit.pipeline_this_week')} value={pipeline.this_week} />
        <PipelineRow label={t('cockpit.pipeline_next_30')} value={pipeline.next_30_days} />
      </section>

      <section className="atoll-cockpit__card">
        <h2 className="atoll-cockpit__card-title">{t('cockpit.attention')}</h2>
        <AttentionRow
          label={t('cockpit.attention_no_haupt')}
          value={attention.courses_without_haupt}
          tone={attention.courses_without_haupt > 0 ? 'danger' : 'ok'}
          hint={t('cockpit.attention_no_haupt_hint')}
        />
        <AttentionRow
          label={t('cockpit.attention_tentative')}
          value={attention.long_tentative}
          tone={attention.long_tentative > 0 ? 'warning' : 'ok'}
          hint={t('cockpit.attention_tentative_hint')}
        />
        <AttentionRow
          label={t('cockpit.attention_idle')}
          value={attention.idle_instructors_6w}
          tone={attention.idle_instructors_6w > 0 ? 'info' : 'ok'}
          hint={t('cockpit.attention_idle_hint')}
        />
      </section>
    </div>
  )
}

function PipelineRow({ label, value }: { label: string; value: number }) {
  return (
    <div className="atoll-cockpit__row">
      <span className="atoll-cockpit__row-label">{label}</span>
      <span className="atoll-cockpit__row-value tabular-nums">{value}</span>
    </div>
  )
}

function AttentionRow({
  label,
  value,
  tone,
  hint,
}: {
  label: string
  value: number
  tone: 'ok' | 'info' | 'warning' | 'danger'
  hint?: string
}) {
  const dotClass = `atoll-cockpit__dot atoll-cockpit__dot--${tone}`
  return (
    <div className="atoll-cockpit__row" title={hint}>
      <span className="atoll-cockpit__row-label">{label}</span>
      <span className="atoll-cockpit__row-attention">
        <span
          className={`atoll-cockpit__row-value tabular-nums${value > 0 && tone !== 'ok' ? ` atoll-cockpit__row-value--${tone}` : ''}`}
        >
          {value}
        </span>
        <Icon.Info aria-hidden style={{ display: 'none' }} />
        <span className={dotClass} aria-hidden />
      </span>
    </div>
  )
}
