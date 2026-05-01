CREATE TABLE import_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_filename TEXT NOT NULL,
  storage_path TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('uploaded', 'mapping', 'dryrun', 'success', 'failed', 'cancelled')),
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  finished_at TIMESTAMPTZ,
  summary_json JSONB,
  triggered_by UUID REFERENCES instructors(id)
);

COMMENT ON TABLE import_logs IS 'Audit log of every Excel-import attempt.';

CREATE INDEX idx_import_logs_started ON import_logs(started_at DESC);
