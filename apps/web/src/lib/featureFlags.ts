// apps/web/src/lib/featureFlags.ts
//
// Lightweight feature-flag lookup. URL param > localStorage > default.
// Setzen via URL: /?crm_v2=1 (persistiert in localStorage)
// Unsetzen via URL: /?crm_v2=0 (löscht localStorage)
// Read-only via isFeatureEnabled('crm_v2')
//
// Phase G Phase 2 nutzt `crm_v2` um die neue Detail-Panel-V2-Variante
// hinter einem Flag zu mounten ohne Production zu beeinflussen.

export const FEATURE_FLAGS = ['crm_v2'] as const
export type FeatureFlag = (typeof FEATURE_FLAGS)[number]

export function isFeatureEnabled(flag: FeatureFlag): boolean {
  // Side-effect: URL override syncs localStorage so the flag persists
  // across navigations.
  if (typeof window !== 'undefined') {
    const params = new URLSearchParams(window.location.search)
    const fromUrl = params.get(flag)
    if (fromUrl === '1' || fromUrl === 'true') {
      localStorage.setItem(flag, 'true')
      return true
    }
    if (fromUrl === '0' || fromUrl === 'false') {
      localStorage.removeItem(flag)
      return false
    }
    return localStorage.getItem(flag) === 'true'
  }
  return false
}
