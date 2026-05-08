/**
 * Drawer — slide-in side panel for forms / detail edits.
 *
 * Foundation rules:
 *   - Anchored right by default; left optional.
 *   - 480px wide on desktop, 100vw on mobile.
 *   - Backdrop dims the page; click outside or Esc closes.
 *   - z-index: var(--z-drawer).
 *   - Focus trap kept simple — first element gets focus, Esc closes.
 */

import { useEffect, useRef, type ReactNode } from 'react'
import { Icon } from '../lib/icons'
import './Drawer.css'

export type DrawerSide = 'right' | 'left'

export interface DrawerProps {
  open: boolean
  onClose: () => void
  title?: ReactNode
  /** Footer area (typically Cancel + Save buttons). */
  footer?: ReactNode
  side?: DrawerSide
  /** Drawer width in px. Default: 480. */
  width?: number
  ariaLabel?: string
  children: ReactNode
}

export function Drawer({
  open,
  onClose,
  title,
  footer,
  side = 'right',
  width = 480,
  ariaLabel,
  children,
}: DrawerProps) {
  const panelRef = useRef<HTMLDivElement>(null)

  // Esc to close + lock body scroll while open.
  useEffect(() => {
    if (!open) return
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose()
    }
    document.addEventListener('keydown', onKey)
    const prevOverflow = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    // Auto-focus first focusable element.
    const focusable = panelRef.current?.querySelector<HTMLElement>(
      'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    )
    focusable?.focus()
    return () => {
      document.removeEventListener('keydown', onKey)
      document.body.style.overflow = prevOverflow
    }
  }, [open, onClose])

  if (!open) return null

  return (
    <div className="atoll-drawer-root" role="dialog" aria-modal="true" aria-label={ariaLabel}>
      <div className="atoll-drawer__backdrop" onClick={onClose} aria-hidden />
      <aside
        ref={panelRef}
        className={`atoll-drawer atoll-drawer--${side}`}
        style={{ width }}
      >
        {title && (
          <header className="atoll-drawer__head">
            <div className="atoll-drawer__title">{title}</div>
            <button
              type="button"
              className="atoll-drawer__close"
              onClick={onClose}
              aria-label="Schliessen"
            >
              <Icon.Close size={16} />
            </button>
          </header>
        )}
        <div className="atoll-drawer__body" data-scroll>{children}</div>
        {footer && <footer className="atoll-drawer__foot">{footer}</footer>}
      </aside>
    </div>
  )
}
