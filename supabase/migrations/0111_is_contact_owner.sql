-- 0111_is_contact_owner.sql
-- ─────────────────────────────────────────────────────────────────
-- Phase G Foundation: Owner-Helper + RLS-Policy für contact_events.
-- Pattern analog zu is_card_owner aus Migration 0097.
-- ─────────────────────────────────────────────────────────────────

-- Helper: ist der eingeloggte User der "Owner" dieses Contacts?
-- Nach Phase F1 ist contact_instructor das Linking zwischen contacts.id
-- und auth.users.id.
CREATE OR REPLACE FUNCTION public.is_contact_owner(p_contact_id UUID)
RETURNS BOOLEAN
LANGUAGE SQL STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.contact_instructor
    WHERE contact_id = p_contact_id
      AND auth_user_id = auth.uid()
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_contact_owner(UUID) TO authenticated;

-- RLS-Policy für contact_events: nur Owner liest/schreibt eigene Events.
CREATE POLICY contact_events_owner ON public.contact_events
  FOR ALL TO authenticated
  USING (public.is_contact_owner(contact_id))
  WITH CHECK (public.is_contact_owner(contact_id));
