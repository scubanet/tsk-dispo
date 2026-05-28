// apps/web/src/screens/contacts/ColumnPicker.tsx
//
// Phase G Phase 4 Task 3 — Dropdown-Button, der pro Catalog-Spalte eine
// Checkbox zeigt. Die `name`-Spalte ist immer aktiv und disabled.
// Footer: „Zurücksetzen"-Link rechtsbündig.
//
// Open/Close-State ist lokal. Click-outside schließt das Menu via
// document-level mousedown-Listener.
import { useEffect, useRef, useState } from 'react'
import { COLUMN_CATALOG, type ColumnId } from '@/hooks/useAddressbookColumns'

export interface ColumnPickerProps {
  visibleIds: ColumnId[]
  onToggle: (id: ColumnId) => void
  onReset: () => void
}

export function ColumnPicker({ visibleIds, onToggle, onReset }: ColumnPickerProps) {
  const [open, setOpen] = useState(false)
  const rootRef = useRef<HTMLDivElement>(null)
  const visibleSet = new Set(visibleIds)

  // Click-outside → close
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

  return (
    <div ref={rootRef} style={{ position: 'relative', flexShrink: 0 }}>
      <button
        type="button"
        aria-label="Spalten konfigurieren"
        title="Spalten konfigurieren"
        aria-haspopup="menu"
        aria-expanded={open}
        onClick={() => setOpen((v) => !v)}
        style={{
          width: 22,
          height: 22,
          display: 'inline-flex',
          alignItems: 'center',
          justifyContent: 'center',
          background: 'transparent',
          border: '1px solid var(--border-primary)',
          borderRadius: 'var(--radius-sm, 4px)',
          cursor: 'pointer',
          color: 'var(--text-secondary)',
          padding: 0,
          flexShrink: 0,
        }}
      >
        {/* Adjustments-Icon (2 horizontale Linien mit Slidern) */}
        <svg
          width={14}
          height={14}
          viewBox="0 0 14 14"
          aria-hidden="true"
          focusable="false"
        >
          <g stroke="currentColor" strokeWidth={1.4} strokeLinecap="round" fill="none">
            <line x1="2" y1="4" x2="12" y2="4" />
            <line x1="2" y1="10" x2="12" y2="10" />
            <circle cx="5" cy="4" r="1.4" fill="currentColor" stroke="none" />
            <circle cx="9" cy="10" r="1.4" fill="currentColor" stroke="none" />
          </g>
        </svg>
      </button>

      {open && (
        <div
          role="menu"
          aria-label="Spalten"
          style={{
            position: 'absolute',
            top: 'calc(100% + 4px)',
            right: 0,
            minWidth: 220,
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
              maxHeight: 320,
              overflowY: 'auto',
            }}
          >
            {COLUMN_CATALOG.map((col) => {
              const isVisible = visibleSet.has(col.id)
              const isDisabled = col.id === 'name'
              return (
                <label
                  key={col.id}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: 8,
                    padding: '5px 12px',
                    cursor: isDisabled ? 'default' : 'pointer',
                    opacity: isDisabled ? 0.7 : 1,
                    userSelect: 'none',
                  }}
                >
                  <input
                    type="checkbox"
                    checked={isVisible}
                    disabled={isDisabled}
                    onChange={() => onToggle(col.id)}
                    aria-label={col.labelKey}
                  />
                  <span>{col.labelKey}</span>
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
              onClick={() => onReset()}
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
              Zurücksetzen
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
