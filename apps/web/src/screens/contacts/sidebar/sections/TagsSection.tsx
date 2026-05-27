// apps/web/src/screens/contacts/sidebar/sections/TagsSection.tsx
//
// Phase G Phase 3 Task 9 — TagsSection: Chip-Pillen für contact.tags + Inline-Add.
// Tags sind ein TEXT[] auf `contacts` (Migration 0079) — kein separater Hook.
// Mutation läuft über useContactFieldMutation mit field='tags', value=string[].
// Dedup: Add ignoriert leere Strings + Duplikate (trim, kein lowercase —
// case-sensitive Tags bewusst, damit User entscheidet).
import { useEffect, useRef, useState } from 'react'
import { SidebarSection } from '../SidebarSection'
import { useContactFieldMutation } from '@/hooks/useContactFieldMutation'
import type { ContactWithProperties } from '@/types/contactProperties'

interface Props {
  contact: ContactWithProperties
}

export function TagsSection({ contact }: Props) {
  const mutate = useContactFieldMutation(contact.id)
  const [adding, setAdding] = useState(false)
  const [draft, setDraft] = useState('')
  const inputRef = useRef<HTMLInputElement | null>(null)

  useEffect(() => {
    if (adding && inputRef.current) {
      inputRef.current.focus()
    }
  }, [adding])

  function startAdd() {
    setDraft('')
    setAdding(true)
  }

  function cancelAdd() {
    setAdding(false)
    setDraft('')
  }

  async function commitAdd() {
    const next = draft.trim()
    if (!next || contact.tags.includes(next)) {
      cancelAdd()
      return
    }
    const nextArray = [...contact.tags, next]
    setAdding(false)
    setDraft('')
    await mutate.mutateAsync({ table: 'contacts', field: 'tags', value: nextArray })
  }

  async function removeTag(tag: string) {
    const nextArray = contact.tags.filter(t => t !== tag)
    await mutate.mutateAsync({ table: 'contacts', field: 'tags', value: nextArray })
  }

  return (
    <SidebarSection id="tags" title="Tags">
      {contact.tags.length === 0 && !adding && (
        <div style={{ color: 'var(--text-tertiary, #888)', fontSize: 13, padding: '4px 0' }}>—</div>
      )}

      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, alignItems: 'center', padding: '4px 0' }}>
        {contact.tags.map(tag => (
          <button
            key={tag}
            type="button"
            onClick={() => void removeTag(tag)}
            aria-label={`Tag ${tag} entfernen`}
            title="Entfernen"
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: 4,
              padding: '2px 8px',
              borderRadius: 999,
              border: '1px solid var(--border-strong, #ccc)',
              background: 'var(--surface-secondary, #f3f3f3)',
              font: 'inherit',
              fontSize: 12,
              color: 'var(--text-primary, #222)',
              cursor: 'pointer',
            }}
          >
            <span>{tag}</span>
            <span aria-hidden style={{ color: 'var(--text-tertiary, #888)', fontSize: 11 }}>×</span>
          </button>
        ))}

        {adding ? (
          <input
            ref={inputRef}
            value={draft}
            placeholder="neuer Tag"
            onChange={e => setDraft(e.target.value)}
            onKeyDown={e => {
              if (e.key === 'Enter' || e.key === 'Tab') {
                e.preventDefault()
                void commitAdd()
              } else if (e.key === 'Escape') {
                e.preventDefault()
                cancelAdd()
              }
            }}
            onBlur={cancelAdd}
            style={{
              font: 'inherit',
              fontSize: 12,
              padding: '2px 6px',
              border: '1px solid var(--border-strong, #ccc)',
              borderRadius: 999,
              background: 'var(--surface-primary, white)',
              outline: 'none',
              minWidth: 80,
              color: 'var(--text-primary, #222)',
            }}
          />
        ) : (
          <button
            type="button"
            onClick={startAdd}
            style={{
              padding: '2px 8px',
              borderRadius: 999,
              border: '1px dashed var(--border-strong, #ccc)',
              background: 'transparent',
              font: 'inherit',
              fontSize: 12,
              color: 'var(--text-tertiary, #888)',
              cursor: 'pointer',
            }}
          >
            + Tag
          </button>
        )}
      </div>
    </SidebarSection>
  )
}
