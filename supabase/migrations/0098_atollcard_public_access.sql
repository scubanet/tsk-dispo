-- 0098: AtollCard — public anon access for `/c/<slug>` page.
--
-- The public Card page lives on Atoll OS web at /c/<slug>. It's reached by
-- anyone scanning the QR — no login. Two access patterns need anon:
--
--   1. SELECT a single card (by slug), but only what's safe for public eyes:
--      title, subtitle, theme, dive_profile, field_visibility, etc.
--      RLS still keeps the owner-only policy for authenticated users.
--   2. INSERT one row into card_scans + card_leads per visit/lead.
--
-- We don't want anon to see all cards (privacy) or read scans/leads
-- (analytics belong to the owner). So:
--   • cards:        anon SELECT only WHERE is_active = true (so deactivated
--                   personas vanish from the public web).
--   • card_scans:   anon INSERT only — no SELECT/UPDATE/DELETE.
--   • card_leads:   anon INSERT only — same.
--
-- The `anon` role in Supabase is the un-authenticated role used by the
-- public anon-key client.

-- cards: public read of active rows
CREATE POLICY cards_public_read ON public.cards
  FOR SELECT TO anon
  USING (is_active = true);

-- card_scans: public insert only
CREATE POLICY card_scans_public_insert ON public.card_scans
  FOR INSERT TO anon
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.cards c
      WHERE c.id = card_scans.card_id AND c.is_active = true
    )
  );

-- card_leads: public insert only
CREATE POLICY card_leads_public_insert ON public.card_leads
  FOR INSERT TO anon
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.cards c
      WHERE c.id = card_leads.card_id AND c.is_active = true
    )
  );

-- contacts: anon may read first/last name + languages, but only for contacts
-- that own at least one active card. Email/phone stay scoped via the field
-- visibility logic on the client. RLS is row-level not column-level, so the
-- client picks which fields to render based on `cards.field_visibility`.
CREATE POLICY contacts_public_read_for_card_owners ON public.contacts
  FOR SELECT TO anon
  USING (
    EXISTS (
      SELECT 1 FROM public.cards c
      WHERE c.person_id = contacts.id AND c.is_active = true
    )
  );
