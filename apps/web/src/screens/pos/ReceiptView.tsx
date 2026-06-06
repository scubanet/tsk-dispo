import { useTranslation } from 'react-i18next'
import { chf } from '@/foundation'
import { type CartLine, lineNet } from '@/screens/pos/types'
import '@/styles/pos-print.css'

export interface ReceiptData {
  invoiceNumber: string | null
  customerName: string
  lines: CartLine[]
  total: number
  method: string
  paid: boolean
  date: string
}

export function ReceiptView({ data, onClose }: { data: ReceiptData; onClose: () => void }) {
  const { t } = useTranslation()
  const dateLabel = new Date(data.date).toLocaleDateString('de-CH')
  return (
    <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.45)', display: 'flex',
      alignItems: 'center', justifyContent: 'center', zIndex: 50 }}>
      <div className="pos-receipt glass-thin" style={{ background: 'var(--surface)', color: 'var(--ink)',
        borderRadius: 12, padding: 20, width: 360, maxWidth: '90vw' }}>
        <div style={{ textAlign: 'center', fontWeight: 700, fontSize: 16 }}>Tauchsport Käge · TSK Zürich</div>
        <div className="caption-2" style={{ textAlign: 'center', marginBottom: 10 }}>
          {t('pos.receipt')} {data.invoiceNumber ?? ''} · {dateLabel}
        </div>
        <div className="caption-2" style={{ marginBottom: 8 }}>{t('pos.customer')}: {data.customerName}</div>
        <div style={{ display: 'grid', gap: 4, borderTop: '0.5px solid var(--hairline)', paddingTop: 8 }}>
          {data.lines.map((l) => (
            <div key={l.variantId} style={{ display: 'flex', justifyContent: 'space-between', gap: 8 }}>
              <span>{l.qty}× {l.name}{l.discountPct > 0 ? ` (−${l.discountPct}%)` : ''}</span>
              <span className="tabular-nums">{chf(lineNet(l))}</span>
            </div>
          ))}
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', fontWeight: 700, marginTop: 8,
          borderTop: '0.5px solid var(--hairline)', paddingTop: 8 }}>
          <span>{t('pos.total')}</span><span className="tabular-nums">{chf(data.total)}</span>
        </div>
        <div className="caption-2" style={{ marginTop: 4 }}>
          {data.paid ? t(`contacts.checkout.method_${data.method}`, { defaultValue: data.method }) : t('pos.unpaid')}
        </div>
        <div className="pos-receipt__noprint" style={{ display: 'flex', gap: 8, marginTop: 16 }}>
          <button className="btn-secondary btn" style={{ flex: 1 }} onClick={onClose}>{t('common.close', 'Schliessen')}</button>
          <button className="btn" style={{ flex: 1 }} onClick={() => window.print()}>{t('pos.print')}</button>
        </div>
      </div>
    </div>
  )
}
