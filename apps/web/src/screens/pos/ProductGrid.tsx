import type { CSSProperties } from 'react'
import { useTranslation } from 'react-i18next'
import { Pill, chf } from '@/foundation'
import type { CatalogItem } from '@/lib/retailQueries'

const cardStyle: CSSProperties = {
  display: 'flex', flexDirection: 'column', gap: 4, padding: '10px 12px', minHeight: 92,
  borderRadius: 10, border: '0.5px solid var(--hairline)', background: 'var(--surface-strong)',
  color: 'var(--ink)', font: 'inherit', textAlign: 'left', cursor: 'pointer',
}

export function ProductGrid({ items, onAdd }: { items: CatalogItem[]; onAdd: (item: CatalogItem) => void }) {
  const { t } = useTranslation()
  if (items.length === 0) {
    return <div className="caption-2" style={{ padding: 'var(--space-3)' }}>{t('pos.no_products')}</div>
  }
  return (
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(150px, 1fr))', gap: 'var(--space-2)' }}>
      {items.map((it) => {
        const soldOut = it.on_hand <= 0 && !it.serialized
        return (
          <button key={it.variant_id} type="button" style={{ ...cardStyle, opacity: soldOut ? 0.5 : 1 }}
            disabled={soldOut} onClick={() => onAdd(it)}>
            <span style={{ fontWeight: 600, fontSize: 13.5 }}>{it.name}</span>
            <span className="caption-2">{it.sku ?? ''}</span>
            <span className="tabular-nums" style={{ marginTop: 'auto' }}>{chf(it.price)}</span>
            <span style={{ display: 'flex', gap: 4, alignItems: 'center' }}>
              <span className="caption-2 tabular-nums">{it.on_hand}</span>
              {it.low && <Pill tone="warning" size="sm">{t('shop.low')}</Pill>}
              {it.serialized && <Pill tone="info" size="sm">{t('shop.serialized')}</Pill>}
            </span>
          </button>
        )
      })}
    </div>
  )
}
