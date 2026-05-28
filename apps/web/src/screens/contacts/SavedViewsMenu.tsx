// apps/web/src/screens/contacts/SavedViewsMenu.tsx
//
// Phase G Phase 4 Task 8 — Dropdown für User-Custom Saved Views.
//
// Renders einen Chip „Eigene Ansichten ▾" der bei Click ein Dropdown mit:
//   1. Liste aller Custom-Views (Click = apply, Hover-Icon = delete)
//   2. „Diese Ansicht speichern …" am Ende
// auflistet. Bei 0 Custom-Views wird nur der Save-Eintrag gezeigt
// (sonst wäre das Dropdown leer und der User hätte keinen Weg zum
// Speichern).

import { useEffect, useRef, useState } from 'react'
import type { ContactSavedView } from '@/types/contactEvents'

export interface SavedViewsMenuProps {
  views: ContactSavedView[]
  onApply: (view: ContactSavedView) => void
  onDelete: (viewId: string) => void
  onOpenSaveDialog: () => void
  isDeleting?: boolean
}

export function SavedViewsMenu({
  views,
  onApply,
  onDelete,
  onOpenSaveDialog,
  isDeleting,
}: SavedViewsMenuProps) {
  const [open, setOpen] = useState(false)
  const rootRef = useRef<HTMLDivElement>(null)

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

  function handleApply(view: ContactSavedView) {
    onApply(view)
    setOpen(false)
  }

  function handleDelete(view: ContactSavedView) {
    const ok =
      typeof window === 'undefined'
        ? true
        : window.confirm(`Ansicht „${view.name}" löschen?`)
    if (!ok) return
    onDelete(view.id)
  }

  function handleSaveClick() {
    setOpen(false)
    onOpenSaveDialog()
  }

  return (
    <div
      ref={rootRef}
      data-testid="saved-views-menu"
      style={{ position: 'relative', flexShrink: 0 }}
    >
      <button
        type="button"
        aria-haspopup="menu"
        aria-expanded={open}
        aria-label="Eigene Ansichten"
        onClick={() => setOpen((v) => !v)}
        style={{
          padding: '3px 10px',
          borderRadius: 'var(--radius-pill, 9999px)',
          border: '1px solid var(--border-primary)',
          background: 'transparent',
          color: 'var(--text-body)',
          fontSize: 12,
          fontWeight: 500,
          cursor: 'pointer',
          whiteSpace: 'nowrap',
        }}
      >
        Eigene Ansichten ▾
      </button>

      {open && (
        <div
          role="menu"
          aria-label="Eigene Ansichten"
          style={{
            position: 'absolute',
            top: 'calc(100% + 4px)',
            left: 0,
            minWidth: 220,
            background: 'var(--surface-primary, #fff)',
            border: '1px solid var(--border-primary)',
            borderRadius: 'var(--radius-sm, 6px)',
            boxShadow: '0 8px 24px rgba(0,0,0,0.12)',
            padding: '4px 0',
            zIndex: 50,
            display: 'flex',
            flexDirection: 'column',
            fontSize: 13,
            color: 'var(--text-body)',
          }}
        >
          {views.length === 0 ? (
            <div
              style={{
                padding: '6px 12px',
                color: 'var(--text-tertiary, #999)',
                fontSize: 12,
                fontStyle: 'italic',
              }}
            >
              Keine eigenen Ansichten
            </div>
          ) : (
            <div style={{ maxHeight: 260, overflowY: 'auto' }}>
              {views.map((view) => (
                <div
                  key={view.id}
                  data-testid={`saved-view-row-${view.id}`}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: 4,
                    padding: '0 6px 0 0',
                  }}
                >
                  <button
                    type="button"
                    role="menuitem"
                    onClick={() => handleApply(view)}
                    style={{
                      flex: 1,
                      textAlign: 'left',
                      background: 'transparent',
                      border: 'none',
                      padding: '6px 12px',
                      fontSize: 13,
                      cursor: 'pointer',
                      color: 'var(--text-body)',
                    }}
                  >
                    {view.name}
                  </button>
                  <button
                    type="button"
                    aria-label={`Ansicht „${view.name}" löschen`}
                    onClick={() => handleDelete(view)}
                    disabled={isDeleting}
                    style={{
                      background: 'transparent',
                      border: 'none',
                      padding: '4px 6px',
                      cursor: 'pointer',
                      color: 'var(--text-tertiary, #999)',
                      fontSize: 14,
                    }}
                  >
                    🗑
                  </button>
                </div>
              ))}
            </div>
          )}

          <div
            style={{
              borderTop: '1px solid var(--border-primary)',
              padding: '2px 0',
            }}
          >
            <button
              type="button"
              role="menuitem"
              onClick={handleSaveClick}
              data-testid="saved-views-menu-save"
              style={{
                display: 'block',
                width: '100%',
                textAlign: 'left',
                background: 'transparent',
                border: 'none',
                padding: '7px 14px',
                fontSize: 13,
                cursor: 'pointer',
                color: 'var(--brand-blue, #2563eb)',
                fontWeight: 500,
              }}
            >
              + Diese Ansicht speichern …
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
