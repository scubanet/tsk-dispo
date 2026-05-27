// apps/web/src/types/contactEvents.ts
// Spec: docs/superpowers/specs/2026-05-27-contacts-crm-redesign.md §4, §8

/** User-logged event types — landen in contact_events table. */
export type UserEventType =
  | 'note'
  | 'call'
  | 'email_external'
  | 'meeting_past'
  | 'task'
  | 'whatsapp_log'

/** System event types — gelesen aus Source-Tables via View. */
export type SystemEventType =
  | 'course_enrollment'
  | 'certification_issued'
  | 'saldo_movement'
  | 'pipeline_change'
  | 'intake_checkpoint'
  | 'skill_checked'
  | 'card_lead_imported'
  | 'role_change'
  | 'audit_edit'

export type EventType = UserEventType | SystemEventType

export type EventStatus = 'open' | 'resolved' | 'archived'

/** Unified direction across call/email/whatsapp. */
export type Direction = 'outbound' | 'inbound'

/** Eine Zeile aus v_contact_timeline. */
export interface TimelineEvent {
  event_id: string
  contact_id: string
  event_type: EventType
  occurred_at: string             // ISO timestamp
  actor_contact_id: string | null
  summary: string
  body: string | null
  payload: Record<string, unknown> | null
  status: EventStatus
  source_table: string
  source_id: string
}

/** Payload-Shapes pro User-Event-Typ. */
export interface CallPayload {
  duration_min?: number
  direction?: Direction
}
export interface EmailExternalPayload {
  subject: string
  direction: Direction
}
export interface MeetingPastPayload {
  duration_min?: number
  location?: string
}
export interface TaskPayload {
  due_date: string                // ISO date
  reminder_at?: string
  completed_at?: string | null
}
export interface WhatsAppLogPayload {
  direction: Direction
}

/** Input für Composer-Insert. */
export type EventComposerInput =
  | { event_type: 'note'; summary: string; body?: string; occurred_at?: string }
  | { event_type: 'call'; summary: string; body?: string; payload: CallPayload; occurred_at?: string }
  | { event_type: 'email_external'; summary: string; body?: string; payload: EmailExternalPayload; occurred_at?: string }
  | { event_type: 'meeting_past'; summary: string; body?: string; payload: MeetingPastPayload; occurred_at?: string }
  | { event_type: 'task'; summary: string; body?: string; payload: TaskPayload; occurred_at?: string }
  | { event_type: 'whatsapp_log'; summary: string; body?: string; payload: WhatsAppLogPayload; occurred_at?: string }

/** Filter für useContactTimeline / useGlobalActivity.
 *  channel ist eine kanal-zentrische Sicht über alle EventTypes;
 *  Mapping: 'meeting' → meeting_past, 'note'/'task' bleiben gleich. */
export interface TimelineFilter {
  event_types?: EventType[]
  channel?: ('email' | 'call' | 'whatsapp' | 'note' | 'meeting' | 'task')[]
  date_from?: string
  date_to?: string
  owner_scope?: 'me' | 'team'
}

/** Persisted user-custom view aus contact_saved_views Tabelle. */
export interface ContactSavedView {
  id: string
  user_id: string
  name: string
  filter: Record<string, unknown>
  columns: string[]
  sort: Array<{ col: string; dir: 'asc' | 'desc' }>
  density: 'compact' | 'comfortable'
  created_at: string
  updated_at: string
}

export interface SavedViewInput {
  name: string
  filter: Record<string, unknown>
  columns: string[]
  sort: Array<{ col: string; dir: 'asc' | 'desc' }>
  density: 'compact' | 'comfortable'
}
