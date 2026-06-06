-- 20260605090700_payment_record_service.sql
-- Phase-1 — Schritt 8a: service-role-only Zahlungs-RPC für Webhooks.
--
-- payment_record() (Schritt 5) hat einen User-Guard (is_dispatcher() OR is_owner()),
-- den der Stripe-Webhook nicht passieren kann (kein User-JWT → auth.uid() NULL).
-- Diese Variante hat KEINEN User-Guard, ist aber NUR an service_role granted
-- (REVOKE von authenticated/anon) — also ausschließlich aus Edge Functions mit
-- Service-Role-Key aufrufbar. Idempotent über provider_ref (zusätzlich zum
-- Unique-Index uq_payments_provider_ref), damit Webhook-Retries nicht doppelt buchen.

BEGIN;

CREATE OR REPLACE FUNCTION public.payment_record_service(
  p_invoice_id   UUID,
  p_method       TEXT,
  p_amount       NUMERIC,
  p_provider     TEXT DEFAULT NULL,
  p_provider_ref TEXT DEFAULT NULL,
  p_received_at  TIMESTAMPTZ DEFAULT now()
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
BEGIN
  IF p_amount <= 0 THEN RAISE EXCEPTION 'amount_must_be_positive'; END IF;

  SELECT tenant_id, contact_id, currency INTO v_tenant, v_contact, v_currency
    FROM public.invoices WHERE id = p_invoice_id;
  IF v_tenant IS NULL THEN RAISE EXCEPTION 'invoice_not_found'; END IF;

  -- Idempotenz: Zahlung mit diesem provider_ref existiert bereits → zurückgeben.
  IF p_provider_ref IS NOT NULL THEN
    SELECT id INTO v_payment
      FROM public.payments
     WHERE tenant_id = v_tenant AND provider_ref = p_provider_ref;
    IF v_payment IS NOT NULL THEN
      RETURN v_payment;
    END IF;
  END IF;

  INSERT INTO public.payments
    (tenant_id, contact_id, invoice_id, kind, method, amount, currency,
     provider, provider_ref, status, received_at)
  VALUES
    (v_tenant, v_contact, p_invoice_id, 'payment', p_method, p_amount, v_currency,
     p_provider, p_provider_ref, 'settled', p_received_at)
  RETURNING id INTO v_payment;

  PERFORM public._recompute_invoice_status(p_invoice_id);

  INSERT INTO public.contact_events (contact_id, event_type, summary, payload, occurred_at)
  VALUES (v_contact, 'payment_received',
          'Zahlung ' || p_amount::text || ' ' || v_currency || ' (' || COALESCE(p_provider, p_method) || ')',
          jsonb_build_object('payment_id', v_payment, 'invoice_id', p_invoice_id,
                             'amount', p_amount, 'method', p_method, 'provider', p_provider),
          p_received_at);

  RETURN v_payment;
END;
$$;

-- Nur Service-Role (Edge Functions). Keine End-User.
REVOKE ALL ON FUNCTION public.payment_record_service(UUID, TEXT, NUMERIC, TEXT, TEXT, TIMESTAMPTZ)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.payment_record_service(UUID, TEXT, NUMERIC, TEXT, TEXT, TIMESTAMPTZ)
  TO service_role;

COMMIT;
