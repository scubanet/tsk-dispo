// apps/web/src/screens/contacts/timeline/EventCard.tsx
import type { TimelineEvent, EventType } from '@/types/contactEvents'

interface Props {
  event: TimelineEvent
}

// Icon-Mapping (Tabler-Icons via Foundation). 'note' → ti-note etc.
// Subagents schreiben hier `data-icon` attribute statt SVG-rendering —
// das eigentliche Icon-Mounting machen wir in Phase 3 wenn Foundation-Icon
// auf alle 15 Typen erweitert ist. Phase 2 zeigt das Label.
const ICON_FOR: Record<EventType, string> = {
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

export function EventCard({ event }: Props) {
  return (
    <article style={{
      display: 'flex', gap: 10, padding: '10px 12px',
      borderBottom: '1px solid var(--border-subtle, #eee)',
    }}>
      <span
        data-icon={ICON_FOR[event.event_type] ?? 'point'}
        aria-hidden="true"
        style={{
          width: 24, height: 24, flexShrink: 0,
          borderRadius: 4, background: 'var(--surface-secondary, #f3f3f3)',
          display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
          fontSize: 11, color: 'var(--text-secondary, #555)',
        }}
      >
        {/* Placeholder bis Foundation-Icon erweitert ist; data-icon attr für test */}
        {ICON_FOR[event.event_type]?.slice(0, 3) ?? '·'}
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
}
