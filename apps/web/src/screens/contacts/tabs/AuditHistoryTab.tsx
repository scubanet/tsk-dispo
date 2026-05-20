/**
 * AuditHistoryTab — full audit history for a contact.
 *
 * Same data source as ActivityTab but with a higher limit (200) and a
 * per-UPDATE diff toggle.
 */

import { useTranslation } from 'react-i18next'
import { useContactAuditLog } from '@/hooks/useContactTabs'

interface Props {
  contactId: string
}

export function AuditHistoryTab({ contactId }: Props) {
  const { t } = useTranslation()
  const { data: rows = [], isLoading } = useContactAuditLog(contactId, 200)

  if (isLoading) return <div className="contact-tab-body tab-stub">{t('contacts.loading_audit')}</div>

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
