-- 20260605091200_m3_rental_service_core.sql
-- Phase-2 / M3 — Verleih & Service inkl. Füllstation (Datenmodell).
--
-- Sicherheits-/haftungskritisch: Geräte tragen Wartungs-/Prüf-Fälligkeiten
-- (next_service_due, cert_due); die Ausgabe-/Füll-RPCs (Migration B) sperren
-- überfällige Geräte. Füllprotokolle sind unveränderlich (Beweismittel).
-- Verleih wird über asset.status getrackt (Einzelstücke), NICHT über das
-- Mengen-Journal aus M2. Optionale Brücke zu M2: rental_assets.serial_unit_id.

BEGIN;

-- ════════════════════════════════════════════════════════════════════
-- 1. Geräte-Registry
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE public.rental_assets (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id        UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  serial_unit_id   UUID REFERENCES public.serial_units(id) ON DELETE SET NULL,  -- Brücke zu M2
  asset_type       TEXT NOT NULL CHECK (asset_type IN
                     ('regulator','bcd','tank','computer','wetsuit','weight','fins','mask','torch','other')),
  label            TEXT NOT NULL,
  size             TEXT,
  config           TEXT,
  status           TEXT NOT NULL DEFAULT 'available'
                     CHECK (status IN ('available','reserved','out','service','retired')),
  condition_grade  TEXT CHECK (condition_grade IS NULL OR condition_grade IN ('A','B','C','D')),
  purchase_date    DATE,
  next_service_due DATE,
  cert_due         DATE,                 -- Flaschen: VIP/Hydro/TÜV
  deposit_default  NUMERIC(12,2) NOT NULL DEFAULT 0,
  notes            TEXT,
  is_active        BOOLEAN NOT NULL DEFAULT true,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_rental_assets_tenant_status ON public.rental_assets(tenant_id, status);
CREATE INDEX idx_rental_assets_service_due   ON public.rental_assets(tenant_id, next_service_due);

-- ════════════════════════════════════════════════════════════════════
-- 2. Wartungspläne (Intervalle je Gerätetyp)
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE public.service_plans (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  asset_type      TEXT NOT NULL,
  name            TEXT NOT NULL,
  interval_months INT NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, asset_type)
);

