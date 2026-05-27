import type { ReactNode } from 'react'
import { Icon, type IconName } from './Icon'

interface Props {
  icon?: IconName
  title: string
  description?: string
  action?: ReactNode
}

export function EmptyState({ icon = 'tag', title, description, action }: Props) {
  return (
    <div className="empty-state">
      <Icon name={icon} size={36} />
      <div className="title-3" style={{ marginTop: 'var(--space-3)' }}>{title}</div>
      {description && (
        <div className="caption" style={{ marginTop: 'var(--space-1)', maxWidth: 320 }}>{description}</div>
      )}
      {action && <div style={{ marginTop: 'var(--space-4)' }}>{action}</div>}
    </div>
  )
}
