// apps/web/src/screens/contacts/sidebar/SidebarSection.tsx
//
// Phase G Phase 3 — Collapsible Sidebar-Section primitive.
// Persistiert open/close-State in localStorage unter key `sidebar-section-${id}`.
// Header ist klickbar, Body collapsed via display:none um Layout-Shifts zu sparen.
import { useEffect, useState, type ReactNode } from 'react'

interface Props {
  id: string  // localStorage key suffix
  title: string
  defaultOpen?: boolean
  children: ReactNode
}

export function SidebarSection({ id, title, defaultOpen = false, children }: Props) {
  const storageKey = `sidebar-section-${id}`
  const [open, setOpen] = useState<boolean>(() => {
    if (typeof window === 'undefined') return defaultOpen
    try {
      const stored = window.localStorage.getItem(storageKey)
      if (stored === null) return defaultOpen
      return stored === 'true'
    } catch {
      return defaultOpen
    }
  })

  useEffect(() => {
    if (typeof window === 'undefined') return
    try {
      window.localStorage.setItem(storageKey, String(open))
    } catch {
      // ignore quota / disabled storage
    }
  }, [open, storageKey])

  return (
    <section
      data-testid={`sidebar-section-${id}`}
      style={{
        borderBottom: '1px solid var(--border-subtle, #eee)',
      }}
    >
      <button
        type="button"
        onClick={() => setOpen(o => !o)}
        aria-expanded={open}
        aria-controls={`sidebar-section-${id}-body`}
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          width: '100%',
          padding: '10px 14px',
          background: 'transparent',
          border: 'none',
          cursor: 'pointer',
          font: 'inherit',
          fontSize: 12,
          fontWeight: 600,
          textTransform: 'uppercase',
          letterSpacing: 0.4,
          color: 'var(--text-secondary, #555)',
          textAlign: 'left',
        }}
      >
        <span>{title}</span>
        <span aria-hidden style={{ fontSize: 10, color: 'var(--text-tertiary, #888)' }}>
          {open ? '▾' : '▸'}
        </span>
      </button>
      <div
        id={`sidebar-section-${id}-body`}
        hidden={!open}
        style={{ padding: open ? '4px 14px 12px 14px' : 0 }}
      >
        {children}
      </div>
    </section>
  )
}
