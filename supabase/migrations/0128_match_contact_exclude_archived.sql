-- 0128_match_contact_exclude_archived.sql
-- Inbound-Matcher darf NIE auf archivierte oder gemergte Kontakte zeigen.
-- Vorher matchte z. B. die Telefonnummer noch auf einen archivierten/gemergten
-- Tombstone ("Peter Muster") statt auf den lebenden Kontakt → eingehende
-- WhatsApp landete am falschen (gelöschten) Datensatz.
CREATE OR REPLACE FUNCTION public.match_contact_by_handle(p_channel TEXT, p_handle TEXT)
RETURNS UUID
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT c.id FROM public.contacts c
  WHERE c.archived_at IS NULL
    AND c.merged_into_id IS NULL
    AND CASE
      WHEN p_channel = 'email' THEN EXISTS (
        SELECT 1 FROM jsonb_array_elements(COALESCE(c.emails, '[]'::jsonb)) e
        WHERE lower(e->>'email') = lower(p_handle))
      WHEN p_channel = 'whatsapp' THEN EXISTS (
        SELECT 1 FROM jsonb_array_elements(COALESCE(c.phones, '[]'::jsonb)) p
        WHERE regexp_replace(p->>'e164', '\D', '', 'g') = regexp_replace(split_part(p_handle, '@', 1), '\D', '', 'g'))
      WHEN p_channel = 'linkedin' THEN c.linkedin_member_id = p_handle
      ELSE false
    END
  LIMIT 1;
$$;
