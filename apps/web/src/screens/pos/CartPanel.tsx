import type { CSSProperties } from 'react'
import { useTranslation } from 'react-i18next'
import { chf } from '@/foundation'
import { useAvailableSerials } from '@/hooks/useRetail'
import { CustomerPicker } from '@/screens/pos/CustomerPicker'
import { type CartLine, lineNet } from '@/screens/pos/types'

const inputStyle: CSSProperties = {
  padding: '6px 8px', borderRadius: 8, border: '0.5px solid var(--hairline)',
  background: 'var(--surface-strong)', color: 'var(--ink)', font: 'inherit', fontSize: 13, width: '100%',
}
const METHODS = ['cash', 'card', 'twint', 'bank'] as const

function SerialSelect({ variantId, value, onChange }: { variantId: string; value: string | null; onChange: (v: string) => void }) {
  const { t } = useTranslation()
  const { data: serials = [] } = useAvailableSerials(variantId)
  return (
    <select style={inputStyle} value={value ?? ''} onChange={(e) => onChange(e.target.value)}>
      <option value="">{t('shop.pick_serial')}</option>
      {serials.map((s) => <option key={s.id} value={s.id}>{s.serial_no}</option>)}
    </select>
  )
}

export interface CartPanelProps {
  lines: CartLine[]
  customerName: string
  isWalkIn: boolean
  onPickCustomer: (id: string, name: string) => void
  onResetCustomer: () => void
  onQty: (variantId: string, qty: number) => void
  onDiscount: (variantId: string, pct: number) => void
  onSerial: (variantId: string, serialId: string) => void
  onRemove: (variantId: string) => void
  method: string
  onMethod: (m: string) => void
  payNow: boolean
  onPayNow: (b: boolean) => void
  onCheckout: () => void
  pending: boolean
  error: string | null
}

export function CartPanel(p: CartPanelProps) {
  const { t } = useTranslation()
  const subtotal = p.lines.reduce((s, l) => s + l.qty * l.unitPrice, 0)
  const discount = p.lines.reduce((s, l) => s + (l.qty * l.unitPrice - lineNet(l)), 0)
  const total = p.lines.reduce((s, l) => s + lineNet(l), 0)
  const missingSerial = p.lines.some((l) => l.serialized && !l.serialUnitId)
  const canCheckout = p.lines.length > 0 && !missingSerial && !p.pending

  return (
    <div style={{ display: 'grid', gap: 12, alignContent: 'start' }}>
      <CustomerPicker name={p.customerName} isWalkIn={p.isWalkIn} onPick={p.onPickCustomer} onReset={p.onResetCustomer} />

      {p.lines.length === 0 ? (
        <div className="caption-2" style={{ padding: 'var(--space-3)' }}>{t('pos.cart_empty')}</div>
      ) : (
        <div style={{ display: 'grid', gap: 8 }}>
          {p.lines.map((l) => (
            <div key={l.variantId} style={{ display: 'grid', gap: 6, padding: 8, border: '0.5px solid var(--hairline)', borderRadius: 8 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8 }}>
                <span style={{ fontWeight: 600, fontSize: 13.5 }}>{l.name}</span>
                <button type="button" className="btn-ghost btn" aria-label={t('contacts.checkout.remove')} onClick={() => p.onRemove(l.variantId)}>×</button>
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: '64px 1fr 70px', gap: 8, alignItems: 'center' }}>
                <input style={inputStyle} type="number" min="1" step="1" aria-label={t('contacts.checkout.qty')}
                  value={l.qty} onChange={(e) => p.onQty(l.variantId, Number(e.target.value))} />
                <span className="tabular-nums caption-2">{chf(l.unitPrice)} × {l.qty}</span>
                <span className="tabular-nums" style={{ textAlign: 'right', fontWeight: 600 }}>{chf(lineNet(l))}</span>
              </div>
              <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
                <span className="caption-2">{t('pos.discount')} %</span>
                <input style={{ ...inputStyle, maxWidth: 80 }} type="number" min="0" max="100" step="1"
                  value={l.discountPct} onChange={(e) => p.onDiscount(l.variantId, Number(e.target.value))} />
              </div>
              {l.serialized && (
                <SerialSelect variantId={l.variantId} value={l.serialUnitId} onChange={(v) => p.onSerial(l.variantId, v)} />
              )}
            </div>
          ))}
        </div>
      )}

      <div style={{ display: 'grid', gap: 4 }}>
        <Row label={t('pos.subtotal')} value={chf(subtotal)} />
        {discount > 0 && <Row label={t('pos.discount')} value={`− ${chf(discount)}`} />}
        <Row label={t('pos.total')} value={chf(total)} strong />
      </div>

      <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
        <label style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
          <input type="checkbox" checked={p.payNow} onChange={(e) => p.onPayNow(e.target.checked)} />
          {t('contacts.checkout.pay_now')}
        </label>
        <select style={{ ...inputStyle, maxWidth: 160 }} value={p.method} disabled={!p.payNow} onChange={(e) => p.onMethod(e.target.value)}>
          {METHODS.map((m) => <option key={m} value={m}>{t(`contacts.checkout.method_${m}`, { defaultValue: m })}</option>)}
        </select>
      </div>

      {missingSerial && <div className="chip chip-red">{t('pos.missing_serial')}</div>}
      {p.error && <div className="chip chip-red">{p.error}</div>}

      <button className="btn" style={{ padding: '12px' }} disabled={!canCheckout} onClick={p.onCheckout}>
        {p.pending ? t('common.saving') : t('pos.charge', { total: chf(total) })}
      </button>
    </div>
  )
}

function Row({ label, value, strong }: { label: string; value: string; strong?: boolean }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', fontWeight: strong ? 600 : 400 }}>
      <span>{label}</span><span className="tabular-nums">{value}</span>
    </div>
  )
}
