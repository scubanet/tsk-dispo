-- 0124_match_contact_by_handle.sql
-- ─────────────────────────────────────────────────────────────────
-- Comms-Integration: matcht einen normalisierten Absender-Handle auf einen
-- Kontakt. E-Mail gegen contacts.emails[].email, WhatsApp gegen
-- contacts.phones[].e164, LinkedIn gegen contacts.linkedin_member_id.
-- Wird von der Service-Rolle der comms-inbound Edge Function gerufen.
-- Spec: docs/superpowers/specs/2026-05-29-comms-integration-unipile-design.md §4.2
-- ─────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.match_contact_by_handle(p_channel TEXT, p_handle TEXT)
RETURNS UUID
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT c.id FROM public.contacts c
  WHERE CASE
    WHEN p_channel = 'email' THEN EXISTS (
      SELECT 1 FROM jsonb_array_elements(COALESCE(c.emails, '[]'::jsonb)) e
      WHERE lower(e->>'email') = lower(p_handle))
    WHEN p_channel = 'whatsapp' THEN EXISTS (
      SELECT 1 FROM jsonb_array_elements(COALESCE(c.phones, '[]'::jsonb)) p
      WHERE p->>'e164' = p_handle)
    WHEN p_channel = 'linkedin' THEN c.linkedin_member_id = p_handle
    ELSE false
  END
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.match_contact_by_handle(TEXT, TEXT) TO service_role, authenticated;
