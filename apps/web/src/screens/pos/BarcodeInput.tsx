import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import type { CatalogItem } from '@/lib/retailQueries'

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
      <div className="pos-field pos-field--scan">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
          <path d="M4 6v12M8 6v12M11 6v12M14 6v12M18 6v12M21 6v12" />
        </svg>
        <input
          value={val}
          autoFocus
          placeholder={t('pos.scan_placeholder')}
          aria-label={t('pos.scan_placeholder')}
          onChange={(e) => { setVal(e.target.value); setErr(false) }}
          onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); submit() } }}
        />
      </div>
      {err && <div className="chip chip-red" style={{ marginTop: 4 }}>{t('pos.scan_unknown', { code: val })}</div>}
    </div>
  )
}
