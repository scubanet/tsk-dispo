-- 20260605090200_finance_core.sql
-- Phase-1 — Schritt 3: Kundenfinanz-Kern (Datenmodell).
--
-- Tabellen: tax_rates, price_book, contact_billing, orders, order_lines,
-- invoices, invoice_lines, tenant_counters + finance_audit_log.
-- Folgt Atoll-Konventionen: gen_random_uuid()-PK, set_updated_at()-Trigger,
-- FK-loses BIGSERIAL-Audit-Log via SECURITY-DEFINER-Trigger (wie contact_audit_log),
-- versionierte Stammdaten via valid_from/valid_to + partiellem Unique-Index (wie comp_rates),
-- tenant-scoped RLS (Writes: is_dispatcher() OR is_owner(), wie 20260604150000-Lockdown).
--
-- BEWUSSTE ABWEICHUNG (D-2/Greenfield): Geldspalten sind generisch NUMERIC(12,2) + currency
-- CHAR(3) statt des _chf-Suffixes, weil Kundenrechnungen mehrwährungs- und steuerfähig sein
-- müssen — im heutigen Atoll (CHF-only, keine MwSt) ohne Präzedenz. Default bleibt CHF.
-- payments (unveränderliches Journal) folgt in Schritt 4; die issued-Invoice-Immutability
-- wird im invoice_issue-RPC (Schritt 6) erzwungen.

BEGIN;

-- ════════════════════════════════════════════════════════════════════
-- 1. Steuersätze (versioniert, Konvention comp_rates)
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE public.tax_rates (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  code        TEXT NOT NULL,                 -- 'standard' | 'reduced' | 'zero'
  rate_pct    NUMERIC(5,2) NOT NULL,         -- z. B. 8.10 (CH-MwSt ab 2024)
  valid_from  DATE NOT NULL DEFAULT current_date,
  valid_to    DATE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (rate_pct >= 0),
  CHECK (valid_to IS NULL OR valid_to > valid_from)
);
COMMENT ON TABLE public.tax_rates IS 'MwSt-Sätze pro Tenant, versioniert (genau ein aktiver pro code).';

-- Genau ein aktiver Satz pro (tenant, code)
CREATE UNIQUE INDEX idx_tax_rates_active
  ON public.tax_rates(tenant_id, code)
  WHERE valid_to IS NULL;

-- ════════════════════════════════════════════════════════════════════
-- 2. Preisbuch (optionaler wiederverwendbarer Preis; Seam für M2/M3/M4)
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE public.price_book (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  item_type     TEXT NOT NULL CHECK (item_type IN ('course','product','rental','trip','fee','custom')),
  item_ref_id   UUID,                         -- polymorpher Verweis (z. B. course_type_id), App-Layer-Integrität
  name          TEXT NOT NULL,
  default_price NUMERIC(12,2) NOT NULL,
  currency      CHAR(3) NOT NULL DEFAULT 'CHF',
  tax_rate_id   UUID REFERENCES public.tax_rates(id) ON DELETE SET NULL,
  valid_from    DATE NOT NULL DEFAULT current_date,
  valid_to      DATE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (default_price >= 0),
  CHECK (valid_to IS NULL OR valid_to > valid_from)
);
COMMENT ON TABLE public.price_book IS 'Wiederverwendbare Preise; item_type/item_ref_id ist die Andocknaht für Retail/Verleih/Trips.';

CREATE INDEX idx_price_book_lookup ON public.price_book(tenant_id, item_type, item_ref_id);
-- Genau ein aktiver Preis pro konkretem Item
CREATE UNIQUE INDEX idx_price_book_active
  ON public.price_book(tenant_id, item_type, item_ref_id)
  WHERE valid_to IS NULL AND item_ref_id IS NOT NULL;

-- ════════════════════════════════════════════════════════════════════
-- 3. Rechnungs-Stammdaten am Kontakt (Sidecar 1:0..1 zu contacts)
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE public.contact_billing (
  contact_id          UUID PRIMARY KEY REFERENCES public.contacts(id) ON DELETE CASCADE,
  tenant_id           UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  billing_email       TEXT,
  billing_address     JSONB,                  -- gleiche Shape wie contacts.addresses-Item
  tax_id              TEXT,                   -- UID/MwSt-Nr. für Personen (Orgs haben sie im org-Sidecar)
  payment_terms_days  INT NOT NULL DEFAULT 0,
  default_discount_pct NUMERIC(5,2) NOT NULL DEFAULT 0,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (default_discount_pct >= 0 AND default_discount_pct <= 100)
);
COMMENT ON TABLE public.contact_billing IS 'Rechnungs-Spezifika am Kontakt (ergänzt contact_organization.billing_*).';

