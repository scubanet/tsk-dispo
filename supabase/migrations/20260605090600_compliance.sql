-- 20260605090600_compliance.sql
-- Phase-1 — Schritt 7: Compliance-Tracking (leichtgewichtig).
--
-- Entscheidung D-3: PADI bietet Medical/Liability/Safe-Diving als Online-Formulare
-- an → Atoll speichert KEINE Dokumente und signiert nichts. Es trackt nur, OB ein
-- Pflicht-Check erledigt ist, von WEM geprüft und BIS WANN gültig — und gated damit
-- Aktivitäten (kein Wassergang/keine Buchung ohne gültigen Check). Saubere SSOT an
-- contacts, aktivitätsbezogen, mit Ablauf. reference_note darf KEINE Diagnose
-- enthalten (nur Bestätigungs-Referenz) → kein Art.-9-Inhalt im System.

BEGIN;

-- ════════════════════════════════════════════════════════════════════
-- 1. Anforderungs-Katalog (was es zu prüfen gibt)
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE public.compliance_requirement_types (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id               UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  code                    TEXT NOT NULL,
  name                    TEXT NOT NULL,
  default_validity_months INT,                 -- NULL = unbegrenzt; Medical z. B. 12
  source_url              TEXT,                 -- Link zum PADI-Online-Formular (nur Referenz)
  is_active               BOOLEAN NOT NULL DEFAULT true,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, code)
);
COMMENT ON TABLE public.compliance_requirement_types IS 'Pflicht-Checks pro Tenant (PADI-Formulare etc.). Kein Dokument, nur Referenz.';

-- ════════════════════════════════════════════════════════════════════
-- 2. Status-Records (pro Kontakt pro Anforderung; Historie, jüngster zählt)
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE public.compliance_records (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id        UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  contact_id       UUID NOT NULL REFERENCES public.contacts(id) ON DELETE CASCADE,
  requirement_code TEXT NOT NULL,
  status           TEXT NOT NULL DEFAULT 'checked' CHECK (status IN ('pending','checked','waived','na')),
  checked_by       UUID,
  checked_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  valid_from       DATE,
  valid_to         DATE,                        -- Ablauf; 'expired' wird daraus ABGELEITET, nicht gespeichert
  source           TEXT NOT NULL DEFAULT 'padi_online' CHECK (source IN ('padi_online','paper','verbal')),
  reference_note   TEXT,                        -- KEINE Diagnose — nur Bestätigungs-Referenz/Formular-ID
  context_type     TEXT,                        -- optional aktivitätsgebunden (z. B. 'course')
  context_id       UUID,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  FOREIGN KEY (tenant_id, requirement_code)
    REFERENCES public.compliance_requirement_types(tenant_id, code)
);
COMMENT ON TABLE public.compliance_records IS 'Prüf-Status je Kontakt/Anforderung (append-only Historie). Inhalt der Formulare wird NICHT gespeichert.';
CREATE INDEX idx_compliance_records_latest
  ON public.compliance_records(contact_id, requirement_code, checked_at DESC);
CREATE INDEX idx_compliance_records_expiry
  ON public.compliance_records(tenant_id, valid_to)
  WHERE valid_to IS NOT NULL;

-- ════════════════════════════════════════════════════════════════════
-- 3. Gates (welche Anforderung welche Aktivität sperrt)
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE public.compliance_gates (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id        UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  activity_type    TEXT NOT NULL CHECK (activity_type IN ('course_enroll','trip_book','rental_out','pool_session')),
  requirement_code TEXT NOT NULL,
  blocking         BOOLEAN NOT NULL DEFAULT true,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, activity_type, requirement_code),
  FOREIGN KEY (tenant_id, requirement_code)
    REFERENCES public.compliance_requirement_types(tenant_id, code)
);

-- ════════════════════════════════════════════════════════════════════
-- 4. contact_events: Compliance-Eventtypen ergänzen (vollständige Liste neu setzen)
-- ════════════════════════════════════════════════════════════════════
ALTER TABLE public.contact_events
  DROP CONSTRAINT IF EXISTS contact_events_event_type_check;
ALTER TABLE public.contact_events
  ADD CONSTRAINT contact_events_event_type_check CHECK (event_type IN (
    'note', 'call', 'email_external', 'meeting_past', 'task',
    'whatsapp_log', 'linkedin_message',
    'invoice_issued', 'payment_received', 'payment_refunded',
    'compliance_checked', 'compliance_expiring'
  ));

