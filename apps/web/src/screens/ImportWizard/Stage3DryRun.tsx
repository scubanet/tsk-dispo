import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'

interface Props {
  storagePath: string
  mappings: Record<string, string>
  onConfirmed: (result: unknown) => void
}

interface DryRunSummary {
  instructors_count: number
  courses_count: number
  assignments_count: number
  opening_balance_sum: number
  ignored_rows: { row: number; reason: string }[]
}

export function Stage3DryRun({ storagePath, mappings, onConfirmed }: Props) {
  const [summary, setSummary] = useState<DryRunSummary | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [applying, setApplying] = useState(false)

  useEffect(() => {
    supabase.functions
      .invoke('excel-import', {
        body: { action: 'dryrun', storage_path: storagePath, mappings },
      })
      .then(({ data, error }) => {
        if (error) setError(error.message)
        else setSummary(data as DryRunSummary)
      })
  }, [storagePath, mappings])

  async function handleApply() {
    setApplying(true)
    const { data, error } = await supabase.functions.invoke('excel-import', {
      body: { action: 'apply', storage_path: storagePath, mappings },
    })
    if (error) {
      setError(error.message)
      setApplying(false)
      return
    }
    onConfirmed(data)
  }

  if (error) return <div className="chip chip-red">{error}</div>
  if (!summary) return <div className="caption">Plane Import…</div>

  return (
    <div className="glass card" style={{ padding: 24 }}>
      <div className="title-3" style={{ marginBottom: 16 }}>Schritt 3 — Vorschau</div>

      <div style={{ display: 'grid', gap: 8, marginBottom: 20 }}>
        <Row label="Instructors" value={summary.instructors_count} />
        <Row label="Kurse" value={summary.courses_count} />
        <Row label="Zuweisungen (Haupt + Assistenten)" value={summary.assignments_count} />
        <Row
          label="Eröffnungs-Saldo (Summe)"
          value={`CHF ${summary.opening_balance_sum.toFixed(2)}`}
        />
      </div>

      {summary.ignored_rows.length > 0 && (
        <>
          <div className="caption" style={{ marginBottom: 6 }}>
            ⚠ {summary.ignored_rows.length} Zeilen werden übersprungen:
          </div>
          <div style={{ maxHeight: 160, overflow: 'auto', marginBottom: 16 }}>
            {summary.ignored_rows.map((r) => (
              <div key={r.row} className="caption-2">
                Zeile {r.row}: {r.reason}
              </div>
            ))}
          </div>
        </>
      )}

      <button className="btn" onClick={handleApply} disabled={applying}>
        {applying ? 'Importiere…' : 'Bestätigen — Import durchführen'}
      </button>
    </div>
  )
}

function Row({ label, value }: { label: string; value: string | number }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between' }}>
      <span className="caption">{label}</span>
      <span className="mono" style={{ fontWeight: 600 }}>{value}</span>
    </div>
  )
}
