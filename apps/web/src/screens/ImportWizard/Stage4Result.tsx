import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'

interface Props {
  result: unknown
}

interface DiffRow {
  instructor_id: string
  name: string
  app_balance: number | null
  excel_opening: number | null
  diff: number | null
}

export function Stage4Result({ result }: Props) {
  const [diff, setDiff] = useState<DiffRow[]>([])

  useEffect(() => {
    supabase.from('v_saldo_diff').select('*').then(({ data }) => {
      setDiff((data as DiffRow[] | null) ?? [])
    })
  }, [])

  const within50 = diff.filter((d) => Math.abs(Number(d.diff ?? 0)) <= 50).length
  const total = diff.length || 1
  const ratio = ((within50 / total) * 100).toFixed(0)

  return (
    <div className="glass card" style={{ padding: 24 }}>
      <div className="title-3" style={{ marginBottom: 12 }}>✅ Import abgeschlossen</div>

      <pre
        style={{
          background: 'rgba(0,0,0,.05)',
          padding: 12,
          borderRadius: 8,
          fontSize: 12,
          overflow: 'auto',
        }}
      >
        {JSON.stringify(result, null, 2)}
      </pre>

      <div className="title-3" style={{ marginTop: 24, marginBottom: 8 }}>
        Saldo-Vergleich App ↔ Excel
      </div>
      <div className="caption" style={{ marginBottom: 12 }}>
        {within50} von {total} Personen innerhalb ±CHF 50 ({ratio}%) — Ziel ≥ 90%
      </div>

      <div style={{ maxHeight: 380, overflow: 'auto' }}>
        <table style={{ width: '100%', fontSize: 13, borderCollapse: 'collapse' }}>
          <thead>
            <tr style={{ borderBottom: '0.5px solid var(--hairline)' }}>
              <th align="left" style={{ padding: '6px 4px' }}>Name</th>
              <th align="right" style={{ padding: '6px 4px' }}>App</th>
              <th align="right" style={{ padding: '6px 4px' }}>Excel</th>
              <th align="right" style={{ padding: '6px 4px' }}>Δ</th>
            </tr>
          </thead>
          <tbody>
            {diff.slice(0, 100).map((d) => {
              const dv = Number(d.diff ?? 0)
              return (
                <tr key={d.instructor_id}>
                  <td style={{ padding: '6px 4px' }}>{d.name}</td>
                  <td align="right" className="mono" style={{ padding: '6px 4px' }}>
                    {Number(d.app_balance ?? 0).toFixed(2)}
                  </td>
                  <td align="right" className="mono" style={{ padding: '6px 4px' }}>
                    {Number(d.excel_opening ?? 0).toFixed(2)}
                  </td>
                  <td
                    align="right"
                    className="mono"
                    style={{
                      padding: '6px 4px',
                      color: Math.abs(dv) > 50 ? '#FF3B30' : 'inherit',
                    }}
                  >
                    {dv.toFixed(2)}
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>
    </div>
  )
}
