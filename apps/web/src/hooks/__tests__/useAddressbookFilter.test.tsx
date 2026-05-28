// apps/web/src/hooks/__tests__/useAddressbookFilter.test.tsx
//
// Phase G Phase 4 Task 5 — Tests für den Filter-State-Hook.
import { describe, it, expect } from 'vitest'
import { renderHook, act } from '@testing-library/react'
import { MemoryRouter, useLocation } from 'react-router-dom'
import type { ReactNode } from 'react'
import {
  useAddressbookFilter,
  parseFilterParam,
  serializeFilter,
  EMPTY_FILTER,
} from '../useAddressbookFilter'

function wrapperFor(url: string) {
  return ({ children }: { children: ReactNode }) => (
    <MemoryRouter initialEntries={[url]}>{children}</MemoryRouter>
  )
}

function useFilterWithLocation() {
  const api = useAddressbookFilter()
  const loc = useLocation()
  return { ...api, search: loc.search }
}

describe('parseFilterParam / serializeFilter', () => {
  it('returns empty state for null/empty', () => {
    expect(parseFilterParam(null)).toEqual(EMPTY_FILTER)
    expect(parseFilterParam('')).toEqual(EMPTY_FILTER)
  })

  it('parses single role', () => {
    expect(parseFilterParam('role:instructor')).toEqual({
      ...EMPTY_FILTER,
      roles: ['instructor'],
    })
  })

  it('parses pipe-separated role values', () => {
    expect(parseFilterParam('role:instructor|cd')).toEqual({
      ...EMPTY_FILTER,
      roles: ['instructor', 'cd'],
    })
  })

  it('parses comma-separated keys', () => {
    expect(parseFilterParam('role:instructor|cd,tag:vip')).toEqual({
      ...EMPTY_FILTER,
      roles: ['instructor', 'cd'],
      tags: ['vip'],
    })
  })

  it('parses saldo + status keys', () => {
    expect(parseFilterParam('saldo:negative,status:archived')).toEqual({
      ...EMPTY_FILTER,
      saldo_buckets: ['negative'],
      status: ['archived'],
    })
  })

  it('ignores unknown keys silently', () => {
    expect(parseFilterParam('bogus:foo,role:instructor')).toEqual({
      ...EMPTY_FILTER,
      roles: ['instructor'],
    })
  })

  it('ignores invalid enum values silently', () => {
    // 'super_admin' is not a ContactRole — dropped. 'instructor' kept.
    expect(parseFilterParam('role:super_admin|instructor')).toEqual({
      ...EMPTY_FILTER,
      roles: ['instructor'],
    })
    // saldo only allows positive/negative/zero
    expect(parseFilterParam('saldo:huge')).toEqual(EMPTY_FILTER)
  })

  it('serialize round-trips with parse', () => {
    const state = {
      ...EMPTY_FILTER,
      roles: ['instructor' as const, 'cd' as const],
      tags: ['vip', 'lead'],
      saldo_buckets: ['negative' as const],
      status: ['archived' as const],
    }
    const serialized = serializeFilter(state)
    expect(serialized).toBe(
      'role:instructor|cd,tag:vip|lead,saldo:negative,status:archived',
    )
    expect(parseFilterParam(serialized)).toEqual(state)
  })

  it('serialize returns empty string for empty state', () => {
    expect(serializeFilter(EMPTY_FILTER)).toBe('')
  })
})

