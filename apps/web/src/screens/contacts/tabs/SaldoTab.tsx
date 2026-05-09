/**
 * SaldoTab — placeholder.
 * Full saldo logic will be extracted from InstructorDetailPanel in Phase G.
 */

import { useState, useEffect } from 'react'
import { supabase } from '@/lib/supabase'

interface Props {
  contactId: string
  onUpdated: () => void
}

export function SaldoTab({ contactId }: Props) {
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
      <p>Saldo-Tab — wird in Phase E.5 aus InstructorDetailPanel extrahiert.</p>
      {count !== null && (
        <p style={{ marginTop: 'var(--space-2)', color: 'var(--text-tertiary)', fontSize: 'var(--text-meta)' }}>
          Buchungen für diesen Kontakt: {count}
        </p>
      )}
    </div>
  )
}
