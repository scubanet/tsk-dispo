// apps/web/src/screens/contacts/activity/ActivityFilterBar.tsx
//
// Phase G Phase 5 Task 0 — Filter-Bar für den globalen Activity-Feed
// (/aktivitaet). 3 Chips in T0:
//
//   Event-Typ ▾ · Owner ▾ · Date-Range ▾ · [Filter zurücksetzen]
//
// Tag- und Status-Chips kommen mit Phase 5.x. Layout-Pattern folgt der
// AddressbookFilterBar (flexWrap statt overflowX, sonst clippen die
// absoluten Dropdowns).

import { FilterChipDropdown } from '../FilterChipDropdown'
import type {
  ActivityFilterState,
  OwnerScope,
  DateBucket,
} from '@/hooks/useActivityFilter'
import type { EventType } from '@/types/contactEvents'

// ── Static option lists ─────────────────────────────────────────────────

const EVENT_TYPE_OPTIONS: ReadonlyArray<{ value: EventType; label: string }> = [
  { value: 'note',                 label: 'Notiz' },
  { value: 'call',                 label: 'Anruf' },
  { value: 'email_external',       label: 'Email' },
  { value: 'meeting_past',         label: 'Meeting' },
  { value: 'task',                 label: 'Aufgabe' },
  { value: 'whatsapp_log',         label: 'WhatsApp' },
  { value: 'course_enrollment',    label: 'Kurs-Einschreibung' },
  { value: 'certification_issued', label: 'Zertifizierung' },
  { value: 'saldo_movement',       label: 'Saldo-Bewegung' },
  { value: 'pipeline_change',      label: 'Pipeline-Wechsel' },
  { value: 'intake_checkpoint',    label: 'Intake-Checkpoint' },
  { value: 'skill_checked',        label: 'Skill-Check' },
  { value: 'card_lead_imported',   label: 'Card-Lead' },
  { value: 'role_change',          label: 'Rollen-Wechsel' },
  { value: 'audit_edit',           label: 'Audit-Edit' },
]

const OWNER_OPTIONS: ReadonlyArray<{ value: OwnerScope; label: string }> = [
  { value: 'mine', label: 'Mein' },
  { value: 'all',  label: 'Alle' },
]

const DATE_OPTIONS: ReadonlyArray<{ value: DateBucket; label: string }> = [
  { value: 'today',     label: 'Heute' },
  { value: 'yesterday', label: 'Gestern' },
  { value: 'lt_7d',     label: 'Letzte 7 Tage' },
  { value: 'lt_30d',    label: 'Letzte 30 Tage' },
  { value: 'custom',    label: 'Custom' },
]

// ── Props ───────────────────────────────────────────────────────────────

export interface ActivityFilterBarProps {
  filter: ActivityFilterState
  onChange: (next: Partial<ActivityFilterState>) => void
  onClear: () => void
}

function hasAnyActivityFilter(state: ActivityFilterState): boolean {
  return (
    state.event_types.length > 0 ||
    state.owner_scope !== null ||
    state.date_bucket !== null
  )
}

/**
 * FilterChipDropdown is multi-select by design. For owner/date we want a
 * single value — we coerce the array to the last picked item, or to `null`
 * when the user clears the chip.
 */
function pickLast<T extends string>(values: T[], current: T | null): T | null {
  if (values.length === 0) return null
  // Strip the previous selection so a re-toggle reads as "switched to other"
  const fresh = values.filter((v) => v !== current)
  return fresh.length > 0 ? fresh[fresh.length - 1] : values[values.length - 1]
}

// ── Component ───────────────────────────────────────────────────────────

export function ActivityFilterBar({
  filter,
  onChange,
  onClear,
}: ActivityFilterBarProps) {
  const anyActive = hasAnyActivityFilter(filter)

  return (
    <div
      data-testid="activity-filter-bar"
      style={{
        display: 'flex',
        flexWrap: 'wrap',
        gap: 6,
        padding: '4px 0',
        alignItems: 'center',
        minWidth: 0,
        // KEIN overflow:auto — clippt sonst die absoluten Chip-Dropdowns.
      }}
    >
      <FilterChipDropdown<EventType>
        label="Event-Typ"
        options={EVENT_TYPE_OPTIONS}
        selected={filter.event_types}
        onChange={(v) => onChange({ event_types: v })}
      />

      <FilterChipDropdown<OwnerScope>
        label="Owner"
        options={OWNER_OPTIONS}
        selected={filter.owner_scope ? [filter.owner_scope] : []}
        onChange={(v) => {
          const next = pickLast(v, filter.owner_scope)
          onChange({ owner_scope: next })
        }}
      />

      <FilterChipDropdown<DateBucket>
        label="Zeitraum"
        options={DATE_OPTIONS}
        selected={filter.date_bucket ? [filter.date_bucket] : []}
        onChange={(v) => {
          const next = pickLast(v, filter.date_bucket)
          onChange({
            date_bucket: next,
            // explicit reset of any custom from/to when switching away
            date_from: next === 'custom' ? filter.date_from : undefined,
            date_to: next === 'custom' ? filter.date_to : undefined,
          })
        }}
      />

      {filter.date_bucket === 'custom' && (
        <div
          data-testid="activity-filter-custom-range"
          style={{
            display: 'flex',
            gap: 6,
            alignItems: 'center',
            padding: '0 4px',
          }}
        >
          <input
            type="date"
            aria-label="Von"
            value={filter.date_from ?? ''}
            onChange={(e) =>
              onChange({ date_from: e.target.value || undefined })
            }
            style={{
              padding: '3px 6px',
              borderRadius: 'var(--radius-sm, 6px)',
              border: '1px solid var(--border-primary)',
              fontSize: 12,
              background: 'transparent',
              color: 'var(--text-body)',
            }}
          />
          <span style={{ color: 'var(--text-muted)', fontSize: 12 }}>—</span>
          <input
            type="date"
            aria-label="Bis"
            value={filter.date_to ?? ''}
            onChange={(e) =>
              onChange({ date_to: e.target.value || undefined })
            }
            style={{
              padding: '3px 6px',
              borderRadius: 'var(--radius-sm, 6px)',
              border: '1px solid var(--border-primary)',
              fontSize: 12,
              background: 'transparent',
              color: 'var(--text-body)',
            }}
          />
        </div>
      )}

      {anyActive && (
        <button
          type="button"
          onClick={onClear}
          style={{
            flexShrink: 0,
            marginLeft: 4,
            padding: '3px 10px',
            borderRadius: 'var(--radius-pill, 9999px)',
            border: '1px solid var(--border-primary)',
            background: 'transparent',
            color: 'var(--text-secondary)',
            fontSize: 12,
            fontWeight: 500,
            cursor: 'pointer',
            whiteSpace: 'nowrap',
          }}
        >
          Filter zurücksetzen
        </button>
      )}
    </div>
  )
}
