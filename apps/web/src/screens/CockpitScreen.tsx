import { useEffect, useMemo, useState } from 'react'
import { useOutletContext } from 'react-router-dom'
import {
  BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid, Cell,
} from 'recharts'
import { Topbar } from '@/components/Topbar'
import { Avatar } from '@/components/Avatar'
import { supabase } from '@/lib/supabase'
import { chf } from '@/lib/format'
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
  id: string; name: string; padi_level: string
  color: string | null; initials: string | null
  total_chf: number; course_count: number
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
  const { user } = useOutletContext<OutletCtx>()
  const [data, setData] = useState<CockpitData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [period, setPeriod] = useState<PeriodKey>('month')

  const range = useMemo(() => periodRange(period), [period])

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

  const accessAllowed = user.role === 'owner' || user.role === 'dispatcher' || user.role === 'cd'
  if (!accessAllowed) {
    return (
      <>
        <Topbar title="Cockpit" />
        <div style={{ padding: 40, textAlign: 'center' }} className="caption">
          Cockpit ist nur für Owner und Dispatcher zugänglich.
        </div>
      </>
    )
  }

  return (
    <>
      <Topbar title="Cockpit" subtitle={range.label}>
        <PeriodSeg value={period} onChange={setPeriod} />
      </Topbar>

      <div className="screen-fade scroll" style={{ padding: '20px 24px 60px', flex: 1 }}>
        {loading && !data ? (
          <div className="caption" style={{ padding: 80, textAlign: 'center' }}>Lade Cockpit-Daten…</div>
        ) : error ? (
          <div className="chip chip-red" style={{ padding: 16, borderRadius: 12 }}>{error}</div>
        ) : data ? (
          <>
            <KpiRow kpis={data.kpis} />
            <MonthlyChart data={data.monthly_payments} />
            <TopInstructorsCard top={data.top_instructors} />
            <BottomGrid pipeline={data.pipeline} attention={data.attention} />
          </>
        ) : null}
      </div>
    </>
  )
}

// =================================================================
// Period Helpers
// =================================================================

