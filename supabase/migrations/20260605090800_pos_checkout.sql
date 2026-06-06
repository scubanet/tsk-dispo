-- 20260605090800_pos_checkout.sql
-- Phase-1 — Schritt 8b: POS-Checkout-RPC (eine atomare Operation fürs Frontend).
--
-- Das Frontend kennt die tenant_id nicht (current_tenant_id() ist server-seitig).
-- pos_checkout() kapselt den ganzen Verkauf server-seitig: Order anlegen
-- (tenant aus current_tenant_id()), Positionen aus p_lines (jsonb-Array) einfügen,
-- invoice_issue() (recalc + Nummer + Snapshot), optional payment_record() für den
-- Vollbetrag. Komponiert die bestehenden RPCs; deren is_dispatcher/is_owner-Guards
-- greifen weiterhin (Aufruf durch eingeloggten Dispatcher/CD).
--
-- p_lines: [{ "description": "...", "quantity": 1, "unit_price": 80,
--             "discount_pct": 0, "tax_rate_id": "<uuid|null>", "item_type": "custom" }, ...]

BEGIN;

CREATE OR REPLACE FUNCTION public.pos_checkout(
  p_contact_id UUID,
  p_lines      JSONB,
  p_method     TEXT DEFAULT 'cash',
  p_pay        BOOLEAN DEFAULT true
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tenant   UUID := public.current_tenant_id();
  v_currency CHAR(3);
  v_order    UUID;
  v_invoice  UUID;
  v_total    NUMERIC;
  v_actor    UUID;
  v_line     JSONB;
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
      (tenant_id, order_id, item_type, description, quantity, unit_price, discount_pct, tax_rate_id)
    VALUES
      (v_tenant, v_order,
       COALESCE(v_line->>'item_type', 'custom'),
       COALESCE(v_line->>'description', 'Position'),
       COALESCE((v_line->>'quantity')::numeric, 1),
       COALESCE((v_line->>'unit_price')::numeric, 0),
       COALESCE((v_line->>'discount_pct')::numeric, 0),
       NULLIF(v_line->>'tax_rate_id', '')::uuid);
  END LOOP;

  v_invoice := public.invoice_issue(v_order);   -- recalc + Nummer + Positions-Snapshot

  IF p_pay THEN
    SELECT total INTO v_total FROM public.invoices WHERE id = v_invoice;
    IF v_total > 0 THEN
      PERFORM public.payment_record(v_invoice, p_method, v_total);
    END IF;
  END IF;

  RETURN jsonb_build_object('order_id', v_order, 'invoice_id', v_invoice);
END;
$$;

REVOKE ALL ON FUNCTION public.pos_checkout(UUID, JSONB, TEXT, BOOLEAN) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pos_checkout(UUID, JSONB, TEXT, BOOLEAN) TO authenticated, service_role;

COMMIT;
