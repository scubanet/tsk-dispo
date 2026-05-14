-- 0096: intake_checklists — RLS-Öffnung für authentifizierte Instructors
-- Heute: nur CD darf schreiben (intake_cd_all). Owner darf lesen (intake_owner_read).
-- Neu: Jeder authentifizierte User mit einem contact_instructor-Eintrag darf
--      INSERT/UPDATE/DELETE. Bewusst permissiv für Soft-Live (3–5 Test-Instructors).
--      Post-Pitch wird die Constraint auf "Instructor des konkreten Kurses" verengt.

CREATE POLICY intake_instructor_write ON public.intake_checklists
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.contact_instructor ci
      WHERE ci.auth_user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.contact_instructor ci
      WHERE ci.auth_user_id = auth.uid()
    )
  );

COMMENT ON POLICY intake_instructor_write ON public.intake_checklists IS
  'Soft-Live-Permissive: alle authentifizierten Instructors dürfen Intakes schreiben. Post-Pitch verengen auf Kurs-Instructor.';
