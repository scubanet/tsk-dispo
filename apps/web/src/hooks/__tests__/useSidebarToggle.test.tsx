// apps/web/src/hooks/__tests__/useSidebarToggle.test.tsx
import { describe, it, expect, beforeEach } from 'vitest'
import { renderHook, act } from '@testing-library/react'
import { useSidebarToggle } from '../useSidebarToggle'

describe('useSidebarToggle', () => {
  beforeEach(() => {
    window.localStorage.clear()
  })

  it('returns defaultOpen=true when localStorage empty', () => {
    const { result } = renderHook(() => useSidebarToggle('test.key', true))
    expect(result.current[0]).toBe(true)
  })

  it('returns defaultOpen=false when localStorage empty', () => {
    const { result } = renderHook(() => useSidebarToggle('test.key', false))
    expect(result.current[0]).toBe(false)
  })

  it('reads existing localStorage value', () => {
    window.localStorage.setItem('test.key', 'false')
    const { result } = renderHook(() => useSidebarToggle('test.key', true))
    expect(result.current[0]).toBe(false)
  })

  it('toggle flips the state', () => {
    const { result } = renderHook(() => useSidebarToggle('test.key', true))
    expect(result.current[0]).toBe(true)
    act(() => { result.current[1]() })
    expect(result.current[0]).toBe(false)
    act(() => { result.current[1]() })
    expect(result.current[0]).toBe(true)
  })

  it('persists toggle into localStorage', () => {
    const { result } = renderHook(() => useSidebarToggle('test.key', true))
    act(() => { result.current[1]() })
    expect(window.localStorage.getItem('test.key')).toBe('false')
    act(() => { result.current[1]() })
    expect(window.localStorage.getItem('test.key')).toBe('true')
  })
})
