// apps/web/src/screens/contacts/timeline/EventCard.tsx
import { forwardRef, useState } from 'react'
import type { TimelineEvent, EventType } from '@/types/contactEvents'
import { Icon, type IconName } from '@/foundation/primitives/Icon'
import './EventCard.css'

type ReplyChannel = 'email' | 'whatsapp' | 'linkedin'

interface Props {
  event: TimelineEvent
  /**
   * Phase G Phase 5 Task 6 — Highlight-Animation.
   * Wenn `true`, läuft ein kurzer Border-Pulse (1.5s, ease-out, runs once) auf
   * der Card. Wird von TimelineFeed gesetzt, wenn der URL-Param `?event=<id>`
   * auf diese Card matched.
   */
  highlighted?: boolean
  /**
   * Löschen einer Nachricht (nur Bubbles: Mail/WhatsApp/LinkedIn, rein & raus).
   * Wenn gesetzt, erscheint beim Hovern ein Mülleimer mit Inline-Bestätigung.
   * Wird vom TimelineFeed mit `event_id` aufgerufen (= contact_events.id).
   */
  onDelete?: (eventId: string) => void
  /** True, solange genau diese Nachricht gerade gelöscht wird. */
  isDeleting?: boolean
  /**
   * Antworten auf eine Nachricht (nur Mail/WhatsApp-Bubbles). Wenn gesetzt,
   * erscheint beim Hovern ein Reply-Pfeil mit Inline-Antwortfeld. Sendet über
   * denselben Pfad wie der Composer (comms-outbound).
   */
  onReply?: (payload: { channel: ReplyChannel; body: string; subject?: string }) => void
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
  linkedin_message:    'brand-linkedin',
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

// Nachrichten-Events tragen eine Richtung (rein/raus) im Payload und werden als
// gerichtete Chat-Bubble dargestellt: links + teal = empfangen, rechts + blau =
// gesendet. Alle übrigen Event-Typen (Saldo, Notiz, Audit, …) bleiben
// zentrierte Zeilen-Marker, weil sie keine Richtung haben.
const MESSAGE_TYPES: ReadonlyArray<EventType> = [
  'email_external', 'whatsapp_log', 'linkedin_message',
]

const CHANNEL_LABEL: Partial<Record<EventType, string>> = {
  email_external:   'E-Mail',
  whatsapp_log:     'WhatsApp',
  linkedin_message: 'LinkedIn',
}

// Event-Typ → Sende-Kanal (für Reply). LinkedIn ist hier gelistet, wird aber für
// den Reply nicht freigeschaltet (comms-outbound kann nur Mail/WhatsApp senden).
const CHANNEL_FOR: Partial<Record<EventType, ReplyChannel>> = {
  email_external: 'email', whatsapp_log: 'whatsapp', linkedin_message: 'linkedin',
}

export const EventCard = forwardRef<HTMLElement, Props>(function EventCard(
  { event, highlighted, onDelete, isDeleting, onReply },
  ref,
) {
  const iconName: IconName = ICON_FOR[event.event_type] ?? 'point'
  const direction = event.payload?.direction as 'inbound' | 'outbound' | undefined
  const isMessage =
    MESSAGE_TYPES.includes(event.event_type) &&
    (direction === 'inbound' || direction === 'outbound')

  const timeLabel = new Date(event.occurred_at).toLocaleString()
  const [confirming, setConfirming] = useState(false)
  const [replying, setReplying] = useState(false)
  const [replyText, setReplyText] = useState('')

  // ── Nachricht: gerichtete Chat-Bubble ──────────────────────────────
  if (isMessage) {
    const outbound = direction === 'outbound'
    const isEmail = event.event_type === 'email_external'
    // E-Mail: summary = Betreff (fett) + body = Text.
    // WhatsApp/LinkedIn: summary ist nur das gekürzte body → nur Text zeigen.
    const subject = isEmail ? event.summary : null
    const text = event.body || (isEmail ? '' : event.summary)
    const channel = CHANNEL_LABEL[event.event_type] ?? ''
    const accent = outbound
      ? 'var(--bubble-out-accent, #185FA5)'
      : 'var(--bubble-in-accent, #0F6E56)'

    const canDelete = typeof onDelete === 'function'
    const replyChannel = CHANNEL_FOR[event.event_type]
    const canReply = typeof onReply === 'function' && (replyChannel === 'email' || replyChannel === 'whatsapp')
    const replySubject = isEmail
      ? ((event.summary ?? '').startsWith('Re:') ? event.summary : `Re: ${event.summary ?? ''}`.trim())
      : undefined
    const actionsHidden = confirming || replying

    function submitReply() {
      const t = replyText.trim()
      if (!t || !replyChannel) return
      onReply?.({ channel: replyChannel as ReplyChannel, body: t, subject: replySubject })
      setReplyText('')
      setReplying(false)
    }

    return (
      <article
        ref={ref}
        data-event-id={event.event_id}
        data-event-highlighted={highlighted ? 'true' : undefined}
        data-direction={direction}
        style={{
          display: 'flex',
          justifyContent: outbound ? 'flex-end' : 'flex-start',
          padding: '6px 12px',
        }}
      >
        <div
          className="event-bubble"
          data-direction={direction}
          style={{
            maxWidth: '80%',
            minWidth: replying ? '60%' : 0,
            padding: '8px 12px 7px',
            border: `1px solid ${outbound ? 'rgba(24,95,165,0.20)' : 'rgba(29,158,117,0.28)'}`,
            background: outbound ? 'var(--bubble-out-bg, #E8F1FB)' : 'var(--bubble-in-bg, #F1FAF6)',
            borderRadius: 14,
            borderTopRightRadius: outbound ? 4 : 14,
            borderTopLeftRadius: outbound ? 14 : 4,
          }}
        >
          <div
            style={{
              display: 'flex', alignItems: 'center', gap: 6,
              fontSize: 11, fontWeight: 600, marginBottom: 3, color: accent,
            }}
          >
            <span data-icon={iconName} aria-hidden="true" style={{ display: 'inline-flex' }}>
              <Icon name={iconName} size={13} />
            </span>
            <span>{outbound ? 'Gesendet' : 'Empfangen'}</span>
            <span aria-hidden="true" style={{ fontSize: 12 }}>{outbound ? '↗' : '↙'}</span>
            {channel && <span style={{ fontWeight: 400, opacity: 0.8 }}>· {channel}</span>}
            <span style={{ marginLeft: 'auto', fontWeight: 400, color: 'var(--text-tertiary, #8a93a6)' }}>
              {timeLabel}
            </span>
            {canReply && !actionsHidden && (
              <button
                type="button"
                className="event-bubble__reply"
                aria-label="Antworten"
                title="Antworten"
                onClick={() => { setConfirming(false); setReplying(true) }}
              >
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                  strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                  <path d="M9 14l-4 -4l4 -4" />
                  <path d="M5 10h11a4 4 0 1 1 0 8h-1" />
                </svg>
              </button>
            )}
            {canDelete && !actionsHidden && (
              <button
                type="button"
                className="event-bubble__delete"
                aria-label="Nachricht löschen"
                title="Nachricht löschen"
                onClick={() => { setReplying(false); setConfirming(true) }}
              >
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                  strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                  <path d="M4 7h16" />
                  <path d="M10 11v6" />
                  <path d="M14 11v6" />
                  <path d="M6 7l1 12a2 2 0 0 0 2 2h6a2 2 0 0 0 2 -2l1 -12" />
                  <path d="M9 7V4a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v3" />
                </svg>
              </button>
            )}
          </div>
          {subject && (
            <div style={{ fontSize: 13, fontWeight: 600, color: 'var(--text-primary, #1a2238)' }}>
              {subject}
            </div>
          )}
          {text && (
            <div
              style={{
                marginTop: subject ? 2 : 0, fontSize: 13,
                color: 'var(--text-primary, #1a2238)', whiteSpace: 'pre-wrap',
                overflowWrap: 'anywhere',
              }}
            >
              {text}
            </div>
          )}

          {canReply && replying && (
            <div style={{ marginTop: 8 }}>
              {isEmail && (
                <div style={{ fontSize: 11, color: 'var(--text-tertiary, #8a93a6)', marginBottom: 4 }}>
                  Betreff: {replySubject}
                </div>
              )}
              <textarea
                value={replyText}
                onChange={e => setReplyText(e.target.value)}
                placeholder="Antwort…"
                autoComplete="off"
                rows={3}
                autoFocus
                style={{
                  width: '100%', boxSizing: 'border-box', padding: 8, fontSize: 13,
                  borderRadius: 8, border: '1px solid var(--border-subtle, #d8dee8)',
                  background: '#fff', resize: 'vertical',
                }}
              />
              <div style={{ display: 'flex', gap: 8, marginTop: 6 }}>
                <button
                  type="button"
                  onClick={submitReply}
                  disabled={!replyText.trim()}
                  style={{
                    padding: '4px 14px', borderRadius: 6, cursor: 'pointer',
                    border: '1px solid rgba(24,95,165,0.35)', background: 'var(--bubble-out-bg, #E8F1FB)',
                    color: 'var(--bubble-out-accent, #185FA5)', fontWeight: 600,
                  }}
                >
                  Senden
                </button>
                <button
                  type="button"
                  onClick={() => { setReplying(false); setReplyText('') }}
                  style={{
                    padding: '4px 12px', borderRadius: 6, cursor: 'pointer',
                    border: '1px solid var(--border-subtle, #d8dee8)', background: 'transparent',
                    color: 'var(--text-secondary, #5a6478)',
                  }}
                >
                  Abbrechen
                </button>
              </div>
            </div>
          )}

          {canDelete && confirming && (
            <div style={{ marginTop: 8, display: 'flex', alignItems: 'center', gap: 8, fontSize: 12 }}>
              <span style={{ color: 'var(--text-secondary, #5a6478)' }}>Nachricht löschen?</span>
              <button
                type="button"
                onClick={() => onDelete?.(event.event_id)}
                disabled={isDeleting}
                style={{
                  padding: '3px 10px', borderRadius: 6, cursor: 'pointer',
                  border: '1px solid rgba(192,57,43,0.35)', background: '#fbeae8',
                  color: 'var(--danger-fg, #c0392b)', fontWeight: 600,
                }}
              >
                {isDeleting ? 'Lösche…' : 'Löschen'}
              </button>
              <button
                type="button"
                onClick={() => setConfirming(false)}
                disabled={isDeleting}
                style={{
                  padding: '3px 10px', borderRadius: 6, cursor: 'pointer',
                  border: '1px solid var(--border-subtle, #d8dee8)', background: 'transparent',
                  color: 'var(--text-secondary, #5a6478)',
                }}
              >
                Abbrechen
              </button>
            </div>
          )}
        </div>
      </article>
    )
  }

  // ── Sonstige Events: zentrierter Zeilen-Marker (unverändert) ────────
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
          {timeLabel} · {event.source_table}
        </div>
      </div>
    </article>
  )
})
