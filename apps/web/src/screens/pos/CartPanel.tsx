import { useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { chf, KpiCard, Stepper } from '@/foundation'
import { useAvailableSerials } from '@/hooks/useRetail'
import { CustomerPicker } from '@/screens/pos/CustomerPicker'
import { type CartLine, lineNet } from '@/screens/pos/types'

const METHODS = ['cash', 'card', 'twint', 'bank'] as const

function SerialSelect({ variantId, value, onChange }: { variantId: string; value: string | null; onChange: (v: string) => void }) {
  const { t } = useTranslation()
  const { data: serials = [] } = useAvailableSerials(variantId)
  return (
    <select className="pos-serial" value={value ?? ''} onChange={(e) => onChange(e.target.value)}>
      <option value="">{t('shop.pick_serial')}</option>
      {serials.map((s) => <option key={s.id} value={s.id}>{s.serial_no}</option>)}
    </select>
  )
}

// Vorgeschlagene Bargeldbeträge: exakt + die nächsten runden Noten darüber.
function cashSuggestions(total: number): number[] {
  if (total <= 0) return []
  const ceilTo = (step: number) => Math.ceil(total / step) * step
  const raw = [total, ceilTo(10), ceilTo(50), ceilTo(100)]
  return [...new Set(raw.map((n) => Math.round(n * 100) / 100))].slice(0, 4)
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
  const units = p.lines.reduce((s, l) => s + l.qty, 0)
  const missingSerial = p.lines.some((l) => l.serialized && !l.serialUnitId)
  const canCheckout = p.lines.length > 0 && !missingSerial && !p.pending

  // Display-only Bargeld-Rechner — beeinflusst den Checkout-Payload nicht.
  const [tendered, setTendered] = useState<number | null>(null)
  useEffect(() => { if (p.lines.length === 0) setTendered(null) }, [p.lines.length])
  const showCash = p.payNow && p.method === 'cash'
  const change = tendered != null && tendered >= total ? Math.round((tendered - total) * 100) / 100 : null

  return (
    <div className="pos-cart">
      <div className="pos-cust">
        <CustomerPicker name={p.customerName} isWalkIn={p.isWalkIn} onPick={p.onPickCustomer} onReset={p.onResetCustomer} />
      </div>

      <KpiCard variant="hero" label={t('pos.to_pay')} value={chf(total)}
        sub={t('pos.cart_summary', { items: p.lines.length, units })} />

      {p.lines.length === 0 ? (
        <div className="caption-2" style={{ padding: 'var(--space-2)' }}>{t('pos.cart_empty')}</div>
      ) : (
        <div className="pos-lines">
          {p.lines.map((l) => (
            <div key={l.variantId} className="pos-line">
              <div>
                <div className="pos-line__name">{l.name}</div>
                {l.sku && <div className="pos-line__sku">{l.sku}</div>}
              </div>
              <div className="pos-line__net tabular-nums">{chf(lineNet(l))}</div>

              <div className="pos-line__ctl">
                <Stepper value={l.qty} min={1} ariaLabel={t('contacts.checkout.qty')}
                  onChange={(n) => p.onQty(l.variantId, n)} />
                <span className="pos-line__disc">
                  {l.discountPct > 0 && <span className="pos-disc-tag">−{l.discountPct}%</span>}
                  <span className="caption-2">{t('pos.discount')} %</span>
                  <input type="number" min="0" max="100" step="1" aria-label={t('pos.discount')}
                    value={l.discountPct} onChange={(e) => p.onDiscount(l.variantId, Number(e.target.value))} />
                </span>
                <button type="button" className="pos-line__x" aria-label={t('contacts.checkout.remove')}
                  onClick={() => p.onRemove(l.variantId)}>✕</button>
              </div>

              {l.serialized && (
                <SerialSelect variantId={l.variantId} value={l.serialUnitId} onChange={(v) => p.onSerial(l.variantId, v)} />
              )}
            </div>
          ))}
        </div>
      )}

      <div className="pos-sum">
        <div className="pos-sum__row"><span>{t('pos.subtotal')}</span><span className="tabular-nums">{chf(subtotal)}</span></div>
        {discount > 0 && (
          <div className="pos-sum__row"><span>{t('pos.discount')}</span><span className="pos-sum__neg tabular-nums">− {chf(discount)}</span></div>
        )}
        <div className="pos-sum__row pos-sum__row--total"><span>{t('pos.total')}</span><span className="tabular-nums">{chf(total)}</span></div>
      </div>

      <label className="pos-paynow">
        <input type="checkbox" checked={p.payNow} onChange={(e) => p.onPayNow(e.target.checked)} />
        {t('contacts.checkout.pay_now')}
      </label>

      {p.payNow && (
        <div className="seg" role="group" aria-label={t('pos.payment_method')}>
          {METHODS.map((m) => (
            <button key={m} type="button" className={p.method === m ? 'active' : ''} onClick={() => p.onMethod(m)}>
              {t(`contacts.checkout.method_${m}`, { defaultValue: m })}
            </button>
          ))}
        </div>
      )}

      {showCash && total > 0 && (
        <>
          <div className="pos-quick">
            {cashSuggestions(total).map((amt, i) => (
              <button key={amt} type="button" className={tendered === amt ? 'is-active' : ''} onClick={() => setTendered(amt)}>
                {i === 0 ? t('pos.exact') : chf(amt)}
              </button>
            ))}
          </div>
          {change != null && (
            <div className="pos-change">
              <span className="caption-2">{t('pos.change')}</span>
              <span className="pos-change__val tabular-nums">{chf(change)}</span>
            </div>
          )}
        </>
      )}

      {missingSerial && <div className="chip chip-red">{t('pos.missing_serial')}</div>}
      {p.error && <div className="chip chip-red">{p.error}</div>}

      <button type="button" className="pos-checkout" disabled={!canCheckout} onClick={p.onCheckout}>
        <span className="pos-checkout__l">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" width="18" height="18" aria-hidden="true">
            <path d="M5 12l5 5L20 7" />
          </svg>
          {p.pending ? t('common.saving') : t('pos.charge_label')}
        </span>
        <span className="tabular-nums">{chf(total)}</span>
      </button>
    </div>
  )
}
