// apps/web/src/hooks/useActivityFilter.ts
//
// Phase G Phase 5 Task 0 — Filter-State für die ActivityFilterBar (/aktivitaet).
//
// Liest/schreibt URL-Param `afilter` in der Form
//   `?afilter=evt:note|call,owner:mine,date:lt_7d`
// Bei Custom-Date:
//   `?afilter=date:custom,from:2026-05-01,to:2026-05-28`.
//
// Pipe-separierte Values pro Key, Komma zwischen Keys.
// Pattern bewusst identisch zu useAddressbookFilter (Phase 4 T5), so dass die
// Memorisierung beim User dieselbe bleibt.

import { useCallback, useMemo } from 'react'
import { useSearchParams } from 'react-router-dom'
import type { EventType, TimelineFilter } from '@/types/contactEvents'

// ── Public types ────────────────────────────────────────────────────────

export type OwnerScope = 'mine' | 'all'
export type DateBucket = 'today' | 'yesterday' | 'lt_7d' | 'lt_30d' | 'custom'

export interface ActivityFilterState {
  event_types: EventType[]
  owner_scope: OwnerScope | null
  date_bucket: DateBucket | null
  date_from?: string  // ISO, only relevant when date_bucket === 'custom'
  date_to?: string    // ISO, only relevant when date_bucket === 'custom'
}

export const EMPTY_ACTIVITY_FILTER: ActivityFilterState = {
  event_types: [],
  owner_scope: null,
  date_bucket: null,
}

// ── Validation sets ─────────────────────────────────────────────────────

const VALID_EVENT_TYPES = new Set<EventType>([
  'note',
  'call',
  'email_external',
  'meeting_past',
  'task',
  'whatsapp_log',
  'course_enrollment',
  'certification_issued',
  'saldo_movement',
  'pipeline_change',
  'intake_checkpoint',
  'skill_checked',
  'card_lead_imported',
  'role_change',
  'audit_edit',
])

const VALID_OWNER = new Set<OwnerScope>(['mine', 'all'])
const VALID_BUCKETS = new Set<DateBucket>([
  'today',
  'yesterday',
  'lt_7d',
  'lt_30d',
  'custom',
])

// Known short URL-keys used inside the `afilter=` param.
type UrlKey = 'evt' | 'owner' | 'date' | 'from' | 'to'
const URL_KEYS: ReadonlyArray<UrlKey> = ['evt', 'owner', 'date', 'from', 'to']

// ── Parse / serialize ───────────────────────────────────────────────────

export function parseActivityFilterParam(
  raw: string | null,
): ActivityFilterState {
  const state: ActivityFilterState = {
    event_types: [],
    owner_scope: null,
    date_bucket: null,
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
      case 'evt': {
        const valid = rawValues.filter((v): v is EventType =>
          VALID_EVENT_TYPES.has(v as EventType),
        )
        if (valid.length > 0) state.event_types.push(...valid)
        break
      }
      case 'owner': {
        const candidate = rawValues[0]
        if (VALID_OWNER.has(candidate as OwnerScope)) {
          state.owner_scope = candidate as OwnerScope
        }
        break
      }
      case 'date': {
        const candidate = rawValues[0]
        if (VALID_BUCKETS.has(candidate as DateBucket)) {
          state.date_bucket = candidate as DateBucket
        }
        break
      }
      case 'from':
        state.date_from = rawValues[0]
        break
      case 'to':
        state.date_to = rawValues[0]
        break
    }
  }

  // from/to only meaningful with date_bucket === 'custom'
  if (state.date_bucket !== 'custom') {
    delete state.date_from
    delete state.date_to
  }

  return state
}

export function serializeActivityFilter(state: ActivityFilterState): string {
  const parts: string[] = []
  if (state.event_types.length > 0) {
    parts.push(`evt:${state.event_types.join('|')}`)
  }
  if (state.owner_scope) parts.push(`owner:${state.owner_scope}`)
  if (state.date_bucket) parts.push(`date:${state.date_bucket}`)
  if (state.date_bucket === 'custom') {
    if (state.date_from) parts.push(`from:${state.date_from}`)
    if (state.date_to) parts.push(`to:${state.date_to}`)
  }
  return parts.join(',')
}

