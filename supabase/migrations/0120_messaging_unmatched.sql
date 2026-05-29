-- 0120_messaging_unmatched.sql
-- ─────────────────────────────────────────────────────────────────
-- Comms-Integration: Quarantäne für inbound-Nachrichten ohne Kontakt-Treffer.
-- Wird NIE verworfen; später per UI einem Kontakt zugeordnet.
-- Spec: docs/superpowers/specs/2026-05-29-comms-integration-unipile-design.md §4.4, §5
-- ─────────────────────────────────────────────────────────────────

CREATE TABLE public.messaging_unmatched (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  channel             TEXT NOT NULL CHECK (channel IN ('email', 'whatsapp', 'linkedin')),
  sender_handle       TEXT NOT NULL,             -- e164 | email | linkedin_member_id
  normalized_payload  JSONB NOT NULL,
  external_id         TEXT NOT NULL,             -- provider_message_id (Idempotenz)
  received_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  resolved_contact_id UUID REFERENCES public.contacts(id) ON DELETE SET NULL
);

CREATE UNIQUE INDEX uq_messaging_unmatched_external
  ON public.messaging_unmatched(external_id);

CREATE INDEX idx_messaging_unmatched_open
  ON public.messaging_unmatched(received_at DESC)
  WHERE resolved_contact_id IS NULL;

ALTER TABLE public.messaging_unmatched ENABLE ROW LEVEL SECURITY;

-- Org-weite Quarantäne: jeder authentifizierte Staff darf lesen + zuordnen.
-- Inserts laufen über die Service-Rolle der Edge Function (umgeht RLS).
CREATE POLICY messaging_unmatched_read ON public.messaging_unmatched
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY messaging_unmatched_assign ON public.messaging_unmatched
  FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);
