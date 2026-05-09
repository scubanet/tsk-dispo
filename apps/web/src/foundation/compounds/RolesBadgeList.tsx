/**
 * RolesBadgeList — renders ContactRole[] as colored pill badges.
 *
 * Color mapping uses existing brand tokens from tokens.css.
 * Missing from spec: --color-brand-teal, --color-brand-amber, --color-brand-purple,
 * --color-brand-deep, --color-brand-pink — mapped to --brand-teal, --brand-amber,
 * --brand-purple, --brand-deep, --brand-pink respectively.
 */

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

const ROLE_LABELS: Record<ContactRole, string> = {
  instructor:           'TL/DM',
  student:              'Schüler',
  candidate:            'Kandidat',
  organization_profile: 'Org',
  cd:                   'CD',
  owner:                'Owner',
  dispatcher:           'Dispatcher',
  newsletter:           'Newsletter',
  supplier:             'Lieferant',
  partner_rep:          'Partner',
  authority:            'Behörde',
}

export interface RolesBadgeListProps {
  roles: ContactRole[]
  onClick?: (role: ContactRole) => void
}

export function RolesBadgeList({ roles, onClick }: RolesBadgeListProps) {
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
          {ROLE_LABELS[role] ?? role}
        </span>
      ))}
    </div>
  )
}
