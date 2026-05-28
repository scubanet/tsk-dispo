// apps/web/src/screens/contacts/FilterChipDropdown.tsx
//
// Phase G Phase 4 Task 5 — Reusable Filter-Chip mit Multi-Select-Dropdown.
//
// Inactive (selected.length === 0): grauer Outline-Chip mit `Label ▾`.
// Active   (selected.length >= 1):  farbiger Chip mit
//                                   `Label: val1, val2 ▾` (max 2 Werte,
//                                   danach `+N` als Overflow-Hinweis).
// Click öffnet/schliesst das Dropdown, Click-outside schliesst.

import { useEffect, useMemo, useRef, useState } from 'react'

export interface FilterChipOption<T extends string> {
  value: T
  label: string
}

export interface FilterChipDropdownProps<T extends string> {
  label: string
  options: ReadonlyArray<FilterChipOption<T>>
  selected: ReadonlyArray<T>
  onChange: (next: T[]) => void
}

export function FilterChipDropdown<T extends string>({
  label,
  options,
  selected,
  onChange,
}: FilterChipDropdownProps<T>) {
  const [open, setOpen] = useState(false)
  const rootRef = useRef<HTMLDivElement>(null)
  const isActive = selected.length > 0

  useEffect(() => {
    if (!open) return
    const onDocMouseDown = (e: MouseEvent) => {
      if (!rootRef.current) return
      if (e.target instanceof Node && rootRef.current.contains(e.target)) return
      setOpen(false)
    }
    document.addEventListener('mousedown', onDocMouseDown)
    return () => document.removeEventListener('mousedown', onDocMouseDown)
  }, [open])

  const chipText = useMemo(() => {
    if (!isActive) return `${label} ▾`
    const labelByValue = new Map(options.map((o) => [o.value, o.label]))
    const shown = selected.slice(0, 2).map((v) => labelByValue.get(v) ?? v)
    const overflow = selected.length - shown.length
    const valuesStr =
      overflow > 0
        ? `${shown.join(', ')} +${overflow}`
        : shown.join(', ')
    return `${label}: ${valuesStr} ▾`
  }, [isActive, label, options, selected])

  function toggleValue(value: T) {
    const isSelected = selected.includes(value)
    const next = isSelected
      ? selected.filter((v) => v !== value)
      : [...selected, value]
    onChange(next as T[])
  }

  function clearAll() {
    onChange([])
  }

  return (
    <div ref={rootRef} style={{ position: 'relative', flexShrink: 0 }}>
      <button
        type="button"
        aria-haspopup="listbox"
        aria-expanded={open}
        aria-label={label}
        onClick={() => setOpen((v) => !v)}
        style={{
          padding: '3px 10px',
          borderRadius: 'var(--radius-pill, 9999px)',
          border: '1px solid var(--border-primary)',
          background: isActive ? 'var(--brand-blue, #2563eb)' : 'transparent',
          color: isActive ? '#fff' : 'var(--text-body)',
          fontSize: 12,
          fontWeight: 500,
          cursor: 'pointer',
          whiteSpace: 'nowrap',
        }}
      >
        {chipText}
      </button>

      {open && (
        <div
          role="listbox"
          aria-label={label}
          style={{
            position: 'absolute',
            top: 'calc(100% + 4px)',
            left: 0,
            minWidth: 200,
            background: 'var(--surface-primary, #fff)',
            border: '1px solid var(--border-primary)',
            borderRadius: 'var(--radius-sm, 6px)',
            boxShadow: '0 8px 24px rgba(0,0,0,0.12)',
            padding: '6px 0',
            zIndex: 50,
            display: 'flex',
            flexDirection: 'column',
            fontSize: 13,
            color: 'var(--text-body)',
          }}
        >
          <div
            style={{
              display: 'flex',
              flexDirection: 'column',
              padding: '4px 0',
              maxHeight: 280,
              overflowY: 'auto',
            }}
          >
            {options.map((opt) => {
              const checked = selected.includes(opt.value)
              return (
                <label
                  key={opt.value}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: 8,
                    padding: '5px 12px',
                    cursor: 'pointer',
                    userSelect: 'none',
                  }}
                >
                  <input
                    type="checkbox"
                    checked={checked}
                    onChange={() => toggleValue(opt.value)}
                    aria-label={opt.label}
                  />
                  <span>{opt.label}</span>
                </label>
              )
            })}
          </div>
          <div
            style={{
              borderTop: '1px solid var(--border-primary)',
              padding: '6px 12px',
              display: 'flex',
              justifyContent: 'flex-end',
            }}
          >
            <button
              type="button"
              onClick={clearAll}
              style={{
                background: 'transparent',
                border: 'none',
                padding: 0,
                color: 'var(--brand-blue, #2563eb)',
                fontSize: 12,
                cursor: 'pointer',
                textDecoration: 'underline',
              }}
            >
              Alle abwählen
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
