import { useImportDryRun, useImportApply } from '@/hooks/useImport'

interface Props {
  storagePath: string
  mappings: Record<string, string>
  onConfirmed: (result: unknown) => void
}

export function Stage3DryRun({ storagePath, mappings, onConfirmed }: Props) {
  const dryRun = useImportDryRun(storagePath, mappings)
  const apply = useImportApply()
  const summary = dryRun.data
  const error = dryRun.error ?? apply.error

  function handleApply() {
    apply.mutate(
      { storagePath, mappings },
      { onSuccess: (data) => onConfirmed(data) },
    )
  }

  if (error) return <div className="chip chip-red">{error.message}</div>
  if (!summary) return <div className="caption">Plane Import…</div>

  return (
    <div className="glass card" style={{ padding: 'var(--space-6)' }}>
      <div className="title-3" style={{ marginBottom: 'var(--space-4)' }}>Schritt 3 — Vorschau</div>

      <div style={{ display: 'grid', gap: 'var(--space-2)', marginBottom: 20 }}>
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
          <div style={{ maxHeight: 160, overflow: 'auto', marginBottom: 'var(--space-4)' }}>
            {summary.ignored_rows.map((r) => (
              <div key={r.row} className="caption-2">
                Zeile {r.row}: {r.reason}
              </div>
            ))}
          </div>
        </>
      )}

      <button className="btn" onClick={handleApply} disabled={apply.isPending}>
        {apply.isPending ? 'Importiere…' : 'Bestätigen — Import durchführen'}
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
