// apps/web/src/hooks/useAddressbookFilter.ts
//
// Phase G Phase 4 Task 5 — Filter-State für die AddressbookFilterBar.
//
// Liest/schreibt URL-Param `filter` in der Form
//   `?filter=key:val1|val2,key:val1`
// Pipe-separierte Values pro Key, Komma zwischen Keys.
// Beispiel: `?filter=role:instructor|cd,tag:vip,saldo:negative`.
//
// State-Shape — alle Filter-Dimensionen als Arrays (auch die Buckets, deren
// Backend-Filter aktuell `single value`-only ist). Mapping auf
// ContactListFilter passiert im AddressbookScreen-Wire-up.

import { useCallback, useMemo } from 'react'
import { useSearchParams } from 'react-router-dom'
import type { ContactRole } from '@/types/contacts'

// ── Public types ────────────────────────────────────────────────────────

export type SaldoBucket = 'positive' | 'negative' | 'zero'
export type LastContactBucket = 'lt_7d' | 'lt_30d' | 'gt_30d'
export type StatusValue = 'active' | 'archived'

export interface AddressbookFilterState {
  roles: ContactRole[]
  tags: string[]
  pipeline_stages: string[]
  languages: string[]
  sources: string[]
  saldo_buckets: SaldoBucket[]
  last_contact_buckets: LastContactBucket[]
  status: StatusValue[]
}

export const EMPTY_FILTER: AddressbookFilterState = {
  roles: [],
  tags: [],
  pipeline_stages: [],
  languages: [],
  sources: [],
  saldo_buckets: [],
  last_contact_buckets: [],
  status: [],
}

// ── Validation sets ─────────────────────────────────────────────────────

const VALID_ROLES = new Set<ContactRole>([
  'instructor',
  'student',
  'candidate',
  'organization_profile',
  'cd',
  'owner',
  'dispatcher',
  'newsletter',
  'supplier',
  'partner_rep',
  'authority',
])

const VALID_SALDO = new Set<SaldoBucket>(['positive', 'negative', 'zero'])
const VALID_LAST = new Set<LastContactBucket>(['lt_7d', 'lt_30d', 'gt_30d'])
const VALID_STATUS = new Set<StatusValue>(['active', 'archived'])

// Known short URL-keys mapped to state-keys.
// Pipeline/language/source/tag don't have a hard validation list — those are
// open arrays. We just trust the param and pass values through.
type UrlKey =
  | 'role'
  | 'tag'
  | 'pipeline'
  | 'language'
  | 'source'
  | 'saldo'
  | 'last_contact'
  | 'status'

const URL_KEYS: ReadonlyArray<UrlKey> = [
  'role',
  'tag',
  'pipeline',
  'language',
  'source',
  'saldo',
  'last_contact',
  'status',
]

// ── Parse / serialize ───────────────────────────────────────────────────

export function parseFilterParam(raw: string | null): AddressbookFilterState {
  const state: AddressbookFilterState = {
    roles: [],
    tags: [],
    pipeline_stages: [],
    languages: [],
    sources: [],
    saldo_buckets: [],
    last_contact_buckets: [],
    status: [],
  }
  if (!raw) return state

  for (const part of raw.split(',')) {
    const trimmed = part.trim()
    if (!trimmed) continue
    const colonIdx = trimmed.indexOf(':')
    if (colonIdx <= 0) continue
    const key = trimmed.slice(0, colonIdx).trim() as UrlKey
    if (!URL_KEYS.includes(key)) continue
    const rawValues = trimmed
      .slice(colonIdx + 1)
      .split('|')
      .map((v) => v.trim())
      .filter((v) => v.length > 0)
    if (rawValues.length === 0) continue

    switch (key) {
      case 'role': {
        const valid = rawValues.filter((v): v is ContactRole =>
          VALID_ROLES.has(v as ContactRole),
        )
        if (valid.length > 0) state.roles.push(...valid)
        break
      }
      case 'tag':
        state.tags.push(...rawValues)
        break
      case 'pipeline':
        state.pipeline_stages.push(...rawValues)
        break
      case 'language':
        state.languages.push(...rawValues)
        break
      case 'source':
        state.sources.push(...rawValues)
        break
      case 'saldo': {
        const valid = rawValues.filter((v): v is SaldoBucket =>
          VALID_SALDO.has(v as SaldoBucket),
        )
        if (valid.length > 0) state.saldo_buckets.push(...valid)
        break
      }
      case 'last_contact': {
        const valid = rawValues.filter((v): v is LastContactBucket =>
          VALID_LAST.has(v as LastContactBucket),
        )
        if (valid.length > 0) state.last_contact_buckets.push(...valid)
        break
      }
      case 'status': {
        const valid = rawValues.filter((v): v is StatusValue =>
          VALID_STATUS.has(v as StatusValue),
        )
        if (valid.length > 0) state.status.push(...valid)
        break
      }
    }
  }

  return state
}

