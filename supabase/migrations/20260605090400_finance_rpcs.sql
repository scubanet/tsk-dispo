-- 20260605090400_finance_rpcs.sql
-- Phase-1 — Schritt 5: Finanz-RPCs (transaktionale, geld-kritische Operationen).
--
-- Konvention: SECURITY DEFINER + Authz-Guard (is_dispatcher() OR is_owner())
-- + Tenant-Check (Entität gehört current_tenant_id()). Schreibende Operationen
-- laufen über diese RPCs (apps/web ruft sie via supabase.rpc()), nicht über
-- direkte Tabellen-Writes — so sind Nummernkreis, Summen, Status-Neuberechnung
-- und Timeline-Events garantiert. Timeline: contact_events (CHECK erweitert).

BEGIN;

-- ── contact_events: Finanz-Eventtypen ergänzen (Muster 0121) ───────────────────
ALTER TABLE public.contact_events
  DROP CONSTRAINT IF EXISTS contact_events_event_type_check;
ALTER TABLE public.contact_events
  ADD CONSTRAINT contact_events_event_type_check CHECK (event_type IN (
    'note', 'call', 'email_external', 'meeting_past', 'task',
    'whatsapp_log', 'linkedin_message',
    'invoice_issued', 'payment_received', 'payment_refunded'
  ));

