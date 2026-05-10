/**
 * SaldoTab — placeholder.
 * Full saldo logic will be extracted from InstructorDetailPanel in Phase G.
 */

import { useState, useEffect } from 'react'
import { useTranslation } from 'react-i18next'
import { supabase } from '@/lib/supabase'

interface Props {
  contactId: string
  onUpdated: () => void
}

export function SaldoTab({ contactId }: Props) {
  const { t } = useTranslation()
  const [count, setCount] = useState<number | null>(null)

  useEffect(() => {
    supabase
      .from('account_movements')
      .select('*', { count: 'exact', head: true })
      .eq('contact_id', contactId)
      .then(({ count: c }) => setCount(c ?? 0))
  }, [contactId])

  return (
    <div className="contact-tab-body tab-stub">
      <p>{t('contacts.saldo_stub')}</p>
      {count !== null && (
        <p style={{ marginTop: 'var(--space-2)', color: 'var(--text-tertiary)', fontSize: 'var(--text-meta)' }}>
          {t('contacts.bookings_count', { count })}
        </p>
      )}
    </div>
  )
}
