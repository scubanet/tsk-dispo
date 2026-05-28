// apps/web/src/hooks/useAddressbookColumns.ts
//
// Phase G Phase 4 Task 3 — Column-Visibility-State für die AddressbookTable.
// Persistiert die Liste der sichtbaren Spalten (ColumnId[]) in localStorage.
// Default = alle Spalten mit `defaultVisible: true` aus dem COLUMN_CATALOG.
//
// Wichtig: Die `name`-Spalte ist immer sichtbar. `toggle('name')` ist ein
// No-Op — wir verhindern damit, dass der User die Identitätsspalte verbirgt.
import { useCallback, useEffect, useState } from 'react'

export type ColumnId =
  | 'name'
  | 'roles'
  | 'email'
  | 'last_contact'
  | 'phone'
  | 'saldo'
  | 'tags'
  | 'org'
  | 'pipeline_stage'
  | 'sprache'
  | 'quelle'
  | 'geburtstag'
  | 'padi_number'
  | 'created_at'

export interface ColumnDef {
  id: ColumnId
  labelKey: string
  defaultVisible: boolean
  gridWidth: string
  sortable?: boolean
}

export const COLUMN_CATALOG: ColumnDef[] = [
  { id: 'name',           labelKey: 'Name',             defaultVisible: true,  gridWidth: '3fr',   sortable: true },
  { id: 'roles',          labelKey: 'Rollen',           defaultVisible: true,  gridWidth: '100px' },
  { id: 'email',          labelKey: 'Email',            defaultVisible: true,  gridWidth: '3fr' },
  { id: 'phone',          labelKey: 'Telefon',          defaultVisible: false, gridWidth: '150px' },
  { id: 'last_contact',   labelKey: 'Letzter Kontakt',  defaultVisible: true,  gridWidth: '160px', sortable: true },
  { id: 'saldo',          labelKey: 'Saldo',            defaultVisible: false, gridWidth: '120px', sortable: true },
  { id: 'tags',           labelKey: 'Tags',             defaultVisible: false, gridWidth: '180px' },
  { id: 'org',            labelKey: 'Organisation',     defaultVisible: false, gridWidth: '160px' },
  { id: 'pipeline_stage', labelKey: 'Pipeline',         defaultVisible: false, gridWidth: '130px' },
  { id: 'sprache',        labelKey: 'Sprache',          defaultVisible: false, gridWidth: '80px' },
  { id: 'quelle',         labelKey: 'Quelle',           defaultVisible: false, gridWidth: '120px' },
  { id: 'geburtstag',     labelKey: 'Geburtstag',       defaultVisible: false, gridWidth: '100px' },
  { id: 'padi_number',    labelKey: 'PADI-Nr',          defaultVisible: false, gridWidth: '100px' },
  { id: 'created_at',     labelKey: 'Erstellt',         defaultVisible: false, gridWidth: '110px', sortable: true },
]

const STORAGE_KEY = 'addressbook.columns'
const VALID_IDS = new Set<ColumnId>(COLUMN_CATALOG.map((c) => c.id))

export function defaultVisibleIds(): ColumnId[] {
  return COLUMN_CATALOG.filter((c) => c.defaultVisible).map((c) => c.id)
}

function readInitial(): ColumnId[] {
  if (typeof window === 'undefined') return defaultVisibleIds()
  try {
    const stored = window.localStorage.getItem(STORAGE_KEY)
    if (!stored) return defaultVisibleIds()
    const parsed = JSON.parse(stored)
    if (!Array.isArray(parsed)) return defaultVisibleIds()
    const filtered = parsed.filter((x): x is ColumnId => typeof x === 'string' && VALID_IDS.has(x as ColumnId))
    if (filtered.length === 0) return defaultVisibleIds()
    // Garantieren, dass 'name' immer drin ist.
    if (!filtered.includes('name')) filtered.unshift('name')
    return filtered
  } catch {
    return defaultVisibleIds()
  }
}

export interface UseAddressbookColumnsResult {
  visibleIds: ColumnId[]
  toggle: (id: ColumnId) => void
  /**
   * Replace the full visible-column list (e.g. when applying a saved view).
   * Filters invalid IDs, dedupes, guarantees 'name' is present, and
   * re-sorts by COLUMN_CATALOG order.
   */
  setVisibleIds: (ids: ColumnId[]) => void
  reset: () => void
}

export function useAddressbookColumns(): UseAddressbookColumnsResult {
  const [visibleIds, setVisibleIdsState] = useState<ColumnId[]>(readInitial)

  useEffect(() => {
    if (typeof window === 'undefined') return
    try {
      window.localStorage.setItem(STORAGE_KEY, JSON.stringify(visibleIds))
    } catch {
      // ignore quota / disabled storage
    }
  }, [visibleIds])

  const toggle = useCallback((id: ColumnId) => {
    // 'name' ist immer sichtbar — silently ignore.
    if (id === 'name') return
    setVisibleIdsState((prev) => {
      if (prev.includes(id)) {
        return prev.filter((c) => c !== id)
      }
      // Beim Hinzufügen die Reihenfolge des COLUMN_CATALOG bewahren.
      const next = [...prev, id]
      const order = new Map(COLUMN_CATALOG.map((c, i) => [c.id, i]))
      next.sort((a, b) => (order.get(a) ?? 0) - (order.get(b) ?? 0))
      return next
    })
  }, [])

  const setVisibleIds = useCallback((ids: ColumnId[]) => {
    const order = new Map(COLUMN_CATALOG.map((c, i) => [c.id, i]))
    const seen = new Set<ColumnId>()
    const cleaned: ColumnId[] = []
    for (const id of ids) {
      if (!VALID_IDS.has(id)) continue
      if (seen.has(id)) continue
      seen.add(id)
      cleaned.push(id)
    }
    if (!cleaned.includes('name')) cleaned.unshift('name')
    cleaned.sort((a, b) => (order.get(a) ?? 0) - (order.get(b) ?? 0))
    setVisibleIdsState(cleaned)
  }, [])

  const reset = useCallback(() => {
    setVisibleIdsState(defaultVisibleIds())
  }, [])

  return { visibleIds, toggle, setVisibleIds, reset }
}
