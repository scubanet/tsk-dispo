// apps/web/src/lib/contactEventQueries.ts
//
// Note: Bei Fehler werfen wir `new Error(error.message)` — `error.code`/`hint`/
// `details` werden bewusst verworfen. UI-Layer braucht nur die Message; wer
// Postgres-Codes braucht, muss die Supabase-Response direkt konsumieren.
import { supabase } from '@/lib/supabase'
import type { EventComposerInput, TimelineEvent } from '@/types/contactEvents'

/**
 * Insert a user-logged event for a contact.
 * RLS (contact_events_owner) gates access — Phase 1 stellt sicher dass
 * nur der Owner inserten kann.
 */
export async function insertContactEvent(
  contactId: string,
  input: EventComposerInput,
): Promise<{ id: string }> {
  const row = {
    contact_id: contactId,
    ...input,
  }
  const { data, error } = await supabase
    .from('contact_events')
    .insert(row)
    .select('id')
    .single()
  if (error) throw new Error(error.message)
  return data as { id: string }
}

/**
 * Update an existing event — Owner-RLS gilt.
 * Common updates: summary, body, status (open → resolved / archived).
 */
export async function updateContactEvent(
  eventId: string,
  patch: Partial<Pick<TimelineEvent, 'summary' | 'body' | 'status' | 'payload'>>,
): Promise<{ id: string }> {
  const { data, error } = await supabase
    .from('contact_events')
    .update(patch)
    .eq('id', eventId)
    .select('id')
    .single()
  if (error) throw new Error(error.message)
  return data as { id: string }
}

/**
 * Hard-delete an event. RLS scoped to owner.
 * Note: löscht nur user-logged Events (Tabelle contact_events) —
 * System-Events sind read-only über die View.
 */
export async function deleteContactEvent(eventId: string): Promise<void> {
  const { error } = await supabase
    .from('contact_events')
    .delete()
    .eq('id', eventId)
  if (error) throw new Error(error.message)
}
