-- 0107_rpc_import_card_lead_merge.sql
-- ─────────────────────────────────────────────────────────────────
-- Erweitert import_card_lead um den MERGE-Path: bei Email-Match wird
-- in den bestehenden Contact gemergt, nur leere Felder werden gefüllt,
-- Email + Phone werden in den JSONB-Arrays angehängt, Audit-Note dranhängt.
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
  SELECT * INTO v_lead FROM public.card_leads WHERE id = p_lead_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'lead_not_found' USING ERRCODE = 'P0002';
  END IF;

  IF v_lead.imported_to_address_book = true
     AND v_lead.imported_contact_id IS NOT NULL THEN
    RETURN QUERY SELECT v_lead.imported_contact_id, 'already_imported'::text;
    RETURN;
  END IF;

  v_email_norm := lower(trim(v_lead.email));
  IF v_email_norm = '' THEN v_email_norm := NULL; END IF;

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

  IF v_existing.id IS NOT NULL THEN
    -- MERGE-Pfad: nur leere Felder füllen, JSONB-Arrays anhängen wo Wert neu ist
    UPDATE public.contacts
    SET
      first_name = coalesce(nullif(first_name, ''), v_lead.first_name),
      last_name  = coalesce(nullif(last_name, ''),  v_lead.last_name),
      primary_email = coalesce(nullif(primary_email, ''), v_email_norm),
      emails = CASE
        WHEN v_email_norm IS NULL THEN emails
        WHEN EXISTS (
          SELECT 1 FROM jsonb_array_elements(emails) e
          WHERE lower(e->>'email') = v_email_norm
        ) THEN emails
        ELSE emails || jsonb_build_array(jsonb_build_object(
          'label', 'card-inbox', 'email', v_email_norm))
      END,
      phones = CASE
        WHEN v_lead.phone IS NULL OR v_lead.phone = '' THEN phones
        WHEN EXISTS (
          SELECT 1 FROM jsonb_array_elements(phones) p
          WHERE p->>'e164' = v_lead.phone
        ) THEN phones
        ELSE phones || jsonb_build_array(jsonb_build_object(
          'label', 'card-inbox', 'e164', v_lead.phone))
      END,
      notes = coalesce(notes, '') || v_audit_note,
      updated_at = now()
    WHERE id = v_existing.id;

    UPDATE public.card_leads
    SET imported_to_address_book = true,
        status                   = 'imported',
        imported_contact_id      = v_existing.id
    WHERE id = p_lead_id;

    RETURN QUERY SELECT v_existing.id, 'merged'::text;

  ELSE
    -- CREATE-Pfad (identisch zu 0106)
    INSERT INTO public.contacts (
      kind, first_name, last_name, primary_email,
      emails, phones, roles, tags, notes, source
    ) VALUES (
      'person', v_lead.first_name, v_lead.last_name, v_email_norm,
      CASE WHEN v_email_norm IS NULL THEN '[]'::jsonb
           ELSE jsonb_build_array(jsonb_build_object(
             'label','card-inbox','email',v_email_norm,'primary',true))
      END,
      CASE WHEN v_lead.phone IS NULL OR v_lead.phone = '' THEN '[]'::jsonb
           ELSE jsonb_build_array(jsonb_build_object(
             'label','card-inbox','e164',v_lead.phone))
      END,
      ARRAY[]::text[],
      ARRAY['card-inbox']::text[],
      v_audit_note,
      'atollcard:lead:' || v_lead.id::text
    )
    RETURNING id INTO v_new_id;

    UPDATE public.card_leads
    SET imported_to_address_book = true,
        status                   = 'imported',
        imported_contact_id      = v_new_id
    WHERE id = p_lead_id;

    RETURN QUERY SELECT v_new_id, 'created'::text;
  END IF;
END;
$$;
