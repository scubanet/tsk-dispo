import type { ReactNode } from 'react'

interface TopbarProps {
  title: string
  subtitle?: string
  children?: ReactNode
}

export function Topbar({ title, subtitle, children }: TopbarProps) {
  return (
    <div className="topbar">
      <div>
        <div className="title-2" style={{ lineHeight: 1.1 }}>{title}</div>
        {subtitle && <div className="caption" style={{ marginTop: 2 }}>{subtitle}</div>}
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>{children}</div>
    </div>
  )
}
