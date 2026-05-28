// apps/web/src/hooks/__tests__/useActivityFilter.test.tsx
//
// Phase G Phase 5 Task 0 — Tests für den ActivityFilter-State-Hook.
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { renderHook, act } from '@testing-library/react'
import { MemoryRouter, useLocation } from 'react-router-dom'
import type { ReactNode } from 'react'
import {
  useActivityFilter,
  parseActivityFilterParam,
  serializeActivityFilter,
  bucketToRange,
  EMPTY_ACTIVITY_FILTER,
} from '../useActivityFilter'

function wrapperFor(url: string) {
  return ({ children }: { children: ReactNode }) => (
    <MemoryRouter initialEntries={[url]}>{children}</MemoryRouter>
  )
}

function useHookWithLocation() {
  const api = useActivityFilter()
  const loc = useLocation()
  return { ...api, search: loc.search }
}

// Tests that depend on date-bucket → ISO mapping fake the system clock.
const FIXED_NOW = new Date('2026-05-28T12:34:56.000Z')

beforeEach(() => {
  vi.useFakeTimers()
  vi.setSystemTime(FIXED_NOW)
})

afterEach(() => {
  vi.useRealTimers()
})

describe('parseActivityFilterParam', () => {
  it('returns empty state for null/empty input', () => {
    expect(parseActivityFilterParam(null)).toEqual(EMPTY_ACTIVITY_FILTER)
    expect(parseActivityFilterParam('')).toEqual(EMPTY_ACTIVITY_FILTER)
  })

  it('parses ?afilter=evt:note → event_types=[note]', () => {
    expect(parseActivityFilterParam('evt:note')).toEqual({
      ...EMPTY_ACTIVITY_FILTER,
      event_types: ['note'],
    })
  })

  it('parses combined evt|call,owner:mine,date:lt_7d', () => {
    expect(
      parseActivityFilterParam('evt:note|call,owner:mine,date:lt_7d'),
    ).toEqual({
      event_types: ['note', 'call'],
      owner_scope: 'mine',
      date_bucket: 'lt_7d',
    })
  })

  it('parses custom-date with from/to', () => {
    expect(
      parseActivityFilterParam(
        'date:custom,from:2026-05-01,to:2026-05-28',
      ),
    ).toEqual({
      event_types: [],
      owner_scope: null,
      date_bucket: 'custom',
      date_from: '2026-05-01',
      date_to: '2026-05-28',
    })
  })

  it('drops from/to when date_bucket is not custom', () => {
    expect(
      parseActivityFilterParam('date:lt_7d,from:2026-05-01,to:2026-05-28'),
    ).toEqual({
      event_types: [],
      owner_scope: null,
      date_bucket: 'lt_7d',
    })
  })

  it('silently ignores unknown keys and unknown enum values', () => {
    expect(
      parseActivityFilterParam('bogus:x,evt:note|fake_event,owner:nobody'),
    ).toEqual({
      ...EMPTY_ACTIVITY_FILTER,
      event_types: ['note'],
    })
  })

  it('round-trips serialize → parse', () => {
    const state = {
      event_types: ['note' as const, 'call' as const],
      owner_scope: 'mine' as const,
      date_bucket: 'custom' as const,
      date_from: '2026-05-01',
      date_to: '2026-05-28',
    }
    const serialized = serializeActivityFilter(state)
    expect(serialized).toBe(
      'evt:note|call,owner:mine,date:custom,from:2026-05-01,to:2026-05-28',
    )
    expect(parseActivityFilterParam(serialized)).toEqual(state)
  })
})

describe('bucketToRange', () => {
  it('today → date_from = startOfDay(now)', () => {
    const range = bucketToRange('today', FIXED_NOW)
    expect(range.date_from).toBeDefined()
    const d = new Date(range.date_from!)
    expect(d.getHours()).toBe(0)
    expect(d.getMinutes()).toBe(0)
    // same calendar day as FIXED_NOW (local tz)
    expect(d.toDateString()).toBe(FIXED_NOW.toDateString())
    expect(range.date_to).toBeUndefined()
  })

  it('yesterday → from start to end of (now-1d)', () => {
    const range = bucketToRange('yesterday', FIXED_NOW)
    const from = new Date(range.date_from!)
    const to = new Date(range.date_to!)
    expect(from.getHours()).toBe(0)
    expect(to.getHours()).toBe(23)
    // both fall on the same calendar day
    expect(from.toDateString()).toBe(to.toDateString())
    // that day is yesterday
    const expectedYest = new Date(FIXED_NOW)
    expectedYest.setDate(expectedYest.getDate() - 1)
    expect(from.toDateString()).toBe(expectedYest.toDateString())
  })

  it('lt_7d → date_from = now - 7d', () => {
    const range = bucketToRange('lt_7d', FIXED_NOW)
    const expected = new Date(FIXED_NOW)
    expected.setDate(expected.getDate() - 7)
    expect(range.date_from).toBe(expected.toISOString())
    expect(range.date_to).toBeUndefined()
  })

  it('lt_30d → date_from = now - 30d', () => {
    const range = bucketToRange('lt_30d', FIXED_NOW)
    const expected = new Date(FIXED_NOW)
    expected.setDate(expected.getDate() - 30)
    expect(range.date_from).toBe(expected.toISOString())
  })

  it('custom returns empty (caller uses explicit from/to)', () => {
    expect(bucketToRange('custom', FIXED_NOW)).toEqual({})
  })

  it('null bucket returns empty', () => {
    expect(bucketToRange(null, FIXED_NOW)).toEqual({})
  })
})

