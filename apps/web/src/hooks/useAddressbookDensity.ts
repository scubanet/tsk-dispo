// apps/web/src/hooks/useAddressbookDensity.ts
//
// Phase G Phase 4 Task 2 — Density-State für AddressbookTable.
// Persistiert 'compact' | 'comfortable' in localStorage. Default 'comfortable'.
// Pattern angelehnt an useSidebarToggle.ts (Phase 3 Task 14).
import { useCallback, useEffect, useState } from 'react'

export type AddressbookDensity = 'compact' | 'comfortable'

const STORAGE_KEY = 'addressbook.density'
const DEFAULT_DENSITY: AddressbookDensity = 'comfortable'

function readInitial(): AddressbookDensity {
  if (typeof window === 'undefined') return DEFAULT_DENSITY
  try {
    const stored = window.localStorage.getItem(STORAGE_KEY)
    if (stored === 'compact' || stored === 'comfortable') return stored
    return DEFAULT_DENSITY
  } catch {
    return DEFAULT_DENSITY
  }
}

export function useAddressbookDensity(): [
  AddressbookDensity,
  (next: AddressbookDensity) => void,
  () => void,
] {
  const [density, setDensityState] = useState<AddressbookDensity>(readInitial)

  useEffect(() => {
    if (typeof window === 'undefined') return
    try {
      window.localStorage.setItem(STORAGE_KEY, density)
    } catch {
      // ignore quota / disabled storage
    }
  }, [density])

  const setDensity = useCallback((next: AddressbookDensity) => {
    setDensityState(next)
  }, [])

  const toggle = useCallback(() => {
    setDensityState((d) => (d === 'compact' ? 'comfortable' : 'compact'))
  }, [])

  return [density, setDensity, toggle]
}