-- ════════════════════════════════════════════════════════════════════
-- 4. Aufträge / Warenkorb
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE public.orders (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id      UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  contact_id     UUID NOT NULL REFERENCES public.contacts(id) ON DELETE RESTRICT,
  status         TEXT NOT NULL DEFAULT 'draft'
                   CHECK (status IN ('draft','open','paid','partially_paid','void','refunded')),
  channel        TEXT NOT NULL DEFAULT 'backoffice'
                   CHECK (channel IN ('pos','backoffice','online')),
  currency       CHAR(3) NOT NULL DEFAULT 'CHF',
  subtotal       NUMERIC(12,2) NOT NULL DEFAULT 0,
  discount_total NUMERIC(12,2) NOT NULL DEFAULT 0,
  tax_total      NUMERIC(12,2) NOT NULL DEFAULT 0,
  grand_total    NUMERIC(12,2) NOT NULL DEFAULT 0,
  note           TEXT,
  created_by     UUID,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.orders IS 'Verkaufskopf. Summen werden per order_recalc()-RPC (Schritt 6) neu berechnet.';

CREATE INDEX idx_orders_tenant_contact ON public.orders(tenant_id, contact_id);
CREATE INDEX idx_orders_status         ON public.orders(tenant_id, status);

CREATE TABLE public.order_lines (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  order_id      UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  item_type     TEXT NOT NULL DEFAULT 'custom'
                   CHECK (item_type IN ('course','product','rental','trip','fee','package','custom')),
  item_ref_id   UUID,                         -- polymorpher Verweis (Kursteilnahme, Produkt, …)
  description   TEXT NOT NULL,
  quantity      NUMERIC(8,2) NOT NULL DEFAULT 1,
  unit_price    NUMERIC(12,2) NOT NULL DEFAULT 0,
  discount_pct  NUMERIC(5,2) NOT NULL DEFAULT 0,
  tax_rate_id   UUID REFERENCES public.tax_rates(id) ON DELETE SET NULL,
  line_subtotal NUMERIC(12,2) NOT NULL DEFAULT 0,
  line_tax      NUMERIC(12,2) NOT NULL DEFAULT 0,
  line_total    NUMERIC(12,2) NOT NULL DEFAULT 0,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (quantity > 0),
  CHECK (discount_pct >= 0 AND discount_pct <= 100)
);
CREATE INDEX idx_order_lines_order ON public.order_lines(order_id);

-- ════════════════════════════════════════════════════════════════════
-- 5. Rechnungen (Kopf + eingefrorene Positionen)
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE public.invoices (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id             UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  contact_id            UUID NOT NULL REFERENCES public.contacts(id) ON DELETE RESTRICT,
  order_id              UUID REFERENCES public.orders(id) ON DELETE SET NULL,
  number                TEXT,                 -- vergeben bei issue via next_invoice_number()
  status                TEXT NOT NULL DEFAULT 'draft'
                          CHECK (status IN ('draft','issued','paid','partially_paid','void','credited')),
  issue_date            DATE,
  due_date              DATE,
  currency              CHAR(3) NOT NULL DEFAULT 'CHF',
  subtotal              NUMERIC(12,2) NOT NULL DEFAULT 0,
  tax_total             NUMERIC(12,2) NOT NULL DEFAULT 0,
  total                 NUMERIC(12,2) NOT NULL DEFAULT 0,
  pdf_ref               TEXT,                 -- optionaler Objektspeicher-Pfad (Beleg, kein Compliance-Doc)
  accounting_export_ref TEXT,                 -- Bexio-Beleg-ID nach Export
  created_by            UUID,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.invoices IS 'Rechnungskopf. Nummer/Positionen werden bei invoice_issue() (Schritt 6) eingefroren.';

CREATE INDEX idx_invoices_tenant_contact ON public.invoices(tenant_id, contact_id);
CREATE INDEX idx_invoices_status         ON public.invoices(tenant_id, status);
-- Eindeutige Rechnungsnummer pro Tenant (sobald vergeben)
CREATE UNIQUE INDEX idx_invoices_number
  ON public.invoices(tenant_id, number)
  WHERE number IS NOT NULL;

CREATE TABLE public.invoice_lines (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  invoice_id    UUID NOT NULL REFERENCES public.invoices(id) ON DELETE CASCADE,
  description   TEXT NOT NULL,
  quantity      NUMERIC(8,2) NOT NULL DEFAULT 1,
  unit_price    NUMERIC(12,2) NOT NULL DEFAULT 0,
  discount_pct  NUMERIC(5,2) NOT NULL DEFAULT 0,
  tax_rate_pct  NUMERIC(5,2) NOT NULL DEFAULT 0,   -- Snapshot des Satzes zum Ausstellungszeitpunkt
  line_subtotal NUMERIC(12,2) NOT NULL DEFAULT 0,
  line_tax      NUMERIC(12,2) NOT NULL DEFAULT 0,
  line_total    NUMERIC(12,2) NOT NULL DEFAULT 0,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.invoice_lines IS 'Eingefrorene Positionssnapshots (nach issue unveränderlich, via RPC erzwungen).';
CREATE INDEX idx_invoice_lines_invoice ON public.invoice_lines(invoice_id);

-- ════════════════════════════════════════════════════════════════════
-- 6. Rechnungsnummern-Zähler (pro Tenant + Jahr) + Generator
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE public.tenant_counters (
  tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  year      INT  NOT NULL,
  last_no   INT  NOT NULL DEFAULT 0,
  PRIMARY KEY (tenant_id, year)
);
COMMENT ON TABLE public.tenant_counters IS 'Monotone Rechnungsnummern pro Tenant/Jahr; nur via next_invoice_number() beschrieben.';

-- Atomarer, lückenfreier Nummerngenerator (Format: <prefix>-YYYY-NNNNNN).
CREATE OR REPLACE FUNCTION public.next_invoice_number(p_tenant_id UUID)
RETURNS TEXT
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_year   INT := EXTRACT(YEAR FROM now())::INT;
  v_no     INT;
  v_prefix TEXT;
BEGIN
  IF NOT (public.is_dispatcher() OR public.is_owner()) THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.tenant_counters AS tc (tenant_id, year, last_no)
       VALUES (p_tenant_id, v_year, 1)
  ON CONFLICT (tenant_id, year)
       DO UPDATE SET last_no = tc.last_no + 1
    RETURNING tc.last_no INTO v_no;

  SELECT invoice_prefix INTO v_prefix FROM public.tenants WHERE id = p_tenant_id;

  RETURN COALESCE(v_prefix, 'R') || '-' || v_year::text || '-' || lpad(v_no::text, 6, '0');
END;
$$;

REVOKE ALL ON FUNCTION public.next_invoice_number(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.next_invoice_number(UUID) TO authenticated, service_role;

-- ════════════════════════════════════════════════════════════════════
-- 7. Finanz-Audit-Log (FK-los, BIGSERIAL, via SECURITY-DEFINER-Trigger — wie contact_audit_log)
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE public.finance_audit_log (
  id             BIGSERIAL PRIMARY KEY,
  tenant_id      UUID,
  table_name     TEXT NOT NULL,
  entity_id      UUID NOT NULL,
  changed_by     UUID,
  changed_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  operation      TEXT NOT NULL CHECK (operation IN ('INSERT','UPDATE','DELETE')),
  changed_fields JSONB,
  old_row        JSONB,
  new_row        JSONB
);
CREATE INDEX idx_finance_audit_entity ON public.finance_audit_log(entity_id, changed_at DESC);
CREATE INDEX idx_finance_audit_tenant ON public.finance_audit_log(tenant_id, changed_at DESC);

CREATE OR REPLACE FUNCTION public.audit_finance_changes()
RETURNS TRIGGER AS $$
DECLARE
  v_changed JSONB;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    SELECT jsonb_object_agg(key, jsonb_build_object('old', old_val, 'new', new_val))
      INTO v_changed
      FROM (
        SELECT o.key AS key, o.value AS old_val, n.value AS new_val
        FROM jsonb_each(to_jsonb(OLD)) AS o(key, value)
        JOIN jsonb_each(to_jsonb(NEW)) AS n(key, value) USING (key)
        WHERE o.value IS DISTINCT FROM n.value
      ) diff;
  END IF;

  INSERT INTO public.finance_audit_log
    (tenant_id, table_name, entity_id, changed_by, operation, changed_fields, old_row, new_row)
  VALUES
    (COALESCE(NEW.tenant_id, OLD.tenant_id),
     TG_TABLE_NAME,
     COALESCE(NEW.id, OLD.id),
     auth.uid(),
     TG_OP,
     v_changed,
     CASE WHEN TG_OP IN ('UPDATE','DELETE') THEN to_jsonb(OLD) END,
     CASE WHEN TG_OP IN ('INSERT','UPDATE') THEN to_jsonb(NEW) END);

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.audit_finance_changes IS
  'Loggt jede Mutation an orders/invoices nach finance_audit_log (Diff bei UPDATE).';

CREATE TRIGGER trg_audit_orders
  AFTER INSERT OR UPDATE OR DELETE ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.audit_finance_changes();

CREATE TRIGGER trg_audit_invoices
  AFTER INSERT OR UPDATE OR DELETE ON public.invoices
  FOR EACH ROW EXECUTE FUNCTION public.audit_finance_changes();

-- ════════════════════════════════════════════════════════════════════
-- 8. updated_at-Trigger (gemeinsame set_updated_at()-Function aus 0001)
-- ════════════════════════════════════════════════════════════════════
CREATE TRIGGER trg_price_book_updated_at
  BEFORE UPDATE ON public.price_book
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_contact_billing_updated_at
  BEFORE UPDATE ON public.contact_billing
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_orders_updated_at
  BEFORE UPDATE ON public.orders
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_order_lines_updated_at
  BEFORE UPDATE ON public.order_lines
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_invoices_updated_at
  BEFORE UPDATE ON public.invoices
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ════════════════════════════════════════════════════════════════════
-- 9. RLS — tenant-scoped (Konvention 20260604150000-Lockdown)
--    SELECT: eigener Mandant. Writes: eigener Mandant UND (dispatcher|owner).
-- ════════════════════════════════════════════════════════════════════
DO $$
DECLARE
  t   text;
  sel text := '(tenant_id = public.current_tenant_id())';
  wr  text := '(tenant_id = public.current_tenant_id() AND (public.is_dispatcher() OR public.is_owner()))';
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'tax_rates','price_book','contact_billing',
    'orders','order_lines','invoices','invoice_lines'
  ] LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;', t);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR SELECT TO authenticated USING %s;',
                   t||'_select', t, sel);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR INSERT TO authenticated WITH CHECK %s;',
                   t||'_insert', t, wr);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR UPDATE TO authenticated USING %s WITH CHECK %s;',
                   t||'_update', t, wr, wr);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR DELETE TO authenticated USING %s;',
                   t||'_delete', t, wr);
  END LOOP;