describe('useActivityFilter', () => {
  it('returns empty state when URL has no ?afilter param', () => {
    const { result } = renderHook(() => useActivityFilter(), {
      wrapper: wrapperFor('/aktivitaet'),
    })
    expect(result.current.filter).toEqual(EMPTY_ACTIVITY_FILTER)
  })

  it('parses ?afilter=evt:note from URL', () => {
    const { result } = renderHook(() => useActivityFilter(), {
      wrapper: wrapperFor('/aktivitaet?afilter=evt:note'),
    })
    expect(result.current.filter.event_types).toEqual(['note'])
  })

  it('parses multi-key afilter from URL', () => {
    const { result } = renderHook(() => useActivityFilter(), {
      wrapper: wrapperFor(
        '/aktivitaet?afilter=evt:note|call,owner:mine,date:lt_7d',
      ),
    })
    expect(result.current.filter).toEqual({
      event_types: ['note', 'call'],
      owner_scope: 'mine',
      date_bucket: 'lt_7d',
    })
  })

  it('parses custom-date afilter from URL', () => {
    const { result } = renderHook(() => useActivityFilter(), {
      wrapper: wrapperFor(
        '/aktivitaet?afilter=date:custom,from:2026-05-01,to:2026-05-28',
      ),
    })
    expect(result.current.filter.date_bucket).toBe('custom')
    expect(result.current.filter.date_from).toBe('2026-05-01')
    expect(result.current.filter.date_to).toBe('2026-05-28')
  })

  it('setFilter writes the param back to the URL', () => {
    const { result } = renderHook(() => useHookWithLocation(), {
      wrapper: wrapperFor('/aktivitaet'),
    })
    act(() => {
      result.current.setFilter({ event_types: ['note'] })
    })
    expect(result.current.filter.event_types).toEqual(['note'])
    expect(result.current.search).toContain('afilter=evt%3Anote')
  })

  it('clear() drops the afilter URL param', () => {
    const { result } = renderHook(() => useHookWithLocation(), {
      wrapper: wrapperFor('/aktivitaet?afilter=evt:note,owner:mine'),
    })
    act(() => {
      result.current.clear()
    })
    expect(result.current.filter).toEqual(EMPTY_ACTIVITY_FILTER)
    expect(result.current.search).not.toContain('afilter=')
  })

  it('toGlobalActivityFilter maps date:today to a date_from', () => {
    const { result } = renderHook(() => useActivityFilter(), {
      wrapper: wrapperFor('/aktivitaet?afilter=date:today'),
    })
    const mapped = result.current.toGlobalActivityFilter()
    expect(mapped.date_from).toBeDefined()
    const d = new Date(mapped.date_from!)
    expect(d.toDateString()).toBe(FIXED_NOW.toDateString())
    expect(mapped.date_to).toBeUndefined()
    expect(mapped.actor_id).toBeUndefined()
  })

  it('toGlobalActivityFilter with owner:mine + actorId sets actor_id', () => {
    const { result } = renderHook(() => useActivityFilter(), {
      wrapper: wrapperFor('/aktivitaet?afilter=owner:mine'),
    })
    const mapped = result.current.toGlobalActivityFilter('user-123')
    expect(mapped.actor_id).toBe('user-123')
  })

  it('toGlobalActivityFilter with owner:mine but no actorId leaves it out', () => {
    const { result } = renderHook(() => useActivityFilter(), {
      wrapper: wrapperFor('/aktivitaet?afilter=owner:mine'),
    })
    const mapped = result.current.toGlobalActivityFilter()
    expect(mapped.actor_id).toBeUndefined()
  })

  it('toGlobalActivityFilter for custom-date uses explicit from/to', () => {
    const { result } = renderHook(() => useActivityFilter(), {
      wrapper: wrapperFor(
        '/aktivitaet?afilter=date:custom,from:2026-05-01,to:2026-05-28',
      ),
    })
    const mapped = result.current.toGlobalActivityFilter()
    expect(mapped.date_from).toBe('2026-05-01')
    expect(mapped.date_to).toBe('2026-05-28')
  })

  it('unknown URL keys/values are silently dropped', () => {
    const { result } = renderHook(() => useActivityFilter(), {
      wrapper: wrapperFor(
        '/aktivitaet?afilter=bogus:x,evt:note|junk,owner:nobody',
      ),
    })
    expect(result.current.filter).toEqual({
      ...EMPTY_ACTIVITY_FILTER,
      event_types: ['note'],
    })
  })
})
