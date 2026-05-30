-- 0123_comms_rls_dispatcher_cd.sql
-- ─────────────────────────────────────────────────────────────────
-- Comms-Funktionen (Kombox) nur für Comms-Staff: Dispatcher, Course
-- Director und Superadmin (derzeit 'owner'; wird zu 'developer' sobald
-- der Rollen-Refactor kommt — dann nur DIESE Funktion anpassen).
-- Ersetzt die breiteren Policies aus 0119 (owner-only via auth.uid),
-- 0120 (USING true) und 0122 (contact-owner). Behebt zugleich den
-- Advisor-Hinweis "RLS Policy Always True" auf messaging_unmatched.
-- Entscheidung 2026-05-29 (Dominik): Zugriff dispo + cd (+ Superadmin).
-- Spec: docs/superpowers/specs/2026-05-29-comms-integration-unipile-design.md §5
-- ─────────────────────────────────────────────────────────────────

-- Einzige Stelle für die Comms-Rollenmenge. Pattern analog zu
-- is_owner_or_dispatcher() aus Migration 0045.
CREATE OR REPLACE FUNCTION public.is_comms_staff()
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.instructors
    WHERE auth_user_id = auth.uid()
      AND role IN ('dispatcher', 'cd', 'owner')   -- 'owner' → 'developer' beim Rollen-Refactor
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_comms_staff() TO authenticated;

-- messaging_accounts: jeder Comms-Staff verwaltet seine eigenen Verbindungen.
DROP POLICY IF EXISTS messaging_accounts_owner ON public.messaging_accounts;
CREATE POLICY messaging_accounts_owner ON public.messaging_accounts
  FOR ALL TO authenticated
  USING (owner_user_id = auth.uid() AND public.is_comms_staff())
  WITH CHECK (owner_user_id = auth.uid() AND public.is_comms_staff());

-- messaging_unmatched: Quarantäne nur für Comms-Staff (lesen + zuordnen).
DROP POLICY IF EXISTS messaging_unmatched_read ON public.messaging_unmatched;
DROP POLICY IF EXISTS messaging_unmatched_assign ON public.messaging_unmatched;
CREATE POLICY messaging_unmatched_read ON public.messaging_unmatched
  FOR SELECT TO authenticated
  USING (public.is_comms_staff());
CREATE POLICY messaging_unmatched_assign ON public.messaging_unmatched
  FOR UPDATE TO authenticated
  USING (public.is_comms_staff())
  WITH CHECK (public.is_comms_staff());

-- contact_enrichment: LinkedIn-Anreicherung nur für Comms-Staff.
DROP POLICY IF EXISTS contact_enrichment_owner ON public.contact_enrichment;
CREATE POLICY contact_enrichment_owner ON public.contact_enrichment
  FOR ALL TO authenticated
  USING (public.is_comms_staff())
  WITH CHECK (public.is_comms_staff());
