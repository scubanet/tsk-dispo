-- 20260605090300_payments_journal.sql
-- Phase-1 — Schritt 4: Zahlungs-Journal (unveränderlich).
--
-- Folgt exakt dem account_movements-Muster (0012): unveränderliches Journal,
-- block_*_update()-Trigger, Saldo nie gespeichert sondern als SUM() berechnet.
-- Beträge sind VORZEICHENBEHAFTET (Erstattung negativ). Zeilen werden in ihrem
-- Endzustand geschrieben (Back-office: 'settled'; PSP-Webhook fügt erst bei
-- payment_intent.succeeded eine 'settled'-Zeile ein) — daher braucht es kein
-- pending→settled-UPDATE und die Immutabilität bleibt sauber.

BEGIN;

CREATE TABLE public.payments (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  contact_id   UUID NOT NULL REFERENCES public.contacts(id) ON DELETE RESTRICT,
  invoice_id   UUID REFERENCES public.invoices(id) ON DELETE SET NULL,
  kind         payment_kind NOT NULL DEFAULT 'payment',
  method       TEXT NOT NULL CHECK (method IN ('cash','card','twint','bank','store_credit','gift_card','package')),
  amount       NUMERIC(12,2) NOT NULL,            -- signiert: Erstattung negativ
  currency     CHAR(3) NOT NULL DEFAULT 'CHF',
  provider     TEXT,
  provider_ref TEXT,
  status       TEXT NOT NULL DEFAULT 'settled' CHECK (status IN ('pending','settled','failed')),
  received_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by   UUID,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (amount <> 0)
);

COMMENT ON TABLE public.payments IS
  'Unveränderliches Zahlungs-Journal. Rechnungs-Saldo = invoice.total − SUM(amount WHERE status=settled). Korrektur/Storno = neue Zeile (kind=refund/adjustment).';

CREATE INDEX idx_payments_invoice        ON public.payments(invoice_id);
CREATE INDEX idx_payments_tenant_contact ON public.payments(tenant_id, contact_id);
-- Idempotenz gegen Webhook-Retries: ein Provider-Beleg nur einmal pro Tenant.
CREATE UNIQUE INDEX uq_payments_provider_ref
  ON public.payments(tenant_id, provider_ref)
  WHERE provider_ref IS NOT NULL;

-- Immutabilität (Muster account_movements 0012): UPDATE blockiert, Korrektur = neue Zeile.
CREATE OR REPLACE FUNCTION public.block_payments_update()
RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION 'payments rows are immutable. Insert a refund/adjustment row instead.';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_block_payments_update
  BEFORE UPDATE ON public.payments
  FOR EACH ROW EXECUTE FUNCTION public.block_payments_update();

-- Audit (FK-loses Log aus Schritt 3); UPDATE feuert nie, weil oben geblockt.
CREATE TRIGGER trg_audit_payments
  AFTER INSERT OR DELETE ON public.payments
  FOR EACH ROW EXECUTE FUNCTION public.audit_finance_changes();

-- ── RLS ───────────────────────────────────────────────────────────────────────
-- SELECT: eigener Mandant. KEINE direkte INSERT/UPDATE/DELETE-Policy — Zahlungen
-- werden ausschließlich über payment_record()/payment_refund() (SECURITY DEFINER)
-- geschrieben, damit Status-Neuberechnung + Timeline garantiert sind.
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
CREATE POLICY payments_select ON public.payments
  FOR SELECT TO authenticated
  USING (tenant_id = public.current_tenant_id());

-- ── Saldo-View (RLS des Aufrufers gilt dank security_invoker) ──────────────────
CREATE VIEW public.v_invoice_balance
  WITH (security_invoker = true) AS
SELECT i.id         AS invoice_id,
       i.tenant_id,
       i.contact_id,
       i.total,
       COALESCE(SUM(p.amount) FILTER (WHERE p.status = 'settled'), 0)            AS paid,
       i.total - COALESCE(SUM(p.amount) FILTER (WHERE p.status = 'settled'), 0)  AS balance
FROM public.invoices i
LEFT JOIN public.payments p ON p.invoice_id = i.id
GROUP BY i.id, i.tenant_id, i.contact_id, i.total;

COMMENT ON VIEW public.v_invoice_balance IS
  'Offener Rechnungssaldo = total − Summe der gebuchten Zahlungen.';

COMMIT;