-- ════════════════════════════════════════════════════════════════════
-- 5. updated_at-Trigger
-- ════════════════════════════════════════════════════════════════════
CREATE TRIGGER trg_compliance_req_types_updated_at
  BEFORE UPDATE ON public.compliance_requirement_types
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ════════════════════════════════════════════════════════════════════
-- 6. Seed (TSK): Standard-Anforderungen + Gates
-- ════════════════════════════════════════════════════════════════════
INSERT INTO public.compliance_requirement_types (tenant_id, code, name, default_validity_months, source_url)
SELECT t.id, v.code, v.name, v.months, v.url
FROM public.tenants t
CROSS JOIN (VALUES
  ('medical',          'Medical Statement',                  12::int, 'https://www.padi.com/scuba-medical-form'),
  ('liability',        'Liability Release / Haftungsausschluss', NULL, NULL),
  ('safe_diving',      'Standard Safe Diving Practices',         NULL, NULL),
  ('insurance',        'Tauchversicherung',                      NULL, NULL),
  ('id_check',         'Ausweisprüfung',                         NULL, NULL),
  ('guardian_consent', 'Einverständnis Erziehungsberechtigte',   NULL, NULL),
  ('elearning',        'eLearning abgeschlossen',                NULL, NULL)
) AS v(code, name, months, url)
WHERE t.slug = 'tsk-zrh'
ON CONFLICT (tenant_id, code) DO NOTHING;

INSERT INTO public.compliance_gates (tenant_id, activity_type, requirement_code, blocking)
SELECT t.id, g.activity, g.req, g.blocking
FROM public.tenants t
CROSS JOIN (VALUES
  ('course_enroll', 'medical',     true),
  ('course_enroll', 'liability',   true),
  ('course_enroll', 'safe_diving', true),
  ('trip_book',     'medical',     true),
  ('trip_book',     'liability',   true),
  ('rental_out',    'liability',   true)
) AS g(activity, req, blocking)
WHERE t.slug = 'tsk-zrh'
ON CONFLICT (tenant_id, activity_type, requirement_code) DO NOTHING;

-- ════════════════════════════════════════════════════════════════════
-- 7. Backfill aus contact_student (defensiv: nur wenn Spalten existieren)
-- ════════════════════════════════════════════════════════════════════
DO $$
DECLARE v_tenant UUID;
BEGIN
  SELECT id INTO v_tenant FROM public.tenants WHERE slug = 'tsk-zrh';
  IF v_tenant IS NULL THEN RETURN; END IF;

  IF EXISTS (SELECT 1 FROM information_schema.columns
             WHERE table_schema='public' AND table_name='contact_student'
               AND column_name='medical_clearance_at') THEN
    INSERT INTO public.compliance_records
      (tenant_id, contact_id, requirement_code, status, checked_at, valid_from, valid_to, source, reference_note)
    SELECT v_tenant, cs.contact_id, 'medical', 'checked',
           cs.medical_clearance_at::timestamptz, cs.medical_clearance_at,
           (cs.medical_clearance_at + INTERVAL '12 months')::date, 'paper', 'Backfill aus contact_student'
    FROM public.contact_student cs
    WHERE cs.medical_clearance_at IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM public.compliance_records cr
                      WHERE cr.contact_id = cs.contact_id AND cr.requirement_code = 'medical');
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.columns
             WHERE table_schema='public' AND table_name='contact_student'
               AND column_name='insurance_provider') THEN
    INSERT INTO public.compliance_records
      (tenant_id, contact_id, requirement_code, status, checked_at, source, reference_note)
    SELECT v_tenant, cs.contact_id, 'insurance', 'checked', now(), 'paper',
           'Backfill: ' || cs.insurance_provider
    FROM public.contact_student cs
    WHERE cs.insurance_provider IS NOT NULL AND cs.insurance_provider <> ''
      AND NOT EXISTS (SELECT 1 FROM public.compliance_records cr
                      WHERE cr.contact_id = cs.contact_id AND cr.requirement_code = 'insurance');
  END IF;
END $$;

-- ════════════════════════════════════════════════════════════════════
-- 8. RLS — Katalog/Gates beschreibbar (dispatcher/owner), Records nur lesbar (Writes via RPC)
-- ════════════════════════════════════════════════════════════════════
DO $$
DECLARE
  t   text;
  sel text := '(tenant_id = public.current_tenant_id())';
  wr  text := '(tenant_id = public.current_tenant_id() AND (public.is_dispatcher() OR public.is_owner()))';
BEGIN
  FOREACH t IN ARRAY ARRAY['compliance_requirement_types','compliance_gates'] LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;', t);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR SELECT TO authenticated USING %s;',  t||'_select', t, sel);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR INSERT TO authenticated WITH CHECK %s;', t||'_insert', t, wr);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR UPDATE TO authenticated USING %s WITH CHECK %s;', t||'_update', t, wr, wr);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR DELETE TO authenticated USING %s;', t||'_delete', t, wr);
  END LOOP;
END $$;

ALTER TABLE public.compliance_records ENABLE ROW LEVEL SECURITY;
CREATE POLICY compliance_records_select ON public.compliance_records
  FOR SELECT TO authenticated USING (tenant_id = public.current_tenant_id());
-- Schreiben ausschließlich über compliance_set() (SECURITY DEFINER).

