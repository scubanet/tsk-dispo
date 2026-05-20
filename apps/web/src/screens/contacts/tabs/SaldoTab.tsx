/**
 * SaldoTab — placeholder.
 * Full saldo logic will be extracted from InstructorDetailPanel in Phase G.
 */

import { useTranslation } from 'react-i18next'
import { useContactBookingCount } from '@/hooks/useContactTabs'

interface Props {
  contactId: string
  onUpdated: () => void
}

export function SaldoTab({ contactId }: Props) {
  const { t } = useTranslation()
  const { data: count } = useContactBookingCount(contactId)

  return (
    <div className="contact-tab-body tab-stub">
      <p>{t('contacts.saldo_stub')}</p>
      {count !== undefined && (
        <p style={{ marginTop: 'var(--space-2)', color: 'var(--text-tertiary)', fontSize: 'var(--text-meta)' }}>
          {t('contacts.bookings_count', { count })}
        </p>
      )}
    </div>
  )
}
