-- 0127_match_whatsapp_normalize.sql
-- WhatsApp-Inbound (360dialog/Meta) liefert die Nummer als Ziffern (z. B.
-- 41791234567), gespeichertes e164 hat führendes '+'. Vergleich daher
-- ziffern-normalisiert auf beiden Seiten (split_part schneidet evtl. @-Suffixe
-- ab). E-Mail/LinkedIn unverändert.
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
      WHERE regexp_replace(p->>'e164', '\D', '', 'g') = regexp_replace(split_part(p_handle, '@', 1), '\D', '', 'g'))
    WHEN p_channel = 'linkedin' THEN c.linkedin_member_id = p_handle
    ELSE false
  END
  LIMIT 1;
$$;
