/**
 * ActivityTab — chronological audit log for a contact.
 */

import { useState, useEffect } from 'react'
import { useTranslation } from 'react-i18next'
import { supabase } from '@/lib/supabase'

interface AuditRow {
  id: string
  changed_at: string
  table_name: string
  operation: string
}

interface Props {
  contactId: string
}

export function ActivityTab({ contactId }: Props) {
  const { t } = useTranslation()
  const [rows, setRows] = useState<AuditRow[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let cancelled = false
    setLoading(true)
    void (async () => {
      const { data } = await supabase
        .from('contact_audit_log')
        .select('id, changed_at, table_name, operation')
        .eq('contact_id', contactId)
        .order('changed_at', { ascending: false })
        .limit(100)
      if (!cancelled) {
        setRows((data ?? []) as AuditRow[])
        setLoading(false)
      }
    })()
    return () => { cancelled = true }
  }, [contactId])

  if (loading) return <div className="contact-tab-body tab-stub">{t('contacts.loading_activity')}</div>

  if (rows.length === 0) {
    return <div className="contact-tab-body tab-stub">{t('contacts.no_activity')}</div>
  }

  return (
    <div className="contact-tab-body">
      <ul className="activity-list">
        {rows.map((row) => (
          <li key={row.id} className="activity-list__item">
            <span className="activity-list__time">
              {new Date(row.changed_at).toLocaleString('de-CH')}
            </span>
            <span className="activity-list__op">{row.operation}</span>
            <span className="activity-list__table">{row.table_name}</span>
          </li>
        ))}
      </ul>
    </div>
  )
}
