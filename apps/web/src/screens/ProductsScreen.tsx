import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { PageHeader, KpiCard, KpiGrid, Pill, EmptyState, Loader, chf } from '@/foundation'
import { useCatalog } from '@/hooks/useRetail'
import { useCurrentUser } from '@/hooks/useCurrentUser'
import { canEditOps } from '@/lib/auth'
import { ProductEditSheet } from '@/screens/ProductEditSheet'
import type { CatalogItem } from '@/lib/retailQueries'

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
    <div className="atoll-screen">
      <PageHeader
        title={t('shop.title')}
        subtitle={t('shop.subtitle', { count: items.length })}
        actions={mayEdit ? <button className="btn" onClick={() => setCreateOpen(true)}>{t('shop.new_product')}</button> : undefined}
      />

      <div className="atoll-screen__body">
        <KpiGrid columns={3} gap="md">
          <KpiCard variant="stat" label={t('shop.kpi_skus')} value={items.length} />
          <KpiCard variant={lowCount > 0 ? 'alert' : 'stat'} alertTone="warning" label={t('shop.kpi_low')} value={lowCount} />
          <KpiCard variant="stat" label={t('shop.kpi_stock_value')} value={chf(stockValue)} />
        </KpiGrid>

        <div className="atoll-panel">
          <div className="atoll-panel__toolbar">
            <label className="atoll-input">
              <input placeholder={t('shop.search')} value={q} onChange={(e) => setQ(e.target.value)} />
            </label>
          </div>

          {filtered.length === 0 ? (
            <div className="atoll-panel__empty">
              <EmptyState title={t('shop.no_products')} />
            </div>
          ) : (
            <div>
              {filtered.map((it) => (
                <div
                  key={it.variant_id}
                  className={`atoll-listrow${mayEdit ? ' atoll-listrow--clickable' : ''}`}
                  onClick={() => mayEdit && setEditing(it)}
                >
                  <div className="atoll-listrow__main">
                    <span className="atoll-listrow__title">{it.name}</span>
                    <span className="caption-2">{[it.brand, it.sku].filter(Boolean).join(' · ') || '—'}</span>
                  </div>
                  <span className="tabular-nums">{chf(it.price)}</span>
                  <div className="atoll-listrow__pills">
                    <span className="tabular-nums">{it.on_hand}</span>
                    {it.low && <Pill tone="warning" size="sm">{t('shop.low')}</Pill>}
                    {it.serialized && <Pill tone="info" size="sm">{t('shop.serialized')}</Pill>}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      <ProductEditSheet open={createOpen} onClose={() => setCreateOpen(false)} onSaved={() => setCreateOpen(false)} item={null} />
      <ProductEditSheet open={!!editing} onClose={() => setEditing(null)} onSaved={() => setEditing(null)} item={editing} />
    </div>
  )
}
