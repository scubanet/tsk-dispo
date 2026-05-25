-- 0106_rpc_import_card_lead.sql
-- ─────────────────────────────────────────────────────────────────
-- AtollCard Web-Inbox Phase 1: RPC zum atomaren Import eines Card-Leads
-- in die contacts-Tabelle, mit Email-Match-Merge, Audit-Note und Bridge.
-- ─────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.import_card_lead(p_lead_id uuid)
RETURNS TABLE (contact_id uuid, action text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_lead        public.card_leads%ROWTYPE;
  v_email_norm  text;
  v_existing    public.contacts%ROWTYPE;
  v_new_id      uuid;
  v_card_slug   text;
  v_audit_note  text;
BEGIN
  -- 1. Lead laden + RLS-Check (SELECT ist via card_leads_owner-Policy gefiltert)
  SELECT * INTO v_lead
  FROM public.card_leads
  WHERE id = p_lead_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'lead_not_found' USING ERRCODE = 'P0002';
  END IF;

  -- 2. Schon importiert? Idempotent: return existing.
  IF v_lead.imported_to_address_book = true
     AND v_lead.imported_contact_id IS NOT NULL THEN
    RETURN QUERY SELECT v_lead.imported_contact_id, 'already_imported'::text;
    RETURN;
  END IF;

  -- 3. Email normalisieren
  v_email_norm := lower(trim(v_lead.email));
  IF v_email_norm = '' THEN v_email_norm := NULL; END IF;

  -- 4. Email-Match suchen (primary_email ODER emails[] JSONB)
  IF v_email_norm IS NOT NULL THEN
    SELECT * INTO v_existing
    FROM public.contacts
    WHERE archived_at IS NULL
      AND (
        lower(primary_email) = v_email_norm
        OR EXISTS (
          SELECT 1 FROM jsonb_array_elements(emails) AS e
          WHERE lower(e->>'email') = v_email_norm
        )
      )
    ORDER BY created_at ASC
    LIMIT 1;
  END IF;

  -- 5. Audit-Note bauen (format konsistent über Merge- und Create-Pfad)
  SELECT slug INTO v_card_slug FROM public.cards WHERE id = v_lead.card_id;

  v_audit_note := format(
    E'\n\n[%s · aus Card-Inbox] Lead von "%s %s" (Karte: %s%s)\n  > "%s"',
    to_char(now(), 'YYYY-MM-DD HH24:MI'),
    coalesce(v_lead.first_name, ''),
    coalesce(v_lead.last_name, ''),
    v_card_slug,
    coalesce(', ' || v_lead.topic, ''),
    coalesce(v_lead.message, '(keine Nachricht)')
  );

  -- 6a. CREATE-Pfad (für Task 3 wird hier ein MERGE-Branch dazu kommen)
  INSERT INTO public.contacts (
    kind, first_name, last_name, primary_email,
    emails, phones, roles, tags, notes, source
  ) VALUES (
    'person',
    v_lead.first_name,
    v_lead.last_name,
    v_email_norm,
    CASE
      WHEN v_email_norm IS NULL THEN '[]'::jsonb
      ELSE jsonb_build_array(jsonb_build_object(
        'label',   'card-inbox',
        'email',   v_email_norm,
        'primary', true
      ))
    END,
    CASE
      WHEN v_lead.phone IS NULL OR v_lead.phone = '' THEN '[]'::jsonb
      ELSE jsonb_build_array(jsonb_build_object(
        'label', 'card-inbox',
        'e164',  v_lead.phone
      ))
    END,
    ARRAY[]::text[],
    ARRAY['card-inbox']::text[],
    v_audit_note,
    'atollcard:lead:' || v_lead.id::text
  )
  RETURNING id INTO v_new_id;

  -- Side-Effects auf den Lead
  UPDATE public.card_leads
  SET imported_to_address_book = true,
      status                   = 'imported',
      imported_contact_id      = v_new_id
  WHERE id = p_lead_id;

  RETURN QUERY SELECT v_new_id, 'created'::text;
END;
$$;

GRANT EXECUTE ON FUNCTION public.import_card_lead(uuid) TO authenticated;
