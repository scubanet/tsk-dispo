-- RLS write lockdown (audit finding H2).
--
-- Problem: contacts, contact_instructor, contact_organization,
-- contact_relationships, contact_student and padi_skill_records all had
-- INSERT/UPDATE/DELETE policies with `USING (true) / WITH CHECK (true)` for the
-- `authenticated` role. Because Auth signup is open (magic-link,
-- shouldCreateUser defaults to true), ANY person with an email address can
-- obtain an authenticated session and then modify or delete ANY row in these
-- tables. The comment in 0084 deferred enforcement "to the app layer" — which
-- RLS does not enforce.
--
-- Fix:
--   * CRM tables (contacts + sidecars + relationships) are only written from
--     dispatcher/CD/owner screens → require is_dispatcher() OR is_owner().
--     (The student_upsert / merge_contacts / gdpr_anonymize_contact RPCs are
--     SECURITY DEFINER and bypass RLS, so they are unaffected.)
--   * padi_skill_records is also written by instructors during course skill
--     check-off (CourseDetailPanel → SkillCheckTab, reachable by instructors
--     via /kurse/:id) → require is_staff() (caller is a linked instructor of
--     any role). This blocks orphan/self-registered accounts while preserving
--     the instructor workflow.
--
-- SELECT policies are intentionally left unchanged (all real users are staff;
-- the public AtollCard anon read path is a separate policy and untouched).

BEGIN;

-- Helper: caller is a linked staff member (instructor row of any role).
CREATE OR REPLACE FUNCTION public.is_staff()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM instructors WHERE auth_user_id = auth.uid()
  );
$function$;
REVOKE ALL ON FUNCTION public.is_staff() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_staff() TO authenticated, service_role;

-- ── CRM tables: dispatcher / cd / owner only ──────────────────────────────────
DO $$
DECLARE
  t text;
  crm_pred text := '(public.is_dispatcher() OR public.is_owner())';
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'contacts','contact_instructor','contact_organization',
    'contact_relationships','contact_student'
  ] LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I;', t||'_insert', t);
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I;', t||'_update', t);
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I;', t||'_delete', t);

    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR INSERT TO authenticated WITH CHECK %s;',
      t||'_insert', t, crm_pred);
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR UPDATE TO authenticated USING %s WITH CHECK %s;',
      t||'_update', t, crm_pred, crm_pred);
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR DELETE TO authenticated USING %s;',
      t||'_delete', t, crm_pred);
  END LOOP;
END $$;

-- ── padi_skill_records: any linked staff (instructors do skill check-off) ─────
DROP POLICY IF EXISTS padi_skill_records_insert ON public.padi_skill_records;
DROP POLICY IF EXISTS padi_skill_records_update ON public.padi_skill_records;
DROP POLICY IF EXISTS padi_skill_records_delete ON public.padi_skill_records;

CREATE POLICY padi_skill_records_insert ON public.padi_skill_records
  FOR INSERT TO authenticated WITH CHECK (public.is_staff());
CREATE POLICY padi_skill_records_update ON public.padi_skill_records
  FOR UPDATE TO authenticated USING (public.is_staff()) WITH CHECK (public.is_staff());
CREATE POLICY padi_skill_records_delete ON public.padi_skill_records
  FOR DELETE TO authenticated USING (public.is_staff());

COMMIT;
