-- 0105_card_leads_imported_contact.sql
-- ─────────────────────────────────────────────────────────────────
-- AtollCard Web-Inbox Phase 1: Bridge-Spalte zwischen card_leads und
-- contacts, plus ein Inbox-View, der Card-Title joined.
-- Spec: docs/superpowers/specs/2026-05-25-atollcard-web-inbox-design.md
-- ─────────────────────────────────────────────────────────────────

-- Bridge-Spalte: welcher Contact wurde aus diesem Lead erstellt.
ALTER TABLE public.card_leads
  ADD COLUMN IF NOT EXISTS imported_contact_id uuid
    REFERENCES public.contacts(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_card_leads_imported_contact
  ON public.card_leads(imported_contact_id)
  WHERE imported_contact_id IS NOT NULL;

-- Convenience-View für die Inbox: joined card.title/slug/badge in einem Schritt.
-- security_invoker = on heisst: die RLS der Basistabellen (card_leads, cards)
-- wird vom Aufrufer angewendet — kein bypass.
CREATE OR REPLACE VIEW public.v_card_leads_inbox AS
SELECT
  l.id, l.card_id, l.first_name, l.last_name, l.email, l.phone,
  l.message, l.topic, l.captured_at, l.status, l.avatar_color,
  l.imported_to_address_book, l.imported_contact_id,
  c.slug      AS card_slug,
  c.title     AS card_title,
  c.badge     AS card_badge,
  c.person_id AS card_person_id
FROM public.card_leads l
JOIN public.cards c ON c.id = l.card_id;

ALTER VIEW public.v_card_leads_inbox SET (security_invoker = on);

-- Read-Permission für die View an authenticated Role.
GRANT SELECT ON public.v_card_leads_inbox TO authenticated;