-- ════════════════════════════════════════════════════════════════════
-- 3. Leihverträge
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE public.rental_agreements (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  person_id    UUID NOT NULL REFERENCES public.contacts(id) ON DELETE RESTRICT,
  status       TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','returned','cancelled')),
  out_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  due_at       TIMESTAMPTZ,
  in_at        TIMESTAMPTZ,
  deposit      NUMERIC(12,2) NOT NULL DEFAULT 0,
  damage_fee   NUMERIC(12,2) NOT NULL DEFAULT 0,
  linked_type  TEXT,                    -- 'course' | 'trip'
  linked_id    UUID,
  note         TEXT,
  created_by   UUID,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_rental_agreements_person ON public.rental_agreements(tenant_id, person_id);
CREATE INDEX idx_rental_agreements_status ON public.rental_agreements(tenant_id, status);

CREATE TABLE public.rental_agreement_assets (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  agreement_id  UUID NOT NULL REFERENCES public.rental_agreements(id) ON DELETE CASCADE,
  asset_id      UUID NOT NULL REFERENCES public.rental_assets(id) ON DELETE RESTRICT,
  condition_out TEXT,
  condition_in  TEXT,
  returned      BOOLEAN NOT NULL DEFAULT false,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (agreement_id, asset_id)
);
CREATE INDEX idx_raa_agreement ON public.rental_agreement_assets(agreement_id);
CREATE INDEX idx_raa_asset     ON public.rental_agreement_assets(asset_id);

-- ════════════════════════════════════════════════════════════════════
-- 4. Service-Jobs
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE public.service_jobs (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id          UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  asset_id           UUID REFERENCES public.rental_assets(id) ON DELETE SET NULL,   -- eigenes Leihgerät
  serial_unit_id     UUID REFERENCES public.serial_units(id) ON DELETE SET NULL,    -- verkauftes Einzelstück
  customer_person_id UUID REFERENCES public.contacts(id) ON DELETE SET NULL,        -- Kundengerät
  type               TEXT NOT NULL CHECK (type IN ('annual_service','repair','inspection','hydro','vip')),
  status             TEXT NOT NULL DEFAULT 'intake'
                       CHECK (status IN ('intake','quoted','approved','in_progress','done','picked_up')),
  description        TEXT,
  labor_cost         NUMERIC(12,2) NOT NULL DEFAULT 0,
  next_due           DATE,
  created_by         UUID,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_service_jobs_tenant_status ON public.service_jobs(tenant_id, status);
CREATE INDEX idx_service_jobs_asset         ON public.service_jobs(asset_id);

CREATE TABLE public.service_job_parts (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  job_id      UUID NOT NULL REFERENCES public.service_jobs(id) ON DELETE CASCADE,
  description TEXT NOT NULL,
  qty         NUMERIC(12,2) NOT NULL DEFAULT 1,
  unit_cost   NUMERIC(12,2) NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_service_job_parts_job ON public.service_job_parts(job_id);

-- ════════════════════════════════════════════════════════════════════
-- 5. Füllstation (UNVERÄNDERLICHES Protokoll)
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE public.fill_logs (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  asset_id          UUID REFERENCES public.rental_assets(id) ON DELETE SET NULL,   -- Hausflasche
  cylinder_ref      TEXT,                                                          -- Kundenflasche (Freitext)
  gas               TEXT NOT NULL CHECK (gas IN ('air','nitrox','trimix')),
  mix_o2            NUMERIC(5,2),
  mix_he            NUMERIC(5,2),
  pressure_bar      INT,
  analyzed_by       UUID,
  filler_id         UUID,
  cert_check_passed BOOLEAN NOT NULL,
  air_card_ref      UUID REFERENCES public.package_purchases(id) ON DELETE SET NULL,
  filled_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by        UUID,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_fill_logs_tenant_date ON public.fill_logs(tenant_id, filled_at DESC);

CREATE OR REPLACE FUNCTION public.block_fill_log_update()
RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION 'fill_logs rows are immutable.';
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_block_fill_log_update
  BEFORE UPDATE ON public.fill_logs
  FOR EACH ROW EXECUTE FUNCTION public.block_fill_log_update();

-- ════════════════════════════════════════════════════════════════════
-- 6. updated_at- + Audit-Trigger
-- ════════════════════════════════════════════════════════════════════
CREATE TRIGGER trg_rental_assets_updated_at     BEFORE UPDATE ON public.rental_assets     FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_service_plans_updated_at     BEFORE UPDATE ON public.service_plans     FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_rental_agreements_updated_at BEFORE UPDATE ON public.rental_agreements FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_service_jobs_updated_at      BEFORE UPDATE ON public.service_jobs      FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_audit_rental_assets     AFTER INSERT OR UPDATE OR DELETE ON public.rental_assets     FOR EACH ROW EXECUTE FUNCTION public.audit_finance_changes();
CREATE TRIGGER trg_audit_rental_agreements AFTER INSERT OR UPDATE OR DELETE ON public.rental_agreements FOR EACH ROW EXECUTE FUNCTION public.audit_finance_changes();
CREATE TRIGGER trg_audit_service_jobs      AFTER INSERT OR UPDATE OR DELETE ON public.service_jobs      FOR EACH ROW EXECUTE FUNCTION public.audit_finance_changes();

-- ════════════════════════════════════════════════════════════════════
-- 7. RLS — Stammdaten/Vorgänge beschreibbar (dispatcher/owner); Füllprotokoll nur lesbar
-- ════════════════════════════════════════════════════════════════════
DO $$
DECLARE
  t   text;
  sel text := '(tenant_id = public.current_tenant_id())';
  wr  text := '(tenant_id = public.current_tenant_id() AND (public.is_dispatcher() OR public.is_owner()))';
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'rental_assets','service_plans','rental_agreements','rental_agreement_assets',
    'service_jobs','service_job_parts'
  ] LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;', t);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR SELECT TO authenticated USING %s;',  t||'_select', t, sel);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR INSERT TO authenticated WITH CHECK %s;', t||'_insert', t, wr);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR UPDATE TO authenticated USING %s WITH CHECK %s;', t||'_update', t, wr, wr);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR DELETE TO authenticated USING %s;', t||'_delete', t, wr);
  END LOOP;
END $$;

ALTER TABLE public.fill_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY fill_logs_select ON public.fill_logs
  FOR SELECT TO authenticated USING (tenant_id = public.current_tenant_id());

-- ════════════════════════════════════════════════════════════════════
-- 8. Views
-- ════════════════════════════════════════════════════════════════════
CREATE VIEW public.v_rental_assets_status
  WITH (security_invoker = true) AS
SELECT a.tenant_id, a.id AS asset_id, a.label, a.asset_type, a.status, a.condition_grade,
       a.next_service_due, a.cert_due,
       (a.next_service_due IS NOT NULL AND a.next_service_due <= current_date) AS service_overdue,
       (a.cert_due IS NOT NULL AND a.cert_due <= current_date)                 AS cert_overdue
FROM public.rental_assets a
WHERE a.is_active;

CREATE VIEW public.v_service_due
  WITH (security_invoker = true) AS
SELECT a.tenant_id, a.id AS asset_id, a.label, a.asset_type, a.next_service_due, a.cert_due
FROM public.rental_assets a
WHERE a.is_active
  AND ((a.next_service_due IS NOT NULL AND a.next_service_due <= current_date)
    OR (a.cert_due IS NOT NULL AND a.cert_due <= current_date));

CREATE VIEW public.v_open_rentals
  WITH (security_invoker = true) AS
SELECT r.id AS agreement_id, r.tenant_id, r.person_id, r.out_at, r.due_at,
       (SELECT count(*) FROM public.rental_agreement_assets ra WHERE ra.agreement_id = r.id) AS asset_count,
       (r.due_at IS NOT NULL AND r.due_at < now()) AS overdue
FROM public.rental_agreements r
WHERE r.status = 'open';

-- ════════════════════════════════════════════════════════════════════
-- 9. Seed: Standard-Wartungsintervalle für TSK
-- ════════════════════════════════════════════════════════════════════
INSERT INTO public.service_plans (tenant_id, asset_type, name, interval_months)
SELECT t.id, v.asset_type, v.name, v.months
FROM public.tenants t
CROSS JOIN (VALUES
  ('regulator', 'Reglerservice jährlich', 12),
  ('bcd',       'BCD-Service jährlich',   12),
  ('computer',  'Computer-Check',         24)
) AS v(asset_type, name, months)
WHERE t.slug = 'tsk-zrh'
ON CONFLICT (tenant_id, asset_type) DO NOTHING;

COMMIT;
