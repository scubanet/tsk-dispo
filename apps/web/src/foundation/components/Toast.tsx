/**
 * Toast — transient notification with provider + hook.
 *
 * Usage:
 *   wrap app:  <ToastProvider><App /></ToastProvider>
 *   inside:    const { toast } = useToast(); toast({ tone: 'success', message: 'Gespeichert.' })
 *
 * Foundation rules:
 *   - z-index: var(--z-toast).
 *   - Auto-dismiss after 4s (configurable).
 *   - Stack vertically, newest on top.
 *   - aria-live="polite" so screen readers announce non-disruptively.
 */

import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from 'react'
import { Icon } from '../lib/icons'
import './Toast.css'

export type ToastTone = 'info' | 'success' | 'warning' | 'danger'

export interface ToastInput {
  message: ReactNode
  tone?: ToastTone
  /** Display duration in ms. Default: 4000. Pass `null` for sticky. */
  duration?: number | null
}

interface ToastEntry extends ToastInput {
  id: number
}

interface ToastContextValue {
  toast: (input: ToastInput) => void
}

const ToastContext = createContext<ToastContextValue | null>(null)

let toastId = 0

export function ToastProvider({ children }: { children: ReactNode }) {
  const [entries, setEntries] = useState<ToastEntry[]>([])

  const toast = useCallback((input: ToastInput) => {
    const id = ++toastId
    setEntries((prev) => [{ ...input, id }, ...prev])
  }, [])

  const dismiss = useCallback((id: number) => {
    setEntries((prev) => prev.filter((e) => e.id !== id))
  }, [])

  return (
    <ToastContext.Provider value={{ toast }}>
      {children}
      <div className="atoll-toast-stack" aria-live="polite" aria-atomic="false">
        {entries.map((entry) => (
          <ToastItem key={entry.id} entry={entry} onDismiss={() => dismiss(entry.id)} />
        ))}
      </div>
    </ToastContext.Provider>
  )
}

function ToastItem({ entry, onDismiss }: { entry: ToastEntry; onDismiss: () => void }) {
  useEffect(() => {
    if (entry.duration === null) return
    const ms = entry.duration ?? 4000
    const timer = setTimeout(onDismiss, ms)
    return () => clearTimeout(timer)
  }, [entry.duration, onDismiss])

  const tone = entry.tone ?? 'info'
  return (
    <div role="status" className={`atoll-toast atoll-toast--${tone}`}>
      <span className="atoll-toast__message">{entry.message}</span>
      <button
        type="button"
        className="atoll-toast__close"
        onClick={onDismiss}
        aria-label="Schliessen"
      >
        <Icon.Close size={12} />
      </button>
    </div>
  )
}

export function useToast(): ToastContextValue {
  const ctx = useContext(ToastContext)
  if (!ctx) {
    // No-op fallback so tests / Storybook stories work without provider.
    return { toast: () => undefined }
  }
  return ctx
}
