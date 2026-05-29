-- 0122_contact_enrichment.sql
-- ─────────────────────────────────────────────────────────────────
-- Comms-Integration: LinkedIn-Anreicherung. linkedin_member_id am Kontakt
-- fürs Matching; contact_enrichment hält angereicherte Werte MIT Herkunft.
-- Regel: Enrichment überschreibt NIE Nutzer-Felder (siehe §4.5).
-- Spec: docs/superpowers/specs/2026-05-29-comms-integration-unipile-design.md §4.2, §4.5, §5
-- ─────────────────────────────────────────────────────────────────

ALTER TABLE public.contacts
  ADD COLUMN linkedin_member_id TEXT;

CREATE UNIQUE INDEX uq_contacts_linkedin_member_id
  ON public.contacts(linkedin_member_id)
  WHERE linkedin_member_id IS NOT NULL;

CREATE TABLE public.contact_enrichment (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_id  UUID NOT NULL REFERENCES public.contacts(id) ON DELETE CASCADE,
  source      TEXT NOT NULL CHECK (source IN ('linkedin')),
  fields      JSONB NOT NULL DEFAULT '{}'::jsonb,   -- {headline, company, position, location, avatar_url, …}
  status      TEXT NOT NULL DEFAULT 'suggested'
    CHECK (status IN ('suggested', 'accepted', 'rejected')),
  fetched_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_contact_enrichment_contact
  ON public.contact_enrichment(contact_id, fetched_at DESC);

ALTER TABLE public.contact_enrichment ENABLE ROW LEVEL SECURITY;

-- Lesen/Verwalten nur durch Kontakt-Owner (Helper aus Migration 0111).
-- Inserts der enrich-Edge-Function laufen über die Service-Rolle.
CREATE POLICY contact_enrichment_owner ON public.contact_enrichment
  FOR ALL TO authenticated
  USING (public.is_contact_owner(contact_id))
  WITH CHECK (public.is_contact_owner(contact_id));
