import { useEffect, useState } from 'react'
import { useOutletContext } from 'react-router-dom'
import { format } from 'date-fns'
import { de } from 'date-fns/locale'
import { Topbar } from '@/components/Topbar'
import { Chip } from '@/components/Chip'
import { EmptyState } from '@/components/EmptyState'
import { fetchMyMovements, type MyMovement } from '@/lib/queries'
import { chf } from '@/lib/format'
import type { OutletCtx } from '@/layout/AppShell'

export function MySaldoScreen() {
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
        <Topbar title="Mein Saldo" />
        <EmptyState
          icon="wallet"
          title="Kein Instructor verknüpft"
          description="Dein Login ist noch keinem TL/DM-Datensatz zugeordnet."
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
      <Topbar title="Mein Saldo" subtitle={`${movements.length} Bewegungen`} />

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
            Aktueller Saldo
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
            <SubStat label="Eröffnung" value={chf(opening)} />
            <Divider />
            <SubStat label="Vergütungen" value={chf(compTotal)} />
            {corrections !== 0 && (
              <>
                <Divider />
                <SubStat label="Korrekturen" value={chf(corrections)} />
              </>
            )}
          </div>
        </div>

        <div className="title-3" style={{ marginBottom: 8 }}>Bewegungen</div>

        {movements.length === 0 ? (
          <EmptyState icon="wallet" title="Noch keine Bewegungen" />
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
                        {format(new Date(m.date), 'd. MMM yyyy', { locale: de })}
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
                      <div className="caption-2" style={{ marginBottom: 6 }}>BERECHNUNG</div>
                      <BreakdownTable breakdown={m.breakdown_json} />
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

function BreakdownTable({ breakdown }: { breakdown: Record<string, unknown> }) {
  const rows = [
    ['Kurstyp', breakdown.course_type_code as string],
    ['Rolle', breakdown.role as string],
    ['PADI-Level', breakdown.padi_level as string],
    ['Theorie h', breakdown.theory_h],
    ['Pool h', breakdown.pool_h],
    ['See h', breakdown.lake_h],
    ['Total h (anteilig)', breakdown.total_h],
    ['Anteil', `${((Number(breakdown.share) || 0) * 100).toFixed(0)}%`],
    ['Stundensatz', `CHF ${breakdown.hourly_rate}`],
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
