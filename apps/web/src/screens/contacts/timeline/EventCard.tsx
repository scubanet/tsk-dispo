// apps/web/src/screens/contacts/timeline/EventCard.tsx
import { forwardRef } from 'react'
import type { TimelineEvent, EventType } from '@/types/contactEvents'
import { Icon, type IconName } from '@/foundation/primitives/Icon'
import './EventCard.css'

interface Props {
  event: TimelineEvent
  /**
   * Phase G Phase 5 Task 6 — Highlight-Animation.
   * Wenn `true`, läuft ein kurzer Border-Pulse (1.5s, ease-out, runs once) auf
   * der Card. Wird von TimelineFeed gesetzt, wenn der URL-Param `?event=<id>`
   * auf diese Card matched.
   */
  highlighted?: boolean
}

// Icon-Mapping (Tabler-Icons via Foundation). Phase 3 (Task 17) ersetzt den
// Text-Placeholder durch echte Inline-SVGs aus Foundation/primitives/Icon.
// Wir behalten das `data-icon` attr am Outer-Span für bestehende Tests.
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

export const EventCard = forwardRef<HTMLElement, Props>(function EventCard(
  { event, highlighted },
  ref,
) {
  const iconName: IconName = ICON_FOR[event.event_type] ?? 'point'
  return (
    <article
      ref={ref}
      data-event-id={event.event_id}
      data-event-highlighted={highlighted ? 'true' : undefined}
      style={{
        display: 'flex', gap: 10, padding: '10px 12px',
        borderBottom: '1px solid var(--border-subtle, #eee)',
      }}
    >
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
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 14, fontWeight: 500 }}>{event.summary}</div>
        {event.body && (
          <div style={{ marginTop: 4, fontSize: 13, color: 'var(--text-secondary, #555)', whiteSpace: 'pre-wrap' }}>
            {event.body}
          </div>
        )}
        <div style={{ marginTop: 4, fontSize: 11, color: 'var(--text-tertiary, #888)' }}>
          {new Date(event.occurred_at).toLocaleString()} · {event.source_table}
        </div>
      </div>
    </article>
  )
})
