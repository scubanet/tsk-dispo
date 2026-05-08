/**
 * TouchpointCard — communication-log entry preview.
 *
 * Used in CRM/Communication detail. Channel icon, summary, timestamp,
 * direction (in/out).
 *
 * Foundation rules:
 *   - Channel determines accent color & icon.
 *   - Direction renders as small caret (← in / → out).
 *   - 12px small-caps label for "VOR 3 STD" relative time.
 */

import type { ReactNode } from 'react'
import { Icon } from '../lib/icons'
import './TouchpointCard.css'

export type TouchpointChannel = 'mail' | 'phone' | 'whatsapp' | 'imessage' | 'note'
export type TouchpointDirection = 'in' | 'out'

export interface TouchpointCardProps {
  channel: TouchpointChannel
  direction: TouchpointDirection
  summary: ReactNode
  /** Relative time, e.g. "vor 3 Std." */
  when?: ReactNode
  /** Author / sender name. */
  by?: string
  onClick?: () => void
}

const CHANNEL_LABEL: Record<TouchpointChannel, string> = {
  mail: 'E-Mail',
  phone: 'Telefon',
  whatsapp: 'WhatsApp',
  imessage: 'iMessage',
  note: 'Notiz',
}

function ChannelIcon({ channel }: { channel: TouchpointChannel }) {
  switch (channel) {
    case 'mail': return <Icon.Mail size={14} />
    case 'phone': return <Icon.Phone size={14} />
    case 'whatsapp':
    case 'imessage': return <Icon.Phone size={14} />
    case 'note': return <Icon.Info size={14} />
  }
}

export function TouchpointCard({
  channel,
  direction,
  summary,
  when,
  by,
  onClick,
}: TouchpointCardProps) {
  const cls = [
    'atoll-touchpoint',
    `atoll-touchpoint--${channel}`,
    `atoll-touchpoint--${direction}`,
    onClick && 'atoll-touchpoint--clickable',
  ]
    .filter(Boolean)
    .join(' ')

  const inner = (
    <>
      <span className="atoll-touchpoint__icon" aria-hidden>
        <ChannelIcon channel={channel} />
      </span>
      <div className="atoll-touchpoint__body">
        <div className="atoll-touchpoint__head small-caps">
          <span>{CHANNEL_LABEL[channel]}</span>
          <span aria-hidden>·</span>
          <span>{direction === 'in' ? 'Eingang' : 'Ausgang'}</span>
          {when && <span className="atoll-touchpoint__when">{when}</span>}
        </div>
        <div className="atoll-touchpoint__summary">{summary}</div>
        {by && <div className="atoll-touchpoint__by">{by}</div>}
      </div>
    </>
  )

  if (onClick) {
    return (
      <button type="button" className={cls} onClick={onClick}>
        {inner}
      </button>
    )
  }
  return <div className={cls}>{inner}</div>
}
