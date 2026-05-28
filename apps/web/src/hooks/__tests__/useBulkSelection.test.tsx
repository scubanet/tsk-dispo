// apps/web/src/hooks/__tests__/useBulkSelection.test.tsx
//
// Phase G Phase 4 Task 6 — Tests für den Bulk-Selection-Hook.
import { describe, it, expect } from 'vitest'
import { renderHook, act } from '@testing-library/react'
import { useBulkSelection } from '../useBulkSelection'

describe('useBulkSelection', () => {
  it('starts empty: selected.size===0, allSelected===false, someSelected===false', () => {
    const { result } = renderHook(() => useBulkSelection<string>(['a', 'b', 'c']))
    expect(result.current.selected.size).toBe(0)
    expect(result.current.allSelected).toBe(false)
    expect(result.current.someSelected).toBe(false)
    expect(result.current.isSelected('a')).toBe(false)
  })

  it('toggle("a") adds the id', () => {
    const { result } = renderHook(() => useBulkSelection<string>(['a', 'b', 'c']))
    act(() => { result.current.toggle('a') })
    expect(result.current.selected.has('a')).toBe(true)
    expect(result.current.selected.size).toBe(1)
    expect(result.current.isSelected('a')).toBe(true)
    expect(result.current.someSelected).toBe(true)
  })

  it('toggle("a") twice removes it again', () => {
    const { result } = renderHook(() => useBulkSelection<string>(['a', 'b', 'c']))
    act(() => { result.current.toggle('a') })
    act(() => { result.current.toggle('a') })
    expect(result.current.selected.size).toBe(0)
    expect(result.current.isSelected('a')).toBe(false)
  })

  it('selectAll() selects every currentId; allSelected becomes true', () => {
    const { result } = renderHook(() => useBulkSelection<string>(['a', 'b', 'c']))
    act(() => { result.current.selectAll() })
    expect(result.current.selected.size).toBe(3)
    expect(result.current.allSelected).toBe(true)
    expect(result.current.someSelected).toBe(false)
    expect(result.current.isSelected('a')).toBe(true)
    expect(result.current.isSelected('b')).toBe(true)
    expect(result.current.isSelected('c')).toBe(true)
  })

  it('clear() resets to empty', () => {
    const { result } = renderHook(() => useBulkSelection<string>(['a', 'b', 'c']))
    act(() => { result.current.selectAll() })
    expect(result.current.selected.size).toBe(3)
    act(() => { result.current.clear() })
    expect(result.current.selected.size).toBe(0)
    expect(result.current.allSelected).toBe(false)
    expect(result.current.someSelected).toBe(false)
  })

  it('someSelected===true when partial selection (1 of 3)', () => {
    const { result } = renderHook(() => useBulkSelection<string>(['a', 'b', 'c']))
    act(() => { result.current.toggle('a') })
    expect(result.current.allSelected).toBe(false)
    expect(result.current.someSelected).toBe(true)
  })

  it('clears selection when currentIds changes (filter wechselt)', () => {
    let ids = ['a', 'b', 'c']
    const { result, rerender } = renderHook(
      ({ currentIds }: { currentIds: string[] }) => useBulkSelection<string>(currentIds),
      { initialProps: { currentIds: ids } },
    )
    act(() => { result.current.toggle('a') })
    expect(result.current.selected.size).toBe(1)

    // Filter wechselt → neue ID-Liste
    ids = ['x', 'y']
    rerender({ currentIds: ids })
    expect(result.current.selected.size).toBe(0)
    expect(result.current.allSelected).toBe(false)
    expect(result.current.someSelected).toBe(false)
  })

  it('allSelected is false when currentIds is empty even if selected is empty', () => {
    const { result } = renderHook(() => useBulkSelection<string>([]))
    expect(result.current.allSelected).toBe(false)
    expect(result.current.someSelected).toBe(false)
  })
})
