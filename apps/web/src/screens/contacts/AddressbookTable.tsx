/**
 * AddressbookTable — table-based List-Pane for the Adressbuch (Phase G Phase 4 Task 1).
 *
 * Replaces the legacy single-column `<ul.atoll-people-list>` with a CSS-Grid
 * table that supports multiple columns. The default column set is 6 columns:
 *
 *   Checkbox │ Name+Avatar │ Rollen │ Email │ Letzter Kontakt │ Aktionen
 *
 * Tasks 2/3 will introduce a ColumnPicker + density toggle that opt-in the
 * remaining hidden columns (Phone, Saldo, Tags). Task 4 wires up sorting on
 * the header cells. Task 6 fills the checkbox column.
 *
 * For now the header cells are static (no onClick / no Sort arrows) and the
 * checkbox + ⋯-action cells are placeholders that stop propagation so they
 * don't accidentally open the detail panel.
 */

import type { CSSProperties, KeyboardEvent } from 'react'
import { Avatar, avatarColor } from '@/foundation'
import type { Contact, ContactRole } from '@/types/contacts'

// ── Role color dots (mirrors RolesBadgeList color mapping) ──────────────

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

// Significant roles to show as dots (skip internal/system ones)
const DOT_ROLES: ContactRole[] = [
  'instructor', 'student', 'candidate', 'organization_profile',
  'newsletter', 'supplier', 'partner_rep', 'authority',
]

export function RoleDots({ roles }: { roles: ContactRole[] }) {
  const visible = roles.filter((r) => DOT_ROLES.includes(r)).slice(0, 4)
  if (visible.length === 0) return null
  return (
    <div style={{ display: 'flex', gap: 3, alignItems: 'center', flexShrink: 0 }}>
      {visible.map((role) => (
        <span
          key={role}
          title={role}
          style={{
            width: 7,
            height: 7,
            borderRadius: '50%',
            background: ROLE_COLORS[role] ?? 'var(--text-tertiary)',
            flexShrink: 0,
          }}
        />
      ))}
    </div>
  )
}

// ── Table props ─────────────────────────────────────────────────────────

export type AddressbookDensity = 'compact' | 'comfortable'

export interface AddressbookTableProps {
  rows: Contact[]
  selectedId: string | null
  onSelect: (id: string) => void
  density?: AddressbookDensity
}

// 6 default columns. Phone / Saldo / Tags arrive in Task 3 (ColumnPicker).
//   1: checkbox placeholder  (40px)
//   2: avatar + name + sub   (3fr)
//   3: role dots             (100px)
//   4: email                 (3fr)
//   5: last contact          (160px)
//   6: actions placeholder   (44px)
//
// Sizing post-hotfix: the table is now always rendered full-width (no
// DetailPane next to it), so we give every column a little more air.
// The 3fr/3fr split keeps Name and Email balanced — both can ellipsis-
// truncate symmetrically when the viewport narrows.
const GRID_TEMPLATE = '40px 3fr 100px 3fr 160px 44px'

// ── Component ───────────────────────────────────────────────────────────

