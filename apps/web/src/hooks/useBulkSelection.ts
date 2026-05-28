// apps/web/src/hooks/useBulkSelection.ts
//
// Phase G Phase 4 Task 6 — Bulk-Selection-State für die AddressbookTable.
//
// Hält ein `Set<T>` mit ausgewählten IDs, plus die typischen Helfer
// (toggle/selectAll/clear) und Aggregate (allSelected/someSelected) für
// einen indeterminate-fähigen Header-Checkbox-State.
//
// Verhalten bei Wechsel der sichtbaren IDs (Filter / Search): der Hook
// clear()'d die Selektion. Das ist deutlich vorhersagbarer als ein Reduce
// auf die Schnittmenge — der User sieht beim Filter-Wechsel garantiert
// keinen "verborgenen" Selection-Rest mehr.
import { useCallback, useEffect, useMemo, useRef, useState } from 'react'

export interface UseBulkSelectionResult<T extends string> {
  selected: Set<T>
  isSelected: (id: T) => boolean
  toggle: (id: T) => void
  selectAll: () => void
  clear: () => void
  allSelected: boolean
  someSelected: boolean
}

export function useBulkSelection<T extends string>(
  currentIds: T[],
): UseBulkSelectionResult<T> {
  const [selected, setSelected] = useState<Set<T>>(() => new Set<T>())

  // Stable signature für currentIds, damit useEffect nicht bei jeder neuen
  // Array-Referenz feuert. Wir vergleichen joined-strings — günstig genug
  // bei <500 Rows und sauber für equality.
  const idsKey = currentIds.join('')
  const lastIdsKeyRef = useRef<string | null>(null)

  useEffect(() => {
    if (lastIdsKeyRef.current === null) {
      // First mount: nur den Marker setzen, nicht clearen (sonst würden
      // initial bereits gesetzte Selektionen — falls jemand sie via state
      // setter hereinpushed — verlorengehen).
      lastIdsKeyRef.current = idsKey
      return
    }
    if (lastIdsKeyRef.current !== idsKey) {
      lastIdsKeyRef.current = idsKey
      setSelected((prev) => (prev.size === 0 ? prev : new Set<T>()))
    }
  }, [idsKey])

  const isSelected = useCallback(
    (id: T) => selected.has(id),
    [selected],
  )

  const toggle = useCallback((id: T) => {
    setSelected((prev) => {
      const next = new Set(prev)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }, [])

  const selectAll = useCallback(() => {
    setSelected(new Set(currentIds))
  }, [currentIds])

  const clear = useCallback(() => {
    setSelected((prev) => (prev.size === 0 ? prev : new Set<T>()))
  }, [])

  const allSelected = useMemo(
    () => currentIds.length > 0 && selected.size === currentIds.length,
    [selected, currentIds.length],
  )

  const someSelected = useMemo(
    () => selected.size > 0 && !allSelected,
    [selected.size, allSelected],
  )

  return { selected, isSelected, toggle, selectAll, clear, allSelected, someSelected }
}