-- ════════════════════════════════════════════════════════════════════
-- 9. Status-View (jüngster Record je Kontakt/Anforderung, abgeleiteter Zustand)
-- ════════════════════════════════════════════════════════════════════
CREATE VIEW public.v_compliance_status
  WITH (security_invoker = true) AS
SELECT DISTINCT ON (cr.contact_id, cr.requirement_code)
       cr.tenant_id,
       cr.contact_id,
       cr.requirement_code,
       cr.status,
       cr.valid_to,
       CASE
         WHEN cr.status = 'checked' AND (cr.valid_to IS NULL OR cr.valid_to >= current_date) THEN 'ok'
         WHEN cr.status = 'checked' AND cr.valid_to < current_date                           THEN 'expired'
         WHEN cr.status IN ('waived','na')                                                    THEN 'ok'
         ELSE 'pending'
       END AS effective_state,
       cr.checked_at
FROM public.compliance_records cr
ORDER BY cr.contact_id, cr.requirement_code, cr.checked_at DESC;

-- ════════════════════════════════════════════════════════════════════
-- 10. RPCs
-- ════════════════════════════════════════════════════════════════════

-- Gating-Abfrage: fehlende/abgelaufene Pflicht-Checks für eine geplante Aktivität.
CREATE OR REPLACE FUNCTION public.check_compliance(
  p_contact_id    UUID,
  p_activity_type TEXT,
  p_context_id    UUID DEFAULT NULL
)
RETURNS TABLE(requirement_code TEXT, state TEXT, blocking BOOLEAN)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT g.requirement_code,
         COALESCE((
           SELECT CASE
                    WHEN r.status = 'checked' AND (r.valid_to IS NULL OR r.valid_to >= current_date) THEN 'ok'
                    WHEN r.status = 'checked' AND r.valid_to < current_date                          THEN 'expired'
                    WHEN r.status IN ('waived','na')                                                  THEN 'ok'
                    ELSE 'pending'
                  END
           FROM public.compliance_records r
           WHERE r.contact_id = p_contact_id AND r.requirement_code = g.requirement_code
           ORDER BY r.checked_at DESC
           LIMIT 1
         ), 'missing') AS state,
         g.blocking
  FROM public.compliance_gates g
  WHERE g.tenant_id = public.current_tenant_id()
    AND g.activity_type = p_activity_type;
$$;

-- Check setzen (schreibt Record + Timeline; valid_to aus default_validity_months wenn nicht gesetzt).
CREATE OR REPLACE FUNCTION public.compliance_set(
  p_contact_id   UUID,
  p_code         TEXT,
  p_status       TEXT DEFAULT 'checked',
  p_valid_to     DATE DEFAULT NULL,
  p_source       TEXT DEFAULT 'padi_online',
  p_note         TEXT DEFAULT NULL,
  p_context_type TEXT DEFAULT NULL,
  p_context_id   UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tenant   UUID := public.current_tenant_id();
  v_months   INT;
  v_name     TEXT;
  v_valid_to DATE;
  v_rec      UUID;
  v_actor    UUID;
BEGIN
  IF NOT (public.is_dispatcher() OR public.is_owner()) THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;
  IF v_tenant IS NULL THEN RAISE EXCEPTION 'no_tenant' USING ERRCODE = '42501'; END IF;

  SELECT default_validity_months, name INTO v_months, v_name
    FROM public.compliance_requirement_types
   WHERE tenant_id = v_tenant AND code = p_code;
  IF v_name IS NULL THEN RAISE EXCEPTION 'unknown_requirement (%)', p_code; END IF;

  v_valid_to := COALESCE(
                  p_valid_to,
                  CASE WHEN v_months IS NOT NULL
                       THEN (current_date + (v_months || ' months')::interval)::date END);
  v_actor := (SELECT contact_id FROM public.contact_instructor WHERE auth_user_id = auth.uid() LIMIT 1);

  INSERT INTO public.compliance_records
    (tenant_id, contact_id, requirement_code, status, checked_by, checked_at,
     valid_from, valid_to, source, reference_note, context_type, context_id)
  VALUES
    (v_tenant, p_contact_id, p_code, p_status, v_actor, now(),
     current_date, v_valid_to, p_source, p_note, p_context_type, p_context_id)
  RETURNING id INTO v_rec;

  INSERT INTO public.contact_events (contact_id, event_type, summary, payload, actor_id)
  VALUES (p_contact_id, 'compliance_checked',
          v_name || ': ' || p_status || COALESCE(' (gültig bis ' || v_valid_to || ')', ''),
          jsonb_build_object('requirement', p_code, 'status', p_status, 'valid_to', v_valid_to),
          v_actor);

  RETURN v_rec;
END;
$$;

REVOKE ALL ON FUNCTION public.check_compliance(UUID, TEXT, UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.compliance_set(UUID, TEXT, TEXT, DATE, TEXT, TEXT, TEXT, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.check_compliance(UUID, TEXT, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.compliance_set(UUID, TEXT, TEXT, DATE, TEXT, TEXT, TEXT, UUID) TO authenticated, service_role;

COMMIT;
