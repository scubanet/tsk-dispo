import type { ReactNode } from 'react'
import { Icon } from './Icon'

interface SheetProps {
  open: boolean
  onClose: () => void
  title: string
  width?: number
  children: ReactNode
}

export function Sheet({ open, onClose, title, width = 520, children }: SheetProps) {
  if (!open) return null
  return (
    <div className="sheet-overlay">
      <div className="sheet-backdrop" onClick={onClose} />
      <div className="sheet-panel glass-strong" style={{ width }}>
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            marginBottom: 14,
          }}
        >
          <div className="title-2">{title}</div>
          <button className="btn-icon" onClick={onClose}>
            <Icon name="x" size={14} />
          </button>
        </div>
        <div className="scroll" style={{ flex: 1, marginRight: -8, paddingRight: 8 }}>
          {children}
        </div>
      </div>
    </div>
  )
}
