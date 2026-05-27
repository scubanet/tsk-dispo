-- 0100: AtollCard — trigger that fires the lead-push Edge Function.
--
-- Don't apply this migration until *all* of the following are done:
--   1. The Edge Function `atollcard-lead-push` is deployed
--      (cd supabase && supabase functions deploy atollcard-lead-push).
--   2. The function's secrets are set (APNS_KEY_ID, APNS_TEAM_ID,
--      APNS_BUNDLE_ID, APNS_AUTH_KEY_BASE64). See README "Phase 6".
--   3. The `pg_net` extension is enabled in the Supabase project
--      (Dashboard → Database → Extensions → enable pg_net).
--
-- If you apply this migration without doing the above, every new lead
-- triggers a failed HTTP call that's logged to `net._http_response`.
-- The lead itself is still inserted fine — the trigger uses AFTER INSERT
-- and ignores HTTP errors.

CREATE OR REPLACE FUNCTION public.notify_lead_push()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  edge_url TEXT;
BEGIN
  edge_url := current_setting('app.edge_function_base_url', true)
            || '/atollcard-lead-push';

  PERFORM net.http_post(
    url     := edge_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.edge_function_anon_key', true)
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

CREATE TRIGGER on_card_lead_inserted
AFTER INSERT ON public.card_leads
FOR EACH ROW EXECUTE FUNCTION public.notify_lead_push();

-- After applying, also configure the two GUCs via Supabase Dashboard
-- → Database → Settings → Database Settings → add a custom GUC:
--   app.edge_function_base_url = https://<project-ref>.supabase.co/functions/v1
--   app.edge_function_anon_key = <your anon key — same as in the iOS Config.swift>
