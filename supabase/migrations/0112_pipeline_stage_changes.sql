-- 0112_pipeline_stage_changes.sql
-- ─────────────────────────────────────────────────────────────────
-- Phase G Foundation: History-Tabelle für Pipeline-Stage-Wechsel.
-- Bisher wurden Stage-Changes nur in contact_audit_log gespiegelt
-- (JSON-Diff in changed_fields). Diese Tabelle macht sie explizit
-- abfragbar — wichtig für die v_contact_timeline View (Migration 0114).
-- Spec: §13 Q2, Audit-Doc §2.
-- ─────────────────────────────────────────────────────────────────

CREATE TABLE public.pipeline_stage_changes (
  id           BIGSERIAL PRIMARY KEY,
  contact_id   UUID NOT NULL REFERENCES public.contacts(id) ON DELETE CASCADE,
  from_stage   TEXT,
  to_stage     TEXT,
  changed_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  changed_by   UUID  -- nullable, no FK (audit pattern, contact_audit_log gleicher Stil)
);

CREATE INDEX idx_pipeline_stage_changes_contact_changed
  ON public.pipeline_stage_changes(contact_id, changed_at DESC);

ALTER TABLE public.pipeline_stage_changes ENABLE ROW LEVEL SECURITY;

CREATE POLICY pipeline_stage_changes_owner ON public.pipeline_stage_changes
  FOR SELECT TO authenticated
  USING (public.is_contact_owner(contact_id));

-- Trigger: schreibt eine Zeile pro Stage-Wechsel an contact_student.
-- Behält Side-Effect der bestehenden tg_contact_student_stage_changed
-- aus 0091 nicht — die feuert weiterhin separat und updated stage_changed_on.
-- Note: der WHEN-Clause am Trigger (siehe unten) filtert schon auf
-- IS DISTINCT FROM — daher kein inneres IF nötig, die Function wird
-- nur bei tatsächlichem Stage-Wechsel überhaupt aufgerufen.
CREATE OR REPLACE FUNCTION public.log_pipeline_stage_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.pipeline_stage_changes (
    contact_id, from_stage, to_stage, changed_by
  ) VALUES (
    NEW.contact_id, OLD.pipeline_stage, NEW.pipeline_stage, auth.uid()
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER tg_log_pipeline_stage_change
  AFTER UPDATE OF pipeline_stage ON public.contact_student
  FOR EACH ROW
  WHEN (OLD.pipeline_stage IS DISTINCT FROM NEW.pipeline_stage)
  EXECUTE FUNCTION public.log_pipeline_stage_change();

-- Backfill aus contact_audit_log: alle bisherigen Stage-Changes.
-- Pattern: table_name='contact_student', operation='UPDATE',
-- changed_fields ? 'pipeline_stage'.
INSERT INTO public.pipeline_stage_changes (contact_id, from_stage, to_stage, changed_at, changed_by)
SELECT
  cal.contact_id,
  cal.changed_fields->'pipeline_stage'->>'old' AS from_stage,
  cal.changed_fields->'pipeline_stage'->>'new' AS to_stage,
  cal.changed_at,
  cal.changed_by
FROM public.contact_audit_log cal
WHERE cal.table_name = 'contact_student'
  AND cal.operation  = 'UPDATE'
  AND cal.changed_fields ? 'pipeline_stage';
