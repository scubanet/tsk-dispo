import { Avatar } from '@/foundation'
import { CardLeadStatusPill } from './CardLeadStatusPill'
import type { CardLeadRow as CardLeadRowData } from '@/types/cardLeads'

interface Props {
  lead: CardLeadRowData
  selected: boolean
  onClick: () => void
}

function formatRelative(iso: string): string {
  const d = new Date(iso)
  const now = new Date()
  const diffMin = Math.floor((now.getTime() - d.getTime()) / 60_000)
  if (diffMin < 1) return 'jetzt'
  if (diffMin < 60) return `vor ${diffMin} Min`
  const diffH = Math.floor(diffMin / 60)
  if (diffH < 24) return `vor ${diffH} h`
  const diffD = Math.floor(diffH / 24)
  if (diffD < 7) return `vor ${diffD} d`
  return d.toLocaleDateString('de-CH', { day: '2-digit', month: 'short' })
}

export function CardLeadRow({ lead, selected, onClick }: Props) {
  const displayName = [lead.first_name, lead.last_name].filter(Boolean).join(' ') || '(ohne Namen)'

  return (
    <button
      type="button"
      onClick={onClick}
      style={{
        display: 'flex',
        gap: 12,
        alignItems: 'flex-start',
        padding: '12px 14px',
        background: selected ? 'var(--surface-selected)' : 'transparent',
        border: 'none',
        borderBottom: '1px solid var(--border-subtle)',
        width: '100%',
        textAlign: 'left',
        cursor: 'pointer',
      }}
    >
      <Avatar id={lead.id} name={displayName} color={lead.avatar_color ?? undefined} size="md" />

      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8 }}>
          <span style={{
            fontSize: 14,
            fontWeight: lead.status === 'new' ? 700 : 500,
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            whiteSpace: 'nowrap',
          }}>
            {displayName}
          </span>
          <span style={{ fontSize: 11, color: 'var(--text-tertiary)', flexShrink: 0 }}>
            {formatRelative(lead.captured_at)}
          </span>
        </div>

        <div style={{ fontSize: 12, color: 'var(--text-secondary)', marginTop: 2 }}>
          {lead.card_title}{lead.topic ? ` · ${lead.topic}` : ''}
        </div>

        <div style={{ marginTop: 6 }}>
          <CardLeadStatusPill status={lead.status} />
        </div>
      </div>
    </button>
  )
}
