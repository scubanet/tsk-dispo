-- 20260605091000_m2_retail_core.sql
-- Phase-2 / M2 — Retail & Lager (Datenmodell).
--
-- Baut auf der Phase-1-Finanzschicht auf: Bestand ist ein UNVERÄNDERLICHES
-- Mengen-Journal (inventory_movements, Muster payments) → on-hand = SUM(qty).
-- Verkauf dockt über order_lines.item_type='product' an (item_ref_id = variant).
-- Seriennummern (serial_units) tracken Einzelstücke für Garantie/Rückruf.
-- Alles tenant-scoped (current_tenant_id) mit denselben RLS-/Trigger-Konventionen.

BEGIN;

-- ════════════════════════════════════════════════════════════════════
-- 1. Produkt-Kategorien (Katalog je Tenant)
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE public.product_categories (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id  UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  code       TEXT NOT NULL,
  name       TEXT NOT NULL,
  is_active  BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, code)
);

-- ════════════════════════════════════════════════════════════════════
-- 2. Produkte + Varianten
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE public.products (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id           UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  category_id         UUID REFERENCES public.product_categories(id) ON DELETE SET NULL,
  name                TEXT NOT NULL,
  brand               TEXT,
  model               TEXT,
  serialized          BOOLEAN NOT NULL DEFAULT false,   -- seriennummernpflichtig?
  tax_rate_id         UUID REFERENCES public.tax_rates(id) ON DELETE SET NULL,
  supplier_contact_id UUID REFERENCES public.contacts(id) ON DELETE SET NULL,  -- Lieferant = contacts(org)
  reorder_point       NUMERIC(12,2) NOT NULL DEFAULT 0,
  reorder_qty         NUMERIC(12,2) NOT NULL DEFAULT 0,
  warranty_months     INT,
  is_active           BOOLEAN NOT NULL DEFAULT true,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_products_tenant_cat ON public.products(tenant_id, category_id);

CREATE TABLE public.product_variants (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  product_id  UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  sku         TEXT,
  barcode     TEXT,
  size        TEXT,
  color       TEXT,
  config      TEXT,
  price       NUMERIC(12,2) NOT NULL DEFAULT 0,
  cost        NUMERIC(12,2) NOT NULL DEFAULT 0,
  currency    CHAR(3) NOT NULL DEFAULT 'CHF',
  is_active   BOOLEAN NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (price >= 0), CHECK (cost >= 0)
);
CREATE INDEX idx_variants_product ON public.product_variants(product_id);
CREATE UNIQUE INDEX uq_variants_sku     ON public.product_variants(tenant_id, sku)     WHERE sku IS NOT NULL;
CREATE UNIQUE INDEX uq_variants_barcode ON public.product_variants(tenant_id, barcode) WHERE barcode IS NOT NULL;

-- ════════════════════════════════════════════════════════════════════
-- 3. Seriennummern (Einzelstücke — Garantie/Rückruf)
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE public.serial_units (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id          UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  variant_id         UUID NOT NULL REFERENCES public.product_variants(id) ON DELETE CASCADE,
  serial_no          TEXT NOT NULL,
  status             TEXT NOT NULL DEFAULT 'in_stock'
                       CHECK (status IN ('in_stock','sold','rental_pool','rma','retired')),
  sold_to_contact_id UUID REFERENCES public.contacts(id) ON DELETE SET NULL,
  sold_at            TIMESTAMPTZ,
  warranty_until     DATE,
  notes              TEXT,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, serial_no)
);
CREATE INDEX idx_serial_units_variant ON public.serial_units(variant_id, status);

-- ════════════════════════════════════════════════════════════════════
-- 4. Bestands-Journal (UNVERÄNDERLICH; on-hand = SUM(qty))
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE public.inventory_movements (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  variant_id  UUID NOT NULL REFERENCES public.product_variants(id) ON DELETE CASCADE,
  qty         NUMERIC(12,2) NOT NULL,        -- signiert: + Eingang / − Abgang
  reason      TEXT NOT NULL CHECK (reason IN
                ('receipt','sale','return','adjustment','rental_out','rental_in','transfer','write_off')),
  ref_type    TEXT,
  ref_id      UUID,
  note        TEXT,
  created_by  UUID,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (qty <> 0)
);
CREATE INDEX idx_inventory_variant ON public.inventory_movements(variant_id);

CREATE OR REPLACE FUNCTION public.block_inventory_movement_update()
RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION 'inventory_movements rows are immutable. Insert a correction row instead.';
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_block_inventory_movement_update
  BEFORE UPDATE ON public.inventory_movements
  FOR EACH ROW EXECUTE FUNCTION public.block_inventory_movement_update();

-- Verknüpft eine serialisierte Verkaufsposition mit dem konkreten Einzelstück.
CREATE TABLE public.order_line_serials (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id      UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  order_line_id  UUID NOT NULL REFERENCES public.order_lines(id) ON DELETE CASCADE,
  serial_unit_id UUID NOT NULL REFERENCES public.serial_units(id) ON DELETE RESTRICT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (serial_unit_id)
);

