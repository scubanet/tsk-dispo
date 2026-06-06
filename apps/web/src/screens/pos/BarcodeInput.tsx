import { useState, type CSSProperties } from 'react'
import { useTranslation } from 'react-i18next'
import type { CatalogItem } from '@/lib/retailQueries'

const inputStyle: CSSProperties = {
  padding: '8px 10px', borderRadius: 8, border: '0.5px solid var(--hairline)',
  background: 'var(--surface-strong)', color: 'var(--ink)', font: 'inherit', fontSize: 13.5, width: '100%',
}

// USB-Scanner = Tastatur + Enter. Lookup gegen den geladenen Katalog (in-memory).
export function BarcodeInput({ catalog, onScan }: { catalog: CatalogItem[]; onScan: (item: CatalogItem) => void }) {
  const { t } = useTranslation()
  const [val, setVal] = useState('')
  const [err, setErr] = useState(false)

  function submit() {
    const code = val.trim()
    if (!code) return
    const hit = catalog.find((c) => c.barcode != null && c.barcode === code)
    if (hit) { onScan(hit); setVal(''); setErr(false) }
    else setErr(true)
  }

  return (
    <div>
      <input style={inputStyle} value={val} autoFocus
        placeholder={t('pos.scan_placeholder')}
        onChange={(e) => { setVal(e.target.value); setErr(false) }}
        onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); submit() } }} />
      {err && <div className="chip chip-red" style={{ marginTop: 4 }}>{t('pos.scan_unknown', { code: val })}</div>}
    </div>
  )
}
