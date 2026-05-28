/**
 * AddressbookTable — table-based List-Pane for the Adressbuch (Phase G Phase 4 Task 1).
 *
 * Layout: CSS-Grid table. Spalten sind dynamisch konfigurierbar über die
 * `columns`-Prop (Task 3 — ColumnPicker). Header- und Body-Rows rendern beide
 * exakt die Liste aus `columns` in derselben Reihenfolge, eingefasst von:
 *
 *   [ Checkbox 40px ] … dynamic columns … [ Aktionen 44px ]
 *
 * Task 4 wires up sorting on the header cells. Task 6 fills the checkbox
 * column. Task 5 fills filter logic.
 */

import { useEffect, useRef } from 'react'
import type { CSSProperties, KeyboardEvent } from 'react'
import { Avatar, avatarColor } from '@/foundation'
import type { Contact, ContactRole } from '@/types/contacts'
import {
  COLUMN_CATALOG,
  defaultVisibleIds,
  type ColumnId,
} from '@/hooks/useAddressbookColumns'
import type { SortSpec } from '@/lib/contactQueries'
import { COLUMN_TO_SORT_FIELD } from '@/hooks/useAddressbookSort'
import { RowQuickActions } from './RowQuickActions'

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
  /**
   * Liste der sichtbaren Spalten (Reihenfolge wird übernommen). Wenn undefined,
   * verwendet die Tabelle die `defaultVisible: true`-Spalten aus dem Catalog.
   */
  columns?: ColumnId[]
  /**
   * Aktiver Multi-Sort. Reihenfolge entspricht der Sort-Priorität (erster
   * Eintrag = primärer Sort). Sortierbare Header-Cells zeigen einen
   * `↑`/`↓`-Indicator, wenn ihr `field` hier vorkommt.
   */
  sort?: SortSpec[]
  /**
   * Wird beim Klick auf einen sortierbaren Header gerufen. `shiftKey=true`
   * signalisiert Multi-Sort-Modus. Bei nicht-sortierbaren Spalten ist die
   * Header-Zelle ein `<div>` und feuert nichts.
   */
  onHeaderClick?: (columnId: ColumnId, shiftKey: boolean) => void
  // ── Task 6: Bulk-Selection ────────────────────────────────────────────
  /** Set der aktuell ausgewählten Row-IDs. */
  selected?: Set<string>
  /** Helper: true wenn `id` selektiert ist. Wird pro Row aufgerufen. */
  isSelected?: (id: string) => boolean
  /** Toggle für eine einzelne Row-ID. */
  onToggleRow?: (id: string) => void
  /** Header-Checkbox-Click — Caller entscheidet "alle aus" oder "alle an". */
  onToggleAll?: () => void
  /** true wenn ALLE currentIds ausgewählt sind (Header checkbox: checked). */
  allSelected?: boolean
  /** true wenn 1..n-1 ausgewählt sind (Header checkbox: indeterminate). */
  someSelected?: boolean
}

const CATALOG_BY_ID: Record<ColumnId, (typeof COLUMN_CATALOG)[number]> =
  COLUMN_CATALOG.reduce((acc, c) => {
    acc[c.id] = c
    return acc
  }, {} as Record<ColumnId, (typeof COLUMN_CATALOG)[number]>)

function buildGridTemplate(columns: ColumnId[]): string {
  const middle = columns
    .map((id) => CATALOG_BY_ID[id]?.gridWidth ?? '1fr')
    .join(' ')
  // Actions-Cell wurde mit Task 9 erweitert: vorher 44px (nur ⋯), jetzt 88px
  // (Quick-Mail + Quick-Notiz + ⋯).
  return `40px ${middle} 88px`
}

// ── Indeterminate-fähige Header-Checkbox ──────────────────────────────
// React kennt das `indeterminate`-Attribut nicht als JSX-Prop — es muss
// imperativ via `ref.current.indeterminate = …` nach jedem Render gesetzt
// werden. Dieser Wrapper macht das gekapselt.
interface BulkHeaderCheckboxProps {
  checked: boolean
  indeterminate: boolean
  onChange: () => void
}
function BulkHeaderCheckbox({ checked, indeterminate, onChange }: BulkHeaderCheckboxProps) {
  const ref = useRef<HTMLInputElement>(null)
  useEffect(() => {
    if (ref.current) ref.current.indeterminate = indeterminate
  }, [indeterminate])
  return (
    <input
      ref={ref}
      type="checkbox"
      aria-label="Alle auswählen"
      title="Alle auswählen / abwählen"
      checked={checked}
      onChange={onChange}
      style={{ cursor: 'pointer', margin: 0 }}
    />
  )
}

function formatDateCH(value: string | null | undefined): string {
  if (!value) return '—'
  const d = new Date(value)
  if (Number.isNaN(d.getTime())) return '—'
  return d.toLocaleDateString('de-CH')
}

// ── Component ───────────────────────────────────────────────────────────

