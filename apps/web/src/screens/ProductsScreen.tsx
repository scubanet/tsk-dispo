import { useState, type CSSProperties } from 'react'
import { useTranslation } from 'react-i18next'
import { PageHeader, KpiCard, KpiGrid, Pill, EmptyState, Loader, chf } from '@/foundation'
import { useCatalog } from '@/hooks/useRetail'
import { useCurrentUser } from '@/hooks/useCurrentUser'
import { canEditOps } from '@/lib/auth'
import { ProductEditSheet } from '@/screens/ProductEditSheet'
import type { CatalogItem } from '@/lib/retailQueries'

const inputStyle: CSSProperties = {
  padding: '8px 10px', borderRadius: 8, border: '0.5px solid var(--hairline)',
  background: 'var(--surface-strong)', color: 'var(--ink)', font: 'inherit', fontSize: 13.5, width: '100%',
}
const rowStyle: CSSProperties = {
  display: 'grid', gridTemplateColumns: '1fr auto auto', alignItems: 'center',
  gap: 'var(--space-3)', padding: 'var(--space-2)', borderBottom: '0.5px solid var(--hairline)', cursor: 'pointer',
}

export function ProductsScreen() {
  const { t } = useTranslation()
  const { data: items = [], isLoading } = useCatalog()
  const { data: user } = useCurrentUser()
  const mayEdit = user ? canEditOps(user.role) : false

  const [q, setQ] = useState('')
  const [createOpen, setCreateOpen] = useState(false)
  const [editing, setEditing] = useState<CatalogItem | null>(null)

  if (isLoading) return <div style={{ padding: 'var(--space-4)' }}><Loader /></div>

  const filtered = items.filter((it) => {
    if (!q.trim()) return true
    const s = q.toLowerCase()
    return it.name.toLowerCase().includes(s) || (it.sku ?? '').toLowerCase().includes(s) || (it.brand ?? '').toLowerCase().includes(s)
  })
  const lowCount = items.filter((it) => it.low).length
  const stockValue = items.reduce((sum, it) => sum + it.on_hand * it.price, 0)

  return (
    <div className="screen" style={{ padding: 'var(--space-4)', display: 'grid', gap: 'var(--space-3)' }}>
      <PageHeader
        title={t('shop.title')}
        subtitle={t('shop.subtitle', { count: items.length })}
        actions={mayEdit ? <button className="btn" onClick={() => setCreateOpen(true)}>{t('shop.new_product')}</button> : undefined}
      />

      <KpiGrid columns={3} gap="md">
        <KpiCard variant="stat" label={t('shop.kpi_skus')} value={items.length} />
        <KpiCard variant={lowCount > 0 ? 'alert' : 'stat'} alertTone="warning" label={t('shop.kpi_low')} value={lowCount} />
        <KpiCard variant="stat" label={t('shop.kpi_stock_value')} value={chf(stockValue)} />
      </KpiGrid>

      <input style={inputStyle} placeholder={t('shop.search')} value={q} onChange={(e) => setQ(e.target.value)} />

      {filtered.length === 0 ? (
        <EmptyState title={t('shop.no_products')} />
      ) : (
        <div>
          {filtered.map((it) => (
            <div key={it.variant_id} style={rowStyle} onClick={() => mayEdit && setEditing(it)}>
              <div style={{ display: 'flex', flexDirection: 'column' }}>
                <span style={{ fontWeight: 600 }}>{it.name}</span>
                <span className="caption-2">{[it.brand, it.sku].filter(Boolean).join(' · ') || '—'}</span>
              </div>
              <span className="tabular-nums">{chf(it.price)}</span>
              <div style={{ display: 'flex', gap: 6, alignItems: 'center', justifyContent: 'flex-end' }}>
                <span className="tabular-nums">{it.on_hand}</span>
                {it.low && <Pill tone="warning" size="sm">{t('shop.low')}</Pill>}
                {it.serialized && <Pill tone="info" size="sm">{t('shop.serialized')}</Pill>}
              </div>
            </div>
          ))}
        </div>
      )}

      <ProductEditSheet open={createOpen} onClose={() => setCreateOpen(false)} onSaved={() => setCreateOpen(false)} item={null} />
      <ProductEditSheet open={!!editing} onClose={() => setEditing(null)} onSaved={() => setEditing(null)} item={editing} />
    </div>
  )
}
