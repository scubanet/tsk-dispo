/**
 * PromptCard — actionable suggestion / next-step card.
 *
 * Used on Heute/Cockpit to surface "next action" prompts:
 *   - "3 Kandidaten warten auf Intake"
 *   - "Pool fehlt für OWD-Kurs morgen"
 *
 * Foundation rules:
 *   - Always clickable (acts as link/button to the action target).
 *   - Tone shifts background (info / warning / success).
 *   - Right-aligned chevron is always present.
 */

import type { ReactNode } from 'react'
import { Icon } from '../lib/icons'
import './PromptCard.css'

export type PromptTone = 'info' | 'warning' | 'success' | 'neutral'

export interface PromptCardProps {
  title: ReactNode
  body?: ReactNode
  tone?: PromptTone
  icon?: ReactNode
  onClick: () => void
  ariaLabel?: string
}

export function PromptCard({
  title,
  body,
  tone = 'neutral',
  icon,
  onClick,
  ariaLabel,
}: PromptCardProps) {
  return (
    <button
      type="button"
      className={`atoll-prompt atoll-prompt--${tone}`}
      onClick={onClick}
      aria-label={ariaLabel ?? (typeof title === 'string' ? title : undefined)}
    >
      {icon && <span className="atoll-prompt__icon">{icon}</span>}
      <span className="atoll-prompt__body">
        <span className="atoll-prompt__title">{title}</span>
        {body && <span className="atoll-prompt__sub">{body}</span>}
      </span>
      <Icon.ChevronRight size={16} className="atoll-prompt__chevron" aria-hidden />
    </button>
  )
}
