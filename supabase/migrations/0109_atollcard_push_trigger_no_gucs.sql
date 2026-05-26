-- 0109: AtollCard — Push-Trigger ohne Custom-GUC-Abhängigkeit (Welle B).
--
-- Replaces the trigger function from migration 0100. The original used
-- `current_setting('app.edge_function_base_url', true)` and
-- `current_setting('app.edge_function_anon_key', true)`, but Supabase's
-- managed Postgres no longer permits `ALTER DATABASE ... SET` for
-- custom GUCs (ERROR 42501 permission denied).
--
-- Solution: hardcode the Edge-Function URL. The Authorization header
-- is dropped — the function is deployed with `--no-verify-jwt`, so any
-- caller can hit it without auth. (If we ever need real JWT verification
-- here, switch to Supabase Vault for the anon key.)
--
-- The trigger itself (on_card_lead_inserted) was already created by 0100
-- and remains unchanged — we only CREATE OR REPLACE the function it calls.
-- If 0100 was never applied to this database, this migration also creates
-- the trigger fresh.

CREATE OR REPLACE FUNCTION public.notify_lead_push()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM net.http_post(
    url     := 'https://axnrilhdokkfujzjifhj.supabase.co/functions/v1/atollcard-lead-push',
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body    := jsonb_build_object('record', row_to_json(NEW))
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Don't block the INSERT just because the push couldn't fire.
  RAISE WARNING 'lead push trigger failed: %', SQLERRM;
  RETURN NEW;
END;
$$;

-- Idempotent: trigger may or may not already exist (depends on whether
-- 0100 was applied). DROP-then-CREATE keeps it deterministic.
DROP TRIGGER IF EXISTS on_card_lead_inserted ON public.card_leads;
CREATE TRIGGER on_card_lead_inserted
AFTER INSERT ON public.card_leads
FOR EACH ROW EXECUTE FUNCTION public.notify_lead_push();
