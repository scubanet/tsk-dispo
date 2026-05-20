/**
 * ActivityTab — chronological audit log for a contact.
 */

import { useTranslation } from 'react-i18next'
import { useContactAuditLog } from '@/hooks/useContactTabs'

interface Props {
  contactId: string
}

export function ActivityTab({ contactId }: Props) {
  const { t } = useTranslation()
  const { data: rows = [], isLoading } = useContactAuditLog(contactId, 100)

  if (isLoading) return <div className="contact-tab-body tab-stub">{t('contacts.loading_activity')}</div>

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