-- ════════════════════════════════════════════════════════════════════
-- 5. Beschaffung (Bestellungen)
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE public.purchase_orders (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id           UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  supplier_contact_id UUID REFERENCES public.contacts(id) ON DELETE SET NULL,
  status              TEXT NOT NULL DEFAULT 'draft'
                        CHECK (status IN ('draft','ordered','received','cancelled')),
  reference           TEXT,
  ordered_at          DATE,
  expected_at         DATE,
  note                TEXT,
  created_by          UUID,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_po_tenant_supplier ON public.purchase_orders(tenant_id, supplier_contact_id);

CREATE TABLE public.purchase_order_lines (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  po_id       UUID NOT NULL REFERENCES public.purchase_orders(id) ON DELETE CASCADE,
  variant_id  UUID NOT NULL REFERENCES public.product_variants(id) ON DELETE RESTRICT,
  qty         NUMERIC(12,2) NOT NULL CHECK (qty > 0),
  unit_cost   NUMERIC(12,2) NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_po_lines_po ON public.purchase_order_lines(po_id);

-- ════════════════════════════════════════════════════════════════════
-- 6. updated_at- + Audit-Trigger
-- ════════════════════════════════════════════════════════════════════
CREATE TRIGGER trg_product_categories_updated_at BEFORE UPDATE ON public.product_categories FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_products_updated_at           BEFORE UPDATE ON public.products           FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_product_variants_updated_at   BEFORE UPDATE ON public.product_variants   FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_serial_units_updated_at       BEFORE UPDATE ON public.serial_units       FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_purchase_orders_updated_at    BEFORE UPDATE ON public.purchase_orders    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_audit_products         AFTER INSERT OR UPDATE OR DELETE ON public.products         FOR EACH ROW EXECUTE FUNCTION public.audit_finance_changes();
CREATE TRIGGER trg_audit_product_variants AFTER INSERT OR UPDATE OR DELETE ON public.product_variants FOR EACH ROW EXECUTE FUNCTION public.audit_finance_changes();
CREATE TRIGGER trg_audit_serial_units     AFTER INSERT OR UPDATE OR DELETE ON public.serial_units     FOR EACH ROW EXECUTE FUNCTION public.audit_finance_changes();
CREATE TRIGGER trg_audit_purchase_orders  AFTER INSERT OR UPDATE OR DELETE ON public.purchase_orders  FOR EACH ROW EXECUTE FUNCTION public.audit_finance_changes();

-- ════════════════════════════════════════════════════════════════════
-- 7. RLS — Katalog/Beschaffung beschreibbar (dispatcher/owner); Journale nur lesbar
-- ════════════════════════════════════════════════════════════════════
DO $$
DECLARE
  t   text;
  sel text := '(tenant_id = public.current_tenant_id())';
  wr  text := '(tenant_id = public.current_tenant_id() AND (public.is_dispatcher() OR public.is_owner()))';
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'product_categories','products','product_variants','serial_units',
    'purchase_orders','purchase_order_lines'
  ] LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;', t);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR SELECT TO authenticated USING %s;',  t||'_select', t, sel);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR INSERT TO authenticated WITH CHECK %s;', t||'_insert', t, wr);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR UPDATE TO authenticated USING %s WITH CHECK %s;', t||'_update', t, wr, wr);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR DELETE TO authenticated USING %s;', t||'_delete', t, wr);
  END LOOP;
END $$;

-- Journale: nur Lesen des eigenen Mandanten; Schreiben via RPC (SECURITY DEFINER).
ALTER TABLE public.inventory_movements ENABLE ROW LEVEL SECURITY;
CREATE POLICY inventory_movements_select ON public.inventory_movements
  FOR SELECT TO authenticated USING (tenant_id = public.current_tenant_id());

ALTER TABLE public.order_line_serials ENABLE ROW LEVEL SECURITY;
CREATE POLICY order_line_serials_select ON public.order_line_serials
  FOR SELECT TO authenticated USING (tenant_id = public.current_tenant_id());

-- ════════════════════════════════════════════════════════════════════
-- 8. Bestands-Views
-- ════════════════════════════════════════════════════════════════════
CREATE VIEW public.v_inventory_on_hand
  WITH (security_invoker = true) AS
SELECT m.tenant_id, m.variant_id, COALESCE(SUM(m.qty), 0) AS on_hand
FROM public.inventory_movements m
GROUP BY m.tenant_id, m.variant_id;

CREATE VIEW public.v_low_stock
  WITH (security_invoker = true) AS
SELECT v.tenant_id, v.id AS variant_id, p.id AS product_id, p.name, v.sku,
       COALESCE(oh.on_hand, 0) AS on_hand, p.reorder_point, p.reorder_qty
FROM public.product_variants v
JOIN public.products p ON p.id = v.product_id
LEFT JOIN public.v_inventory_on_hand oh ON oh.variant_id = v.id
WHERE p.reorder_point > 0
  AND COALESCE(oh.on_hand, 0) <= p.reorder_point
  AND v.is_active AND p.is_active;

-- ════════════════════════════════════════════════════════════════════
-- 9. Seed: Standard-Kategorien für TSK
-- ════════════════════════════════════════════════════════════════════
INSERT INTO public.product_categories (tenant_id, code, name)
SELECT t.id, v.code, v.name
FROM public.tenants t
CROSS JOIN (VALUES
  ('regulator','Atemregler'), ('bcd','Jacket/BCD'), ('computer','Tauchcomputer'),
  ('wetsuit','Anzug'), ('mask','Maske'), ('fins','Flossen'), ('tank','Flasche'),
  ('accessory','Zubehör'), ('consumable','Verbrauchsmaterial'), ('course_material','Kursmaterial')
) AS v(code, name)
WHERE t.slug = 'tsk-zrh'
ON CONFLICT (tenant_id, code) DO NOTHING;

COMMIT;
