// apps/web/src/hooks/__tests__/useAddressbookSort.test.tsx
//
// Phase G Phase 4 Task 4 — Tests für den Multi-Sort-Hook.
import { describe, it, expect } from 'vitest'
import { renderHook, act } from '@testing-library/react'
import { MemoryRouter, useLocation } from 'react-router-dom'
import type { ReactNode } from 'react'
import {
  useAddressbookSort,
  parseSortParam,
  serializeSort,
} from '../useAddressbookSort'

function wrapperFor(url: string) {
  return ({ children }: { children: ReactNode }) => (
    <MemoryRouter initialEntries={[url]}>{children}</MemoryRouter>
  )
}

// Combined hook that exposes both the sort state and the current location's
// search string, so we can assert that the URL was actually rewritten.
function useSortWithLocation() {
  const sortApi = useAddressbookSort()
  const loc = useLocation()
  return { ...sortApi, search: loc.search }
}

describe('parseSortParam / serializeSort', () => {
  it('returns [] for null/empty', () => {
    expect(parseSortParam(null)).toEqual([])
    expect(parseSortParam('')).toEqual([])
  })

  it('parses a single field:dir', () => {
    expect(parseSortParam('name:asc')).toEqual([{ field: 'name', direction: 'asc' }])
  })

  it('parses multiple ordered specs', () => {
    expect(parseSortParam('last_contact:desc,name:asc')).toEqual([
      { field: 'last_contact', direction: 'desc' },
      { field: 'name', direction: 'asc' },
    ])
  })

  it('ignores invalid field or direction tokens', () => {
    expect(parseSortParam('bogus:asc,name:up,last_contact:desc')).toEqual([
      { field: 'last_contact', direction: 'desc' },
    ])
  })

  it('serializes round-trip stable', () => {
    const sort = [
      { field: 'last_contact' as const, direction: 'desc' as const },
      { field: 'name' as const, direction: 'asc' as const },
    ]
    expect(serializeSort(sort)).toBe('last_contact:desc,name:asc')
  })
})

describe('useAddressbookSort', () => {
  it('returns sort=[] when URL has no ?sort param', () => {
    const { result } = renderHook(() => useAddressbookSort(), {
      wrapper: wrapperFor('/contacts'),
    })
    expect(result.current.sort).toEqual([])
  })

  it('parses ?sort=name:asc from the URL', () => {
    const { result } = renderHook(() => useAddressbookSort(), {
      wrapper: wrapperFor('/contacts?sort=name:asc'),
    })
    expect(result.current.sort).toEqual([{ field: 'name', direction: 'asc' }])
  })

  it('parses multi-sort param preserving order', () => {
    const { result } = renderHook(() => useAddressbookSort(), {
      wrapper: wrapperFor('/contacts?sort=last_contact:desc,name:asc'),
    })
    expect(result.current.sort).toEqual([
      { field: 'last_contact', direction: 'desc' },
      { field: 'name', direction: 'asc' },
    ])
  })

  it('plain-click on a new sortable column sets sort=[{field, asc}]', () => {
    const { result } = renderHook(() => useSortWithLocation(), {
      wrapper: wrapperFor('/contacts'),
    })
    act(() => { result.current.onHeaderClick('name', false) })
    expect(result.current.sort).toEqual([{ field: 'name', direction: 'asc' }])
    expect(result.current.search).toContain('sort=name%3Aasc')
  })

  it('plain-click on column sorted asc flips to desc', () => {
    const { result } = renderHook(() => useSortWithLocation(), {
      wrapper: wrapperFor('/contacts?sort=name:asc'),
    })
    act(() => { result.current.onHeaderClick('name', false) })
    expect(result.current.sort).toEqual([{ field: 'name', direction: 'desc' }])
  })

  it('plain-click on column sorted desc removes the sort (cycle to off)', () => {
    const { result } = renderHook(() => useSortWithLocation(), {
      wrapper: wrapperFor('/contacts?sort=name:desc'),
    })
    act(() => { result.current.onHeaderClick('name', false) })
    expect(result.current.sort).toEqual([])
    // URL no longer has the sort param
    expect(result.current.search).not.toContain('sort=')
  })

  it('plain-click replaces multi-sort with the single cycled spec', () => {
    const { result } = renderHook(() => useSortWithLocation(), {
      wrapper: wrapperFor('/contacts?sort=last_contact:desc,name:asc'),
    })
    // Plain click on `saldo` (which maps to 'balance' field, not in sort yet)
    act(() => { result.current.onHeaderClick('saldo', false) })
    expect(result.current.sort).toEqual([{ field: 'balance', direction: 'asc' }])
  })

  it('shift-click on a new column appends (multi-sort)', () => {
    const { result } = renderHook(() => useSortWithLocation(), {
      wrapper: wrapperFor('/contacts?sort=last_contact:desc'),
    })
    act(() => { result.current.onHeaderClick('name', true) })
    expect(result.current.sort).toEqual([
      { field: 'last_contact', direction: 'desc' },
      { field: 'name', direction: 'asc' },
    ])
  })

  it('shift-click on existing asc column flips it in place', () => {
    const { result } = renderHook(() => useSortWithLocation(), {
      wrapper: wrapperFor('/contacts?sort=last_contact:desc,name:asc'),
    })
    act(() => { result.current.onHeaderClick('name', true) })
    expect(result.current.sort).toEqual([
      { field: 'last_contact', direction: 'desc' },
      { field: 'name', direction: 'desc' },
    ])
  })

  it('shift-click on existing desc column removes it, preserves others', () => {
    const { result } = renderHook(() => useSortWithLocation(), {
      wrapper: wrapperFor('/contacts?sort=last_contact:desc,name:desc'),
    })
    act(() => { result.current.onHeaderClick('name', true) })
    expect(result.current.sort).toEqual([
      { field: 'last_contact', direction: 'desc' },
    ])
  })

  it('click on non-sortable ColumnId is a no-op', () => {
    const { result } = renderHook(() => useSortWithLocation(), {
      wrapper: wrapperFor('/contacts?sort=name:asc'),
    })
    act(() => { result.current.onHeaderClick('roles', false) })
    expect(result.current.sort).toEqual([{ field: 'name', direction: 'asc' }])
    act(() => { result.current.onHeaderClick('email', true) })
    expect(result.current.sort).toEqual([{ field: 'name', direction: 'asc' }])
  })

  it('clear() resets sort=[] and removes the URL param', () => {
    const { result } = renderHook(() => useSortWithLocation(), {
      wrapper: wrapperFor('/contacts?sort=last_contact:desc,name:asc'),
    })
    act(() => { result.current.clear() })
    expect(result.current.sort).toEqual([])
    expect(result.current.search).not.toContain('sort=')
  })
})
