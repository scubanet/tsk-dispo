import { useTranslation } from 'react-i18next'
import { Pill, chf } from '@/foundation'
import type { CatalogItem } from '@/lib/retailQueries'

export function ProductGrid({ items, onAdd }: { items: CatalogItem[]; onAdd: (item: CatalogItem) => void }) {
  const { t } = useTranslation()
  if (items.length === 0) {
    return <div className="caption-2" style={{ padding: 'var(--space-3)' }}>{t('pos.no_products')}</div>
  }
  return (
    <div className="pos-products">
      {items.map((it) => {
        const soldOut = it.on_hand <= 0 && !it.serialized
        return (
          <button key={it.variant_id} type="button" className="pos-pcard" disabled={soldOut} onClick={() => onAdd(it)}>
            <span className="pos-pcard__add" aria-hidden="true">+</span>
            <span className="pos-pcard__name">{it.name}</span>
            {it.sku && <span className="pos-pcard__sku">{it.sku}</span>}
            <span className="pos-pcard__price tabular-nums">{chf(it.price)}</span>
            <span className="pos-pcard__meta">
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
