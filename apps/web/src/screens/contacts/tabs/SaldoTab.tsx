/**
 * SaldoTab — Finanz-Übersicht eines Kontakts (Phase-1 Kundenfinanzen).
 * Ersetzt den früheren Platzhalter. Liest v_contact_finance / v_invoice_balance
 * und bietet Dispatcher/CD einen POS-Checkout.
 */
import { useState, type CSSProperties } from 'react'
import { useTranslation } from 'react-i18next'
import { KpiCard, KpiGrid, Pill, EmptyState, Loader, chf, dateMedium } from '@/foundation'
import { useContactFinance } from '@/hooks/useContactFinance'
import { useCurrentUser } from '@/hooks/useCurrentUser'
import { canEditOps } from '@/lib/auth'
import { CheckoutSheet } from '@/screens/contacts/CheckoutSheet'

interface Props {
  contactId: string
  onUpdated: () => void
}

const STATUS_TONE: Record<string, 'neutral' | 'info' | 'success' | 'warning'> = {
  draft: 'neutral',
  issued: 'info',
  partially_paid: 'warning',
  paid: 'success',
  void: 'neutral',
  credited: 'warning',
}

const rowStyle: CSSProperties = {
  display: 'grid',
  gridTemplateColumns: '1fr auto auto',
  alignItems: 'center',
  gap: 'var(--space-2)',
  padding: 'var(--space-2)',
  borderBottom: '0.5px solid var(--hairline)',
}

export function SaldoTab({ contactId, onUpdated }: Props) {
  const { t } = useTranslation()
  const { data, isLoading } = useContactFinance(contactId)
  const { data: user } = useCurrentUser()
  const [checkoutOpen, setCheckoutOpen] = useState(false)
  const mayEdit = user ? canEditOps(user.role) : false

  if (isLoading || !data) {
    return <div className="contact-tab-body"><Loader /></div>
  }

  const { summary, invoices, payments } = data

  return (
    <div className="contact-tab-body" style={{ display: 'grid', gap: 'var(--space-3)' }}>
      <KpiGrid columns={3} gap="md">
        <KpiCard variant="hero" label={t('contacts.finance.open_balance')} value={chf(summary.open_invoice_balance)} />
        <KpiCard variant="stat" label={t('contacts.finance.store_credit')} value={chf(summary.store_credit_balance)} />
        <KpiCard variant="stat" label={t('contacts.finance.open_packages')} value={summary.open_package_units} sub={t('contacts.finance.package_units')} />
      </KpiGrid>

      {mayEdit && (
        <div>
          <button className="btn" onClick={() => setCheckoutOpen(true)}>{t('contacts.finance.new_sale')}</button>
        </div>
      )}

      <section>
        <div className="caption-2" style={{ marginBottom: 'var(--space-1)' }}>{t('contacts.finance.invoices').toUpperCase()}</div>
        {invoices.length === 0 ? (
          <EmptyState title={t('contacts.finance.no_invoices')} />
        ) : (
          <div>
            {invoices.map((inv) => (
              <div key={inv.id} style={rowStyle}>
                <div style={{ display: 'flex', flexDirection: 'column' }}>
                  <span style={{ fontWeight: 600 }}>{inv.number ?? t('contacts.finance.status_draft')}</span>
                  <span className="caption-2">{inv.issue_date ? dateMedium(inv.issue_date) : '—'}</span>
                </div>
                <Pill tone={STATUS_TONE[inv.status] ?? 'neutral'} size="sm">
                  {t(`contacts.finance.status_${inv.status}`, { defaultValue: inv.status })}
                </Pill>
                <div className="tabular-nums" style={{ textAlign: 'right', display: 'grid', gap: 2, justifyItems: 'end' }}>
                  <span>{chf(inv.total)}</span>
                  {inv.balance > 0 && (
                    <Pill tone="warning" size="sm">{t('contacts.finance.balance')}: {chf(inv.balance)}</Pill>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </section>

      <section>
        <div className="caption-2" style={{ marginBottom: 'var(--space-1)' }}>{t('contacts.finance.recent_payments').toUpperCase()}</div>
        {payments.length === 0 ? (
          <EmptyState title={t('contacts.finance.no_payments')} />
        ) : (
          <div>
            {payments.map((p) => (
              <div key={p.id} style={rowStyle}>
                <span>{t(`contacts.checkout.method_${p.method}`, { defaultValue: p.method })}</span>
                <span className="caption-2">{dateMedium(p.received_at)}</span>
                <span className="tabular-nums" style={{ textAlign: 'right' }}>{chf(p.amount)}</span>
              </div>
            ))}
          </div>
        )}
      </section>

      <CheckoutSheet open={checkoutOpen} onClose={() => setCheckoutOpen(false)} onSaved={onUpdated} contactId={contactId} />
    </div>
  )
}