export function AddressbookTable({
  rows,
  selectedId,
  onSelect,
  density = 'comfortable',
  columns,
  sort,
  onHeaderClick,
  selected,
  isSelected,
  onToggleRow,
  onToggleAll,
  allSelected = false,
  someSelected = false,
}: AddressbookTableProps) {
  const bulkEnabled = !!onToggleRow && !!onToggleAll
  void selected // currently only used by callers; props are accepted for completeness
  const compact = density === 'compact'
  const rowHeight = compact ? 32 : 44
  const fontSize = compact ? 13 : 14
  const subFontSize = compact ? 11 : 12
  const cellPaddingX = compact ? 8 : 12

  const cols = columns ?? defaultVisibleIds()
  const gridTemplate = buildGridTemplate(cols)

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

  const truncate: CSSProperties = {
    whiteSpace: 'nowrap',
    overflow: 'hidden',
    textOverflow: 'ellipsis',
    display: 'block',
    lineHeight: `${rowHeight}px`,
    width: '100%',
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
          gridTemplateColumns: gridTemplate,
          position: 'sticky',
          top: 0,
          background: 'var(--surface-primary)',
          zIndex: 1,
        }}
      >
        <div
          role="columnheader"
          aria-label="Auswahl"
          style={{ ...headerCell, justifyContent: 'center' }}
          onClick={(e) => e.stopPropagation()}
        >
          {bulkEnabled && (
            <BulkHeaderCheckbox
              checked={allSelected}
              indeterminate={someSelected}
              onChange={() => onToggleAll!()}
            />
          )}
        </div>
        {cols.map((id) => {
          const def = CATALOG_BY_ID[id]
          const label = def?.labelKey ?? id
          const sortField = COLUMN_TO_SORT_FIELD[id]
          const isSortable = def?.sortable === true && !!sortField
          const activeSort = sortField
            ? sort?.find((s) => s.field === sortField)
            : undefined
          const indicator = activeSort
            ? activeSort.direction === 'asc'
              ? ' ↑'
              : ' ↓'
            : ''

          if (isSortable && onHeaderClick) {
            return (
              <div key={id} role="columnheader" style={headerCell}>
                <button
                  type="button"
                  onClick={(e) => onHeaderClick(id, e.shiftKey)}
                  style={{
                    background: 'transparent',
                    border: 0,
                    padding: 0,
                    margin: 0,
                    font: 'inherit',
                    color: 'inherit',
                    textTransform: 'inherit',
                    letterSpacing: 'inherit',
                    cursor: 'pointer',
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: 2,
                  }}
                >
                  {label}
                  {indicator && (
                    <span aria-hidden="true" style={{ fontWeight: 700 }}>
                      {indicator}
                    </span>
                  )}
                </button>
              </div>
            )
          }

          return (
            <div key={id} role="columnheader" style={headerCell}>
              {label}
            </div>
          )
        })}
        <div role="columnheader" aria-label="Aktionen" style={headerCell} />
      </div>

      {/* Body rows */}
      {rows.map((r) => {
        const isActive = r.id === selectedId
        const rowSelected = isSelected ? isSelected(r.id) : false
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

        const rowBackground = isActive
          ? 'var(--surface-secondary)'
          : rowSelected
          ? 'var(--surface-selected, #f0f7ff)'
          : 'transparent'

        return (
          <div
            key={r.id}
            role="row"
            tabIndex={0}
            aria-selected={isActive}
            data-active={isActive || undefined}
            data-selected={rowSelected || undefined}
            onClick={handleActivate}
            onKeyDown={handleKeyDown}
            style={{
              display: 'grid',
              gridTemplateColumns: gridTemplate,
              height: rowHeight,
              cursor: 'pointer',
              background: rowBackground,
              borderBottom: '1px solid var(--border-primary)',
              transition: 'background 120ms ease',
              outline: 'none',
            }}
            onMouseEnter={(e) => {
              if (!isActive && !rowSelected) {
                (e.currentTarget as HTMLDivElement).style.background =
                  'var(--surface-hover, var(--bg-sand))'
              }
            }}
            onMouseLeave={(e) => {
              if (!isActive && !rowSelected) {
                (e.currentTarget as HTMLDivElement).style.background = 'transparent'
              }
            }}
          >
            {/* Cell 1: bulk-selection checkbox (Task 6). */}
            <div
              role="cell"
              style={{ ...baseCell, justifyContent: 'center' }}
              onClick={(e) => e.stopPropagation()}
            >
              {bulkEnabled && (
                <input
                  type="checkbox"
                  aria-label={`Auswählen ${r.display_name}`}
                  checked={rowSelected}
                  onChange={() => onToggleRow!(r.id)}
                  onClick={(e) => e.stopPropagation()}
                  style={{ cursor: 'pointer', margin: 0 }}
                />
              )}
            </div>

            {/* Dynamic cells in `cols` order */}
            {cols.map((id) => renderCell(id, r, {
              baseCell,
              truncate,
              isActive,
              subtitle,
              subFontSize,
              rowHeight,
            }))}

            {/* Last cell: Quick-Actions (Task 9) + actions (⋯) */}
            <div
              role="cell"
              style={{
                ...baseCell,
                padding: 0,
                justifyContent: 'center',
                gap: compact ? 2 : 4,
              }}
            >
              <RowQuickActions contact={r} density={density} />
              <button
                type="button"
                aria-label="Aktionen"
                onClick={(e) => e.stopPropagation()}
                style={{
                  width: compact ? 18 : 22,
                  height: compact ? 18 : 22,
                  display: 'inline-flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  background: 'transparent',
                  border: 'none',
                  borderRadius: 'var(--radius-sm, 4px)',
                  cursor: 'pointer',
                  color: 'var(--text-tertiary)',
                  fontSize: compact ? 14 : 16,
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

// ── Cell renderer (per ColumnId) ────────────────────────────────────────

interface CellCtx {
  baseCell: CSSProperties
  truncate: CSSProperties
  isActive: boolean
  subtitle: string
  subFontSize: number
  rowHeight: number
}

function renderCell(id: ColumnId, r: Contact, ctx: CellCtx) {
  const { baseCell, truncate, isActive, subtitle, subFontSize } = ctx
  const dash = (
    <span style={{ color: 'var(--text-tertiary)' }}>—</span>
  )

  switch (id) {
    case 'name':
      return (
        <div key={id} role="cell" style={{ ...baseCell, gap: 10, overflow: 'hidden' }}>
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
      )

    case 'roles':
      return (
        <div key={id} role="cell" style={baseCell}>
          <RoleDots roles={r.roles} />
        </div>
      )

    case 'email':
      return (
        <div
          key={id}
          role="cell"
          style={{ ...baseCell, color: 'var(--text-secondary)', overflow: 'hidden' }}
        >
          <span style={truncate}>{r.primary_email ?? ''}</span>
        </div>
      )

    case 'phone': {
      const p = r.phones?.[0]?.e164
      return (
        <div key={id} role="cell" style={{ ...baseCell, color: 'var(--text-secondary)', overflow: 'hidden' }}>
          {p ? <span style={truncate}>{p}</span> : dash}
        </div>
      )
    }

    case 'last_contact':
      // Stub — Task 4 fills with last_contact_at aggregate.
      return (
        <div
          key={id}
          role="cell"
          style={{ ...baseCell, color: 'var(--text-tertiary)', fontVariantNumeric: 'tabular-nums' }}
        >
          {dash}
        </div>
      )

    case 'saldo':
      // Stub — braucht v_contact_balance-Join, kommt in T4 oder via eigenem Hook.
      return (
        <div
          key={id}
          role="cell"
          style={{ ...baseCell, color: 'var(--text-tertiary)', fontVariantNumeric: 'tabular-nums', justifyContent: 'flex-end' }}
        >
          {dash}
        </div>
      )

    case 'tags': {
      const tags = r.tags ?? []
      if (tags.length === 0) return (
        <div key={id} role="cell" style={baseCell}>{dash}</div>
      )
      const shown = tags.slice(0, 3).join(', ')
      const extra = tags.length > 3 ? ` +${tags.length - 3}` : ''
      return (
        <div key={id} role="cell" style={{ ...baseCell, color: 'var(--text-secondary)', overflow: 'hidden' }}>
          <span style={truncate}>{shown}{extra}</span>
        </div>
      )
    }

    case 'org':
      // Stub — braucht contact_relationships works_at-Join, kommt später.
      return (
        <div key={id} role="cell" style={baseCell}>{dash}</div>
      )

    case 'pipeline_stage':
      // Stub — braucht contact_student-Join. listContacts joinet das nur, wenn
      // pipeline_stages-Filter aktiv ist; daher hier konsistent Dash.
      return (
        <div key={id} role="cell" style={baseCell}>{dash}</div>
      )

    case 'sprache': {
      const lang = r.languages?.[0]
      return (
        <div key={id} role="cell" style={{ ...baseCell, color: 'var(--text-secondary)' }}>
          {lang ? <span>{lang}</span> : dash}
        </div>
      )
    }

    case 'quelle':
      return (
        <div key={id} role="cell" style={{ ...baseCell, color: 'var(--text-secondary)', overflow: 'hidden' }}>
          {r.source ? <span style={truncate}>{r.source}</span> : dash}
        </div>
      )

    case 'geburtstag':
      return (
        <div key={id} role="cell" style={{ ...baseCell, color: 'var(--text-secondary)', fontVariantNumeric: 'tabular-nums' }}>
          {r.birth_date ? <span>{formatDateCH(r.birth_date)}</span> : dash}
        </div>
      )

    case 'padi_number':
      // Stub — braucht contact_instructor-Join.
      return (
        <div key={id} role="cell" style={baseCell}>{dash}</div>
      )

    case 'created_at':
      return (
        <div key={id} role="cell" style={{ ...baseCell, color: 'var(--text-tertiary)', fontVariantNumeric: 'tabular-nums' }}>
          <span>{formatDateCH(r.created_at)}</span>
        </div>
      )

    default:
      return <div key={id} role="cell" style={baseCell} />
  }
}
