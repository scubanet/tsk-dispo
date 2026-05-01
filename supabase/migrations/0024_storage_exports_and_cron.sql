-- Storage bucket for weekly exports + cron-job to trigger weekly-export Sundays.

INSERT INTO storage.buckets (id, name, public)
VALUES ('exports', 'exports', false)
ON CONFLICT (id) DO NOTHING;

-- RLS for exports bucket: only dispatcher can list/download
DROP POLICY IF EXISTS "exports_dispatcher_all" ON storage.objects;
CREATE POLICY "exports_dispatcher_all"
  ON storage.objects FOR ALL
  USING (
    bucket_id = 'exports'
    AND EXISTS (
      SELECT 1 FROM instructors
      WHERE auth_user_id = auth.uid() AND role = 'dispatcher'
    )
  );

-- Cron job that calls the weekly-export Edge Function every Sunday at 23:00 UTC.
-- NOTE: requires pg_cron + pg_net extensions to be enabled in the Supabase project.
-- Dashboard → Database → Extensions → enable "pg_cron" and "pg_net".
-- Then this migration will succeed; until then, the cron-call is a no-op (the SELECT
-- runs with try/catch via DO block to prevent migration failure).

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.schedule(
      'tsk-dispo-weekly-export',
      '0 23 * * 0',  -- every Sunday 23:00 UTC
      $cron$
        SELECT net.http_post(
          url := current_setting('app.weekly_export_url', true),
          headers := jsonb_build_object(
            'Authorization', 'Bearer ' || current_setting('app.service_role_key', true),
            'Content-Type', 'application/json'
          ),
          body := jsonb_build_object('source', 'cron')
        );
      $cron$
    );
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'Could not schedule cron (extension missing or permissions): %', SQLERRM;
END;
$$;

-- After enabling pg_cron + pg_net, run this once in SQL editor to set the function URL:
-- ALTER DATABASE postgres SET app.weekly_export_url =
--   'https://axnrilhdokkfujzjifhj.supabase.co/functions/v1/weekly-export';
-- ALTER DATABASE postgres SET app.service_role_key = '<your-service-role-key>';
