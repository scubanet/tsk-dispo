/**
 * Loader — accessible loading indicator (GL-004 L3).
 *
 * Drop-in replacement for inline `<div>Lade…</div>` strings scattered
 * across the app. Uses i18n via `common.loading` by default, and emits
 * `role="status"` + `aria-live="polite"` so screen-reader users hear the
 * state change.
 */

import { useTranslation } from 'react-i18next'

export interface LoaderProps {
  /** Override the default `common.loading` label. */
  label?: string
  /** Visual size of the centred text. */
  size?: 'sm' | 'md' | 'lg'
  /** Optional className for outer container styling. */
  className?: string
}

export function Loader({ label, size = 'md', className }: LoaderProps) {
  const { t } = useTranslation()
  const text = label ?? t('common.loading')

  return (
    <div
      role="status"
      aria-live="polite"
      className={className}
      style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: 'var(--space-8)',
        color: 'var(--text-tertiary)',
        font: 'inherit',
        fontSize:
          size === 'sm' ? 'var(--text-meta)' :
          size === 'lg' ? 'var(--text-h3)' :
          'var(--text-body)',
      }}
    >
      {text}
    </div>
  )
}