export function AddressbookTable({
  rows,
  selectedId,
  onSelect,
  density = 'comfortable',
}: AddressbookTableProps) {
  const compact = density === 'compact'
  const rowHeight = compact ? 32 : 44
  const fontSize = compact ? 13 : 14
  const subFontSize = compact ? 11 : 12
  const cellPaddingX = compact ? 8 : 12

  const baseCell: CSSProperties = {
    display: 'flex',
    alignItems: 'center',
    minWidth: 0,
    padding: `0 ${cellPaddingX}px`,
    boxSizing: 'border-box',
  }

  const headerCell: CSSProperties = {
    ...baseCell,
    height: compact ? 28 : 32,
    fontSize: 11,
    fontWeight: 600,
    textTransform: 'uppercase',
    letterSpacing: '0.04em',
    color: 'var(--text-tertiary)',
    borderBottom: '1px solid var(--border-primary)',
  }

  return (
    <div
      role="table"
      aria-label="Kontakte"
      data-density={density}
      style={{
        width: '100%',
        display: 'flex',
        flexDirection: 'column',
        fontSize,
      }}
    >
      {/* Sticky header row */}
      <div
        role="row"
        style={{
          display: 'grid',
          gridTemplateColumns: GRID_TEMPLATE,
          position: 'sticky',
          top: 0,
          background: 'var(--surface-primary)',
          zIndex: 1,
        }}
      >
        <div role="columnheader" aria-label="Auswahl" style={headerCell} />
        <div role="columnheader" style={headerCell}>Name</div>
        <div role="columnheader" style={headerCell}>Rollen</div>
        <div role="columnheader" style={headerCell}>Email</div>
        <div role="columnheader" style={headerCell}>Letzter Kontakt</div>
        <div role="columnheader" aria-label="Aktionen" style={headerCell} />
      </div>

      {/* Body rows */}
      {rows.map((r) => {
        const isActive = r.id === selectedId
        const subtitle =
          r.primary_email ??
          (r.kind === 'organization' ? 'Organisation' : '')

        const handleActivate = () => onSelect(r.id)
        const handleKeyDown = (e: KeyboardEvent<HTMLDivElement>) => {
          if (e.key === 'Enter' || e.key === ' ') {
            e.preventDefault()
            onSelect(r.id)
          }
        }

        return (
          <div
            key={r.id}
            role="row"
            tabIndex={0}
            aria-selected={isActive}
            data-active={isActive || undefined}
            onClick={handleActivate}
            onKeyDown={handleKeyDown}
            style={{
              display: 'grid',
              gridTemplateColumns: GRID_TEMPLATE,
              height: rowHeight,
              cursor: 'pointer',
              background: isActive ? 'var(--surface-secondary)' : 'transparent',
              borderBottom: '1px solid var(--border-primary)',
              transition: 'background 120ms ease',
              outline: 'none',
            }}
            onMouseEnter={(e) => {
              if (!isActive) {
                (e.currentTarget as HTMLDivElement).style.background =
                  'var(--surface-hover, var(--bg-sand))'
              }
            }}
            onMouseLeave={(e) => {
              if (!isActive) {
                (e.currentTarget as HTMLDivElement).style.background = 'transparent'
              }
            }}
          >
            {/* Cell 1: checkbox placeholder (Task 6 fills) */}
            <div
              role="cell"
              style={baseCell}
              onClick={(e) => e.stopPropagation()}
            />

            {/* Cell 2: avatar + name + subtitle */}
            <div role="cell" style={{ ...baseCell, gap: 10, overflow: 'hidden' }}>
              <Avatar
                id={r.id}
                name={r.display_name}
                size="sm"
                color={avatarColor(r.id)}
              />
              <div style={{ display: 'flex', flexDirection: 'column', minWidth: 0, lineHeight: 1.2 }}>
                <div
                  style={{
                    fontWeight: 500,
                    whiteSpace: 'nowrap',
                    overflow: 'hidden',
                    textOverflow: 'ellipsis',
                    color: isActive ? 'var(--brand-blue-800)' : 'var(--text-body)',
                  }}
                >
                  {r.display_name}
                </div>
                {subtitle && (
                  <div
                    style={{
                      fontSize: subFontSize,
                      color: 'var(--text-tertiary)',
                      whiteSpace: 'nowrap',
                      overflow: 'hidden',
                      textOverflow: 'ellipsis',
                    }}
                  >
                    {subtitle}
                  </div>
                )}
              </div>
            </div>

            {/* Cell 3: role dots */}
            <div role="cell" style={baseCell}>
              <RoleDots roles={r.roles} />
            </div>

            {/* Cell 4: email (truncate) */}
            <div
              role="cell"
              style={{
                ...baseCell,
                color: 'var(--text-secondary)',
                whiteSpace: 'nowrap',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
                display: 'block',
                lineHeight: `${rowHeight}px`,
              }}
            >
              {r.primary_email ?? ''}
            </div>

            {/* Cell 5: last contact (stub — Task 4 fills) */}
            <div
              role="cell"
              style={{
                ...baseCell,
                color: 'var(--text-tertiary)',
                fontVariantNumeric: 'tabular-nums',
              }}
            >
              —
            </div>

            {/* Cell 6: actions (⋯) */}
            <div
              role="cell"
              style={{ ...baseCell, padding: 0, justifyContent: 'center' }}
            >
              <button
                type="button"
                aria-label="Aktionen"
                onClick={(e) => e.stopPropagation()}
                style={{
                  width: 24,
                  height: 24,
                  display: 'inline-flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  background: 'transparent',
                  border: 'none',
                  borderRadius: 'var(--radius-sm, 4px)',
                  cursor: 'pointer',
                  color: 'var(--text-tertiary)',
                  fontSize: 16,
                  lineHeight: 1,
                  padding: 0,
                }}
              >
                ⋯
              </button>
            </div>
          </div>
        )
      })}
    </div>
  )
}
