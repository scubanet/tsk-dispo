-- 0080: Contacts triggers (updated_at, audit, role-sidecar consistency)

-- updated_at on all contact tables
CREATE TRIGGER trg_contacts_updated_at
  BEFORE UPDATE ON public.contacts
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_contact_instructor_updated_at
  BEFORE UPDATE ON public.contact_instructor
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_contact_student_updated_at
  BEFORE UPDATE ON public.contact_student
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_contact_organization_updated_at
  BEFORE UPDATE ON public.contact_organization
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ── Audit log function ──────────────────────────────────────────────
-- Logs every INSERT/UPDATE/DELETE on contacts and the three role
-- sidecars to contact_audit_log. The diff for UPDATE is computed by
-- comparing the JSON representations of OLD vs NEW.
CREATE OR REPLACE FUNCTION audit_contact_changes()
RETURNS TRIGGER AS $$
DECLARE
  v_contact_id UUID;
  v_changed JSONB;
BEGIN
  -- Determine which contact this change relates to
  IF TG_TABLE_NAME = 'contacts' THEN
    v_contact_id := COALESCE(NEW.id, OLD.id);
  ELSE
    v_contact_id := COALESCE(NEW.contact_id, OLD.contact_id);
  END IF;

  -- For UPDATE: compute diff of changed fields
  IF TG_OP = 'UPDATE' THEN
    SELECT jsonb_object_agg(key, jsonb_build_object('old', old_val, 'new', new_val))
    INTO v_changed
    FROM (
      SELECT o.key AS key, o.value AS old_val, n.value AS new_val
      FROM jsonb_each(to_jsonb(OLD)) AS o(key, value)
      JOIN jsonb_each(to_jsonb(NEW)) AS n(key, value) USING (key)
      WHERE o.value IS DISTINCT FROM n.value
    ) diff;
  END IF;

  INSERT INTO public.contact_audit_log
    (contact_id, changed_by, table_name, operation,
     changed_fields, old_row, new_row)
  VALUES
    (v_contact_id,
     auth.uid(),
     TG_TABLE_NAME,
     TG_OP,
     v_changed,
     CASE WHEN TG_OP IN ('UPDATE','DELETE') THEN to_jsonb(OLD) END,
     CASE WHEN TG_OP IN ('INSERT','UPDATE') THEN to_jsonb(NEW) END);

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_audit_contacts
  AFTER INSERT OR UPDATE OR DELETE ON public.contacts
  FOR EACH ROW EXECUTE FUNCTION audit_contact_changes();

CREATE TRIGGER trg_audit_contact_instructor
  AFTER INSERT OR UPDATE OR DELETE ON public.contact_instructor
  FOR EACH ROW EXECUTE FUNCTION audit_contact_changes();

CREATE TRIGGER trg_audit_contact_student
  AFTER INSERT OR UPDATE OR DELETE ON public.contact_student
  FOR EACH ROW EXECUTE FUNCTION audit_contact_changes();

CREATE TRIGGER trg_audit_contact_organization
  AFTER INSERT OR UPDATE OR DELETE ON public.contact_organization
  FOR EACH ROW EXECUTE FUNCTION audit_contact_changes();

-- ── Role sidecar consistency ─────────────────────────────────────────
-- Whenever a sidecar row is created, the matching role is added to
-- contacts.roles[]. When the sidecar is deleted, the role is removed.
CREATE OR REPLACE FUNCTION sync_role_from_sidecar()
RETURNS TRIGGER AS $$
DECLARE
  v_role TEXT;
BEGIN
  v_role := CASE TG_TABLE_NAME
    WHEN 'contact_instructor'   THEN 'instructor'
    WHEN 'contact_student'      THEN 'student'
    WHEN 'contact_organization' THEN 'organization_profile'
  END;

  IF TG_OP = 'INSERT' THEN
    UPDATE public.contacts
       SET roles = array_append(roles, v_role)
     WHERE id = NEW.contact_id
       AND NOT (v_role = ANY(roles));
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.contacts
       SET roles = array_remove(roles, v_role)
     WHERE id = OLD.contact_id;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sync_instructor_role
  AFTER INSERT OR DELETE ON public.contact_instructor
  FOR EACH ROW EXECUTE FUNCTION sync_role_from_sidecar();

CREATE TRIGGER trg_sync_student_role
  AFTER INSERT OR DELETE ON public.contact_student
  FOR EACH ROW EXECUTE FUNCTION sync_role_from_sidecar();

CREATE TRIGGER trg_sync_organization_role
  AFTER INSERT OR DELETE ON public.contact_organization
  FOR EACH ROW EXECUTE FUNCTION sync_role_from_sidecar();

COMMENT ON FUNCTION audit_contact_changes IS
  'Logs every contact mutation to contact_audit_log with diff for UPDATE.';
COMMENT ON FUNCTION sync_role_from_sidecar IS
  'Keeps contacts.roles[] in sync with sidecar table membership.';
