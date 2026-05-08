/**
 * EmptyState — generic "nothing here" placeholder.
 *
 * Use whenever a list/pane has no items to show. Keeps phrasing
 * consistent: friendly, action-oriented if a CTA fits.
 */

import type { ReactNode } from 'react'
import './EmptyState.css'

export interface EmptyStateProps {
  /** Decorative icon or illustration. */
  icon?: ReactNode
  title: ReactNode
  body?: ReactNode
  /** Optional primary action button. */
  action?: { label: string; onClick: () => void }
}

export function EmptyState({ icon, title, body, action }: EmptyStateProps) {
  return (
    <div className="atoll-empty" role="status">
      {icon && <div className="atoll-empty__icon" aria-hidden>{icon}</div>}
      <div className="atoll-empty__title">{title}</div>
      {body && <div className="atoll-empty__body">{body}</div>}
      {action && (
        <button type="button" className="atoll-empty__action" onClick={action.onClick}>
          {action.label}
        </button>
      )}
    </div>
  )
}
