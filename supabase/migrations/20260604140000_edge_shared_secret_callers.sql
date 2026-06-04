-- Edge-function shared-secret wiring (audit finding #3).
--
-- The edge functions atollcard-lead-push, send-notification,
-- send-assignment-notification and weekly-export now require an
-- `x-edge-secret` header matching the `EDGE_SHARED_SECRET` function env var
-- (they ran unauthenticated with the service_role key before). This migration
-- updates the two *in-database* callers (the lead-push trigger and the
-- weekly-export cron job) to send that header, sourced from Supabase Vault.
--
-- ── One-time setup required (NOT in this migration, to keep the secret out of
--    git) ────────────────────────────────────────────────────────────────────
--   1. Pick a random value, e.g.  openssl rand -hex 32
--   2. Store it as a function env var (project-wide, covers all 4 functions):
--        supabase secrets set EDGE_SHARED_SECRET=<value>
--   3. Store the SAME value in Vault under the name `edge_shared_secret`
--      (run once in the SQL editor):
--        select vault.create_secret('<value>', 'edge_shared_secret');
--   4. Add an HTTP header  x-edge-secret: <value>  to the two Database Webhooks
--      (Dashboard → Database → Webhooks) that call send-notification and
--      send-assignment-notification.
--   5. Redeploy the functions:
--        supabase functions deploy atollcard-lead-push send-notification \
--          send-assignment-notification weekly-export
--
-- Fail-safe: if the Vault secret is missing, the header is sent empty, the
-- function returns 401, and the push/export simply does not fire — it never
-- fails open, and the lead INSERT is never blocked (trigger swallows errors).

-- ── 1. Lead-push trigger ────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.notify_lead_push()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_secret text;
BEGIN
  SELECT decrypted_secret INTO v_secret
    FROM vault.decrypted_secrets
   WHERE name = 'edge_shared_secret'
   LIMIT 1;

  PERFORM net.http_post(
    url     := 'https://axnrilhdokkfujzjifhj.supabase.co/functions/v1/atollcard-lead-push',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'x-edge-secret', COALESCE(v_secret, '')
    ),
    body    := jsonb_build_object('record', row_to_json(NEW))
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Don't block the INSERT just because the push couldn't fire.
  RAISE WARNING 'lead push trigger failed: %', SQLERRM;
  RETURN NEW;
END;
$$;

-- ── 2. Weekly-export cron job ─────────────────────────────────────────────────
-- Reschedule with a hardcoded URL (the old job relied on custom GUCs that
-- managed Postgres no longer allows — see migration 0109) and send the secret
-- header from Vault instead of a service_role bearer token.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    -- Drop the old (broken) schedule if present.
    BEGIN
      PERFORM cron.unschedule('tsk-dispo-weekly-export');
    EXCEPTION WHEN OTHERS THEN
      NULL;  -- job didn't exist
    END;

    PERFORM cron.schedule(
      'tsk-dispo-weekly-export',
      '0 23 * * 0',  -- every Sunday 23:00 UTC
      $cron$
        SELECT net.http_post(
          url := 'https://axnrilhdokkfujzjifhj.supabase.co/functions/v1/weekly-export',
          headers := jsonb_build_object(
            'Content-Type',  'application/json',
            'x-edge-secret', COALESCE(
              (SELECT decrypted_secret FROM vault.decrypted_secrets
                WHERE name = 'edge_shared_secret' LIMIT 1), '')
          ),
          body := jsonb_build_object('source', 'cron')
        );
      $cron$
    );
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'Could not (re)schedule cron: %', SQLERRM;
END;
$$;
