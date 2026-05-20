/**
 * OrgMembersTab — lists all contacts with a 'works_at' relationship to this org.
 * Visible only for organization contacts.
 */

import { useTranslation } from 'react-i18next'
import { useOrgMembers } from '@/hooks/useContactTabs'

interface Props {
  orgId: string
  onSelectContact?: (id: string) => void
}

export function OrgMembersTab({ orgId, onSelectContact }: Props) {
  const { t } = useTranslation()
  const { data: members = [], isLoading } = useOrgMembers(orgId)

  if (isLoading) return <div className="contact-tab-body tab-stub">{t('contacts.loading_members')}</div>

  if (members.length === 0) {
    return <div className="contact-tab-body tab-stub">{t('contacts.no_members')}</div>
  }

  return (
    <div className="contact-tab-body">
      <ul className="members-list">
        {members.map((m) => (
          <li
            key={m.id}
            className="members-list__item"
            style={{ cursor: onSelectContact ? 'pointer' : 'default' }}
            onClick={() => onSelectContact?.(m.from_contact_id)}
          >
            <span className="members-list__name">{m.from_contact?.display_name ?? '—'}</span>
            {m.role_at_org && (
              <span className="members-list__role" style={{ color: 'var(--text-tertiary)', fontSize: 'var(--text-meta)' }}>
                {m.role_at_org}
              </span>
            )}
            {m.from_contact?.primary_email && (
              <span className="members-list__email" style={{ color: 'var(--text-tertiary)', fontSize: 'var(--text-meta)' }}>
                {m.from_contact.primary_email}
              </span>
            )}
          </li>
        ))}
      </ul>
    </div>
  )
}
