// apps/web/src/screens/contacts/activity/ContactPicker.tsx
//
// Phase G Phase 5 Task 2 — ContactPicker (Autocomplete-Combobox).
//
// Pflichtfeld im ActivityComposer: erst Contact wählen, dann Note/Call/…
// loggen. Klassisches Combobox-Pattern: Input + Dropdown mit Suchresultaten,
// Keyboard-Navigation (Arrows/Enter/Esc), Click-outside schließt.
//
// Wenn ein Contact ausgewählt ist, wird statt des Inputs ein kompakter Chip
// gerendert (`{display_name} ✕`).

import { useEffect, useMemo, useRef, useState } from 'react'
import { useContactList } from '@/hooks/useContactList'
import { Avatar } from '@/foundation/primitives/Avatar'

export interface ContactPickerValue {
  id: string
  display_name: string
}

export interface ContactPickerProps {
  value: ContactPickerValue | null
  onChange: (next: ContactPickerValue | null) => void
  placeholder?: string
  autoFocus?: boolean
}

const MIN_QUERY_LENGTH = 2
const MAX_RESULTS = 10

export function ContactPicker({
  value,
  onChange,
  placeholder = 'Contact suchen…',
  autoFocus = false,
}: ContactPickerProps) {
  const [query, setQuery] = useState('')
  const [open, setOpen] = useState(false)
  const [focusedIndex, setFocusedIndex] = useState(0)
  const rootRef = useRef<HTMLDivElement>(null)
  const inputRef = useRef<HTMLInputElement>(null)

  const enabled = query.trim().length >= MIN_QUERY_LENGTH
  const listQuery = useContactList(
    enabled ? { searchText: query.trim() } : {},
    0,
    MAX_RESULTS,
  )
  // Manually short-circuit when not enabled — useContactList doesn't expose
  // `enabled`, but we just don't read its rows in that case.
  const results = useMemo(() => {
    if (!enabled) return []
    return (listQuery.data?.rows ?? []).slice(0, MAX_RESULTS)
  }, [enabled, listQuery.data])

  const isLoading = enabled && listQuery.isFetching
  const showEmpty =
    enabled && !listQuery.isFetching && results.length === 0

  // Reset focusedIndex when result set changes.
  useEffect(() => {
    setFocusedIndex(0)
  }, [results.length])

  // Click-outside closes dropdown.
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

  function selectResult(r: { id: string; display_name: string }) {
    onChange({ id: r.id, display_name: r.display_name })
    setQuery('')
    setOpen(false)
  }

  function onKeyDown(e: React.KeyboardEvent<HTMLInputElement>) {
    if (e.key === 'ArrowDown') {
      e.preventDefault()
      if (results.length === 0) return
      setOpen(true)
      setFocusedIndex((i) => Math.min(i + 1, results.length - 1))
    } else if (e.key === 'ArrowUp') {
      e.preventDefault()
      if (results.length === 0) return
      setFocusedIndex((i) => Math.max(i - 1, 0))
    } else if (e.key === 'Enter') {
      if (open && results.length > 0) {
        e.preventDefault()
        const r = results[focusedIndex] ?? results[0]
        if (r) selectResult(r)
      }
    } else if (e.key === 'Escape') {
      e.preventDefault()
      setOpen(false)
    }
  }

  // ── Chip mode ──────────────────────────────────────────────────────────
  if (value) {
    return (
      <div
        ref={rootRef}
        data-testid="contact-picker"
        style={{
          display: 'inline-flex',
          alignItems: 'center',
          gap: 6,
          padding: '4px 8px 4px 10px',
          borderRadius: 9999,
          background: 'var(--brand-blue, #2563eb)',
          color: '#fff',
          fontSize: 13,
          fontWeight: 500,
          maxWidth: '100%',
        }}
      >
        <span
          data-testid="contact-picker-chip-name"
          style={{
            whiteSpace: 'nowrap',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
          }}
        >
          {value.display_name}
        </span>
        <button
          type="button"
          aria-label="Auswahl entfernen"
          onClick={() => {
            onChange(null)
            // Focus back to the input that re-renders on next tick.
            setTimeout(() => inputRef.current?.focus(), 0)
          }}
          style={{
            background: 'transparent',
            border: 'none',
            color: '#fff',
            cursor: 'pointer',
            padding: 0,
            display: 'inline-flex',
            alignItems: 'center',
            justifyContent: 'center',
            width: 18,
            height: 18,
            borderRadius: 9999,
            fontSize: 14,
            lineHeight: 1,
          }}
        >
          {'✕'}
        </button>
      </div>
    )
  }

  // ── Combobox mode ──────────────────────────────────────────────────────
  const dropdownVisible = open && enabled

  return (
    <div
      ref={rootRef}
      data-testid="contact-picker"
      style={{ position: 'relative', width: '100%' }}
    >
      <div style={{ position: 'relative' }}>
        <input
          ref={inputRef}
          type="text"
          role="combobox"
          aria-haspopup="listbox"
          aria-expanded={dropdownVisible}
          aria-autocomplete="list"
          aria-controls="contact-picker-listbox"
          aria-activedescendant={
            dropdownVisible && results[focusedIndex]
              ? `contact-picker-opt-${results[focusedIndex].id}`
              : undefined
          }
          placeholder={placeholder}
          autoFocus={autoFocus}
          value={query}
          onChange={(e) => {
            setQuery(e.target.value)
            setOpen(true)
          }}
          onFocus={() => {
            if (enabled) setOpen(true)
          }}
          onKeyDown={onKeyDown}
          style={{
            width: '100%',
            padding: '6px 28px 6px 10px',
            border: '1px solid var(--border-primary)',
            borderRadius: 'var(--radius-sm, 6px)',
            fontSize: 14,
            background: 'var(--surface-primary, #fff)',
            color: 'var(--text-body)',
            outline: 'none',
            boxSizing: 'border-box',
          }}
        />
        {isLoading && (
          <span
            data-testid="contact-picker-loading"
            style={{
              position: 'absolute',
              right: 8,
              top: '50%',
              transform: 'translateY(-50%)',
              fontSize: 11,
              color: 'var(--text-muted, #6b7280)',
            }}
          >
            Lädt…
          </span>
        )}
      </div>

      {dropdownVisible && (
        <div
          id="contact-picker-listbox"
          role="listbox"
          aria-label="Contact-Suche"
          style={{
            position: 'absolute',
            top: 'calc(100% + 4px)',
            left: 0,
            right: 0,
            background: 'var(--surface-primary, #fff)',
            border: '1px solid var(--border-primary)',
            borderRadius: 'var(--radius-sm, 6px)',
            boxShadow: '0 8px 24px rgba(0,0,0,0.12)',
            zIndex: 50,
            maxHeight: 320,
            overflowY: 'auto',
            padding: '4px 0',
          }}
        >
          {showEmpty && (
            <div
              data-testid="contact-picker-empty"
              style={{
                padding: '10px 12px',
                fontSize: 13,
                color: 'var(--text-muted, #6b7280)',
              }}
            >
              Keine Treffer
            </div>
          )}
          {results.map((row, idx) => {
            const active = idx === focusedIndex
            return (
              <button
                type="button"
                key={row.id}
                id={`contact-picker-opt-${row.id}`}
                role="option"
                aria-selected={active}
                data-testid={`contact-picker-option-${row.id}`}
                onMouseDown={(e) => {
                  // Use mousedown so the click fires before input blur which
                  // could otherwise tear down the listbox via click-outside.
                  e.preventDefault()
                  selectResult(row)
                }}
                onMouseEnter={() => setFocusedIndex(idx)}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 10,
                  width: '100%',
                  textAlign: 'left',
                  padding: '6px 12px',
                  background: active
                    ? 'var(--surface-selected, #eff6ff)'
                    : 'transparent',
                  border: 'none',
                  cursor: 'pointer',
                  fontSize: 13,
                  color: 'var(--text-body)',
                }}
              >
                <Avatar id={row.id} name={row.display_name} size="sm" />
                <span
                  style={{
                    display: 'flex',
                    flexDirection: 'column',
                    minWidth: 0,
                    flex: 1,
                  }}
                >
                  <span
                    style={{
                      fontWeight: 500,
                      whiteSpace: 'nowrap',
                      overflow: 'hidden',
                      textOverflow: 'ellipsis',
                    }}
                  >
                    {row.display_name}
                  </span>
                  {row.primary_email && (
                    <span
                      style={{
                        fontSize: 12,
                        color: 'var(--text-muted, #6b7280)',
                        whiteSpace: 'nowrap',
                        overflow: 'hidden',
                        textOverflow: 'ellipsis',
                      }}
                    >
                      {row.primary_email}
                    </span>
                  )}
                </span>
              </button>
            )
          })}
        </div>
      )}
    </div>
  )
}
