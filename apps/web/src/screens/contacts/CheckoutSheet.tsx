import { useEffect, useState, type CSSProperties } from 'react'
import { useTranslation } from 'react-i18next'
import { Sheet } from '@/components/Sheet'
import { chf } from '@/foundation'
import { useActiveTaxRates, usePosCheckout } from '@/hooks/useContactFinance'
import { useCatalog, useAvailableSerials } from '@/hooks/useRetail'
import type { CheckoutLine } from '@/lib/financeQueries'

interface Props {
  open: boolean
  onClose: () => void
  onSaved: () => void
  contactId: string
}

interface DraftLine {
  description: string
  quantity: string
  unit_price: string
  tax_rate_id: string
  item_type: 'custom' | 'product'
  item_ref_id: string      // Varianten-ID bei Produkten
  serial_unit_id: string
  serialized: boolean
}

const METHODS = ['cash', 'card', 'twint', 'bank'] as const
const emptyLine = (): DraftLine => ({
  description: '', quantity: '1', unit_price: '', tax_rate_id: '',
  item_type: 'custom', item_ref_id: '', serial_unit_id: '', serialized: false,
})

const inputStyle: CSSProperties = {
  padding: '8px 10px',
  borderRadius: 8,
  border: '0.5px solid var(--hairline)',
  background: 'var(--surface-strong)',
  color: 'var(--ink)',
  font: 'inherit',
  fontSize: 13.5,
  width: '100%',
}

function SerialSelect({ variantId, value, onChange }: { variantId: string; value: string; onChange: (v: string) => void }) {
  const { t } = useTranslation()
  const { data: serials = [] } = useAvailableSerials(variantId || null)
  return (
    <select style={inputStyle} value={value} onChange={(e) => onChange(e.target.value)}>
      <option value="">{t('shop.pick_serial')}</option>
      {serials.map((s) => (
        <option key={s.id} value={s.id}>{s.serial_no}</option>
      ))}
    </select>
  )
}