END $$;

-- tenant_counters: nur Lesen des eigenen Mandanten; Schreiben ausschließlich via SECURITY-DEFINER next_invoice_number()
ALTER TABLE public.tenant_counters ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_counters_select ON public.tenant_counters
  FOR SELECT TO authenticated USING (tenant_id = public.current_tenant_id());

-- finance_audit_log: nur Lesen des eigenen Mandanten; Schreiben ausschließlich via Trigger
ALTER TABLE public.finance_audit_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY finance_audit_log_select ON public.finance_audit_log
  FOR SELECT TO authenticated USING (tenant_id = public.current_tenant_id());

-- ════════════════════════════════════════════════════════════════════
-- 10. Seed: Default-Steuersätze für TSK (anpassen — viele Tauchkurse können MwSt-befreit sein)
-- ════════════════════════════════════════════════════════════════════
INSERT INTO public.tax_rates (tenant_id, code, rate_pct)
SELECT t.id, v.code, v.rate
FROM public.tenants t
CROSS JOIN (VALUES ('zero', 0.00), ('standard', 8.10)) AS v(code, rate)
WHERE t.slug = 'tsk-zrh'
  AND NOT EXISTS (
    SELECT 1 FROM public.tax_rates x
    WHERE x.tenant_id = t.id AND x.code = v.code AND x.valid_to IS NULL
  );

COMMIT;