-- ════════════════════════════════════════════════════════════════════
-- order_recalc: Positions- und Kopfsummen neu berechnen
-- ════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.order_recalc(p_order_id UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tenant UUID;
BEGIN
  IF NOT (public.is_dispatcher() OR public.is_owner()) THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;

  SELECT tenant_id INTO v_tenant FROM public.orders WHERE id = p_order_id;
  IF v_tenant IS NULL THEN RAISE EXCEPTION 'order_not_found'; END IF;
  IF v_tenant <> public.current_tenant_id() THEN
    RAISE EXCEPTION 'wrong_tenant' USING ERRCODE = '42501';
  END IF;

  -- Positionswerte (Netto, MwSt, Brutto) je Zeile
  WITH calc AS (
    SELECT ol.id,
           round(ol.quantity * ol.unit_price * (1 - ol.discount_pct / 100.0), 2) AS sub,
           COALESCE(tr.rate_pct, 0) AS rate
    FROM public.order_lines ol
    LEFT JOIN public.tax_rates tr ON tr.id = ol.tax_rate_id
    WHERE ol.order_id = p_order_id
  )
  UPDATE public.order_lines ol
     SET line_subtotal = c.sub,
         line_tax      = round(c.sub * c.rate / 100.0, 2),
         line_total    = c.sub + round(c.sub * c.rate / 100.0, 2)
    FROM calc c
   WHERE ol.id = c.id;

  -- Kopfsummen
  UPDATE public.orders o
     SET subtotal       = COALESCE((SELECT SUM(line_subtotal) FROM public.order_lines WHERE order_id = o.id), 0),
         tax_total      = COALESCE((SELECT SUM(line_tax)      FROM public.order_lines WHERE order_id = o.id), 0),
         grand_total    = COALESCE((SELECT SUM(line_total)    FROM public.order_lines WHERE order_id = o.id), 0),
         discount_total = COALESCE((SELECT SUM(round(quantity * unit_price * (discount_pct / 100.0), 2))
                                    FROM public.order_lines WHERE order_id = o.id), 0)
   WHERE o.id = p_order_id;
END;
$$;

-- ════════════════════════════════════════════════════════════════════
-- _recompute_invoice_status: intern, setzt invoice/order-Status aus Zahlungen
-- ════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public._recompute_invoice_status(p_invoice_id UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total  NUMERIC;
  v_paid   NUMERIC;
  v_status TEXT;
  v_order  UUID;
BEGIN
  SELECT total, order_id INTO v_total, v_order FROM public.invoices WHERE id = p_invoice_id;
  SELECT COALESCE(SUM(amount), 0) INTO v_paid
    FROM public.payments WHERE invoice_id = p_invoice_id AND status = 'settled';

  IF v_paid >= v_total AND v_total > 0 THEN
    v_status := 'paid';
  ELSIF v_paid > 0 THEN
    v_status := 'partially_paid';
  ELSE
    v_status := 'issued';
  END IF;

  UPDATE public.invoices
     SET status = v_status
   WHERE id = p_invoice_id AND status NOT IN ('void', 'credited');

  IF v_order IS NOT NULL THEN
    UPDATE public.orders
       SET status = CASE
                      WHEN v_status = 'paid'           THEN 'paid'
                      WHEN v_status = 'partially_paid' THEN 'partially_paid'
                      ELSE status
                    END
     WHERE id = v_order;
  END IF;
END;
$$;

-- ════════════════════════════════════════════════════════════════════
-- invoice_issue: Rechnung aus Auftrag erstellen (Nummer + Positions-Snapshot)
-- ════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.invoice_issue(p_order_id UUID)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tenant   UUID;
  v_contact  UUID;
  v_currency CHAR(3);
  v_status   TEXT;
  v_terms    INT;
  v_number   TEXT;
  v_invoice  UUID;
  v_actor    UUID;
  v_sub      NUMERIC;
  v_tax      NUMERIC;
  v_total    NUMERIC;
BEGIN
  IF NOT (public.is_dispatcher() OR public.is_owner()) THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;

  SELECT tenant_id, contact_id, currency, status
    INTO v_tenant, v_contact, v_currency, v_status
    FROM public.orders WHERE id = p_order_id;
  IF v_tenant IS NULL THEN RAISE EXCEPTION 'order_not_found'; END IF;
  IF v_tenant <> public.current_tenant_id() THEN
    RAISE EXCEPTION 'wrong_tenant' USING ERRCODE = '42501';
  END IF;
  IF v_status NOT IN ('draft', 'open') THEN
    RAISE EXCEPTION 'order_not_issuable (status=%)', v_status;
  END IF;

  PERFORM public.order_recalc(p_order_id);
  SELECT subtotal, tax_total, grand_total INTO v_sub, v_tax, v_total
    FROM public.orders WHERE id = p_order_id;

  SELECT COALESCE(payment_terms_days, 0) INTO v_terms
    FROM public.contact_billing WHERE contact_id = v_contact;
  v_terms := COALESCE(v_terms, 0);

  v_number := public.next_invoice_number(v_tenant);
  v_actor  := (SELECT contact_id FROM public.contact_instructor WHERE auth_user_id = auth.uid() LIMIT 1);

  INSERT INTO public.invoices
    (tenant_id, contact_id, order_id, number, status, issue_date, due_date,
     currency, subtotal, tax_total, total, created_by)
  VALUES
    (v_tenant, v_contact, p_order_id, v_number, 'issued', current_date, current_date + v_terms,
     v_currency, v_sub, v_tax, v_total, v_actor)
  RETURNING id INTO v_invoice;

  INSERT INTO public.invoice_lines
    (tenant_id, invoice_id, description, quantity, unit_price, discount_pct,
     tax_rate_pct, line_subtotal, line_tax, line_total)
  SELECT v_tenant, v_invoice, ol.description, ol.quantity, ol.unit_price, ol.discount_pct,
         COALESCE(tr.rate_pct, 0), ol.line_subtotal, ol.line_tax, ol.line_total
  FROM public.order_lines ol
  LEFT JOIN public.tax_rates tr ON tr.id = ol.tax_rate_id
  WHERE ol.order_id = p_order_id;

  UPDATE public.orders SET status = 'open' WHERE id = p_order_id;

  INSERT INTO public.contact_events (contact_id, event_type, summary, payload, actor_id)
  VALUES (v_contact, 'invoice_issued',
          'Rechnung ' || v_number || ' gestellt',
          jsonb_build_object('invoice_id', v_invoice, 'total', v_total, 'currency', v_currency),
          v_actor);

  RETURN v_invoice;
END;
$$;

-- ════════════════════════════════════════════════════════════════════
-- payment_record: Zahlung buchen (unveränderlich) + Status + Timeline
-- ════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.payment_record(
  p_invoice_id  UUID,
  p_method      TEXT,
  p_amount      NUMERIC,
  p_provider    TEXT DEFAULT NULL,
  p_provider_ref TEXT DEFAULT NULL,
  p_received_at TIMESTAMPTZ DEFAULT now()
)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tenant   UUID;
  v_contact  UUID;
  v_currency CHAR(3);
  v_payment  UUID;
  v_actor    UUID;
BEGIN
  IF NOT (public.is_dispatcher() OR public.is_owner()) THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;
  IF p_amount <= 0 THEN RAISE EXCEPTION 'amount_must_be_positive'; END IF;

  SELECT tenant_id, contact_id, currency INTO v_tenant, v_contact, v_currency
    FROM public.invoices WHERE id = p_invoice_id;
  IF v_tenant IS NULL THEN RAISE EXCEPTION 'invoice_not_found'; END IF;
  IF v_tenant <> public.current_tenant_id() THEN
    RAISE EXCEPTION 'wrong_tenant' USING ERRCODE = '42501';
  END IF;

  v_actor := (SELECT contact_id FROM public.contact_instructor WHERE auth_user_id = auth.uid() LIMIT 1);

  INSERT INTO public.payments
    (tenant_id, contact_id, invoice_id, kind, method, amount, currency,
     provider, provider_ref, status, received_at, created_by)
  VALUES
    (v_tenant, v_contact, p_invoice_id, 'payment', p_method, p_amount, v_currency,
     p_provider, p_provider_ref, 'settled', p_received_at, v_actor)
  RETURNING id INTO v_payment;

  PERFORM public._recompute_invoice_status(p_invoice_id);

  INSERT INTO public.contact_events (contact_id, event_type, summary, payload, actor_id, occurred_at)
  VALUES (v_contact, 'payment_received',
          'Zahlung ' || p_amount::text || ' ' || v_currency || ' erhalten',
          jsonb_build_object('payment_id', v_payment, 'invoice_id', p_invoice_id,
                             'amount', p_amount, 'method', p_method),
          v_actor, p_received_at);

  RETURN v_payment;
END;
$$;

-- ════════════════════════════════════════════════════════════════════
-- payment_refund: Erstattung (neue negative Zeile) + Status + Timeline
-- (Store-Credit-Variante folgt mit packages_and_credit in Schritt 6)
-- ════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.payment_refund(
  p_invoice_id UUID,
  p_amount     NUMERIC,
  p_method     TEXT DEFAULT 'bank'
)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tenant   UUID;
  v_contact  UUID;
  v_currency CHAR(3);
  v_payment  UUID;
  v_actor    UUID;
  v_net      NUMERIC;
BEGIN
  IF NOT (public.is_dispatcher() OR public.is_owner()) THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;
  IF p_amount <= 0 THEN RAISE EXCEPTION 'amount_must_be_positive'; END IF;

  SELECT tenant_id, contact_id, currency INTO v_tenant, v_contact, v_currency
    FROM public.invoices WHERE id = p_invoice_id;
  IF v_tenant IS NULL THEN RAISE EXCEPTION 'invoice_not_found'; END IF;
  IF v_tenant <> public.current_tenant_id() THEN
    RAISE EXCEPTION 'wrong_tenant' USING ERRCODE = '42501';
  END IF;

  v_actor := (SELECT contact_id FROM public.contact_instructor WHERE auth_user_id = auth.uid() LIMIT 1);

  INSERT INTO public.payments
    (tenant_id, contact_id, invoice_id, kind, method, amount, currency, status, received_at, created_by)
  VALUES
    (v_tenant, v_contact, p_invoice_id, 'refund', p_method, -abs(p_amount), v_currency, 'settled', now(), v_actor)
  RETURNING id INTO v_payment;

  PERFORM public._recompute_invoice_status(p_invoice_id);

  -- Bei Voll-Erstattung (netto ≤ 0) Rechnung als 'credited' markieren.
  SELECT COALESCE(SUM(amount), 0) INTO v_net
    FROM public.payments WHERE invoice_id = p_invoice_id AND status = 'settled';
  IF v_net <= 0 THEN
    UPDATE public.invoices SET status = 'credited' WHERE id = p_invoice_id;
  END IF;

  INSERT INTO public.contact_events (contact_id, event_type, summary, payload, actor_id)
  VALUES (v_contact, 'payment_refunded',
          'Erstattung ' || p_amount::text || ' ' || v_currency,
          jsonb_build_object('payment_id', v_payment, 'invoice_id', p_invoice_id, 'amount', -abs(p_amount)),
          v_actor);

  RETURN v_payment;
END;
$$;

-- ── Grants: öffentliche RPCs für authenticated; interner Helper nur service_role ──
REVOKE ALL ON FUNCTION public.order_recalc(UUID)                                   FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.invoice_issue(UUID)                                  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.payment_record(UUID, TEXT, NUMERIC, TEXT, TEXT, TIMESTAMPTZ) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.payment_refund(UUID, NUMERIC, TEXT)                  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public._recompute_invoice_status(UUID)                      FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.order_recalc(UUID)                                   TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.invoice_issue(UUID)                                  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.payment_record(UUID, TEXT, NUMERIC, TEXT, TEXT, TIMESTAMPTZ) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.payment_refund(UUID, NUMERIC, TEXT)                  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public._recompute_invoice_status(UUID)                      TO service_role;

COMMIT;
