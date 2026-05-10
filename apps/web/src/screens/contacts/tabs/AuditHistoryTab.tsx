/**
 * AuditHistoryTab — full audit history for a contact.
 *
 * Fetches contact_audit_log rows (limit 200, descending by changed_at)
 * and renders them as a timestamped list with per-UPDATE diff toggle.
 */

import { useState, useEffect } from 'react'
import { useTranslation } from 'react-i18next'
import { supabase } from '@/lib/supabase'

interface AuditRow {
  id: string
  changed_at: string
  table_name: string
  operation: 'INSERT' | 'UPDATE' | 'DELETE' | string
  changed_fields?: Record<string, unknown> | null
}

interface Props {
  contactId: string
}

export function AuditHistoryTab({ contactId }: Props) {
  const { t } = useTranslation()
  const [rows, setRows] = useState<AuditRow[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let cancelled = false
    setLoading(true)
    void (async () => {
      const { data } = await supabase
        .from('contact_audit_log')
        .select('id, changed_at, table_name, operation, changed_fields')
        .eq('contact_id', contactId)
        .order('changed_at', { ascending: false })
        .limit(200)
      if (!cancelled) {
        setRows((data ?? []) as AuditRow[])
        setLoading(false)
      }
    })()
    return () => { cancelled = true }
  }, [contactId])

  if (loading) return <div className="contact-tab-body tab-stub">{t('contacts.loading_audit')}</div>

  if (rows.length === 0) {
    return <div className="contact-tab-body tab-stub">{t('contacts.no_audit')}</div>
  }

  return (
    <div className="contact-tab-body">
      <ul className="audit-list">
        {rows.map((row) => (
          <li key={row.id} className="audit-entry">
            <div className="audit-entry__meta">
              <span className="audit-entry__time">
                {new Date(row.changed_at).toLocaleString('de-CH')}
              </span>
              <span className={`audit-op audit-op--${row.operation.toLowerCase()}`}>
                {row.operation}
              </span>
              <span className="audit-entry__table">{row.table_name}</span>
            </div>
            {row.operation === 'UPDATE' && row.changed_fields && (
              <details className="audit-entry__diff">
                <summary>{t('contacts.changed_fields')}</summary>
                <pre>{JSON.stringify(row.changed_fields, null, 2)}</pre>
              </details>
            )}
          </li>
        ))}
      </ul>
    </div>
  )
}
