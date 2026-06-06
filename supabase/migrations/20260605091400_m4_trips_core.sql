-- 20260605091400_m4_trips_core.sql
-- Phase-2 / M4 — Trips & Buchungen (Datenmodell).
--
-- Geschäftslogik (Migration B): Buchung prüft das Brevet-Level gegen das
-- Mindest-Level (min_cert_rank) der Tauchplätze der Ausfahrt und steuert
-- Kapazität/Warteliste. Brevet-Rang als kleines Ordinal (0=keins .. 5=Pro),
-- damit der Vergleich self-contained bleibt; der Aufrufer liefert den Rang
-- des Tauchers (Override für Sonderfälle möglich).

BEGIN;

-- ════════════════════════════════════════════════════════════════════
-- 1. Tauchplätze
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE public.dive_sites (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  name            TEXT NOT NULL,
  region          TEXT,
  geo_lat         NUMERIC(9,6),
  geo_lng         NUMERIC(9,6),
  min_cert_rank   INT NOT NULL DEFAULT 0,   -- 0=keins,1=OWD,2=AOWD,3=Rescue,4=DM,5=Pro
  max_depth_m     INT,
  difficulty      TEXT CHECK (difficulty IS NULL OR difficulty IN ('easy','medium','hard')),
  current_strength TEXT CHECK (current_strength IS NULL OR current_strength IN ('none','mild','medium','strong')),
  tide_dependent  BOOLEAN NOT NULL DEFAULT false,
  notes           TEXT,
  is_active       BOOLEAN NOT NULL DEFAULT true,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_dive_sites_tenant ON public.dive_sites(tenant_id, is_active);

-- ════════════════════════════════════════════════════════════════════
-- 2. Trip-Vorlagen + Boote
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE public.trip_templates (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id        UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  name             TEXT NOT NULL,
  description      TEXT,
  default_capacity INT NOT NULL DEFAULT 8,
  price            NUMERIC(12,2) NOT NULL DEFAULT 0,
  tax_rate_id      UUID REFERENCES public.tax_rates(id) ON DELETE SET NULL,
  meeting_point    TEXT,
  is_active        BOOLEAN NOT NULL DEFAULT true,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.boats (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id  UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  name       TEXT NOT NULL,
  capacity   INT,
  is_active  BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ════════════════════════════════════════════════════════════════════
-- 3. Termine (Ausfahrten) + Spot-Zuordnung
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE public.trip_departures (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  template_id   UUID REFERENCES public.trip_templates(id) ON DELETE SET NULL,
  name          TEXT NOT NULL,
  datetime      TIMESTAMPTZ NOT NULL,
  meeting_point TEXT,
  boat_id       UUID REFERENCES public.boats(id) ON DELETE SET NULL,
  capacity      INT NOT NULL DEFAULT 8,
  status        TEXT NOT NULL DEFAULT 'scheduled'
                  CHECK (status IN ('scheduled','confirmed','running','done','cancelled')),
  note          TEXT,
  created_by    UUID,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_trip_departures_tenant_dt ON public.trip_departures(tenant_id, datetime);

CREATE TABLE public.trip_departure_sites (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  departure_id UUID NOT NULL REFERENCES public.trip_departures(id) ON DELETE CASCADE,
  site_id      UUID NOT NULL REFERENCES public.dive_sites(id) ON DELETE RESTRICT,
  ord          INT NOT NULL DEFAULT 1,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (departure_id, site_id)
);
CREATE INDEX idx_tds_departure ON public.trip_departure_sites(departure_id);

-- ════════════════════════════════════════════════════════════════════
-- 4. Buchungen
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE public.trip_bookings (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id           UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  departure_id        UUID NOT NULL REFERENCES public.trip_departures(id) ON DELETE CASCADE,
  person_id           UUID NOT NULL REFERENCES public.contacts(id) ON DELETE RESTRICT,
  status              TEXT NOT NULL DEFAULT 'booked'
                        CHECK (status IN ('booked','waitlisted','cancelled','no_show','attended')),
  cert_check          TEXT NOT NULL DEFAULT 'ok' CHECK (cert_check IN ('ok','override','failed')),
  cert_rank_at_booking INT,
  needs_rental        BOOLEAN NOT NULL DEFAULT false,
  needs_guide         BOOLEAN NOT NULL DEFAULT false,
  forms_status        TEXT NOT NULL DEFAULT 'pending' CHECK (forms_status IN ('pending','complete')),
  payment_status      TEXT NOT NULL DEFAULT 'open' CHECK (payment_status IN ('open','paid')),
  package_purchase_id UUID REFERENCES public.package_purchases(id) ON DELETE SET NULL,
  booked_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  note                TEXT,
  created_by          UUID,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (departure_id, person_id)
);
CREATE INDEX idx_trip_bookings_departure ON public.trip_bookings(departure_id, status);

-- ════════════════════════════════════════════════════════════════════
-- 5. updated_at- + Audit-Trigger
-- ════════════════════════════════════════════════════════════════════
CREATE TRIGGER trg_dive_sites_updated_at      BEFORE UPDATE ON public.dive_sites      FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_trip_templates_updated_at  BEFORE UPDATE ON public.trip_templates  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_boats_updated_at           BEFORE UPDATE ON public.boats           FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_trip_departures_updated_at BEFORE UPDATE ON public.trip_departures FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_trip_bookings_updated_at   BEFORE UPDATE ON public.trip_bookings   FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_audit_trip_departures AFTER INSERT OR UPDATE OR DELETE ON public.trip_departures FOR EACH ROW EXECUTE FUNCTION public.audit_finance_changes();
CREATE TRIGGER trg_audit_trip_bookings   AFTER INSERT OR UPDATE OR DELETE ON public.trip_bookings   FOR EACH ROW EXECUTE FUNCTION public.audit_finance_changes();

-- ════════════════════════════════════════════════════════════════════
-- 6. RLS — Stammdaten/Termine beschreibbar (dispatcher/owner); Buchungen nur lesbar (Writes via RPC)
-- ════════════════════════════════════════════════════════════════════
DO $$
DECLARE
  t   text;
  sel text := '(tenant_id = public.current_tenant_id())';
  wr  text := '(tenant_id = public.current_tenant_id() AND (public.is_dispatcher() OR public.is_owner()))';
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'dive_sites','trip_templates','boats','trip_departures','trip_departure_sites'
  ] LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;', t);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR SELECT TO authenticated USING %s;',  t||'_select', t, sel);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR INSERT TO authenticated WITH CHECK %s;', t||'_insert', t, wr);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR UPDATE TO authenticated USING %s WITH CHECK %s;', t||'_update', t, wr, wr);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR DELETE TO authenticated USING %s;', t||'_delete', t, wr);
  END LOOP;
END $$;

ALTER TABLE public.trip_bookings ENABLE ROW LEVEL SECURITY;
CREATE POLICY trip_bookings_select ON public.trip_bookings
  FOR SELECT TO authenticated USING (tenant_id = public.current_tenant_id());
-- Schreiben ausschließlich über trip_book()/trip_cancel_booking()/trip_checkin().

-- ════════════════════════════════════════════════════════════════════
-- 7. Views (Auslastung + Manifest)
-- ════════════════════════════════════════════════════════════════════
CREATE VIEW public.v_trip_departures
  WITH (security_invoker = true) AS
SELECT d.id AS departure_id, d.tenant_id, d.name, d.datetime, d.status, d.capacity, d.boat_id, d.meeting_point,
       (SELECT count(*) FROM public.trip_bookings b WHERE b.departure_id = d.id AND b.status = 'booked')      AS booked,
       (SELECT count(*) FROM public.trip_bookings b WHERE b.departure_id = d.id AND b.status = 'waitlisted')  AS waitlisted,
       greatest(d.capacity - (SELECT count(*) FROM public.trip_bookings b WHERE b.departure_id = d.id AND b.status = 'booked'), 0) AS free
FROM public.trip_departures d;

CREATE VIEW public.v_trip_manifest
  WITH (security_invoker = true) AS
SELECT b.id AS booking_id, b.tenant_id, b.departure_id, b.person_id, c.display_name AS person_name,
       b.status, b.cert_check, b.needs_rental, b.needs_guide, b.forms_status, b.payment_status, b.booked_at
FROM public.trip_bookings b
JOIN public.contacts c ON c.id = b.person_id;

COMMIT;