describe('useAddressbookFilter', () => {
  it('returns empty state when URL has no ?filter param', () => {
    const { result } = renderHook(() => useAddressbookFilter(), {
      wrapper: wrapperFor('/contacts'),
    })
    expect(result.current.filter).toEqual(EMPTY_FILTER)
  })

  it('parses ?filter=role:instructor', () => {
    const { result } = renderHook(() => useAddressbookFilter(), {
      wrapper: wrapperFor('/contacts?filter=role:instructor'),
    })
    expect(result.current.filter.roles).toEqual(['instructor'])
  })

  it('parses multi-key filter from URL', () => {
    const { result } = renderHook(() => useAddressbookFilter(), {
      wrapper: wrapperFor('/contacts?filter=role:instructor|cd,tag:vip'),
    })
    expect(result.current.filter.roles).toEqual(['instructor', 'cd'])
    expect(result.current.filter.tags).toEqual(['vip'])
  })

  it('parses saldo + status from URL', () => {
    const { result } = renderHook(() => useAddressbookFilter(), {
      wrapper: wrapperFor('/contacts?filter=saldo:negative,status:archived'),
    })
    expect(result.current.filter.saldo_buckets).toEqual(['negative'])
    expect(result.current.filter.status).toEqual(['archived'])
  })

  it('setFilter({ roles }) writes role= to URL', () => {
    const { result } = renderHook(() => useFilterWithLocation(), {
      wrapper: wrapperFor('/contacts'),
    })
    act(() => {
      result.current.setFilter({ roles: ['student'] })
    })
    expect(result.current.filter.roles).toEqual(['student'])
    expect(result.current.search).toContain('filter=role%3Astudent')
  })

  it('setFilter({ tags }) writes pipe-joined tag values', () => {
    const { result } = renderHook(() => useFilterWithLocation(), {
      wrapper: wrapperFor('/contacts'),
    })
    act(() => {
      result.current.setFilter({ tags: ['vip', 'lead'] })
    })
    expect(result.current.filter.tags).toEqual(['vip', 'lead'])
    // URL-encoded `|` is %7C
    expect(result.current.search).toContain('filter=tag%3Avip%7Clead')
  })

  it('setFilter merges with existing state (partial update)', () => {
    const { result } = renderHook(() => useFilterWithLocation(), {
      wrapper: wrapperFor('/contacts?filter=role:instructor'),
    })
    act(() => {
      result.current.setFilter({ tags: ['vip'] })
    })
    expect(result.current.filter.roles).toEqual(['instructor'])
    expect(result.current.filter.tags).toEqual(['vip'])
  })

  it('clear() drops the filter param from the URL', () => {
    const { result } = renderHook(() => useFilterWithLocation(), {
      wrapper: wrapperFor('/contacts?filter=role:instructor,tag:vip'),
    })
    act(() => {
      result.current.clear()
    })
    expect(result.current.filter).toEqual(EMPTY_FILTER)
    expect(result.current.search).not.toContain('filter=')
  })

  it('replaceAll overwrites the whole state in one call', () => {
    const { result } = renderHook(() => useFilterWithLocation(), {
      wrapper: wrapperFor('/contacts?filter=role:instructor,tag:vip'),
    })
    act(() => {
      result.current.replaceAll({
        ...EMPTY_FILTER,
        roles: ['student'],
        languages: ['de'],
      })
    })
    expect(result.current.filter.roles).toEqual(['student'])
    expect(result.current.filter.languages).toEqual(['de'])
    // Old tag was dropped
    expect(result.current.filter.tags).toEqual([])
    expect(result.current.search).toContain('role%3Astudent')
    expect(result.current.search).toContain('language%3Ade')
  })

  it('replaceAll with EMPTY_FILTER removes the URL param', () => {
    const { result } = renderHook(() => useFilterWithLocation(), {
      wrapper: wrapperFor('/contacts?filter=role:instructor'),
    })
    act(() => {
      result.current.replaceAll(EMPTY_FILTER)
    })
    expect(result.current.filter).toEqual(EMPTY_FILTER)
    expect(result.current.search).not.toContain('filter=')
  })

  it('unknown URL keys are silently dropped', () => {
    const { result } = renderHook(() => useAddressbookFilter(), {
      wrapper: wrapperFor('/contacts?filter=bogus:x,role:instructor'),
    })
    expect(result.current.filter.roles).toEqual(['instructor'])
  })
})
