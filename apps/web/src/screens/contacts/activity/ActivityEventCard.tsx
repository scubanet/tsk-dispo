// apps/web/src/screens/contacts/activity/ActivityEventCard.tsx
//
// Phase G Phase 5 Task 1 — ActivityEventCard.
//
// Identische Komponente wie der Contact-Timeline-EventCard (§4), zusätzlich
// rechts in jeder Karte: Contact-Avatar + Name (klickbar → öffnet
// ContactDetailPanel via Query-Param ?contact=<id>&event=<eid>).
//
// Layout:
//   [Icon] [Summary + Body + Meta]              [Avatar + Name]
//
// Pragmatischer Entscheid: wir re-implementieren das EventCard-Layout inline
// statt EventCard zu wrappen, damit das ganze <article> einen einzigen
// click-target ergibt und wir kein verschachteltes <article>-im-<article>
// erzeugen. Das Icon-Mapping liegt parallel — kleine Duplikation, aber
// sauberer Layout-Control.

import type { KeyboardEvent } from 'react'
import { useNavigate } from 'react-router-dom'
import type { TimelineEvent, EventType } from '@/types/contactEvents'
import { Icon, type IconName } from '@/foundation/primitives/Icon'
import { Avatar } from '@/foundation/primitives/Avatar'
import { avatarColor } from '@/foundation/lib/colors'

interface Props {
  event: TimelineEvent
  /** Resolved display-name aus dem Parent (per Lookup-Map). Wenn nicht
   *  vorhanden, fällt die Karte auf `'Contact'` als Fallback-Text zurück. */
  contactName?: string
}

// Icon-Mapping parallel zum Contact-Timeline EventCard. Wenn der Catalog
// dort wächst, hier mit-pflegen (oder beide nach einem gemeinsamen Modul
// extrahieren — Pre-mature in T1).
const ICON_FOR: Record<EventType, IconName> = {
  note:                'note',
  call:                'phone',
  email_external:      'mail',
  meeting_past:        'calendar-event',
  task:                'checkbox',
  whatsapp_log:        'brand-whatsapp',
  course_enrollment:   'school',
  certification_issued:'certificate',
  saldo_movement:      'cash',
  pipeline_change:     'arrow-right',
  intake_checkpoint:   'checkbox',
  skill_checked:       'anchor',
  card_lead_imported:  'id-badge',
  role_change:         'user-cog',
  audit_edit:          'edit',
}

export function ActivityEventCard({ event, contactName }: Props) {
  const navigate = useNavigate()
  const iconName: IconName = ICON_FOR[event.event_type] ?? 'point'
  const nameForDisplay = contactName ?? 'Contact'
  // Avatar braucht einen `name`-String für Initialen — bei fehlendem
  // contactName fallback auf contact_id, damit `initialsFromName` etwas
  // brauchbares (oder zumindest deterministisches) liefert.
  const nameForAvatar = contactName ?? event.contact_id

  const target = `/contacts?contact=${encodeURIComponent(event.contact_id)}&event=${encodeURIComponent(event.event_id)}`

  const handleActivate = () => navigate(target)
  const handleKeyDown = (e: KeyboardEvent<HTMLElement>) => {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault()
      navigate(target)
    }
  }

  return (
    <article
      role="button"
      tabIndex={0}
      onClick={handleActivate}
      onKeyDown={handleKeyDown}
      aria-label={`${event.summary} — ${nameForDisplay}`}
      style={{
        display: 'flex',
        gap: 10,
        padding: '10px 12px',
        borderBottom: '1px solid var(--border-subtle, #eee)',
        cursor: 'pointer',
        outline: 'none',
        transition: 'background 120ms ease',
        alignItems: 'flex-start',
      }}
      onMouseEnter={(e) => {
        (e.currentTarget as HTMLElement).style.background =
          'var(--surface-hover, var(--bg-sand, #f7f5ef))'
      }}
      onMouseLeave={(e) => {
        (e.currentTarget as HTMLElement).style.background = 'transparent'
      }}
      onFocus={(e) => {
        (e.currentTarget as HTMLElement).style.background =
          'var(--surface-hover, var(--bg-sand, #f7f5ef))'
      }}
      onBlur={(e) => {
        (e.currentTarget as HTMLElement).style.background = 'transparent'
      }}
    >
      {/* Icon — identisch zur Contact-Timeline-EventCard */}
      <span
        data-icon={iconName}
        aria-hidden="true"
        style={{
          width: 24, height: 24, flexShrink: 0,
          borderRadius: 4, background: 'var(--surface-secondary, #f3f3f3)',
          display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
          color: 'var(--text-secondary, #555)',
        }}
      >
        <Icon name={iconName} size={14} />
      </span>

      {/* Mitte: Summary + Body + Meta */}
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 14, fontWeight: 500 }}>{event.summary}</div>
        {event.body && (
          <div style={{
            marginTop: 4, fontSize: 13,
            color: 'var(--text-secondary, #555)', whiteSpace: 'pre-wrap',
          }}>
            {event.body}
          </div>
        )}
        <div style={{ marginTop: 4, fontSize: 11, color: 'var(--text-tertiary, #888)' }}>
          {new Date(event.occurred_at).toLocaleString()} · {event.source_table}
        </div>
      </div>

      {/* Rechts: Contact-Anchor */}
      <div
        data-testid="contact-anchor"
        style={{
          display: 'flex', alignItems: 'center', gap: 6,
          flexShrink: 0, marginLeft: 8,
        }}
      >
        <Avatar
          id={event.contact_id}
          name={nameForAvatar}
          size="sm"
          color={avatarColor(event.contact_id)}
        />
        <span style={{
          fontSize: 12,
          color: 'var(--text-secondary, #555)',
          maxWidth: 140,
          overflow: 'hidden',
          textOverflow: 'ellipsis',
          whiteSpace: 'nowrap',
        }}>
          {nameForDisplay}
        </span>
      </div>
    </article>
  )
}
