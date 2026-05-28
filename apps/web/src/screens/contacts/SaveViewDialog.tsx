// apps/web/src/screens/contacts/SaveViewDialog.tsx
//
// Phase G Phase 4 Task 8 — Speichern-Dialog für Custom Saved Views.
//
// Simples Modal mit Name-Input und Save/Cancel-Buttons.
// Esc schließt, Enter submitted, Backdrop-Click schließt.
// Bei Save-Error wird die Error-Message als Banner angezeigt
// (typischerweise UNIQUE-Constraint-Violation "Name existiert bereits").

import { useEffect, useRef, useState } from 'react'

export interface SaveViewDialogProps {
  open: boolean
  onClose: () => void
  onSave: (name: string) => Promise<void>
  isSaving: boolean
}

export function SaveViewDialog({
  open,
  onClose,
  onSave,
  isSaving,
}: SaveViewDialogProps) {
  const [name, setName] = useState('')
  const [error, setError] = useState<string | null>(null)
  const inputRef = useRef<HTMLInputElement>(null)

  // Reset state when dialog (re-)opens.
  useEffect(() => {
    if (open) {
      setName('')
      setError(null)
      // Focus input on next tick.
      const id = window.setTimeout(() => inputRef.current?.focus(), 0)
      return () => window.clearTimeout(id)
    }
    return undefined
  }, [open])

  // Esc closes the dialog.
  useEffect(() => {
    if (!open) return
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        e.preventDefault()
        onClose()
      }
    }
    document.addEventListener('keydown', onKey)
    return () => document.removeEventListener('keydown', onKey)
  }, [open, onClose])

  if (!open) return null

  const trimmed = name.trim()
  const canSave = trimmed.length > 0 && !isSaving

  async function handleSave() {
    if (!canSave) return
    setError(null)
    try {
      await onSave(trimmed)
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err)
      // UNIQUE-Constraint (Postgres code 23505) → freundliche Meldung.
      if (
        /duplicate/i.test(msg) ||
        msg.includes('23505') ||
        /unique/i.test(msg)
      ) {
        setError('Name existiert bereits')
      } else {
        setError(msg)
      }
    }
  }

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    void handleSave()
  }

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-label="Ansicht speichern"
      data-testid="save-view-dialog"
      onClick={() => onClose()}
      style={{
        position: 'fixed',
        inset: 0,
        background: 'rgba(0,0,0,0.4)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        zIndex: 100,
      }}
    >
      <form
        onSubmit={handleSubmit}
        onClick={(e) => e.stopPropagation()}
        style={{
          background: 'var(--surface-primary, #fff)',
          borderRadius: 8,
          padding: '20px 24px',
          minWidth: 320,
          maxWidth: 380,
          boxShadow: '0 12px 36px rgba(0,0,0,0.2)',
          display: 'flex',
          flexDirection: 'column',
          gap: 12,
        }}
      >
        <h3 style={{ margin: 0, fontSize: 16, fontWeight: 600 }}>
          Ansicht speichern
        </h3>
        <label
          style={{
            display: 'flex',
            flexDirection: 'column',
            gap: 4,
            fontSize: 13,
            color: 'var(--text-body)',
          }}
        >
          <span>Name</span>
          <input
            ref={inputRef}
            type="text"
            value={name}
            maxLength={60}
            onChange={(e) => setName(e.target.value)}
            placeholder="z.B. Meine Studenten"
            aria-label="Name der Ansicht"
            disabled={isSaving}
            style={{
              padding: '6px 10px',
              border: '1px solid var(--border-primary)',
              borderRadius: 6,
              fontSize: 13,
            }}
          />
        </label>

        {error && (
          <div
            role="alert"
            data-testid="save-view-error"
            style={{
              padding: '6px 10px',
              background: 'var(--danger-bg, #fef2f2)',
              color: 'var(--danger, #b91c1c)',
              borderRadius: 6,
              fontSize: 12,
            }}
          >
            {error}
          </div>
        )}

        <div
          style={{
            display: 'flex',
            justifyContent: 'flex-end',
            gap: 8,
            marginTop: 4,
          }}
        >
          <button
            type="button"
            onClick={onClose}
            disabled={isSaving}
            style={{
              padding: '6px 14px',
              borderRadius: 'var(--radius-pill, 9999px)',
              border: '1px solid var(--border-primary)',
              background: 'transparent',
              color: 'var(--text-body)',
              fontSize: 13,
              cursor: 'pointer',
            }}
          >
            Abbrechen
          </button>
          <button
            type="submit"
            disabled={!canSave}
            style={{
              padding: '6px 14px',
              borderRadius: 'var(--radius-pill, 9999px)',
              border: '1px solid var(--brand-blue, #2563eb)',
              background: canSave
                ? 'var(--brand-blue, #2563eb)'
                : 'var(--surface-secondary, #f5f5f7)',
              color: canSave ? '#fff' : 'var(--text-tertiary, #999)',
              fontSize: 13,
              cursor: canSave ? 'pointer' : 'not-allowed',
              fontWeight: 500,
            }}
          >
            {isSaving ? 'Speichert …' : 'Speichern'}
          </button>
        </div>
      </form>
    </div>
  )
}
