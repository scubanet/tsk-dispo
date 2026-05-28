// apps/web/src/hooks/useAddressbookSort.ts
//
// Phase G Phase 4 Task 4 — Multi-Sort-State für die AddressbookTable.
//
// Liest/schreibt URL-Param `sort` in der Form `field:dir,field:dir`.
// Beispiel: `?sort=last_contact:desc,name:asc`. Reihenfolge der Einträge
// definiert die Sort-Priorität (erster Eintrag = primärer Sort).
//
// Click-Logik (per Spec §6.5):
//   Plain-Click:
//     - Spalte noch nicht sortiert     → sort = [{field, asc}]
//     - Spalte sortiert asc            → sort = [{field, desc}]
//     - Spalte sortiert desc           → sort = []   (cycle to off)
//   Shift-Click (Multi-Sort):
//     - Spalte noch nicht im Set       → append {field, asc}
//     - Spalte schon asc               → flip to desc (gleicher Index)
//     - Spalte schon desc              → remove (preserves other sorts)
//
// Mapping `ColumnId` → `SortSpec.field` ist als `COLUMN_TO_SORT_FIELD`
// exportiert, damit die AddressbookTable denselben Lookup wiederverwenden
// kann (Header-Indicator zeigt nur sortierbare Spalten).

import { useCallback, useMemo } from 'react'
import { useSearchParams } from 'react-router-dom'
import type { SortSpec } from '@/lib/contactQueries'
import type { ColumnId } from '@/hooks/useAddressbookColumns'

// ── Public mapping ──────────────────────────────────────────────────────

/**
 * ColumnId → SortSpec.field. Spalten, die NICHT sortierbar sind, fehlen hier
 * absichtlich. Der Catalog-Eintrag (`sortable: true`) und dieses Mapping
 * müssen synchron bleiben — sortable-Spalten ohne Mapping wären ein Bug.
 */
export const COLUMN_TO_SORT_FIELD: Partial<Record<ColumnId, SortSpec['field']>> = {
  name:         'name',
  last_contact: 'last_contact',
  saldo:        'balance',
  created_at:   'created_at',
}

const VALID_FIELDS = new Set<SortSpec['field']>(['name', 'last_contact', 'balance', 'created_at'])
const VALID_DIRS = new Set<SortSpec['direction']>(['asc', 'desc'])

// ── Serialisierung ──────────────────────────────────────────────────────

export function parseSortParam(raw: string | null): SortSpec[] {
  if (!raw) return []
  const out: SortSpec[] = []
  for (const part of raw.split(',')) {
    const trimmed = part.trim()
    if (!trimmed) continue
    const [field, dir] = trimmed.split(':')
    if (!field || !dir) continue
    if (!VALID_FIELDS.has(field as SortSpec['field'])) continue
    if (!VALID_DIRS.has(dir as SortSpec['direction'])) continue
    out.push({
      field: field as SortSpec['field'],
      direction: dir as SortSpec['direction'],
    })
  }
  return out
}

export function serializeSort(sort: SortSpec[]): string {
  return sort.map((s) => `${s.field}:${s.direction}`).join(',')
}

// ── Hook ─────────────────────────────────────────────────────────────────

export interface UseAddressbookSortResult {
  sort: SortSpec[]
  onHeaderClick: (columnId: ColumnId, shiftKey: boolean) => void
  clear: () => void
}

export function useAddressbookSort(): UseAddressbookSortResult {
  const [searchParams, setSearchParams] = useSearchParams()

  const raw = searchParams.get('sort')
  const sort = useMemo<SortSpec[]>(() => parseSortParam(raw), [raw])

  const writeSort = useCallback(
    (next: SortSpec[]) => {
      setSearchParams(
        (prev) => {
          const params = new URLSearchParams(prev)
          if (next.length === 0) {
            params.delete('sort')
          } else {
            params.set('sort', serializeSort(next))
          }
          return params
        },
        { replace: true },
      )
    },
    [setSearchParams],
  )

  const onHeaderClick = useCallback(
    (columnId: ColumnId, shiftKey: boolean) => {
      const field = COLUMN_TO_SORT_FIELD[columnId]
      if (!field) return // Spalte ist nicht sortierbar — silent no-op.

      const existingIdx = sort.findIndex((s) => s.field === field)
      const existing = existingIdx >= 0 ? sort[existingIdx] : null

      if (shiftKey) {
        // Multi-Sort: append / flip / remove
        if (!existing) {
          writeSort([...sort, { field, direction: 'asc' }])
          return
        }
        if (existing.direction === 'asc') {
          const next = sort.slice()
          next[existingIdx] = { field, direction: 'desc' }
          writeSort(next)
          return
        }
        // desc → remove, preserve other sorts
        const next = sort.filter((_, i) => i !== existingIdx)
        writeSort(next)
        return
      }

      // Plain-Click: replace the whole sort with the cycled spec for this
      // column. Cycle asc → desc → off.
      if (!existing) {
        writeSort([{ field, direction: 'asc' }])
        return
      }
      if (existing.direction === 'asc') {
        writeSort([{ field, direction: 'desc' }])
        return
      }
      // desc → off
      writeSort([])
    },
    [sort, writeSort],
  )

  const clear = useCallback(() => {
    writeSort([])
  }, [writeSort])

  return { sort, onHeaderClick, clear }
}
