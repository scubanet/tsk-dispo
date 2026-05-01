import { useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import clsx from 'clsx'
import { Topbar } from '@/components/Topbar'
import { Icon } from '@/components/Icon'
import { supabase } from '@/lib/supabase'
import { chf } from '@/lib/format'

interface Row {
  instructor_id: string
  name: string
  app_balance: number
  excel_saldo: number
  diff: number
}

type SortKey = 'name' | 'app_balance' | 'diff'

export function SaldiScreen() {
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
          ((data ?? []) as any[]).map((d) => ({
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

  const within50 = rows.filter((r) => Math.abs(r.diff) <= 50).length
  const total = rows.length || 1
  const ratio = ((within50 / total) * 100).toFixed(0)
  const totalAppBalance = rows.reduce((s, r) => s + r.app_balance, 0)

  return (
    <>
      <Topbar
        title="Saldi"
        subtitle={`${rows.length} Personen · Σ App-Saldo ${chf(totalAppBalance)}`}
      >
        <div className="search" style={{ width: 220 }}>
          <Icon name="search" size={14} />
          <input
            placeholder="Suchen…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>
      </Topbar>

      <div className="screen-fade scroll" style={{ flex: 1, padding: '20px 24px 40px' }}>
        <div className="glass card" style={{ marginBottom: 16 }}>
          <div className="title-3" style={{ marginBottom: 8 }}>Saldo-Vergleich App ↔ Excel</div>
          <div className="caption">
            {within50} von {total} Personen innerhalb ±CHF 50 ({ratio}%). Δ &gt; 50 weist meist
            auf Guru-Bezüge oder manuelle Korrekturen hin (kommen in Slice C).
          </div>
        </div>

        <div className="glass card">
          <div className="seg" style={{ marginBottom: 12 }}>
            <button className={clsx(sortBy === 'name' && 'active')} onClick={() => setSortBy('name')}>
              Name
            </button>
            <button className={clsx(sortBy === 'app_balance' && 'active')} onClick={() => setSortBy('app_balance')}>
              Saldo (App)
            </button>
            <button className={clsx(sortBy === 'diff' && 'active')} onClick={() => setSortBy('diff')}>
              Δ größte zuerst
            </button>
          </div>

          <table style={{ width: '100%', fontSize: 13 }}>
            <thead>
              <tr style={{ borderBottom: '0.5px solid var(--hairline)' }}>
                <th align="left" style={{ padding: '6px 4px' }}>Name</th>
                <th align="right" style={{ padding: '6px 4px' }}>App</th>
                <th align="right" style={{ padding: '6px 4px' }}>Excel</th>
                <th align="right" style={{ padding: '6px 4px' }}>Δ</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((r) => (
                <tr
                  key={r.instructor_id}
                  onClick={() => navigate(`/tldm/${r.instructor_id}`)}
                  style={{ cursor: 'pointer' }}
                  className="list-row"
                >
                  <td style={{ padding: '8px 4px' }}>{r.name}</td>
                  <td align="right" className="mono" style={{ padding: '8px 4px' }}>
                    {chf(r.app_balance)}
                  </td>
                  <td align="right" className="mono" style={{ padding: '8px 4px' }}>
                    {chf(r.excel_saldo)}
                  </td>
                  <td
                    align="right"
                    className="mono"
                    style={{
                      padding: '8px 4px',
                      color: Math.abs(r.diff) > 50 ? '#FF3B30' : 'var(--ink-3)',
                      fontWeight: Math.abs(r.diff) > 50 ? 600 : 400,
                    }}
                  >
                    {chf(r.diff)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </>
  )
}