export function serializeFilter(state: AddressbookFilterState): string {
  const parts: string[] = []
  if (state.roles.length > 0) parts.push(`role:${state.roles.join('|')}`)
  if (state.tags.length > 0) parts.push(`tag:${state.tags.join('|')}`)
  if (state.pipeline_stages.length > 0)
    parts.push(`pipeline:${state.pipeline_stages.join('|')}`)
  if (state.languages.length > 0)
    parts.push(`language:${state.languages.join('|')}`)
  if (state.sources.length > 0) parts.push(`source:${state.sources.join('|')}`)
  if (state.saldo_buckets.length > 0)
    parts.push(`saldo:${state.saldo_buckets.join('|')}`)
  if (state.last_contact_buckets.length > 0)
    parts.push(`last_contact:${state.last_contact_buckets.join('|')}`)
  if (state.status.length > 0) parts.push(`status:${state.status.join('|')}`)
  return parts.join(',')
}

export function isFilterEmpty(state: AddressbookFilterState): boolean {
  return (
    state.roles.length === 0 &&
    state.tags.length === 0 &&
    state.pipeline_stages.length === 0 &&
    state.languages.length === 0 &&
    state.sources.length === 0 &&
    state.saldo_buckets.length === 0 &&
    state.last_contact_buckets.length === 0 &&
    state.status.length === 0
  )
}

// ── Hook ────────────────────────────────────────────────────────────────

export interface UseAddressbookFilterResult {
  filter: AddressbookFilterState
  setFilter: (partial: Partial<AddressbookFilterState>) => void
  /**
   * Replace the entire filter state in one go (e.g. when applying a saved
   * view). Empty fields auto-prune the URL param like `setFilter` does.
   */
  replaceAll: (next: AddressbookFilterState) => void
  clear: () => void
}

export function useAddressbookFilter(): UseAddressbookFilterResult {
  const [searchParams, setSearchParams] = useSearchParams()

  const raw = searchParams.get('filter')
  const filter = useMemo<AddressbookFilterState>(
    () => parseFilterParam(raw),
    [raw],
  )

  const writeFilter = useCallback(
    (next: AddressbookFilterState) => {
      setSearchParams(
        (prev) => {
          const params = new URLSearchParams(prev)
          if (isFilterEmpty(next)) {
            params.delete('filter')
          } else {
            params.set('filter', serializeFilter(next))
          }
          return params
        },
        { replace: true },
      )
    },
    [setSearchParams],
  )

  const setFilter = useCallback(
    (partial: Partial<AddressbookFilterState>) => {
      const next: AddressbookFilterState = { ...filter, ...partial }
      writeFilter(next)
    },
    [filter, writeFilter],
  )

  const replaceAll = useCallback(
    (next: AddressbookFilterState) => {
      writeFilter(next)
    },
    [writeFilter],
  )

  const clear = useCallback(() => {
    writeFilter(EMPTY_FILTER)
  }, [writeFilter])

  return { filter, setFilter, replaceAll, clear }
}