export function isActivityFilterEmpty(state: ActivityFilterState): boolean {
  return (
    state.event_types.length === 0 &&
    state.owner_scope === null &&
    state.date_bucket === null
  )
}

// ── Date-bucket → TimelineFilter mapping ────────────────────────────────

function startOfDay(d: Date): Date {
  const x = new Date(d)
  x.setHours(0, 0, 0, 0)
  return x
}

function endOfDay(d: Date): Date {
  const x = new Date(d)
  x.setHours(23, 59, 59, 999)
  return x
}

function addDays(d: Date, days: number): Date {
  const x = new Date(d)
  x.setDate(x.getDate() + days)
  return x
}

/**
 * Map a date_bucket onto concrete ISO timestamps. Pure function — uses
 * `now` from the caller so that tests can fake-time it.
 */
export function bucketToRange(
  bucket: DateBucket | null,
  now: Date = new Date(),
): { date_from?: string; date_to?: string } {
  if (!bucket) return {}
  switch (bucket) {
    case 'today':
      return { date_from: startOfDay(now).toISOString() }
    case 'yesterday': {
      const yest = addDays(now, -1)
      return {
        date_from: startOfDay(yest).toISOString(),
        date_to: endOfDay(yest).toISOString(),
      }
    }
    case 'lt_7d':
      return { date_from: addDays(now, -7).toISOString() }
    case 'lt_30d':
      return { date_from: addDays(now, -30).toISOString() }
    case 'custom':
      return {}
  }
}

// ── Hook ────────────────────────────────────────────────────────────────

export interface UseActivityFilterResult {
  filter: ActivityFilterState
  setFilter: (partial: Partial<ActivityFilterState>) => void
  replaceAll: (next: ActivityFilterState) => void
  clear: () => void
  /**
   * Convert the UI-state into the server-shape consumed by
   * `useGlobalActivity`. When owner_scope === 'mine' the caller must
   * provide their own contact-id so that the server filter narrows on
   * `actor_contact_id`.
   */
  toGlobalActivityFilter: (actorId?: string) => TimelineFilter
}

export function useActivityFilter(): UseActivityFilterResult {
  const [searchParams, setSearchParams] = useSearchParams()

  const raw = searchParams.get('afilter')
  const filter = useMemo<ActivityFilterState>(
    () => parseActivityFilterParam(raw),
    [raw],
  )

  const writeFilter = useCallback(
    (next: ActivityFilterState) => {
      setSearchParams(
        (prev) => {
          const params = new URLSearchParams(prev)
          if (isActivityFilterEmpty(next)) {
            params.delete('afilter')
          } else {
            params.set('afilter', serializeActivityFilter(next))
          }
          return params
        },
        { replace: true },
      )
    },
    [setSearchParams],
  )

  const setFilter = useCallback(
    (partial: Partial<ActivityFilterState>) => {
      const next: ActivityFilterState = { ...filter, ...partial }
      // If date_bucket flipped away from 'custom', drop the dangling
      // from/to fields so they don't leak back into the URL.
      if (next.date_bucket !== 'custom') {
        delete next.date_from
        delete next.date_to
      }
      writeFilter(next)
    },
    [filter, writeFilter],
  )

  const replaceAll = useCallback(
    (next: ActivityFilterState) => {
      writeFilter(next)
    },
    [writeFilter],
  )

  const clear = useCallback(() => {
    writeFilter(EMPTY_ACTIVITY_FILTER)
  }, [writeFilter])

  const toGlobalActivityFilter = useCallback(
    (actorId?: string): TimelineFilter => {
      const out: TimelineFilter = {}
      if (filter.event_types.length > 0) {
        out.event_types = filter.event_types
      }

      if (filter.date_bucket === 'custom') {
        if (filter.date_from) out.date_from = filter.date_from
        if (filter.date_to) out.date_to = filter.date_to
      } else {
        const { date_from, date_to } = bucketToRange(filter.date_bucket)
        if (date_from) out.date_from = date_from
        if (date_to) out.date_to = date_to
      }

      if (filter.owner_scope === 'mine' && actorId) {
        out.actor_id = actorId
      }

      return out
    },
    [filter],
  )

  return {
    filter,
    setFilter,
    replaceAll,
    clear,
    toGlobalActivityFilter,
  }
}
