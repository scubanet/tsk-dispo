// apps/web/src/hooks/__tests__/useAddressbookColumns.test.tsx
//
// Phase G Phase 4 Task 3 — Tests für den ColumnPicker-Hook.
import { describe, it, expect, beforeEach } from 'vitest'
import { renderHook, act } from '@testing-library/react'
import {
  useAddressbookColumns,
  COLUMN_CATALOG,
  defaultVisibleIds,
} from '../useAddressbookColumns'

const KEY = 'addressbook.columns'

describe('useAddressbookColumns', () => {
  beforeEach(() => {
    window.localStorage.clear()
  })

  it('returns default visible columns when localStorage is empty', () => {
    const { result } = renderHook(() => useAddressbookColumns())
    const expected = COLUMN_CATALOG.filter((c) => c.defaultVisible).map((c) => c.id)
    expect(result.current.visibleIds).toEqual(expected)
    // Sanity: name, roles, email, last_contact sind sichtbar
    expect(result.current.visibleIds).toContain('name')
    expect(result.current.visibleIds).toContain('roles')
    expect(result.current.visibleIds).toContain('email')
    expect(result.current.visibleIds).toContain('last_contact')
    // Aber nicht phone/saldo/tags etc.
    expect(result.current.visibleIds).not.toContain('phone')
    expect(result.current.visibleIds).not.toContain('saldo')
  })

  it('reads existing localStorage value', () => {
    window.localStorage.setItem(KEY, JSON.stringify(['name', 'email', 'phone']))
    const { result } = renderHook(() => useAddressbookColumns())
    expect(result.current.visibleIds).toEqual(['name', 'email', 'phone'])
  })

  it('toggle("phone") adds phone when not visible and removes it when visible', () => {
    const { result } = renderHook(() => useAddressbookColumns())
    expect(result.current.visibleIds).not.toContain('phone')

    act(() => { result.current.toggle('phone') })
    expect(result.current.visibleIds).toContain('phone')
    // Persistiert?
    const persisted1 = JSON.parse(window.localStorage.getItem(KEY) ?? '[]')
    expect(persisted1).toContain('phone')

    act(() => { result.current.toggle('phone') })
    expect(result.current.visibleIds).not.toContain('phone')
    const persisted2 = JSON.parse(window.localStorage.getItem(KEY) ?? '[]')
    expect(persisted2).not.toContain('phone')
  })

  it('toggle("name") is a no-op — name remains visible', () => {
    const { result } = renderHook(() => useAddressbookColumns())
    expect(result.current.visibleIds).toContain('name')

    act(() => { result.current.toggle('name') })
    expect(result.current.visibleIds).toContain('name')

    act(() => { result.current.toggle('name') })
    expect(result.current.visibleIds).toContain('name')
  })

  it('setVisibleIds replaces the list, dedupes, forces name, and sorts by catalog', () => {
    const { result } = renderHook(() => useAddressbookColumns())
    act(() => {
      // Out-of-order + duplicate + missing 'name' + invalid id.
      result.current.setVisibleIds([
        'saldo',
        'email',
        'email',
        'phone',
        'bogus' as never,
      ])
    })
    // 'name' was injected automatically.
    expect(result.current.visibleIds).toContain('name')
    // Order matches COLUMN_CATALOG: name, email, phone, saldo
    expect(result.current.visibleIds).toEqual([
      'name',
      'email',
      'phone',
      'saldo',
    ])
    // No duplicates.
    const seen = new Set(result.current.visibleIds)
    expect(seen.size).toBe(result.current.visibleIds.length)
  })

  it('reset() restores defaults', () => {
    const { result } = renderHook(() => useAddressbookColumns())
    act(() => {
      result.current.toggle('phone')
      result.current.toggle('saldo')
    })
    expect(result.current.visibleIds).toContain('phone')
    expect(result.current.visibleIds).toContain('saldo')

    act(() => { result.current.reset() })
    expect(result.current.visibleIds).toEqual(defaultVisibleIds())
    expect(result.current.visibleIds).not.toContain('phone')
    expect(result.current.visibleIds).not.toContain('saldo')
  })
})
