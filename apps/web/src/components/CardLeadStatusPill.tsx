import type { CardLeadStatus } from '@/types/cardLeads'

const STATUS_COLOR: Record<CardLeadStatus, string> = {
  new:       'var(--brand-red)',
  opened:    'var(--brand-amber)',
  contacted: 'var(--brand-blue)',
  imported:  'var(--brand-teal)',
  archived:  'var(--text-tertiary)',
  spam:      'var(--text-tertiary)',
}

const STATUS_LABEL: Record<CardLeadStatus, string> = {
  new:       'Neu',
  opened:    'Geöffnet',
  contacted: 'Kontaktiert',
  imported:  'Importiert',
  archived:  'Archiviert',
  spam:      'Spam',
}

export function CardLeadStatusPill({ status }: { status: CardLeadStatus }) {
  const color = STATUS_COLOR[status]
  const label = STATUS_LABEL[status]
  const strikethrough = status === 'spam'

  return (
    <span
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        padding: '2px 8px',
        borderRadius: 12,
        background: `color-mix(in srgb, ${color} 14%, transparent)`,
        color,
        fontSize: 11,
        fontWeight: 600,
        textTransform: 'uppercase',
        letterSpacing: '.05em',
        textDecoration: strikethrough ? 'line-through' : 'none',
      }}
    >
      {label}
    </span>
  )
}
