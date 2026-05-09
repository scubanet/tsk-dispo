-- 0084: Contacts RLS — permissive policies matching project convention
-- (read+write for authenticated; app enforces role-based access in queries)

ALTER TABLE public.contacts                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contact_instructor       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contact_student          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contact_organization     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contact_relationships    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contact_audit_log        ENABLE ROW LEVEL SECURITY;

-- contacts: read+write for authenticated
CREATE POLICY contacts_select ON public.contacts
  FOR SELECT TO authenticated USING (true);
CREATE POLICY contacts_insert ON public.contacts
  FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY contacts_update ON public.contacts
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY contacts_delete ON public.contacts
  FOR DELETE TO authenticated USING (true);

-- contact_instructor: same
CREATE POLICY contact_instructor_select ON public.contact_instructor
  FOR SELECT TO authenticated USING (true);
CREATE POLICY contact_instructor_insert ON public.contact_instructor
  FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY contact_instructor_update ON public.contact_instructor
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY contact_instructor_delete ON public.contact_instructor
  FOR DELETE TO authenticated USING (true);

-- contact_student: same
CREATE POLICY contact_student_select ON public.contact_student
  FOR SELECT TO authenticated USING (true);
CREATE POLICY contact_student_insert ON public.contact_student
  FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY contact_student_update ON public.contact_student
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY contact_student_delete ON public.contact_student
  FOR DELETE TO authenticated USING (true);

-- contact_organization: same
CREATE POLICY contact_organization_select ON public.contact_organization
  FOR SELECT TO authenticated USING (true);
CREATE POLICY contact_organization_insert ON public.contact_organization
  FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY contact_organization_update ON public.contact_organization
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY contact_organization_delete ON public.contact_organization
  FOR DELETE TO authenticated USING (true);

-- contact_relationships: same
CREATE POLICY contact_relationships_select ON public.contact_relationships
  FOR SELECT TO authenticated USING (true);
CREATE POLICY contact_relationships_insert ON public.contact_relationships
  FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY contact_relationships_update ON public.contact_relationships
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY contact_relationships_delete ON public.contact_relationships
  FOR DELETE TO authenticated USING (true);

-- contact_audit_log: read-only from app (writes happen via triggers as SECURITY DEFINER)
CREATE POLICY contact_audit_log_select ON public.contact_audit_log
  FOR SELECT TO authenticated USING (true);
-- intentionally no INSERT/UPDATE/DELETE policy — only the trigger function (SECURITY DEFINER) writes here

COMMENT ON TABLE public.contacts IS
  'Unified CRM contacts table. RLS: permissive for authenticated. App layer enforces role checks.';
