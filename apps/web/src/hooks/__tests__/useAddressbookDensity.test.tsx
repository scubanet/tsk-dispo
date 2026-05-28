// apps/web/src/hooks/__tests__/useAddressbookDensity.test.tsx
//
// Phase G Phase 4 Task 2 — Tests für den Density-Toggle-Hook.
// Pattern wie useSidebarToggle.test.tsx.
import { describe, it, expect, beforeEach } from 'vitest'
import { renderHook, act } from '@testing-library/react'
import { useAddressbookDensity } from '../useAddressbookDensity'

const KEY = 'addressbook.density'

describe('useAddressbookDensity', () => {
  beforeEach(() => {
    window.localStorage.clear()
  })

  it('returns "comfortable" by default when localStorage is empty', () => {
    const { result } = renderHook(() => useAddressbookDensity())
    expect(result.current[0]).toBe('comfortable')
  })

  it('reads existing localStorage value', () => {
    window.localStorage.setItem(KEY, 'compact')
    const { result } = renderHook(() => useAddressbookDensity())
    expect(result.current[0]).toBe('compact')
  })

  it('toggle flips between comfortable and compact and persists', () => {
    const { result } = renderHook(() => useAddressbookDensity())
    expect(result.current[0]).toBe('comfortable')

    act(() => { result.current[2]() })
    expect(result.current[0]).toBe('compact')
    expect(window.localStorage.getItem(KEY)).toBe('compact')

    act(() => { result.current[2]() })
    expect(result.current[0]).toBe('comfortable')
    expect(window.localStorage.getItem(KEY)).toBe('comfortable')
  })

  it('setDensity writes correctly and is reload-stable', () => {
    const { result } = renderHook(() => useAddressbookDensity())
    act(() => { result.current[1]('compact') })
    expect(result.current[0]).toBe('compact')
    expect(window.localStorage.getItem(KEY)).toBe('compact')

    // Simulate a reload by re-mounting the hook — must read the persisted value.
    const { result: result2 } = renderHook(() => useAddressbookDensity())
    expect(result2.current[0]).toBe('compact')
  })
})
