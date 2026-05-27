// apps/web/src/hooks/useSidebarToggle.ts
//
// Phase G Phase 3 Task 14 — Collapse/Expand-State für Sidebars mit
// localStorage-Persistenz. Liefert [open, toggle] zurück.
import { useCallback, useEffect, useState } from 'react'

export function useSidebarToggle(
  key: string,
  defaultOpen: boolean,
): [boolean, () => void] {
  const [open, setOpen] = useState<boolean>(() => {
    if (typeof window === 'undefined') return defaultOpen
    try {
      const stored = window.localStorage.getItem(key)
      if (stored === null) return defaultOpen
      return stored === 'true'
    } catch {
      return defaultOpen
    }
  })

  useEffect(() => {
    if (typeof window === 'undefined') return
    try {
      window.localStorage.setItem(key, String(open))
    } catch {
      // ignore quota / disabled storage
    }
  }, [key, open])

  const toggle = useCallback(() => setOpen(o => !o), [])

  return [open, toggle]
}
