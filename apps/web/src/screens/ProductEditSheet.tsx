import { useEffect, useState, type CSSProperties, type ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { Sheet } from '@/components/Sheet'
import { useProductCategories, useSaveProduct, useAdjustStock, useCurrentTenant } from '@/hooks/useRetail'
import type { CatalogItem } from '@/lib/retailQueries'

interface Props {
  open: boolean
  onClose: () => void
  onSaved: () => void
  item: CatalogItem | null
}

const inputStyle: CSSProperties = {
  padding: '8px 10px', borderRadius: 8, border: '0.5px solid var(--hairline)',
  background: 'var(--surface-strong)', color: 'var(--ink)', font: 'inherit', fontSize: 13.5, width: '100%',
}

function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div>
      <div className="caption-2" style={{ marginBottom: 4 }}>{label.toUpperCase()}</div>
      {children}
    </div>
  )
}

export function ProductEditSheet({ open, onClose, onSaved, item }: Props) {
  const { t } = useTranslation()
  const { data: categories = [] } = useProductCategories()
  const { data: tenantId } = useCurrentTenant()
  const save = useSaveProduct()
  const adjust = useAdjustStock()
  const isEdit = !!item

  const [name, setName] = useState('')
  const [categoryId, setCategoryId] = useState('')
  const [brand, setBrand] = useState('')
  const [model, setModel] = useState('')
  const [sku, setSku] = useState('')
  const [serialized, setSerialized] = useState(false)
  const [price, setPrice] = useState('')
  const [cost, setCost] = useState('')
  const [reorder, setReorder] = useState('0')
  const [adjustQty, setAdjustQty] = useState('')
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!open) return
    setError(null)
    setAdjustQty('')
    if (item) {
      setName(item.name)
      setCategoryId(item.category_id ?? '')
      setBrand(item.brand ?? '')
      setModel(item.model ?? '')
      setSku(item.sku ?? '')
      setSerialized(item.serialized)
      setPrice(String(item.price))
      setCost('')
      setReorder(String(item.reorder_point))
    } else {
      setName(''); setCategoryId(''); setBrand(''); setModel(''); setSku('')
      setSerialized(false); setPrice(''); setCost(''); setReorder('0')
    }
  }, [open, item])

  async function submit() {
    if (!name.trim()) { setError(t('shop.name_required')); return }
    if (!tenantId) { setError(t('common.error')); return }
    setError(null)
    try {
      await save.mutateAsync({
        productId: item?.product_id,
        variantId: item?.variant_id,
        tenantId,
        name: name.trim(),
        categoryId: categoryId || null,
        brand: brand || null,
        model: model || null,
        serialized,
        sku: sku || null,
        price: Number(price || 0),
        cost: Number(cost || 0),
        reorderPoint: Number(reorder || 0),
      })
      onSaved()
      onClose()
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t('common.error'))
    }
  }

  async function doAdjust() {
    if (!item || !adjustQty || Number(adjustQty) === 0) return
    setError(null)
    try {
      await adjust.mutateAsync({ variantId: item.variant_id, qty: Number(adjustQty), reason: 'adjustment' })
      setAdjustQty('')
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t('common.error'))
    }
  }

  return (
    <Sheet open={open} onClose={onClose} title={isEdit ? t('shop.edit_product') : t('shop.new_product')} width={540}>
      <div style={{ display: 'grid', gap: 12 }}>
        <Field label={t('shop.name')}>
          <input style={inputStyle} value={name} onChange={(e) => setName(e.target.value)} />
        </Field>
        <Field label={t('shop.category')}>
          <select style={inputStyle} value={categoryId} onChange={(e) => setCategoryId(e.target.value)}>
            <option value="">—</option>
            {categories.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
          </select>
        </Field>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
          <Field label={t('shop.brand')}><input style={inputStyle} value={brand} onChange={(e) => setBrand(e.target.value)} /></Field>
          <Field label={t('shop.model')}><input style={inputStyle} value={model} onChange={(e) => setModel(e.target.value)} /></Field>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8 }}>
          <Field label={t('shop.sku')}><input style={inputStyle} value={sku} onChange={(e) => setSku(e.target.value)} /></Field>
          <Field label={t('shop.price')}><input style={inputStyle} type="number" min="0" step="0.05" value={price} onChange={(e) => setPrice(e.target.value)} /></Field>
          <Field label={t('shop.cost')}><input style={inputStyle} type="number" min="0" step="0.05" value={cost} onChange={(e) => setCost(e.target.value)} /></Field>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8, alignItems: 'end' }}>
          <Field label={t('shop.reorder_point')}><input style={inputStyle} type="number" min="0" step="1" value={reorder} onChange={(e) => setReorder(e.target.value)} /></Field>
          <label style={{ display: 'flex', gap: 6, alignItems: 'center', paddingBottom: 8 }}>
            <input type="checkbox" checked={serialized} onChange={(e) => setSerialized(e.target.checked)} /> {t('shop.serialized')}
          </label>
        </div>

        {isEdit && (
          <div style={{ display: 'grid', gap: 6, borderTop: '0.5px solid var(--hairline)', paddingTop: 10 }}>
            <div className="caption-2">{t('shop.adjust_stock')} · {t('shop.on_hand')}: {item?.on_hand}</div>
            <div style={{ display: 'flex', gap: 8 }}>
              <input style={inputStyle} type="number" step="1" placeholder="+/−" value={adjustQty} onChange={(e) => setAdjustQty(e.target.value)} />
              <button className="btn-secondary btn" disabled={adjust.isPending || !adjustQty} onClick={doAdjust}>{t('shop.apply')}</button>
            </div>
          </div>
        )}

        {error && <div className="chip chip-red">{error}</div>}

        <div style={{ display: 'flex', gap: 'var(--space-2)' }}>
          <button className="btn-secondary btn" onClick={onClose}>{t('common.cancel')}</button>
          <button className="btn" onClick={submit} disabled={save.isPending || !name.trim()} style={{ flex: 1 }}>
            {save.isPending ? t('common.saving') : t('common.save')}
          </button>
        </div>
      </div>
    </Sheet>
  )
}
