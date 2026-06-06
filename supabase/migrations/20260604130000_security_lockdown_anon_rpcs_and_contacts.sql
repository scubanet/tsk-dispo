-- Security lockdown: close anon-exploitable surface (audit 2026-06-04, findings #1 + #2)
--
-- Problem (verified live against prod):
--   * Destructive SECURITY DEFINER RPCs (owner = postgres, which bypasses RLS)
--     were EXECUTE-granted to `anon` / PUBLIC with no internal authz check, so
--     anyone holding the public anon key could call them via /rest/v1/rpc/<fn>:
--       - gdpr_anonymize_contact  -> wipe any contact's PII
--       - merge_contacts          -> repoint ~18 FK tables, archive any contact
--       - student_upsert          -> insert/overwrite arbitrary contacts
--       - import_card_lead / find_potential_duplicates / match_contact_by_handle
--   * `contacts` carried a row-level anon SELECT policy for active-card owners,
--     but anon held *table-wide* SELECT, so ALL columns (birth_date, addresses,
--     notes, emails[], gender, tags) leaked — not just the 6 the public card
--     business card actually needs.
--   * v_instructor_balance / v_saldo_diff / v_course_participant_count /
--     v_instructor_certifications_by_level were SECURITY DEFINER views readable
--     by anon and by any authenticated user, leaking every instructor's CHF
--     balance regardless of RLS.
--
-- Fix:
--   1. Revoke EXECUTE from anon + PUBLIC on the 6 RPCs; re-grant only to
--      authenticated + service_role.
--   2. Add an authz guard (dispatcher/cd/owner) inside the 3 destructive
--      contact-mutating RPCs, and pin search_path on the two that lacked it.
--   3. Replace anon's table-wide contacts grant with a column-limited SELECT
--      grant (the row-level policy for active-card owners is kept unchanged).
--   4. Flip the 4 reporting views to security_invoker (so underlying RLS
--      applies per caller) and revoke anon SELECT on them.

BEGIN;

-- ---------------------------------------------------------------------------
-- 1 + 2. RPC lockdown
-- ---------------------------------------------------------------------------

-- gdpr_anonymize_contact: add guard + pin search_path (was missing).
CREATE OR REPLACE FUNCTION public.gdpr_anonymize_contact(p_contact_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT (public.is_dispatcher() OR public.is_owner()) THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;

  UPDATE contacts
     SET first_name   = 'Gelöscht',
         last_name    = '#' || substr(id::text, 1, 8),
         legal_name   = CASE WHEN kind = 'organization'
                             THEN 'Gelöschte Organisation #' || substr(id::text, 1, 8)
                             ELSE NULL END,
         trading_name = NULL,
         birth_date   = NULL,
         gender       = NULL,
         primary_email = NULL,
         emails       = '[]'::jsonb,
         phones       = '[]'::jsonb,
         addresses    = '[]'::jsonb,
         notes        = NULL,
         tags         = '{}',
         consent_marketing = false,
         archived_at  = now()
   WHERE id = p_contact_id;
END;
$function$;

-- merge_contacts: add guard + pin search_path (was missing).
CREATE OR REPLACE FUNCTION public.merge_contacts(p_winner uuid, p_loser uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_loser_roles TEXT[];
BEGIN
  IF NOT (public.is_dispatcher() OR public.is_owner()) THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;

  IF p_winner = p_loser THEN
    RAISE EXCEPTION 'Cannot merge contact with itself';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM contacts WHERE id = p_winner) THEN
    RAISE EXCEPTION 'Winner contact % not found', p_winner;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM contacts WHERE id = p_loser) THEN
    RAISE EXCEPTION 'Loser contact % not found', p_loser;
  END IF;
  SELECT roles INTO v_loser_roles FROM contacts WHERE id = p_loser;

  UPDATE course_assignments         SET instructor_id              = p_winner WHERE instructor_id              = p_loser;
  UPDATE account_movements          SET instructor_id              = p_winner WHERE instructor_id              = p_loser;
  UPDATE account_movements          SET created_by                 = p_winner WHERE created_by                 = p_loser;
  UPDATE instructor_skills          SET instructor_id              = p_winner WHERE instructor_id              = p_loser;
  UPDATE availability               SET instructor_id              = p_winner WHERE instructor_id              = p_loser;
  UPDATE communication_entries      SET created_by                 = p_winner WHERE created_by                 = p_loser;
  UPDATE device_tokens              SET instructor_id              = p_winner WHERE instructor_id              = p_loser;
  UPDATE intake_checklists          SET checked_by_id              = p_winner WHERE checked_by_id              = p_loser;
  UPDATE performance_records        SET assessed_by_id             = p_winner WHERE assessed_by_id             = p_loser;
  UPDATE course_participants        SET certified_by_instructor_id = p_winner WHERE certified_by_instructor_id = p_loser;
  UPDATE import_logs                SET triggered_by               = p_winner WHERE triggered_by               = p_loser;
  UPDATE courses                    SET created_by                 = p_winner WHERE created_by                 = p_loser;

  UPDATE course_participants    SET student_id = p_winner WHERE student_id = p_loser;
  UPDATE elearning_progress     SET student_id = p_winner WHERE student_id = p_loser;
  UPDATE intake_checklists      SET student_id = p_winner WHERE student_id = p_loser;
  UPDATE performance_records    SET student_id = p_winner WHERE student_id = p_loser;
  UPDATE student_certifications SET student_id = p_winner WHERE student_id = p_loser;
  UPDATE communication_entries  SET contact_id = p_winner WHERE contact_id = p_loser;

  UPDATE contact_relationships
     SET from_contact_id = p_winner
   WHERE from_contact_id = p_loser AND to_contact_id <> p_winner;
  UPDATE contact_relationships
     SET to_contact_id   = p_winner
   WHERE to_contact_id   = p_loser AND from_contact_id <> p_winner;
  DELETE FROM contact_relationships
   WHERE (from_contact_id = p_loser AND to_contact_id = p_winner)
      OR (from_contact_id = p_winner AND to_contact_id = p_loser);

  UPDATE contacts
     SET merged_into_id = p_winner, archived_at = now()
   WHERE id = p_loser;
  UPDATE contacts
     SET roles = ARRAY(SELECT DISTINCT unnest(roles || v_loser_roles))
   WHERE id = p_winner;
END;
$function$;

-- student_upsert: add guard (already had search_path).
CREATE OR REPLACE FUNCTION public.student_upsert(p_contact_id uuid, p_contact jsonb, p_student jsonb, p_org_id uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_contact_id UUID;
  v_roles      TEXT[];
  v_phones     JSONB;
  v_emails     JSONB;
  v_addresses  JSONB;
  v_languages  TEXT[];
  v_tags       TEXT[];
BEGIN
  IF NOT (public.is_dispatcher() OR public.is_owner()) THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;

  v_phones := CASE
    WHEN p_contact->>'phone' IS NOT NULL AND p_contact->>'phone' <> ''
    THEN jsonb_build_array(jsonb_build_object(
      'label','mobile','e164',p_contact->>'phone','primary',true))
    ELSE '[]'::jsonb
  END;

  v_emails := CASE
    WHEN p_contact->>'primary_email' IS NOT NULL AND p_contact->>'primary_email' <> ''
    THEN jsonb_build_array(jsonb_build_object(
      'label','work','email',p_contact->>'primary_email','primary',true))
    ELSE '[]'::jsonb
  END;

  v_addresses := CASE
    WHEN p_contact->'address' IS NOT NULL
     AND (COALESCE(p_contact->'address'->>'street','') <> ''
       OR COALESCE(p_contact->'address'->>'city','')   <> '')
    THEN jsonb_build_array(jsonb_build_object(
      'label','home',
      'street',     COALESCE(p_contact->'address'->>'street',''),
      'postal_code',COALESCE(p_contact->'address'->>'postal_code',''),
      'city',       COALESCE(p_contact->'address'->>'city',''),
      'country',    COALESCE(p_contact->'address'->>'country',''),
      'primary',true))
    ELSE '[]'::jsonb
  END;

  v_tags      := COALESCE(ARRAY(SELECT jsonb_array_elements_text(p_contact->'tags')),     '{}');
  v_languages := COALESCE(ARRAY(SELECT jsonb_array_elements_text(p_contact->'languages')),'{}');

  v_roles := ARRAY[]::TEXT[];
  IF (p_contact->>'is_student')::BOOLEAN   THEN v_roles := array_append(v_roles, 'student');   END IF;
  IF (p_contact->>'is_candidate')::BOOLEAN THEN v_roles := array_append(v_roles, 'candidate'); END IF;

  IF p_contact_id IS NULL THEN
    INSERT INTO contacts (
      kind, first_name, last_name, primary_email, emails, phones, addresses,
      languages, roles, tags, notes, birth_date, source
    ) VALUES (
      'person',
      p_contact->>'first_name',
      COALESCE(NULLIF(p_contact->>'last_name',''), '-'),
      NULLIF(p_contact->>'primary_email',''),
      v_emails, v_phones, v_addresses, v_languages, v_roles, v_tags,
      NULLIF(p_contact->>'notes',''),
      NULLIF(p_contact->>'birthday','')::DATE,
      'student_upsert'
    )
    RETURNING id INTO v_contact_id;

    INSERT INTO contact_student (
      contact_id, pipeline_stage, lead_source, is_candidate,
      level, photo_url, organization_role
    ) VALUES (
      v_contact_id,
      NULLIF(p_student->>'pipeline_stage','none'),
      NULLIF(p_student->>'lead_source',''),
      COALESCE((p_student->>'is_candidate')::BOOLEAN, false),
      NULLIF(p_student->>'level',''),
      NULLIF(p_student->>'photo_url',''),
      NULLIF(p_student->>'organization_role','')
    );
  ELSE
    v_contact_id := p_contact_id;

    UPDATE contacts SET
      first_name    = p_contact->>'first_name',
      last_name     = COALESCE(NULLIF(p_contact->>'last_name',''), '-'),
      primary_email = NULLIF(p_contact->>'primary_email',''),
      emails        = v_emails,
      phones        = v_phones,
      addresses     = v_addresses,
      languages     = v_languages,
      roles         = v_roles,
      tags          = v_tags,
      notes         = NULLIF(p_contact->>'notes',''),
      birth_date    = NULLIF(p_contact->>'birthday','')::DATE,
      updated_at    = now()
    WHERE id = v_contact_id;

    INSERT INTO contact_student (
      contact_id, pipeline_stage, lead_source, is_candidate,
      level, photo_url, organization_role
    ) VALUES (
      v_contact_id,
      NULLIF(p_student->>'pipeline_stage','none'),
      NULLIF(p_student->>'lead_source',''),
      COALESCE((p_student->>'is_candidate')::BOOLEAN, false),
      NULLIF(p_student->>'level',''),
      NULLIF(p_student->>'photo_url',''),
      NULLIF(p_student->>'organization_role','')
    )
    ON CONFLICT (contact_id) DO UPDATE SET
      pipeline_stage    = EXCLUDED.pipeline_stage,
      lead_source       = EXCLUDED.lead_source,
      is_candidate      = EXCLUDED.is_candidate,
      level             = EXCLUDED.level,
      photo_url         = EXCLUDED.photo_url,
      organization_role = EXCLUDED.organization_role,
      updated_at        = now();
  END IF;

  IF p_org_id IS NOT NULL THEN
    INSERT INTO contact_relationships (from_contact_id, to_contact_id, kind)
    VALUES (v_contact_id, p_org_id, 'works_at')
    ON CONFLICT DO NOTHING;
    DELETE FROM contact_relationships
    WHERE from_contact_id = v_contact_id
      AND kind = 'works_at'
      AND to_contact_id <> p_org_id;
  ELSE
    DELETE FROM contact_relationships
    WHERE from_contact_id = v_contact_id
      AND kind = 'works_at';
  END IF;

  RETURN v_contact_id;
END;
$function$;

-- Revoke anon/PUBLIC EXECUTE on all six; re-grant to the roles that need it.
-- match_contact_by_handle is also called by the comms-inbound edge function
-- (service_role), so service_role must retain EXECUTE.
DO $$
DECLARE fn text;
BEGIN
  FOREACH fn IN ARRAY ARRAY[
    'public.gdpr_anonymize_contact(uuid)',
    'public.merge_contacts(uuid, uuid)',
    'public.student_upsert(uuid, jsonb, jsonb, uuid)',
    'public.import_card_lead(uuid)',
    'public.find_potential_duplicates(uuid)',
    'public.match_contact_by_handle(text, text)'
  ] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon;', fn);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated, service_role;', fn);
  END LOOP;
END $$;

-- ---------------------------------------------------------------------------
-- 3. contacts: column-limited anon SELECT (public AtollCard business card)
-- ---------------------------------------------------------------------------
-- Row-level policy `contacts_public_read_for_card_owners` (active-card owners)
-- is left intact; here we constrain *which columns* anon may read and remove
-- any anon write grants (writes were already blocked by RLS — this removes the
-- dead grant as defense in depth).
REVOKE SELECT, INSERT, UPDATE, DELETE ON public.contacts FROM anon;
GRANT SELECT (id, first_name, last_name, primary_email, phones, languages, avatar_url)
  ON public.contacts TO anon;

-- ---------------------------------------------------------------------------
-- 4. Reporting views: enforce caller RLS + drop anon access
-- ---------------------------------------------------------------------------
ALTER VIEW public.v_instructor_balance                 SET (security_invoker = on);
ALTER VIEW public.v_saldo_diff                         SET (security_invoker = on);
ALTER VIEW public.v_course_participant_count           SET (security_invoker = on);
ALTER VIEW public.v_instructor_certifications_by_level SET (security_invoker = on);

REVOKE ALL ON public.v_instructor_balance                 FROM anon;
REVOKE ALL ON public.v_saldo_diff                         FROM anon;
REVOKE ALL ON public.v_course_participant_count           FROM anon;
REVOKE ALL ON public.v_instructor_certifications_by_level FROM anon;

COMMIT;
