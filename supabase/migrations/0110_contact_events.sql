-- 0110_contact_events.sql
-- ─────────────────────────────────────────────────────────────────
-- Phase G Foundation: dedizierte Tabelle für user-logged Events
-- (Notiz, Anruf, Mail-Zusammenfassung, Meeting, Task, WhatsApp-Log).
-- System-Events bleiben in ihren Source-Tables; die View
-- v_contact_timeline (Migration 0114) unioniert beides.
-- Spec: docs/superpowers/specs/2026-05-27-contacts-crm-redesign.md §8.1
-- ─────────────────────────────────────────────────────────────────

CREATE TABLE public.contact_events (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_id   UUID NOT NULL REFERENCES public.contacts(id) ON DELETE CASCADE,
  event_type   TEXT NOT NULL CHECK (event_type IN (
    'note', 'call', 'email_external', 'meeting_past', 'task', 'whatsapp_log'
  )),
  occurred_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  actor_id     UUID REFERENCES public.contacts(id) ON DELETE SET NULL,
  summary      TEXT NOT NULL,
  body         TEXT,
  payload      JSONB,
  status       TEXT NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'resolved', 'archived')),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_contact_events_contact_occurred
  ON public.contact_events(contact_id, occurred_at DESC);

CREATE INDEX idx_contact_events_actor_occurred
  ON public.contact_events(actor_id, occurred_at DESC)
  WHERE actor_id IS NOT NULL;

CREATE INDEX idx_contact_events_open_tasks
  ON public.contact_events(contact_id, (payload->>'due_date'))
  WHERE event_type = 'task' AND status = 'open';

ALTER TABLE public.contact_events ENABLE ROW LEVEL SECURITY;

-- Note: RLS-Policy contact_events_owner kommt in Migration 0111 nachdem
-- is_contact_owner() Helper definiert ist.
