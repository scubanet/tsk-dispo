-- 0121_contact_events_messaging.sql
-- ─────────────────────────────────────────────────────────────────
-- Comms-Integration: contact_events um Messaging-Felder erweitern.
-- - linkedin_message als neuer event_type
-- - external_id (provider_message_id) für Idempotenz gegen Webhook-Retries
-- - messaging_account_id FK auf das Quell-Konto
-- Spec: docs/superpowers/specs/2026-05-29-comms-integration-unipile-design.md §4.1, §4.3
-- ─────────────────────────────────────────────────────────────────

-- event_type CHECK um 'linkedin_message' erweitern (Constraint neu setzen).
ALTER TABLE public.contact_events
  DROP CONSTRAINT IF EXISTS contact_events_event_type_check;

ALTER TABLE public.contact_events
  ADD CONSTRAINT contact_events_event_type_check CHECK (event_type IN (
    'note', 'call', 'email_external', 'meeting_past', 'task',
    'whatsapp_log', 'linkedin_message'
  ));

ALTER TABLE public.contact_events
  ADD COLUMN external_id TEXT,
  ADD COLUMN messaging_account_id UUID
    REFERENCES public.messaging_accounts(id) ON DELETE SET NULL;

-- Idempotenz: derselbe Provider-Message identisch nur einmal.
CREATE UNIQUE INDEX uq_contact_events_external_id
  ON public.contact_events(external_id)
  WHERE external_id IS NOT NULL;