export function CheckoutSheet({ open, onClose, onSaved, contactId }: Props) {
  const { t } = useTranslation()
  const { data: taxRates = [] } = useActiveTaxRates()
  const { data: catalog = [] } = useCatalog()
  const checkout = usePosCheckout(contactId)

  const [lines, setLines] = useState<DraftLine[]>([emptyLine()])
  const [method, setMethod] = useState<string>('cash')
  const [payNow, setPayNow] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!open) return
    setLines([emptyLine()])
    setMethod('cash')
    setPayNow(true)
    setError(null)
  }, [open])

  function updateLine(i: number, patch: Partial<DraftLine>) {
    setLines((ls) => ls.map((l, idx) => (idx === i ? { ...l, ...patch } : l)))
  }

  function selectProduct(i: number, variantId: string) {
    if (!variantId) {
      updateLine(i, { item_type: 'custom', item_ref_id: '', serialized: false, serial_unit_id: '' })
      return
    }
    const c = catalog.find((x) => x.variant_id === variantId)
    updateLine(i, {
      item_type: 'product',
      item_ref_id: variantId,
      description: c ? (c.sku ? `${c.name} · ${c.sku}` : c.name) : '',
      unit_price: c ? String(c.price) : '',
      serialized: c?.serialized ?? false,
      serial_unit_id: '',
    })
  }

  const rateById = new Map(taxRates.map((r) => [r.id, r.rate_pct] as [string, number]))
  const valid = lines.filter((l) => l.description.trim() && Number(l.unit_price) > 0)
  const total = valid.reduce((sum, l) => {
    const net = Number(l.quantity || 0) * Number(l.unit_price || 0)
    const rate = l.tax_rate_id ? (rateById.get(l.tax_rate_id) ?? 0) : 0
    return sum + net + (net * rate) / 100
  }, 0)

  async function finish() {
    if (valid.length === 0) {
      setError(t('contacts.checkout.empty'))
      return
    }
    setError(null)
    const payload: CheckoutLine[] = valid.map((l) => ({
      description: l.description.trim(),
      quantity: Number(l.quantity || 1),
      unit_price: Number(l.unit_price),
      tax_rate_id: l.tax_rate_id || null,
      item_type: l.item_type,
      item_ref_id: l.item_type === 'product' ? (l.item_ref_id || null) : null,
      serial_unit_id: l.serialized && l.serial_unit_id ? l.serial_unit_id : null,
    }))
    try {
      await checkout.mutateAsync({ contactId, lines: payload, method, pay: payNow })
      onSaved()
      onClose()
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t('common.error'))
    }
  }

  return (
    <Sheet open={open} onClose={onClose} title={t('contacts.checkout.title')} width={620}>
      <div style={{ display: 'grid', gap: 14 }}>
        {lines.map((l, i) => (
          <div key={i} style={{ display: 'grid', gap: 6, padding: 8, border: '0.5px solid var(--hairline)', borderRadius: 8 }}>
            <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
              <select style={inputStyle} value={l.item_ref_id} onChange={(e) => selectProduct(i, e.target.value)}>
                <option value="">{t('contacts.checkout.manual_line')}</option>
                {catalog.map((c) => (
                  <option key={c.variant_id} value={c.variant_id}>
                    {c.name}{c.sku ? ` · ${c.sku}` : ''} — {chf(c.price)} ({c.on_hand})
                  </option>
                ))}
              </select>
              <button className="btn-ghost btn" aria-label={t('contacts.checkout.remove')} disabled={lines.length === 1}
                onClick={() => setLines((ls) => ls.filter((_, idx) => idx !== i))}>×</button>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 60px 92px 120px', gap: 8 }}>
              <input style={inputStyle} placeholder={t('contacts.checkout.description')} value={l.description} onChange={(e) => updateLine(i, { description: e.target.value })} />
              <input style={inputStyle} type="number" min="0" step="0.5" aria-label={t('contacts.checkout.qty')} value={l.quantity} onChange={(e) => updateLine(i, { quantity: e.target.value })} />
              <input style={inputStyle} type="number" min="0" step="0.05" placeholder={t('contacts.checkout.unit_price')} value={l.unit_price} onChange={(e) => updateLine(i, { unit_price: e.target.value })} />
              <select style={inputStyle} value={l.tax_rate_id} onChange={(e) => updateLine(i, { tax_rate_id: e.target.value })}>
                <option value="">{t('contacts.checkout.no_tax')}</option>
                {taxRates.map((r) => (
                  <option key={r.id} value={r.id}>{r.code} ({r.rate_pct}%)</option>
                ))}
              </select>
            </div>

            {l.serialized && (
              <SerialSelect variantId={l.item_ref_id} value={l.serial_unit_id} onChange={(v) => updateLine(i, { serial_unit_id: v })} />
            )}
          </div>
        ))}

        <button className="btn-secondary btn" onClick={() => setLines((ls) => [...ls, emptyLine()])}>
          {t('contacts.checkout.add_line')}
        </button>

        <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
          <label style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
            <input type="checkbox" checked={payNow} onChange={(e) => setPayNow(e.target.checked)} />
            {t('contacts.checkout.pay_now')}
          </label>
          <select style={{ ...inputStyle, maxWidth: 160 }} value={method} disabled={!payNow} onChange={(e) => setMethod(e.target.value)}>
            {METHODS.map((m) => (
              <option key={m} value={m}>{t(`contacts.checkout.method_${m}`, { defaultValue: m })}</option>
            ))}
          </select>
        </div>

        <div style={{ display: 'flex', justifyContent: 'space-between', fontWeight: 600 }}>
          <span>{t('contacts.checkout.total')}</span>
          <span className="tabular-nums">{chf(total)}</span>
        </div>

        {error && <div className="chip chip-red">{error}</div>}

        <div style={{ display: 'flex', gap: 'var(--space-2)' }}>
          <button className="btn-secondary btn" onClick={onClose}>{t('common.cancel')}</button>
          <button className="btn" onClick={finish} disabled={checkout.isPending || valid.length === 0} style={{ flex: 1 }}>
            {checkout.isPending ? t('common.saving') : t('contacts.checkout.finish')}
          </button>
        </div>
      </div>
    </Sheet>
  )
}
