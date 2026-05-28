// apps/web/src/screens/contacts/AddressbookBulkActionBar.tsx
//
// Phase G Phase 4 Task 7 — Bulk-Action-Bar (sticky-bottom slide-in).
//
// Layout: [N ausgewählt] [+ Tags ▾] [Pipeline ▾] [✉ Massen-Mail]
//         [⋯] [✕ Auswahl aufheben]
//
// Mass-Mail = Stub-Modal "TODO Phase 5". Export-CSV und Saved-View sind
// ebenfalls Stubs (alert "Coming soon"). Archivieren via window.confirm.
//
// Click-outside-Verhalten der Dropdowns folgt FilterChipDropdown-Pattern.

import { useEffect, useRef, useState } from 'react'
import { useBulkContactMutation } from '@/hooks/useBulkContactMutation'

// ── Option-Listen (DRY-Trade-off: bewusst lokale Constants, da
// FilterBar-Optionen Labels in DE haben aber wir hier ggf. abweichen).
const TAG_OPTIONS = [
  { value: 'vip', label: 'VIP' },
  { value: 'lead', label: 'Lead' },
  { value: 'follow_up', label: 'Follow-Up' },
  { value: 'archive', label: 'Archiv' },
] as const

const PIPELINE_OPTIONS = [
  { value: 'lead', label: 'Lead' },
  { value: 'qualified', label: 'Qualified' },
  { value: 'opportunity', label: 'Opportunity' },
  { value: 'customer', label: 'Customer' },
  { value: 'candidate', label: 'Candidate' },
  { value: 'lost', label: 'Lost' },
] as const

export interface AddressbookBulkActionBarProps {
  selectedIds: string[]
  onClear: () => void
}

type OpenMenu = null | 'tags' | 'pipeline' | 'overflow'

