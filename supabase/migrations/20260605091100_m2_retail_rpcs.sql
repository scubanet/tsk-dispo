-- 20260605091100_m2_retail_rpcs.sql
-- Phase-2 / M2 — Retail-RPCs + Verkaufs-Integration in den POS-Checkout.
--
-- inventory_adjust : manuelle Bestandskorrektur.
-- po_receive       : Wareneingang → Bestand + optional Seriennummern.
-- pos_fulfill      : Bestandsabgang für Produkt-Positionen einer Order (intern).
-- pos_checkout     : neu definiert — bucht nach invoice_issue den Lagerabgang und
--                    markiert verkaufte Seriennummern. Rückwärtskompatibel: Nicht-
--                    Produkt-Positionen (Kurse/Gebühren) bleiben unberührt.

BEGIN;

-- ── Manuelle Bestandskorrektur ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.inventory_adjust(
  p_variant_id UUID,
  p_qty        NUMERIC,
  p_reason     TEXT DEFAULT 'adjustment',
  p_note       TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_tenant UUID;
  v_id     UUID;
  v_actor  UUID;
BEGIN
  IF NOT (public.is_dispatcher() OR public.is_owner()) THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;
  IF p_qty = 0 THEN RAISE EXCEPTION 'qty_must_be_nonzero'; END IF;

  SELECT tenant_id INTO v_tenant FROM public.product_variants WHERE id = p_variant_id;
  IF v_tenant IS NULL THEN RAISE EXCEPTION 'variant_not_found'; END IF;
  IF v_tenant <> public.current_tenant_id() THEN
    RAISE EXCEPTION 'wrong_tenant' USING ERRCODE = '42501';
  END IF;

  v_actor := (SELECT contact_id FROM public.contact_instructor WHERE auth_user_id = auth.uid() LIMIT 1);

  INSERT INTO public.inventory_movements (tenant_id, variant_id, qty, reason, ref_type, note, created_by)
  VALUES (v_tenant, p_variant_id, p_qty, p_reason, 'manual', p_note, v_actor)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

-- ── Wareneingang ──────────────────────────────────────────────────────────────
-- p_serials (optional): [{ "variant_id": "...", "serial_no": "..." }, ...]
CREATE OR REPLACE FUNCTION public.po_receive(
  p_po_id   UUID,
  p_serials JSONB DEFAULT '[]'
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_tenant UUID;
  v_status TEXT;
  v_actor  UUID;
  r        RECORD;
  s        JSONB;
BEGIN
  IF NOT (public.is_dispatcher() OR public.is_owner()) THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;

  SELECT tenant_id, status INTO v_tenant, v_status FROM public.purchase_orders WHERE id = p_po_id;
  IF v_tenant IS NULL THEN RAISE EXCEPTION 'po_not_found'; END IF;
  IF v_tenant <> public.current_tenant_id() THEN
    RAISE EXCEPTION 'wrong_tenant' USING ERRCODE = '42501';
  END IF;
  IF v_status = 'received' THEN RAISE EXCEPTION 'po_already_received'; END IF;

  v_actor := (SELECT contact_id FROM public.contact_instructor WHERE auth_user_id = auth.uid() LIMIT 1);

  FOR r IN SELECT variant_id, qty FROM public.purchase_order_lines WHERE po_id = p_po_id LOOP
    INSERT INTO public.inventory_movements (tenant_id, variant_id, qty, reason, ref_type, ref_id, created_by)
    VALUES (v_tenant, r.variant_id, abs(r.qty), 'receipt', 'purchase_order', p_po_id, v_actor);
  END LOOP;

  IF p_serials IS NOT NULL AND jsonb_typeof(p_serials) = 'array' THEN
    FOR s IN SELECT * FROM jsonb_array_elements(p_serials) LOOP
      INSERT INTO public.serial_units (tenant_id, variant_id, serial_no, status)
      VALUES (v_tenant, (s->>'variant_id')::uuid, s->>'serial_no', 'in_stock')
      ON CONFLICT (tenant_id, serial_no) DO NOTHING;
    END LOOP;
  END IF;

  UPDATE public.purchase_orders SET status = 'received' WHERE id = p_po_id;
END;
$$;

-- ── Verkaufs-Fulfillment (intern; bucht Lagerabgang für Produkt-Positionen) ────
CREATE OR REPLACE FUNCTION public.pos_fulfill(p_order_id UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_tenant  UUID;
  v_contact UUID;
  v_actor   UUID;
  r         RECORD;
BEGIN
  SELECT tenant_id, contact_id INTO v_tenant, v_contact FROM public.orders WHERE id = p_order_id;
  IF v_tenant IS NULL THEN RAISE EXCEPTION 'order_not_found'; END IF;
  v_actor := (SELECT contact_id FROM public.contact_instructor WHERE auth_user_id = auth.uid() LIMIT 1);

  -- Lagerabgang nur für Produkt-Positionen mit gültiger Variante.
  FOR r IN
    SELECT ol.item_ref_id AS variant_id, ol.quantity
    FROM public.order_lines ol
    JOIN public.product_variants v ON v.id = ol.item_ref_id
    WHERE ol.order_id = p_order_id AND ol.item_type = 'product'
  LOOP
    INSERT INTO public.inventory_movements (tenant_id, variant_id, qty, reason, ref_type, ref_id, created_by)
    VALUES (v_tenant, r.variant_id, -abs(r.quantity), 'sale', 'order', p_order_id, v_actor);
  END LOOP;

  -- Verkaufte Seriennummern als 'sold' markieren.
  UPDATE public.serial_units su
     SET status = 'sold', sold_to_contact_id = v_contact, sold_at = now()
    FROM public.order_line_serials ols
    JOIN public.order_lines ol ON ol.id = ols.order_line_id
   WHERE ols.serial_unit_id = su.id AND ol.order_id = p_order_id;
END;
$$;

-- ── POS-Checkout NEU: + Seriennummern-Erfassung + Lagerabgang ─────────────────
-- p_lines-Position zusätzlich optional: "serial_unit_id" für serialisierte Produkte.
CREATE OR REPLACE FUNCTION public.pos_checkout(
  p_contact_id UUID,
  p_lines      JSONB,
  p_method     TEXT DEFAULT 'cash',
  p_pay        BOOLEAN DEFAULT true
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_tenant   UUID := public.current_tenant_id();
  v_currency CHAR(3);
  v_order    UUID;
  v_invoice  UUID;
  v_total    NUMERIC;
  v_actor    UUID;
  v_line     JSONB;
  v_line_id  UUID;
BEGIN
  IF NOT (public.is_dispatcher() OR public.is_owner()) THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;
  IF v_tenant IS NULL THEN RAISE EXCEPTION 'no_tenant' USING ERRCODE = '42501'; END IF;
  IF p_lines IS NULL OR jsonb_typeof(p_lines) <> 'array' OR jsonb_array_length(p_lines) = 0 THEN
    RAISE EXCEPTION 'no_lines';
  END IF;

  SELECT default_currency INTO v_currency FROM public.tenants WHERE id = v_tenant;
  v_actor := (SELECT contact_id FROM public.contact_instructor WHERE auth_user_id = auth.uid() LIMIT 1);

  INSERT INTO public.orders (tenant_id, contact_id, status, channel, currency, created_by)
  VALUES (v_tenant, p_contact_id, 'draft', 'pos', COALESCE(v_currency, 'CHF'), v_actor)
  RETURNING id INTO v_order;

  FOR v_line IN SELECT * FROM jsonb_array_elements(p_lines) LOOP
    INSERT INTO public.order_lines
      (tenant_id, order_id, item_type, item_ref_id, description, quantity, unit_price, discount_pct, tax_rate_id)
    VALUES
      (v_tenant, v_order,
       COALESCE(v_line->>'item_type', 'custom'),
       NULLIF(v_line->>'item_ref_id', '')::uuid,
       COALESCE(v_line->>'description', 'Position'),
       COALESCE((v_line->>'quantity')::numeric, 1),
       COALESCE((v_line->>'unit_price')::numeric, 0),
       COALESCE((v_line->>'discount_pct')::numeric, 0),
       NULLIF(v_line->>'tax_rate_id', '')::uuid)
    RETURNING id INTO v_line_id;

    -- Serialisierte Verkaufsposition mit Einzelstück verknüpfen.
    IF NULLIF(v_line->>'serial_unit_id', '') IS NOT NULL THEN
      INSERT INTO public.order_line_serials (tenant_id, order_line_id, serial_unit_id)
      VALUES (v_tenant, v_line_id, (v_line->>'serial_unit_id')::uuid);
    END IF;
  END LOOP;

  v_invoice := public.invoice_issue(v_order);   -- recalc + Nummer + Snapshot
  PERFORM public.pos_fulfill(v_order);          -- Lagerabgang + Seriennummern

  IF p_pay THEN
    SELECT total INTO v_total FROM public.invoices WHERE id = v_invoice;
    IF v_total > 0 THEN
      PERFORM public.payment_record(v_invoice, p_method, v_total);
    END IF;
  END IF;

  RETURN jsonb_build_object('order_id', v_order, 'invoice_id', v_invoice);
END;
$$;

-- ── Grants ────────────────────────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.inventory_adjust(UUID, NUMERIC, TEXT, TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.po_receive(UUID, JSONB)                     FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.pos_fulfill(UUID)                           FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.inventory_adjust(UUID, NUMERIC, TEXT, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.po_receive(UUID, JSONB)                     TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.pos_fulfill(UUID)                           TO service_role;  -- nur intern (via pos_checkout)

COMMIT;
