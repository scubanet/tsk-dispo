// apps/web/src/screens/contacts/AddressbookFilterBar.tsx
//
// Phase G Phase 4 Task 5 — Filter-Bar mit 8 Chip-Dropdowns.
//
// Aufbau pro Spec §6.3:
//   Rolle ▾ · Tag ▾ · Status ▾ · Pipeline ▾ · Letzter Kontakt ▾ ·
//   Saldo ▾ · Sprache ▾ · Quelle ▾ · [Filter zurücksetzen]
//
// Tag- und Quelle-Listen sind statisch (Common-Values).
// Echte distinct-Queries werden in Phase 4.x nachgereicht.

import { FilterChipDropdown } from './FilterChipDropdown'
import type {
  AddressbookFilterState,
  SaldoBucket,
  LastContactBucket,
  StatusValue,
} from '@/hooks/useAddressbookFilter'
import type { ContactRole } from '@/types/contacts'

// ── Static option lists ────────────────────────────────────────────────

const ROLE_OPTIONS: ReadonlyArray<{ value: ContactRole; label: string }> = [
  { value: 'instructor',           label: 'Instructor' },
  { value: 'student',              label: 'Schüler' },
  { value: 'candidate',            label: 'Kandidat' },
  { value: 'organization_profile', label: 'Organisation' },
  { value: 'cd',                   label: 'CD' },
  { value: 'owner',                label: 'Owner' },
  { value: 'dispatcher',           label: 'Dispatcher' },
  { value: 'newsletter',           label: 'Newsletter' },
  { value: 'supplier',             label: 'Lieferant' },
  { value: 'partner_rep',          label: 'Partner-Rep' },
  { value: 'authority',            label: 'Behörde' },
]

const TAG_OPTIONS: ReadonlyArray<{ value: string; label: string }> = [
  { value: 'vip',       label: 'VIP' },
  { value: 'lead',      label: 'Lead' },
  { value: 'follow_up', label: 'Follow-Up' },
  { value: 'archive',   label: 'Archiv' },
]

const STATUS_OPTIONS: ReadonlyArray<{ value: StatusValue; label: string }> = [
  { value: 'active',   label: 'Aktiv' },
  { value: 'archived', label: 'Archiviert' },
]

const PIPELINE_OPTIONS: ReadonlyArray<{ value: string; label: string }> = [
  { value: 'lead',        label: 'Lead' },
  { value: 'qualified',   label: 'Qualified' },
  { value: 'opportunity', label: 'Opportunity' },
  { value: 'customer',    label: 'Customer' },
  { value: 'candidate',   label: 'Candidate' },
  { value: 'lost',        label: 'Lost' },
]

const LAST_CONTACT_OPTIONS: ReadonlyArray<{
  value: LastContactBucket
  label: string
}> = [
  { value: 'lt_7d',  label: '< 7 Tage' },
  { value: 'lt_30d', label: '< 30 Tage' },
  { value: 'gt_30d', label: '> 30 Tage' },
]

const SALDO_OPTIONS: ReadonlyArray<{ value: SaldoBucket; label: string }> = [
  { value: 'positive', label: 'Positiv' },
  { value: 'negative', label: 'Negativ' },
  { value: 'zero',     label: 'Null' },
]

const LANGUAGE_OPTIONS: ReadonlyArray<{ value: string; label: string }> = [
  { value: 'de', label: 'Deutsch' },
  { value: 'en', label: 'English' },
  { value: 'fr', label: 'Français' },
  { value: 'it', label: 'Italiano' },
]

const SOURCE_OPTIONS: ReadonlyArray<{ value: string; label: string }> = [
  { value: 'manual',       label: 'Manuell' },
  { value: 'card',         label: 'AtollCard' },
  { value: 'excel_import', label: 'Excel-Import' },
  { value: 'webform',      label: 'Webform' },
]

// ── Props ───────────────────────────────────────────────────────────────

export interface AddressbookFilterBarProps {
  filter: AddressbookFilterState
  onChange: <K extends keyof AddressbookFilterState>(
    key: K,
    values: AddressbookFilterState[K],
  ) => void
  onClear: () => void
}

function hasAnyFilter(state: AddressbookFilterState): boolean {
  return (
    state.roles.length > 0 ||
    state.tags.length > 0 ||
    state.pipeline_stages.length > 0 ||
    state.languages.length > 0 ||
    state.sources.length > 0 ||
    state.saldo_buckets.length > 0 ||
    state.last_contact_buckets.length > 0 ||
    state.status.length > 0
  )
}

// ── Component ───────────────────────────────────────────────────────────

export function AddressbookFilterBar({
  filter,
  onChange,
  onClear,
}: AddressbookFilterBarProps) {
  const anyActive = hasAnyFilter(filter)
  return (
    <div
      data-testid="addressbook-filter-bar"
      style={{
        display: 'flex',
        gap: 6,
        overflowX: 'auto',
        padding: '4px 0',
        scrollbarWidth: 'none',
        maskImage:
          'linear-gradient(to right, black calc(100% - 24px), transparent)',
        WebkitMaskImage:
          'linear-gradient(to right, black calc(100% - 24px), transparent)',
        alignItems: 'center',
        minWidth: 0,
      }}
    >
      <FilterChipDropdown<ContactRole>
        label="Rolle"
        options={ROLE_OPTIONS}
        selected={filter.roles}
        onChange={(v) => onChange('roles', v)}
      />
      <FilterChipDropdown<string>
        label="Tag"
        options={TAG_OPTIONS}
        selected={filter.tags}
        onChange={(v) => onChange('tags', v)}
      />
      <FilterChipDropdown<StatusValue>
        label="Status"
        options={STATUS_OPTIONS}
        selected={filter.status}
        onChange={(v) => onChange('status', v)}
      />
      <FilterChipDropdown<string>
        label="Pipeline"
        options={PIPELINE_OPTIONS}
        selected={filter.pipeline_stages}
        onChange={(v) => onChange('pipeline_stages', v)}
      />
      <FilterChipDropdown<LastContactBucket>
        label="Letzter Kontakt"
        options={LAST_CONTACT_OPTIONS}
        selected={filter.last_contact_buckets}
        onChange={(v) => onChange('last_contact_buckets', v)}
      />
      <FilterChipDropdown<SaldoBucket>
        label="Saldo"
        options={SALDO_OPTIONS}
        selected={filter.saldo_buckets}
        onChange={(v) => onChange('saldo_buckets', v)}
      />
      <FilterChipDropdown<string>
        label="Sprache"
        options={LANGUAGE_OPTIONS}
        selected={filter.languages}
        onChange={(v) => onChange('languages', v)}
      />
      <FilterChipDropdown<string>
        label="Quelle"
        options={SOURCE_OPTIONS}
        selected={filter.sources}
        onChange={(v) => onChange('sources', v)}
      />

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
