-- Storage bucket for Excel-Import uploads (private; only dispatcher reads/writes)
INSERT INTO storage.buckets (id, name, public)
VALUES ('imports', 'imports', false)
ON CONFLICT (id) DO NOTHING;

-- RLS for the bucket: only dispatcher uploads/reads
CREATE POLICY "imports_dispatcher_all"
  ON storage.objects FOR ALL
  USING (
    bucket_id = 'imports'
    AND EXISTS (
      SELECT 1 FROM instructors
      WHERE auth_user_id = auth.uid() AND role = 'dispatcher'
    )
  );
