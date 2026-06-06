import { useState, type CSSProperties } from 'react'
import { useTranslation } from 'react-i18next'
import { Sheet } from '@/components/Sheet'
import { useContactSearch } from '@/hooks/usePos'

const inputStyle: CSSProperties = {
  padding: '8px 10px', borderRadius: 8, border: '0.5px solid var(--hairline)',
  background: 'var(--surface-strong)', color: 'var(--ink)', font: 'inherit', fontSize: 13.5, width: '100%',
}

// Zeigt den aktuellen Kunden als Chip; Klick oeffnet die Suche. „Zuruecksetzen"
// stellt Laufkundschaft wieder her (Handler liegt im PosScreen).
export function CustomerPicker({ name, isWalkIn, onPick, onReset }: {
  name: string
  isWalkIn: boolean
  onPick: (id: string, name: string) => void
  onReset: () => void
}) {
  const { t } = useTranslation()
  const [open, setOpen] = useState(false)
  const [q, setQ] = useState('')
  const { data: results = [], isFetching } = useContactSearch(q)

  return (
    <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
      <span className="caption-2">{t('pos.customer')}:</span>
      <button type="button" className="chip" onClick={() => setOpen(true)}>{name}</button>
      {!isWalkIn && (
        <button type="button" className="btn-ghost btn" onClick={onReset}>{t('pos.walk_in_reset')}</button>
      )}
      <Sheet open={open} onClose={() => setOpen(false)} title={t('pos.pick_customer')} width={460}>
        <input style={inputStyle} autoFocus placeholder={t('pos.search_customer')}
          value={q} onChange={(e) => setQ(e.target.value)} />
        <div style={{ marginTop: 8, display: 'grid', gap: 2 }}>
          {isFetching && <div className="caption-2">{t('common.loading', 'Laedt …')}</div>}
          {!isFetching && q.trim().length >= 2 && results.length === 0 && (
            <div className="caption-2">{t('pos.no_customer_hits')}</div>
          )}
          {results.map((c) => (
            <button key={c.id} type="button" className="sb-row" style={{ width: '100%', textAlign: 'left' }}
              onClick={() => { onPick(c.id, c.name); setOpen(false); setQ('') }}>{c.name}</button>
          ))}
        </div>
      </Sheet>
    </div>
  )
}
