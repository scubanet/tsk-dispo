// apps/web/src/screens/contacts/sidebar/EditableField.tsx
//
// Phase G Phase 3 — Inline-Edit primitive für Single-Value-Felder.
// Verhalten:
//   - Klick auf den Wert → editing-Mode (Input wird focused + selected)
//   - Enter / Tab → commit (onSave wird gerufen)
//   - Esc → cancel
//   - Click outside (blur) → cancel
//   - Validate liefert null bei ok, string als Error → roter Border + Tooltip
//   - onSave error → revert + Error-Anzeige
//
// Null-Werte werden als '—' angezeigt.
import { useEffect, useRef, useState } from 'react'

type FieldType = 'text' | 'email' | 'tel' | 'date' | 'number'

interface Props {
  label: string
  value: string | null
  onSave: (next: string | null) => Promise<void> | void
  type?: FieldType
  validate?: (value: string) => string | null
  placeholder?: string
}

export function EditableField({
  label,
  value,
  onSave,
  type = 'text',
  validate,
  placeholder,
}: Props) {
  const [editing, setEditing] = useState(false)
  const [draft, setDraft] = useState<string>(value ?? '')
  const [saving, setSaving] = useState(false)
  const [errorMsg, setErrorMsg] = useState<string | null>(null)
  const inputRef = useRef<HTMLInputElement | null>(null)
  // Avoids double-handling on Enter (keyDown commit → blur cancel).
  const committedRef = useRef(false)

  useEffect(() => {
    if (!editing) setDraft(value ?? '')
  }, [value, editing])

  useEffect(() => {
    if (editing && inputRef.current) {
      inputRef.current.focus()
      inputRef.current.select()
    }
  }, [editing])

  function startEdit() {
    if (saving) return
    committedRef.current = false
    setErrorMsg(null)
    setDraft(value ?? '')
    setEditing(true)
  }

  function cancel() {
    if (committedRef.current) return
    setEditing(false)
    setErrorMsg(null)
    setDraft(value ?? '')
  }

  async function commit() {
    if (committedRef.current) return
    committedRef.current = true
    const trimmed = draft.trim()
    const validationError = validate ? validate(trimmed) : null
    if (validationError) {
      setErrorMsg(validationError)
      committedRef.current = false
      return
    }
    // No-op if unchanged
    const original = value ?? ''
    if (trimmed === original) {
      setEditing(false)
      return
    }
    setSaving(true)
    try {
      const next = trimmed === '' ? null : trimmed
      await onSave(next)
      setEditing(false)
      setErrorMsg(null)
    } catch (e) {
      committedRef.current = false
      setErrorMsg(e instanceof Error ? e.message : 'Fehler beim Speichern')
      setDraft(value ?? '')
    } finally {
      setSaving(false)
    }
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 2, padding: '6px 0' }}>
      <div style={{
        fontSize: 11,
        color: 'var(--text-tertiary, #888)',
        letterSpacing: 0.2,
      }}>
        {label}
      </div>

      {editing ? (
        <input
          ref={inputRef}
          type={type}
          value={draft}
          placeholder={placeholder}
          disabled={saving}
          onChange={e => setDraft(e.target.value)}
          onKeyDown={e => {
            if (e.key === 'Enter' || e.key === 'Tab') {
              e.preventDefault()
              void commit()
            } else if (e.key === 'Escape') {
              e.preventDefault()
              cancel()
            }
          }}
          onBlur={() => cancel()}
          title={errorMsg ?? undefined}
          style={{
            font: 'inherit',
            fontSize: 13,
            padding: '4px 6px',
            border: `1px solid ${errorMsg ? 'var(--color-text-danger, #c0392b)' : 'var(--border-strong, #ccc)'}`,
            borderRadius: 4,
            background: 'var(--surface-primary, white)',
            outline: 'none',
            color: 'var(--text-primary, #222)',
          }}
        />
      ) : (
        <button
          type="button"
          onClick={startEdit}
          style={{
            font: 'inherit',
            fontSize: 13,
            padding: '4px 6px',
            margin: 0,
            border: '1px solid transparent',
            borderRadius: 4,
            background: 'transparent',
            textAlign: 'left',
            cursor: 'text',
            color: value == null
              ? 'var(--text-tertiary, #888)'
              : 'var(--text-primary, #222)',
          }}
        >
          {value == null || value === '' ? '—' : value}
        </button>
      )}

      {errorMsg && (
        <div
          role="alert"
          style={{
            fontSize: 11,
            color: 'var(--color-text-danger, #c0392b)',
            marginTop: 2,
          }}
        >
          {errorMsg}
        </div>
      )}
    </div>
  )
}