export function AddressbookBulkActionBar({
  selectedIds,
  onClear,
}: AddressbookBulkActionBarProps) {
  const [openMenu, setOpenMenu] = useState<OpenMenu>(null)
  const [pendingTags, setPendingTags] = useState<string[]>([])
  const [massMailOpen, setMassMailOpen] = useState(false)
  const [errorMsg, setErrorMsg] = useState<string | null>(null)
  const rootRef = useRef<HTMLDivElement>(null)

  const mutation = useBulkContactMutation()
  const busy = mutation.isPending
  const n = selectedIds.length

  // ── Click-outside schliesst offene Dropdowns ──────────────────────────
  useEffect(() => {
    if (openMenu === null) return
    const onDocMouseDown = (e: MouseEvent) => {
      if (!rootRef.current) return
      if (e.target instanceof Node && rootRef.current.contains(e.target)) return
      setOpenMenu(null)
    }
    document.addEventListener('mousedown', onDocMouseDown)
    return () => document.removeEventListener('mousedown', onDocMouseDown)
  }, [openMenu])

  function runAction(args: Parameters<typeof mutation.mutate>[0]) {
    setErrorMsg(null)
    mutation.mutate(args, {
      onError: (err) => setErrorMsg(err instanceof Error ? err.message : String(err)),
      onSuccess: () => setOpenMenu(null),
    })
  }

  function handleApplyTags() {
    if (pendingTags.length === 0) return
    runAction({ type: 'add_tags', ids: selectedIds, tags: pendingTags })
    setPendingTags([])
  }

  function handlePipeline(stage: string) {
    runAction({ type: 'set_pipeline_stage', ids: selectedIds, stage })
  }

  function handleSetActive(active: boolean) {
    runAction({ type: 'set_active', ids: selectedIds, active })
  }

  function handleArchive() {
    const ok =
      typeof window === 'undefined'
        ? true
        : window.confirm(`${n} Kontakt(e) archivieren?`)
    if (!ok) return
    runAction({ type: 'archive', ids: selectedIds })
  }

  function comingSoon(label: string) {
    if (typeof window !== 'undefined') {
      window.alert(`${label}: Coming soon`)
    }
    setOpenMenu(null)
  }

  return (
    <>
      <div
        ref={rootRef}
        data-testid="addressbook-bulk-action-bar"
        role="toolbar"
        aria-label="Bulk-Aktionen"
        style={{
          position: 'sticky',
          bottom: 0,
          left: 0,
          right: 0,
          background: 'var(--surface-primary, #fff)',
          borderTop: '1px solid var(--border-primary)',
          boxShadow: '0 -4px 12px rgba(0,0,0,0.06)',
          padding: '10px 16px',
          display: 'flex',
          alignItems: 'center',
          gap: 10,
          zIndex: 40,
          flexShrink: 0,
          transition: 'transform 200ms ease-out',
          transform: 'translateY(0)',
        }}
      >
        <span
          data-testid="bulk-action-counter"
          style={{
            fontSize: 13,
            fontWeight: 600,
            color: 'var(--text-body)',
            marginRight: 4,
          }}
        >
          {n} ausgewählt
        </span>

        {/* ── Tags-Dropdown ──────────────────────────────────────── */}
        <div style={{ position: 'relative' }}>
          <button
            type="button"
            disabled={busy}
            aria-haspopup="menu"
            aria-expanded={openMenu === 'tags'}
            onClick={() => setOpenMenu(openMenu === 'tags' ? null : 'tags')}
            style={chipBtn}
          >
            + Tags ▾
          </button>
          {openMenu === 'tags' && (
            <div role="menu" aria-label="Tags hinzufügen" style={menuPanel}>
              <div style={{ padding: '4px 0', maxHeight: 240, overflowY: 'auto' }}>
                {TAG_OPTIONS.map((opt) => {
                  const checked = pendingTags.includes(opt.value)
                  return (
                    <label key={opt.value} style={menuItem}>
                      <input
                        type="checkbox"
                        checked={checked}
                        aria-label={opt.label}
                        onChange={() => {
                          setPendingTags((prev) =>
                            checked
                              ? prev.filter((v) => v !== opt.value)
                              : [...prev, opt.value],
                          )
                        }}
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
                  onClick={handleApplyTags}
                  disabled={pendingTags.length === 0 || busy}
                  style={primaryLink}
                >
                  Anwenden
                </button>
              </div>
            </div>
          )}
        </div>

        {/* ── Pipeline-Dropdown ──────────────────────────────────── */}
        <div style={{ position: 'relative' }}>
          <button
            type="button"
            disabled={busy}
            aria-haspopup="menu"
            aria-expanded={openMenu === 'pipeline'}
            onClick={() =>
              setOpenMenu(openMenu === 'pipeline' ? null : 'pipeline')
            }
            style={chipBtn}
          >
            Pipeline ▾
          </button>
          {openMenu === 'pipeline' && (
            <div role="menu" aria-label="Pipeline-Stufe" style={menuPanel}>
              {PIPELINE_OPTIONS.map((opt) => (
                <button
                  key={opt.value}
                  type="button"
                  role="menuitem"
                  onClick={() => handlePipeline(opt.value)}
                  style={menuItemBtn}
                >
                  {opt.label}
                </button>
              ))}
            </div>
          )}
        </div>

        {/* ── Massen-Mail-Stub ───────────────────────────────────── */}
        <button
          type="button"
          disabled={busy}
          onClick={() => setMassMailOpen(true)}
          style={chipBtn}
        >
          ✉ Massen-Mail
        </button>

        {/* ── Overflow-Menu (⋯) ──────────────────────────────────── */}
        <div style={{ position: 'relative' }}>
          <button
            type="button"
            disabled={busy}
            aria-haspopup="menu"
            aria-expanded={openMenu === 'overflow'}
            aria-label="Weitere Aktionen"
            onClick={() =>
              setOpenMenu(openMenu === 'overflow' ? null : 'overflow')
            }
            style={chipBtn}
          >
            ⋯
          </button>
          {openMenu === 'overflow' && (
            <div
              role="menu"
              aria-label="Weitere Aktionen"
              style={{ ...menuPanel, right: 0, left: 'auto' }}
            >
              <button
                type="button"
                role="menuitem"
                onClick={() => handleSetActive(true)}
                style={menuItemBtn}
              >
                Als aktiv setzen
              </button>
              <button
                type="button"
                role="menuitem"
                onClick={() => handleSetActive(false)}
                style={menuItemBtn}
              >
                Als inaktiv setzen
              </button>
              <button
                type="button"
                role="menuitem"
                onClick={() => comingSoon('Export CSV')}
                style={menuItemBtn}
              >
                Export CSV
              </button>
              <button
                type="button"
                role="menuitem"
                onClick={() => comingSoon('Zu Saved View hinzufügen')}
                style={menuItemBtn}
              >
                Zu Saved View hinzufügen
              </button>
              <button
                type="button"
                role="menuitem"
                onClick={handleArchive}
                style={{ ...menuItemBtn, color: 'var(--danger, #b91c1c)' }}
              >
                Archivieren
              </button>
            </div>
          )}
        </div>

        {/* spacer */}
        <div style={{ flex: 1 }} />

        <button
          type="button"
          onClick={onClear}
          disabled={busy}
          style={{
            ...chipBtn,
            background: 'transparent',
            color: 'var(--text-secondary)',
          }}
        >
          ✕ Auswahl aufheben
        </button>
      </div>

      {errorMsg && (
        <div
          data-testid="bulk-action-error"
          role="alert"
          style={{
            padding: '6px 16px',
            background: 'var(--danger-bg, #fef2f2)',
            color: 'var(--danger, #b91c1c)',
            fontSize: 12,
            borderTop: '1px solid var(--border-primary)',
          }}
        >
          {errorMsg}
        </div>
      )}

      {/* ── Mass-Mail-Stub-Modal ──────────────────────────────────── */}
      {massMailOpen && (
        <div
          role="dialog"
          aria-modal="true"
          aria-label="Massen-Mail"
          data-testid="mass-mail-modal"
          style={{
            position: 'fixed',
            inset: 0,
            background: 'rgba(0,0,0,0.4)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 100,
          }}
          onClick={() => setMassMailOpen(false)}
        >
          <div
            onClick={(e) => e.stopPropagation()}
            style={{
              background: 'var(--surface-primary, #fff)',
              borderRadius: 8,
              padding: '20px 24px',
              maxWidth: 360,
              boxShadow: '0 12px 36px rgba(0,0,0,0.2)',
            }}
          >
            <h3 style={{ margin: '0 0 8px', fontSize: 16 }}>Massen-Mail</h3>
            <p style={{ margin: '0 0 16px', fontSize: 13, color: 'var(--text-secondary)' }}>
              Massen-Mail-Composer kommt in Phase 5 (TODO Phase 5).
            </p>
            <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
              <button
                type="button"
                onClick={() => setMassMailOpen(false)}
                style={chipBtn}
              >
                Schließen
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  )
}

// ── styling ──────────────────────────────────────────────────────────
const chipBtn: React.CSSProperties = {
  padding: '5px 12px',
  borderRadius: 'var(--radius-pill, 9999px)',
  border: '1px solid var(--border-primary)',
  background: 'var(--surface-secondary, #f5f5f7)',
  color: 'var(--text-body)',
  fontSize: 12,
  fontWeight: 500,
  cursor: 'pointer',
  whiteSpace: 'nowrap',
}

const menuPanel: React.CSSProperties = {
  position: 'absolute',
  bottom: 'calc(100% + 6px)',
  left: 0,
  minWidth: 200,
  background: 'var(--surface-primary, #fff)',
  border: '1px solid var(--border-primary)',
  borderRadius: 'var(--radius-sm, 6px)',
  boxShadow: '0 8px 24px rgba(0,0,0,0.18)',
  padding: '6px 0',
  zIndex: 50,
  display: 'flex',
  flexDirection: 'column',
  fontSize: 13,
  color: 'var(--text-body)',
}

const menuItem: React.CSSProperties = {
  display: 'flex',
  alignItems: 'center',
  gap: 8,
  padding: '5px 12px',
  cursor: 'pointer',
  userSelect: 'none',
}

const menuItemBtn: React.CSSProperties = {
  display: 'block',
  width: '100%',
  textAlign: 'left',
  background: 'transparent',
  border: 'none',
  padding: '7px 14px',
  fontSize: 13,
  cursor: 'pointer',
  color: 'var(--text-body)',
}

const primaryLink: React.CSSProperties = {
  background: 'transparent',
  border: 'none',
  padding: 0,
  color: 'var(--brand-blue, #2563eb)',
  fontSize: 12,
  cursor: 'pointer',
  textDecoration: 'underline',
}
