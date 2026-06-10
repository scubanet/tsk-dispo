import { useEffect, useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { PageHeader, Loader } from '@/foundation'
import { useCatalog } from '@/hooks/useRetail'
import { useCurrentUser } from '@/hooks/useCurrentUser'
import { isPrivileged } from '@/lib/auth'
import { useWalkInContact, usePosCheckout } from '@/hooks/usePos'
import { fetchInvoiceNumber } from '@/lib/posQueries'
import { BarcodeInput } from '@/screens/pos/BarcodeInput'
import { ProductGrid } from '@/screens/pos/ProductGrid'
import { CartPanel } from '@/screens/pos/CartPanel'
import { ReceiptView, type ReceiptData } from '@/screens/pos/ReceiptView'
import { type CartLine, lineNet } from '@/screens/pos/types'
import type { CatalogItem } from '@/lib/retailQueries'
import type { CheckoutLine } from '@/lib/financeQueries'
import './pos.css'

export function PosScreen() {
  const { t } = useTranslation()
  const { data: user } = useCurrentUser()
  const { data: catalog = [], isLoading } = useCatalog()
  const { data: walkInId } = useWalkInContact()
  const checkout = usePosCheckout()

  const [q, setQ] = useState('')
  const [lines, setLines] = useState<CartLine[]>([])
  const [contactId, setContactId] = useState<string | null>(null)
  const [contactName, setContactName] = useState(t('pos.walk_in'))
  const [method, setMethod] = useState('cash')
  const [payNow, setPayNow] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [receipt, setReceipt] = useState<ReceiptData | null>(null)

  const isWalkIn = contactId == null || contactId === walkInId
  useEffect(() => {
    if (contactId == null && walkInId) { setContactId(walkInId); setContactName(t('pos.walk_in')) }
  }, [walkInId, contactId, t])

  const filtered = useMemo(() => {
    const s = q.trim().toLowerCase()
    if (!s) return catalog
    return catalog.filter((c) =>
      c.name.toLowerCase().includes(s) || (c.sku ?? '').toLowerCase().includes(s) || (c.brand ?? '').toLowerCase().includes(s))
  }, [catalog, q])

  function addToCart(item: CatalogItem) {
    setError(null)
    setLines((ls) => {
      const idx = ls.findIndex((l) => l.variantId === item.variant_id)
      if (idx >= 0) return ls.map((l, i) => (i === idx ? { ...l, qty: l.qty + 1 } : l))
      return [...ls, {
        variantId: item.variant_id, name: item.name, sku: item.sku,
        unitPrice: item.price, qty: 1, discountPct: 0,
        serialized: item.serialized, serialUnitId: null,
      }]
    })
  }
  const setQty = (id: string, qty: number) =>
    setLines((ls) => ls.map((l) => (l.variantId === id ? { ...l, qty: Math.max(1, qty || 1) } : l)))
  const setDiscount = (id: string, pct: number) =>
    setLines((ls) => ls.map((l) => (l.variantId === id ? { ...l, discountPct: Math.min(100, Math.max(0, pct || 0)) } : l)))
  const setSerial = (id: string, sid: string) =>
    setLines((ls) => ls.map((l) => (l.variantId === id ? { ...l, serialUnitId: sid || null } : l)))
  const removeLine = (id: string) => setLines((ls) => ls.filter((l) => l.variantId !== id))

  function pickCustomer(id: string, name: string) { setContactId(id); setContactName(name) }
  function resetCustomer() { setContactId(walkInId ?? null); setContactName(t('pos.walk_in')) }

  async function onCheckout() {
    if (!contactId) { setError(t('pos.no_walk_in')); return }
    setError(null)
    const total = lines.reduce((s, l) => s + lineNet(l), 0)
    const payload: CheckoutLine[] = lines.map((l) => ({
      description: l.sku ? `${l.name} · ${l.sku}` : l.name,
      quantity: l.qty, unit_price: l.unitPrice, discount_pct: l.discountPct,
      tax_rate_id: null, item_type: 'product', item_ref_id: l.variantId,
      serial_unit_id: l.serialized ? l.serialUnitId : null,
    }))
    try {
      const res = await checkout.mutateAsync({ contactId, lines: payload, method, pay: payNow })
      let number: string | null = null
      try { number = await fetchInvoiceNumber(res.invoice_id) } catch { /* Beleg ohne Nummer */ }
      setReceipt({ invoiceNumber: number, customerName: contactName, lines, total, method, paid: payNow, date: new Date().toISOString() })
      setLines([]); resetCustomer()
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t('common.error'))
    }
  }

  if (!user || !isPrivileged(user.role)) {
    return <div style={{ padding: 'var(--space-4)' }}>{t('pos.not_allowed')}</div>
  }
  if (isLoading) return <div style={{ padding: 'var(--space-4)' }}><Loader /></div>

  return (
    <div className="screen" style={{ padding: 'var(--space-4)', display: 'grid', gap: 'var(--space-3)' }}>
      <PageHeader title={t('pos.title')} subtitle={t('pos.subtitle')} />
      <div className="pos-grid">
        <div className="pos-catalogue">
          <div className="pos-toolbar">
            <BarcodeInput catalog={catalog} onScan={addToCart} />
            <div className="pos-field">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
                <circle cx="11" cy="11" r="7" /><path d="m21 21-4.3-4.3" />
              </svg>
              <input placeholder={t('pos.search')} aria-label={t('pos.search')} value={q} onChange={(e) => setQ(e.target.value)} />
            </div>
          </div>
          <div className="pos-cathead">
            <span className="pos-cathead__t">{t('pos.products')}</span>
            <span className="caption-2 tabular-nums">{filtered.length}</span>
          </div>
          <ProductGrid items={filtered} onAdd={addToCart} />
        </div>
        <CartPanel
          lines={lines} customerName={contactName} isWalkIn={isWalkIn}
          onPickCustomer={pickCustomer} onResetCustomer={resetCustomer}
          onQty={setQty} onDiscount={setDiscount} onSerial={setSerial} onRemove={removeLine}
          method={method} onMethod={setMethod} payNow={payNow} onPayNow={setPayNow}
          onCheckout={onCheckout} pending={checkout.isPending} error={error}
        />
      </div>
      {receipt && <ReceiptView data={receipt} onClose={() => setReceipt(null)} />}
    </div>
  )
}
