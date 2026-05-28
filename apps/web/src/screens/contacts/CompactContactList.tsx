/**
 * CompactContactList — single-column contact list for the narrow ListPane
 * mode of the Adressbuch (Phase G Phase 4 — Hotfix Task 1).
 *
 * Used when `?contact=` is set: the AddressbookScreen drops to a master-
 * detail layout and the list pane is too narrow (~270px) to host a multi-
 * column table. We render the pre-T1 `atoll-people-row` button layout —
 * Avatar left, Name + Email subtitle in the middle, RoleDots right.
 *
 * Sibling component to `AddressbookTable`. Both consume the same `Contact[]`
 * and call `onSelect(id)`. The role-dot rendering is shared via the
 * `RoleDots` named export from AddressbookTable.
 */

import { Avatar, avatarColor } from '@/foundation'
import type { Contact } from '@/types/contacts'
import { RoleDots } from './AddressbookTable'

export interface CompactContactListProps {
  rows: Contact[]
  selectedId: string | null
  onSelect: (id: string) => void
}

export function CompactContactList({ rows, selectedId, onSelect }: CompactContactListProps) {
  return (
    <ul className="atoll-people-list" role="list">
      {rows.map((r) => {
        const isActive = r.id === selectedId
        const subtitle =
          r.primary_email ??
          (r.kind === 'organization' ? 'Organisation' : '')

        return (
          <li key={r.id}>
            <button
              type="button"
              className={
                'atoll-people-row' + (isActive ? ' atoll-people-row--active' : '')
              }
              aria-current={isActive ? 'true' : undefined}
              onClick={() => onSelect(r.id)}
            >
              <Avatar
                id={r.id}
                name={r.display_name}
                size="sm"
                color={avatarColor(r.id)}
              />
              <div className="atoll-people-row__main">
                <div className="atoll-people-row__name">{r.display_name}</div>
                {subtitle && (
                  <div className="atoll-people-row__sub">{subtitle}</div>
                )}
              </div>
              <RoleDots roles={r.roles} />
            </button>
          </li>
        )
      })}
    </ul>
  )
}
