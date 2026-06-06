-- 20260605091500_m4_trips_rpcs.sql
-- Phase-2 / M4 — Trip-Buchungs-RPCs mit Brevet-Gate + Kapazität/Warteliste.
--
-- trip_book           : Buchung; prüft Brevet-Rang gegen das anspruchsvollste
--                       min_cert_rank der Ausfahrt-Spots; bei voller Kapazität
--                       Warteliste; Override für Sonderfälle.
-- trip_cancel_booking : Storno; rückt ältesten Wartelistenplatz nach.
-- trip_checkin        : attended / no_show am Tag.

BEGIN;

CREATE OR REPLACE FUNCTION public.trip_book(
  p_departure_id    UUID,
  p_person_id       UUID,
  p_diver_cert_rank INT DEFAULT 0,
  p_override        BOOLEAN DEFAULT false,
  p_needs_rental    BOOLEAN DEFAULT false,
  p_needs_guide     BOOLEAN DEFAULT false
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_tenant   UUID;
  v_actor    UUID;
  v_min_rank INT;
  v_capacity INT;
  v_booked   INT;
  v_status   TEXT;
  v_cert     TEXT;
  v_booking  UUID;
BEGIN
  IF NOT (public.is_dispatcher() OR public.is_owner()) THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;

  SELECT tenant_id, capacity INTO v_tenant, v_capacity
    FROM public.trip_departures WHERE id = p_departure_id;
  IF v_tenant IS NULL THEN RAISE EXCEPTION 'departure_not_found'; END IF;
  IF v_tenant <> public.current_tenant_id() THEN RAISE EXCEPTION 'wrong_tenant' USING ERRCODE = '42501'; END IF;

  -- Brevet-Gate: anspruchsvollster Spot der Ausfahrt bestimmt das Mindest-Level.
  SELECT COALESCE(max(s.min_cert_rank), 0) INTO v_min_rank
    FROM public.trip_departure_sites ds
    JOIN public.dive_sites s ON s.id = ds.site_id
   WHERE ds.departure_id = p_departure_id;

  IF p_diver_cert_rank >= v_min_rank THEN
    v_cert := 'ok';
  ELSIF p_override THEN
    v_cert := 'override';
  ELSE
    RAISE EXCEPTION 'cert_level_too_low (need %, have %)', v_min_rank, p_diver_cert_rank;
  END IF;

  -- Kapazität → fester Platz oder Warteliste.
  SELECT count(*) INTO v_booked
    FROM public.trip_bookings WHERE departure_id = p_departure_id AND status = 'booked';
  v_status := CASE WHEN v_booked < v_capacity THEN 'booked' ELSE 'waitlisted' END;

  v_actor := (SELECT contact_id FROM public.contact_instructor WHERE auth_user_id = auth.uid() LIMIT 1);

  INSERT INTO public.trip_bookings
    (tenant_id, departure_id, person_id, status, cert_check, cert_rank_at_booking, needs_rental, needs_guide, created_by)
  VALUES
    (v_tenant, p_departure_id, p_person_id, v_status, v_cert, p_diver_cert_rank, p_needs_rental, p_needs_guide, v_actor)
  RETURNING id INTO v_booking;

  RETURN jsonb_build_object('booking_id', v_booking, 'status', v_status, 'cert_check', v_cert);
END;
$$;

CREATE OR REPLACE FUNCTION public.trip_cancel_booking(p_booking_id UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_tenant    UUID;
  v_departure UUID;
  v_was       TEXT;
  v_promote   UUID;
BEGIN
  IF NOT (public.is_dispatcher() OR public.is_owner()) THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;

  SELECT tenant_id, departure_id, status INTO v_tenant, v_departure, v_was
    FROM public.trip_bookings WHERE id = p_booking_id;
  IF v_tenant IS NULL THEN RAISE EXCEPTION 'booking_not_found'; END IF;
  IF v_tenant <> public.current_tenant_id() THEN RAISE EXCEPTION 'wrong_tenant' USING ERRCODE = '42501'; END IF;

  UPDATE public.trip_bookings SET status = 'cancelled' WHERE id = p_booking_id;

  -- Wurde ein fester Platz frei → ältesten Wartelistenplatz nachrücken.
  IF v_was = 'booked' THEN
    SELECT id INTO v_promote
      FROM public.trip_bookings
     WHERE departure_id = v_departure AND status = 'waitlisted'
     ORDER BY booked_at ASC LIMIT 1;
    IF v_promote IS NOT NULL THEN
      UPDATE public.trip_bookings SET status = 'booked' WHERE id = v_promote;
    END IF;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.trip_checkin(p_booking_id UUID, p_attended BOOLEAN)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_tenant UUID;
BEGIN
  IF NOT (public.is_dispatcher() OR public.is_owner()) THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;

  SELECT tenant_id INTO v_tenant FROM public.trip_bookings WHERE id = p_booking_id;
  IF v_tenant IS NULL THEN RAISE EXCEPTION 'booking_not_found'; END IF;
  IF v_tenant <> public.current_tenant_id() THEN RAISE EXCEPTION 'wrong_tenant' USING ERRCODE = '42501'; END IF;

  UPDATE public.trip_bookings
     SET status = CASE WHEN p_attended THEN 'attended' ELSE 'no_show' END
   WHERE id = p_booking_id;
END;
$$;

-- ── Grants ────────────────────────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.trip_book(UUID, UUID, INT, BOOLEAN, BOOLEAN, BOOLEAN) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.trip_cancel_booking(UUID)                             FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.trip_checkin(UUID, BOOLEAN)                            FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.trip_book(UUID, UUID, INT, BOOLEAN, BOOLEAN, BOOLEAN) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.trip_cancel_booking(UUID)                             TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.trip_checkin(UUID, BOOLEAN)                            TO authenticated, service_role;

COMMIT;