function periodRange(p: PeriodKey): { start: string; end: string; label: string } {
  const now = new Date()
  const y = now.getFullYear()
  const m = now.getMonth()
  const fmt = (d: Date) => d.toISOString().slice(0, 10)

  if (p === 'month') {
    const start = new Date(y, m, 1)
    const end = new Date(y, m + 1, 0)
    return {
      start: fmt(start),
      end: fmt(end),
      label: start.toLocaleDateString('de-CH', { month: 'long', year: 'numeric' }),
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

function PeriodSeg({ value, onChange }: { value: PeriodKey; onChange: (v: PeriodKey) => void }) {
  return (
    <div className="seg">
      <button className={value === 'month' ? 'active' : ''} onClick={() => onChange('month')}>Monat</button>
      <button className={value === 'quarter' ? 'active' : ''} onClick={() => onChange('quarter')}>Quartal</button>
      <button className={value === 'ytd' ? 'active' : ''} onClick={() => onChange('ytd')}>YTD</button>
    </div>
  )
}

// =================================================================
// KPI Row
// =================================================================

function KpiRow({ kpis }: { kpis: KPIs }) {
  return (
    <div style={{
      display: 'grid',
      gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
      gap: 14,
      marginBottom: 24,
    }}>
      <KpiCard
        label="Vergütungen"
        value={chf(kpis.payments_chf)}
        sub={`${kpis.payments_count} Buchungen`}
        accent="linear-gradient(135deg, #0A84FF, #30B0C7)"
      />
      <KpiCard
        label="Kurse"
        value={String(kpis.courses_in_period)}
        sub="im Zeitraum (ohne CXL)"
      />
      <KpiCard
        label="Aktive TLs"
        value={`${kpis.active_instructors_in_period} / ${kpis.total_active_instructors}`}
        sub="im Zeitraum / total"
      />
      <KpiCard
        label="Schüler"
        value={String(kpis.active_students)}
        sub="aktive Datensätze"
      />
    </div>
  )
}

function KpiCard({ label, value, sub, accent }: {
  label: string; value: string; sub: string; accent?: string
}) {
  const isHero = !!accent
  return (
    <div
      className="glass card"
      style={{
        padding: 18,
        background: accent,
        color: isHero ? '#fff' : undefined,
      }}
    >
      <div style={{
        fontSize: 11, fontWeight: 700, letterSpacing: '.08em',
        textTransform: 'uppercase',
        opacity: isHero ? 0.85 : 0.55,
      }}>{label}</div>
      <div className="mono" style={{
        fontSize: 28, fontWeight: 700, marginTop: 6, letterSpacing: '-.02em',
      }}>
        {value}
      </div>
      <div style={{ fontSize: 12, opacity: isHero ? 0.85 : 0.6, marginTop: 4 }}>{sub}</div>
    </div>
  )
}

// =================================================================
// Monthly Chart (Bar) — letzte 12 Monate
// =================================================================

function MonthlyChart({ data }: { data: MonthlyPayment[] }) {
  // Daten formatieren für recharts
  const chartData = data.map((d) => {
    const [y, m] = d.month.split('-').map(Number)
    const date = new Date(y, m - 1, 1)
    return {
      month: date.toLocaleDateString('de-CH', { month: 'short', year: '2-digit' }),
      total: Number(d.total),
    }
  })

  const currentMonth = new Date().toLocaleDateString('de-CH', { month: 'short', year: '2-digit' })

  return (
    <div className="glass card" style={{ padding: 20, marginBottom: 24 }}>
      <div className="title-3" style={{ marginBottom: 4 }}>Vergütungen pro Monat</div>
      <div className="caption" style={{ marginBottom: 14 }}>Letzte 12 Monate · alle Instruktoren</div>
      {chartData.length === 0 ? (
        <div className="caption" style={{ padding: 40, textAlign: 'center' }}>
          Noch keine completed-Vergütungen in den letzten 12 Monaten.
        </div>
      ) : (
        <ResponsiveContainer width="100%" height={220}>
          <BarChart data={chartData} margin={{ top: 10, right: 10, bottom: 0, left: -10 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="rgba(0,0,0,.08)" vertical={false} />
            <XAxis
              dataKey="month"
              tick={{ fontSize: 11, fill: 'var(--ink-2)' }}
              axisLine={false}
              tickLine={false}
            />
            <YAxis
              tick={{ fontSize: 11, fill: 'var(--ink-2)' }}
              axisLine={false}
              tickLine={false}
              tickFormatter={(v) => `${(v / 1000).toFixed(0)}k`}
            />
            <Tooltip
              cursor={{ fill: 'rgba(10,132,255,.06)' }}
              contentStyle={{
                borderRadius: 8,
                border: 'none',
                background: 'rgba(255,255,255,.95)',
                boxShadow: '0 4px 14px rgba(0,0,0,.1)',
                fontSize: 13,
              }}
              formatter={(value: number) => [chf(value), 'Total']}
            />
            <Bar dataKey="total" radius={[6, 6, 0, 0]}>
              {chartData.map((d, i) => (
                <Cell key={i} fill={d.month === currentMonth ? '#0A84FF' : '#30B0C7'} />
              ))}
            </Bar>
          </BarChart>
        </ResponsiveContainer>
      )}
    </div>
  )
}

// =================================================================
// Top Instructors Card
// =================================================================

function TopInstructorsCard({ top }: { top: TopInstructor[] }) {
  const max = Math.max(...top.map((t) => Number(t.total_chf)), 1)
  return (
    <div className="glass card" style={{ padding: 20, marginBottom: 24 }}>
      <div className="title-3" style={{ marginBottom: 4 }}>Top 10 TL/DM</div>
      <div className="caption" style={{ marginBottom: 14 }}>Nach Vergütung im gewählten Zeitraum</div>
      {top.length === 0 ? (
        <div className="caption" style={{ padding: 30, textAlign: 'center' }}>
          Keine Vergütungen im Zeitraum.
        </div>
      ) : (
        <div style={{ display: 'grid', gap: 10 }}>
          {top.map((t, i) => (
            <div key={t.id} style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
              <div className="mono" style={{ fontSize: 12, color: 'var(--ink-2)', width: 18, textAlign: 'right' }}>
                {i + 1}.
              </div>
              <Avatar
                initials={t.initials || t.name.slice(0, 2).toUpperCase()}
                color={t.color || '#0A84FF'}
                size="sm"
              />
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', gap: 8 }}>
                  <div style={{ fontSize: 13, fontWeight: 500, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {t.name}
                  </div>
                  <div className="mono" style={{ fontSize: 13, fontWeight: 600 }}>
                    {chf(t.total_chf)}
                  </div>
                </div>
                {/* Bar */}
                <div style={{
                  height: 4, background: 'rgba(0,0,0,.06)', borderRadius: 999,
                  marginTop: 4, overflow: 'hidden',
                }}>
                  <div style={{
                    height: '100%',
                    width: `${(Number(t.total_chf) / max) * 100}%`,
                    background: 'linear-gradient(90deg, #0A84FF, #30B0C7)',
                    borderRadius: 999,
                  }} />
                </div>
                <div className="caption-2" style={{ marginTop: 2 }}>
                  {t.padi_level} · {t.course_count} Kurse
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

// =================================================================
// Bottom — Pipeline + Attention nebeneinander
// =================================================================

function BottomGrid({ pipeline, attention }: { pipeline: Pipeline; attention: Attention }) {
  return (
    <div style={{
      display: 'grid',
      gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))',
      gap: 14,
    }}>
      <div className="glass card" style={{ padding: 18 }}>
        <div className="title-3" style={{ marginBottom: 12 }}>Pipeline</div>
        <Row label="Heute"           value={pipeline.today} />
        <Row label="Diese Woche"     value={pipeline.this_week} />
        <Row label="Nächste 30 Tage" value={pipeline.next_30_days} />
      </div>

      <div className="glass card" style={{ padding: 18 }}>
        <div className="title-3" style={{ marginBottom: 12 }}>Achtung</div>
        <AttentionRow
          label="Kurse ohne Haupt-TL"
          value={attention.courses_without_haupt}
          severity={attention.courses_without_haupt > 0 ? 'red' : 'ok'}
          hint="Kritisch — Kurs kann nicht stattfinden ohne Haupt-Leiter"
        />
        <AttentionRow
          label="Tentative im Monat"
          value={attention.long_tentative}
          severity={attention.long_tentative > 0 ? 'orange' : 'ok'}
          hint="Noch nicht bestätigte Kurse in den nächsten 30 Tagen"
        />
        <AttentionRow
          label="TLs > 6 Wochen ohne Einsatz"
          value={attention.idle_instructors_6w}
          severity={attention.idle_instructors_6w > 0 ? 'yellow' : 'ok'}
          hint="Hinweis — diese TLs könnten Einsätze brauchen"
        />
      </div>
    </div>
  )
}

function Row({ label, value }: { label: string; value: number }) {
  return (
    <div style={{
      display: 'flex', justifyContent: 'space-between', alignItems: 'center',
      padding: '8px 0', borderBottom: '0.5px solid var(--hairline)',
    }}>
      <div style={{ fontSize: 13 }}>{label}</div>
      <div className="mono" style={{ fontSize: 18, fontWeight: 600 }}>{value}</div>
    </div>
  )
}

function AttentionRow({ label, value, severity, hint }: {
  label: string
  value: number
  severity: 'ok' | 'yellow' | 'orange' | 'red'
  hint?: string
}) {
  // Konsistent mit Calendar-Status-Farben:
  // red = blockierend, orange = tentative, yellow = Hinweis, green = ok
  const color =
    severity === 'red'    ? '#FF3B30' :
    severity === 'orange' ? '#FF9500' :
    severity === 'yellow' ? '#FFCC00' :
                            '#34C759'
  return (
    <div
      title={hint}
      style={{
        display: 'flex', justifyContent: 'space-between', alignItems: 'center',
        padding: '8px 0', borderBottom: '0.5px solid var(--hairline)',
      }}
    >
      <div style={{ fontSize: 13 }}>{label}</div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        <div className="mono" style={{ fontSize: 18, fontWeight: 600, color: value > 0 ? color : 'var(--ink-2)' }}>
          {value}
        </div>
        <div style={{
          width: 8, height: 8, borderRadius: 999, background: color,
          // Bei gelb: Border damit's auf weissem Background sichtbar bleibt
          boxShadow: severity === 'yellow' ? 'inset 0 0 0 0.5px rgba(0,0,0,.15)' : undefined,
        }} />
      </div>
    </div>
  )
}
