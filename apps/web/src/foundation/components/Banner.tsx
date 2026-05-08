/**
 * Banner — inline alert / informational message.
 *
 * Foundation rules:
 *   - Four tones: info, warning, danger, success.
 *   - Optional dismiss button (top-right close icon).
 *   - Used for canTeach() warnings on assignment forms.
 */

import type { ReactNode } from 'react'
import { Icon } from '../lib/icons'
import './Banner.css'

export type BannerTone = 'info' | 'warning' | 'danger' | 'success'

export interface BannerProps {
  tone?: BannerTone
  title?: ReactNode
  children: ReactNode
  /** When provided, renders a close button. */
  onDismiss?: () => void
  icon?: ReactNode
}

function defaultIcon(tone: BannerTone) {
  switch (tone) {
    case 'info': return <Icon.Info size={16} />
    case 'warning': return <Icon.Warning size={16} />
    case 'danger': return <Icon.Warning size={16} />
    case 'success': return <Icon.Success size={16} />
  }
}

export function Banner({
  tone = 'info',
  title,
  children,
  onDismiss,
  icon,
}: BannerProps) {
  return (
    <div role="status" className={`atoll-banner atoll-banner--${tone}`}>
      <span className="atoll-banner__icon" aria-hidden>
        {icon ?? defaultIcon(tone)}
      </span>
      <div className="atoll-banner__body">
        {title && <div className="atoll-banner__title">{title}</div>}
        <div className="atoll-banner__content">{children}</div>
      </div>
      {onDismiss && (
        <button
          type="button"
          className="atoll-banner__close"
          onClick={onDismiss}
          aria-label="Schliessen"
        >
          <Icon.Close size={14} />
        </button>
      )}
    </div>
  )
}
