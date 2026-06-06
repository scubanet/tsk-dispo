-- 20260605091300_m3_rental_service_rpcs.sql
-- Phase-2 / M3 — Verleih-/Service-/Füll-RPCs mit eingebauten Sicherheits-Gates.
--
-- rental_checkout : Ausgabe; SPERRT Geräte mit fälliger Wartung/Prüfung.
-- rental_checkin  : Rückgabe; Zustand/Schaden, Gerät zurück in Pool oder Service.
-- service_open    : Service-Job anlegen; Gerät auf 'service'.
-- service_complete: Service fertig; next_service_due aus service_plan fortschreiben.
-- fill_log_create : Füllung; SPERRT bei abgelaufener Flaschenprüfung / nicht
--                   bestandenem Cert-Check; optional Air-Card abbuchen.

BEGIN;

-- ── Ausgabe ───────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.rental_checkout(
  p_person_id   UUID,
  p_asset_ids   UUID[],
  p_due_at      TIMESTAMPTZ DEFAULT NULL,
  p_deposit     NUMERIC DEFAULT 0,
  p_linked_type TEXT DEFAULT NULL,
  p_linked_id   UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_tenant    UUID := public.current_tenant_id();
  v_actor     UUID;
  v_agreement UUID;
  v_asset     UUID;
  v_status    TEXT;
  v_svc       DATE;
  v_cert      DATE;
BEGIN
  IF NOT (public.is_dispatcher() OR public.is_owner()) THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;
  IF v_tenant IS NULL THEN RAISE EXCEPTION 'no_tenant' USING ERRCODE = '42501'; END IF;
  IF p_asset_ids IS NULL OR array_length(p_asset_ids, 1) IS NULL THEN RAISE EXCEPTION 'no_assets'; END IF;

  v_actor := (SELECT contact_id FROM public.contact_instructor WHERE auth_user_id = auth.uid() LIMIT 1);

  INSERT INTO public.rental_agreements (tenant_id, person_id, status, due_at, deposit, linked_type, linked_id, created_by)
  VALUES (v_tenant, p_person_id, 'open', p_due_at, p_deposit, p_linked_type, p_linked_id, v_actor)
  RETURNING id INTO v_agreement;

  FOREACH v_asset IN ARRAY p_asset_ids LOOP
    SELECT status, next_service_due, cert_due
      INTO v_status, v_svc, v_cert
      FROM public.rental_assets WHERE id = v_asset AND tenant_id = v_tenant;

    IF v_status IS NULL THEN RAISE EXCEPTION 'asset_not_found'; END IF;
    IF v_status <> 'available' THEN RAISE EXCEPTION 'asset_not_available (%)', v_status; END IF;
    -- SICHERHEITS-GATE: keine Ausgabe mit fälliger Wartung oder Flaschenprüfung.
    IF (v_svc IS NOT NULL AND v_svc < current_date) OR (v_cert IS NOT NULL AND v_cert < current_date) THEN
      RAISE EXCEPTION 'asset_maintenance_overdue';
    END IF;

    INSERT INTO public.rental_agreement_assets (tenant_id, agreement_id, asset_id)
    VALUES (v_tenant, v_agreement, v_asset);
    UPDATE public.rental_assets SET status = 'out' WHERE id = v_asset;
  END LOOP;

  RETURN v_agreement;
END;
$$;

-- ── Rückgabe ──────────────────────────────────────────────────────────────────
-- p_returns (optional): [{ "asset_id": "...", "condition_in": "B", "to_service": false, "damage_fee": 0 }, ...]
CREATE OR REPLACE FUNCTION public.rental_checkin(
  p_agreement_id UUID,
  p_returns      JSONB DEFAULT '[]'
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_tenant UUID;
  v_damage NUMERIC := 0;
  r        JSONB;
BEGIN
  IF NOT (public.is_dispatcher() OR public.is_owner()) THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;

  SELECT tenant_id INTO v_tenant FROM public.rental_agreements WHERE id = p_agreement_id;
  IF v_tenant IS NULL THEN RAISE EXCEPTION 'agreement_not_found'; END IF;
  IF v_tenant <> public.current_tenant_id() THEN RAISE EXCEPTION 'wrong_tenant' USING ERRCODE = '42501'; END IF;

  IF p_returns IS NOT NULL AND jsonb_typeof(p_returns) = 'array' AND jsonb_array_length(p_returns) > 0 THEN
    FOR r IN SELECT * FROM jsonb_array_elements(p_returns) LOOP
      UPDATE public.rental_agreement_assets
         SET returned = true, condition_in = r->>'condition_in'
       WHERE agreement_id = p_agreement_id AND asset_id = (r->>'asset_id')::uuid;
      UPDATE public.rental_assets
         SET status = CASE WHEN COALESCE((r->>'to_service')::boolean, false) THEN 'service' ELSE 'available' END
       WHERE id = (r->>'asset_id')::uuid AND tenant_id = v_tenant;
      v_damage := v_damage + COALESCE((r->>'damage_fee')::numeric, 0);
    END LOOP;
  ELSE
    UPDATE public.rental_agreement_assets SET returned = true WHERE agreement_id = p_agreement_id;
    UPDATE public.rental_assets a SET status = 'available'
      FROM public.rental_agreement_assets ra
     WHERE ra.agreement_id = p_agreement_id AND ra.asset_id = a.id;
  END IF;

  UPDATE public.rental_agreements
     SET status = 'returned', in_at = now(), damage_fee = damage_fee + v_damage
   WHERE id = p_agreement_id;
END;
$$;

-- ── Service eröffnen ──────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.service_open(
  p_type               TEXT,
  p_asset_id           UUID DEFAULT NULL,
  p_serial_unit_id     UUID DEFAULT NULL,
  p_customer_person_id UUID DEFAULT NULL,
  p_description        TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_tenant UUID;
  v_actor  UUID;
  v_job    UUID;
BEGIN
  IF NOT (public.is_dispatcher() OR public.is_owner()) THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;

  IF p_asset_id IS NOT NULL THEN
    SELECT tenant_id INTO v_tenant FROM public.rental_assets WHERE id = p_asset_id;
    IF v_tenant IS NULL THEN RAISE EXCEPTION 'asset_not_found'; END IF;
  ELSE
    v_tenant := public.current_tenant_id();
  END IF;
  IF v_tenant IS NULL OR v_tenant <> public.current_tenant_id() THEN
    RAISE EXCEPTION 'wrong_tenant' USING ERRCODE = '42501';
  END IF;

  v_actor := (SELECT contact_id FROM public.contact_instructor WHERE auth_user_id = auth.uid() LIMIT 1);

  INSERT INTO public.service_jobs
    (tenant_id, asset_id, serial_unit_id, customer_person_id, type, status, description, created_by)
  VALUES
    (v_tenant, p_asset_id, p_serial_unit_id, p_customer_person_id, p_type, 'intake', p_description, v_actor)
  RETURNING id INTO v_job;

  IF p_asset_id IS NOT NULL THEN
    UPDATE public.rental_assets SET status = 'service' WHERE id = p_asset_id;
  END IF;

  RETURN v_job;
END;
$$;

-- ── Service abschließen (next_service_due fortschreiben) ──────────────────────
CREATE OR REPLACE FUNCTION public.service_complete(
  p_job_id   UUID,
  p_next_due DATE DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_tenant   UUID;
  v_asset    UUID;
  v_type     TEXT;
  v_interval INT;
  v_next     DATE;
BEGIN
  IF NOT (public.is_dispatcher() OR public.is_owner()) THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;

  SELECT tenant_id, asset_id INTO v_tenant, v_asset FROM public.service_jobs WHERE id = p_job_id;
  IF v_tenant IS NULL THEN RAISE EXCEPTION 'job_not_found'; END IF;
  IF v_tenant <> public.current_tenant_id() THEN RAISE EXCEPTION 'wrong_tenant' USING ERRCODE = '42501'; END IF;

  UPDATE public.service_jobs SET status = 'done' WHERE id = p_job_id;

  IF v_asset IS NOT NULL THEN
    SELECT asset_type INTO v_type FROM public.rental_assets WHERE id = v_asset;
    SELECT interval_months INTO v_interval FROM public.service_plans WHERE tenant_id = v_tenant AND asset_type = v_type;
    v_next := COALESCE(p_next_due,
                       CASE WHEN v_interval IS NOT NULL
                            THEN (current_date + (v_interval || ' months')::interval)::date END);
    UPDATE public.rental_assets
       SET status = 'available', next_service_due = COALESCE(v_next, next_service_due)
     WHERE id = v_asset;
  END IF;
END;
$$;

-- ── Füllung (mit Cert-Sperre) ─────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fill_log_create(
  p_gas               TEXT,
  p_pressure_bar      INT,
  p_cert_check_passed BOOLEAN,
  p_asset_id          UUID DEFAULT NULL,
  p_cylinder_ref      TEXT DEFAULT NULL,
  p_mix_o2            NUMERIC DEFAULT NULL,
  p_mix_he            NUMERIC DEFAULT NULL,
  p_analyzed_by       UUID DEFAULT NULL,
  p_air_card_ref      UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_tenant UUID := public.current_tenant_id();
  v_actor  UUID;
  v_cert   DATE;
  v_id     UUID;
BEGIN
  IF NOT (public.is_dispatcher() OR public.is_owner()) THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;
  IF v_tenant IS NULL THEN RAISE EXCEPTION 'no_tenant' USING ERRCODE = '42501'; END IF;

  -- SICHERHEITS-GATE: Cert-Check muss bestanden sein.
  IF NOT p_cert_check_passed THEN RAISE EXCEPTION 'cert_check_failed'; END IF;

  -- SICHERHEITS-GATE: Hausflasche mit abgelaufener Prüfung → keine Füllung.
  IF p_asset_id IS NOT NULL THEN
    SELECT cert_due INTO v_cert FROM public.rental_assets WHERE id = p_asset_id AND tenant_id = v_tenant;
    IF v_cert IS NOT NULL AND v_cert < current_date THEN RAISE EXCEPTION 'cylinder_cert_expired'; END IF;
  END IF;

  v_actor := (SELECT contact_id FROM public.contact_instructor WHERE auth_user_id = auth.uid() LIMIT 1);

  INSERT INTO public.fill_logs
    (tenant_id, asset_id, cylinder_ref, gas, mix_o2, mix_he, pressure_bar,
     analyzed_by, filler_id, cert_check_passed, air_card_ref, created_by)
  VALUES
    (v_tenant, p_asset_id, p_cylinder_ref, p_gas, p_mix_o2, p_mix_he, p_pressure_bar,
     COALESCE(p_analyzed_by, v_actor), v_actor, p_cert_check_passed, p_air_card_ref, v_actor)
  RETURNING id INTO v_id;

  -- Optional: eine Einheit von der Air-Card abbuchen.
  IF p_air_card_ref IS NOT NULL THEN
    PERFORM public.package_redeem(p_air_card_ref, 1, 'fill', v_id);
  END IF;

  RETURN v_id;
END;
$$;

-- ── Grants ────────────────────────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.rental_checkout(UUID, UUID[], TIMESTAMPTZ, NUMERIC, TEXT, UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.rental_checkin(UUID, JSONB)                                     FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.service_open(TEXT, UUID, UUID, UUID, TEXT)                       FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.service_complete(UUID, DATE)                                     FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fill_log_create(TEXT, INT, BOOLEAN, UUID, TEXT, NUMERIC, NUMERIC, UUID, UUID) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.rental_checkout(UUID, UUID[], TIMESTAMPTZ, NUMERIC, TEXT, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rental_checkin(UUID, JSONB)                                     TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.service_open(TEXT, UUID, UUID, UUID, TEXT)                       TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.service_complete(UUID, DATE)                                     TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fill_log_create(TEXT, INT, BOOLEAN, UUID, TEXT, NUMERIC, NUMERIC, UUID, UUID) TO authenticated, service_role;

COMMIT;
