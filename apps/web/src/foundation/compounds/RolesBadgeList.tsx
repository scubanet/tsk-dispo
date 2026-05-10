/**
 * RolesBadgeList — renders ContactRole[] as colored pill badges.
 *
 * Color mapping uses existing brand tokens from tokens.css.
 * Missing from spec: --color-brand-teal, --color-brand-amber, --color-brand-purple,
 * --color-brand-deep, --color-brand-pink — mapped to --brand-teal, --brand-amber,
 * --brand-purple, --brand-deep, --brand-pink respectively.
 */

import { useTranslation } from 'react-i18next'
import type { ContactRole } from '@/types/contacts'

const ROLE_COLORS: Record<ContactRole, string> = {
  instructor:           'var(--brand-blue)',
  student:              'var(--brand-teal)',
  candidate:            'var(--brand-amber)',
  organization_profile: 'var(--brand-purple)',
  cd:                   'var(--brand-deep)',
  owner:                'var(--brand-red)',
  dispatcher:           'var(--brand-pink)',
  newsletter:           'var(--text-tertiary)',
  supplier:             'var(--text-tertiary)',
  partner_rep:          'var(--text-tertiary)',
  authority:            'var(--text-tertiary)',
}

const ROLE_LABEL_KEYS: Record<ContactRole, string> = {
  instructor:           'contacts.role_instructor',
  student:              'contacts.role_student',
  candidate:            'contacts.role_candidate',
  organization_profile: 'contacts.role_org',
  cd:                   'contacts.role_cd',
  owner:                'contacts.role_owner',
  dispatcher:           'contacts.role_dispatcher',
  newsletter:           'contacts.role_newsletter',
  supplier:             'contacts.role_supplier',
  partner_rep:          'contacts.role_partner',
  authority:            'contacts.role_authority',
}

export interface RolesBadgeListProps {
  roles: ContactRole[]
  onClick?: (role: ContactRole) => void
}

export function RolesBadgeList({ roles, onClick }: RolesBadgeListProps) {
  const { t } = useTranslation()
  if (roles.length === 0) return null

  return (
    <div className="roles-badge-list">
      {roles.map((role) => (
        <span
          key={role}
          className={`roles-badge${onClick ? ' roles-badge--clickable' : ''}`}
          style={{ background: ROLE_COLORS[role] ?? 'var(--text-tertiary)' }}
          role={onClick ? 'button' : undefined}
          tabIndex={onClick ? 0 : undefined}
          onClick={onClick ? () => onClick(role) : undefined}
          onKeyDown={
            onClick
              ? (e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); onClick(role) } }
              : undefined
          }
        >
          {ROLE_LABEL_KEYS[role] ? t(ROLE_LABEL_KEYS[role]) : role}
        </span>
      ))}
    </div>
  )
}
