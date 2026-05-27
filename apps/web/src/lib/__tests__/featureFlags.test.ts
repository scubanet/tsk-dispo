// apps/web/src/lib/__tests__/featureFlags.test.ts
import { describe, it, expect, beforeEach } from 'vitest'
import { isFeatureEnabled, FEATURE_FLAGS } from '../featureFlags'

describe('featureFlags', () => {
  beforeEach(() => {
    localStorage.clear()
    // Reset URL — happy-dom supports this
    window.history.replaceState({}, '', '/')
  })

  it('returns default (false) when no override set', () => {
    expect(isFeatureEnabled('crm_v2')).toBe(false)
  })

  it('returns true when localStorage set', () => {
    localStorage.setItem('crm_v2', 'true')
    expect(isFeatureEnabled('crm_v2')).toBe(true)
  })

  it('URL ?crm_v2=1 sets and returns true', () => {
    window.history.replaceState({}, '', '/?crm_v2=1')
    expect(isFeatureEnabled('crm_v2')).toBe(true)
    expect(localStorage.getItem('crm_v2')).toBe('true')
  })

  it('URL ?crm_v2=0 unsets and returns false', () => {
    localStorage.setItem('crm_v2', 'true')
    window.history.replaceState({}, '', '/?crm_v2=0')
    expect(isFeatureEnabled('crm_v2')).toBe(false)
    expect(localStorage.getItem('crm_v2')).toBeNull()
  })

  it('FEATURE_FLAGS enumerates known flags', () => {
    expect(FEATURE_FLAGS).toContain('crm_v2')
  })
})
