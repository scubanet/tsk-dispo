-- 20260605090500_packages_and_credit.sql
-- Phase-1 — Schritt 6: Pakete/Air-Cards, Store-Credit, Gutscheine.
--
-- Prepaid-Werte als unveränderliche Einlöse-/Guthaben-Journale (Muster payments/
-- account_movements): package_redemptions und store_credit_entries sind immutabel,
-- Saldo = units_total − SUM(redemptions) bzw. SUM(amount). Schreiben nur über
-- SECURITY-DEFINER-RPCs. tenant-scoped RLS. Decken: 10er-Tauchpaket, Air-Card/
-- Füllkarte, Kursbundle (package_*), Store-Credit/Erstattungsguthaben
-- (store_credit_entries) und Gutscheine (gift_cards).

BEGIN;

-- ════════════════════════════════════════════════════════════════════
-- 1. Paket-Katalog (Definition)
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE public.package_products (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  name            TEXT NOT NULL,
  kind            TEXT NOT NULL CHECK (kind IN ('dive_pack','air_card','course_bundle','value_credit')),
  unit_type       TEXT NOT NULL CHECK (unit_type IN ('dive','fill','currency','course')),
  units_total     NUMERIC(10,2) NOT NULL CHECK (units_total > 0),
  price           NUMERIC(12,2) NOT NULL CHECK (price >= 0),
  currency        CHAR(3) NOT NULL DEFAULT 'CHF',
  validity_months INT,                          -- NULL = unbegrenzt gültig
  tax_rate_id     UUID REFERENCES public.tax_rates(id) ON DELETE SET NULL,
  is_active       BOOLEAN NOT NULL DEFAULT true,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.package_products IS '10er-Tauchpaket / Air-Card / Kursbundle / Wertguthaben (Definition).';
CREATE INDEX idx_package_products_tenant ON public.package_products(tenant_id, is_active);

-- ════════════════════════════════════════════════════════════════════
-- 2. Paket-Kauf (Instanz pro Kunde)
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE public.package_purchases (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id           UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  contact_id          UUID NOT NULL REFERENCES public.contacts(id) ON DELETE RESTRICT,
  package_product_id  UUID REFERENCES public.package_products(id) ON DELETE SET NULL,
  order_id            UUID REFERENCES public.orders(id) ON DELETE SET NULL,
  units_total         NUMERIC(10,2) NOT NULL CHECK (units_total > 0),
  purchased_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at          DATE,
  created_by          UUID,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.package_purchases IS 'Vom Kunden gekauftes Paket. Rest = units_total − SUM(package_redemptions.units).';
CREATE INDEX idx_package_purchases_contact ON public.package_purchases(tenant_id, contact_id);

-- ════════════════════════════════════════════════════════════════════
-- 3. Paket-Einlösung (UNVERÄNDERLICHES Journal)
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE public.package_redemptions (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id           UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  package_purchase_id UUID NOT NULL REFERENCES public.package_purchases(id) ON DELETE CASCADE,
  units               NUMERIC(10,2) NOT NULL CHECK (units > 0),   -- Verbrauch (positiv)
  ref_type            TEXT,                                       -- z. B. 'trip_booking', 'fill'
  ref_id              UUID,
  redeemed_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by          UUID,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.package_redemptions IS 'Unveränderliches Einlöse-Journal. Korrektur = neue Zeile.';
CREATE INDEX idx_package_redemptions_purchase ON public.package_redemptions(package_purchase_id);

CREATE OR REPLACE FUNCTION public.block_package_redemption_update()
RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION 'package_redemptions rows are immutable. Insert a correction row instead.';
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_block_package_redemption_update
  BEFORE UPDATE ON public.package_redemptions
  FOR EACH ROW EXECUTE FUNCTION public.block_package_redemption_update();

-- ════════════════════════════════════════════════════════════════════
-- 4. Store-Credit (UNVERÄNDERLICHES Geld-Guthaben-Journal pro Kunde)
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE public.store_credit_entries (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  contact_id  UUID NOT NULL REFERENCES public.contacts(id) ON DELETE RESTRICT,
  amount      NUMERIC(12,2) NOT NULL CHECK (amount <> 0),   -- signiert: +Aufladung / −Verbrauch
  currency    CHAR(3) NOT NULL DEFAULT 'CHF',
  reason      TEXT NOT NULL CHECK (reason IN ('refund','goodwill','gift','redeem','purchase','adjustment')),
  ref_type    TEXT,
  ref_id      UUID,
  created_by  UUID,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.store_credit_entries IS 'Unveränderliches Store-Credit-Journal. Guthaben = SUM(amount) je Kontakt.';
CREATE INDEX idx_store_credit_contact ON public.store_credit_entries(tenant_id, contact_id);

CREATE OR REPLACE FUNCTION public.block_store_credit_update()
RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION 'store_credit_entries rows are immutable. Insert a correction row instead.';
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_block_store_credit_update
  BEFORE UPDATE ON public.store_credit_entries
  FOR EACH ROW EXECUTE FUNCTION public.block_store_credit_update();

-- ════════════════════════════════════════════════════════════════════
-- 5. Gutscheine
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE public.gift_cards (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id           UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  code                TEXT NOT NULL,
  initial_amount      NUMERIC(12,2) NOT NULL CHECK (initial_amount > 0),
  currency            CHAR(3) NOT NULL DEFAULT 'CHF',
  issued_to_contact_id UUID REFERENCES public.contacts(id) ON DELETE SET NULL,
  expires_at          DATE,
  status              TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','spent','void')),
  created_by          UUID,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.gift_cards IS 'Gutschein. Einlösung lädt den Wert als Store-Credit auf den Kunden und setzt status=spent.';
CREATE UNIQUE INDEX uq_gift_cards_code ON public.gift_cards(tenant_id, code);

-- ════════════════════════════════════════════════════════════════════
-- 6. updated_at- + Audit-Trigger
-- ════════════════════════════════════════════════════════════════════
CREATE TRIGGER trg_package_products_updated_at
  BEFORE UPDATE ON public.package_products
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_package_purchases_updated_at
  BEFORE UPDATE ON public.package_purchases
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_gift_cards_updated_at
  BEFORE UPDATE ON public.gift_cards
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_audit_package_purchases
  AFTER INSERT OR UPDATE OR DELETE ON public.package_purchases
  FOR EACH ROW EXECUTE FUNCTION public.audit_finance_changes();
CREATE TRIGGER trg_audit_gift_cards
  AFTER INSERT OR UPDATE OR DELETE ON public.gift_cards
  FOR EACH ROW EXECUTE FUNCTION public.audit_finance_changes();

-- ════════════════════════════════════════════════════════════════════
-- 7. RLS — Kataloge/Werte beschreibbar (dispatcher/owner), Journale nur lesbar
-- ════════════════════════════════════════════════════════════════════
DO $$
DECLARE
  t   text;
  sel text := '(tenant_id = public.current_tenant_id())';
  wr  text := '(tenant_id = public.current_tenant_id() AND (public.is_dispatcher() OR public.is_owner()))';
BEGIN
  FOREACH t IN ARRAY ARRAY['package_products','package_purchases','gift_cards'] LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;', t);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR SELECT TO authenticated USING %s;',  t||'_select', t, sel);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR INSERT TO authenticated WITH CHECK %s;', t||'_insert', t, wr);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR UPDATE TO authenticated USING %s WITH CHECK %s;', t||'_update', t, wr, wr);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR DELETE TO authenticated USING %s;', t||'_delete', t, wr);
  END LOOP;
END $$;

-- Unveränderliche Journale: nur Lesen des eigenen Mandanten; Schreiben via RPC.
ALTER TABLE public.package_redemptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY package_redemptions_select ON public.package_redemptions
  FOR SELECT TO authenticated USING (tenant_id = public.current_tenant_id());

ALTER TABLE public.store_credit_entries ENABLE ROW LEVEL SECURITY;
CREATE POLICY store_credit_entries_select ON public.store_credit_entries
  FOR SELECT TO authenticated USING (tenant_id = public.current_tenant_id());

-- ════════════════════════════════════════════════════════════════════
-- 8. Saldo-Views (security_invoker → RLS des Aufrufers gilt)
-- ════════════════════════════════════════════════════════════════════
CREATE VIEW public.v_package_balance
  WITH (security_invoker = true) AS
SELECT pp.id AS package_purchase_id,
       pp.tenant_id,
       pp.contact_id,
       pp.units_total,
       COALESCE(SUM(r.units), 0)                  AS units_used,
       pp.units_total - COALESCE(SUM(r.units), 0) AS units_remaining,
       pp.expires_at,
       (pp.expires_at IS NULL OR pp.expires_at >= current_date) AS is_valid
FROM public.package_purchases pp
LEFT JOIN public.package_redemptions r ON r.package_purchase_id = pp.id
GROUP BY pp.id, pp.tenant_id, pp.contact_id, pp.units_total, pp.expires_at;

CREATE VIEW public.v_store_credit_balance
  WITH (security_invoker = true) AS
SELECT tenant_id, contact_id, currency, SUM(amount) AS balance
FROM public.store_credit_entries
GROUP BY tenant_id, contact_id, currency;

-- Finanz-Überblick je Kontakt (für den künftigen Finanz-Tab statt SaldoTab-Stub).
-- Hinweis: contacts hat kein tenant_id; die Keys kommen aus den (tenant-scoped) Finanztabellen.
CREATE VIEW public.v_contact_finance
  WITH (security_invoker = true) AS
WITH inv AS (
  SELECT i.tenant_id, i.contact_id,
         SUM(i.total - COALESCE(p.paid, 0)) AS open_balance
  FROM public.invoices i
  LEFT JOIN (
    SELECT invoice_id, SUM(amount) FILTER (WHERE status = 'settled') AS paid
    FROM public.payments GROUP BY invoice_id
  ) p ON p.invoice_id = i.id
  WHERE i.status IN ('issued', 'partially_paid')
  GROUP BY i.tenant_id, i.contact_id
),
cred AS (
  SELECT tenant_id, contact_id, SUM(amount) AS store_credit
  FROM public.store_credit_entries GROUP BY tenant_id, contact_id
),
pkg AS (
  SELECT pp.tenant_id, pp.contact_id,
         SUM(pp.units_total - COALESCE(r.used, 0)) AS open_units
  FROM public.package_purchases pp
  LEFT JOIN (
    SELECT package_purchase_id, SUM(units) AS used
    FROM public.package_redemptions GROUP BY package_purchase_id
  ) r ON r.package_purchase_id = pp.id
  WHERE pp.expires_at IS NULL OR pp.expires_at >= current_date
  GROUP BY pp.tenant_id, pp.contact_id
),
keys AS (
  SELECT tenant_id, contact_id FROM inv
  UNION SELECT tenant_id, contact_id FROM cred
  UNION SELECT tenant_id, contact_id FROM pkg
)
SELECT k.tenant_id,
       k.contact_id,
       COALESCE(inv.open_balance, 0)  AS open_invoice_balance,
       COALESCE(cred.store_credit, 0) AS store_credit_balance,
       COALESCE(pkg.open_units, 0)    AS open_package_units
FROM keys k
LEFT JOIN inv  ON inv.tenant_id  = k.tenant_id AND inv.contact_id  = k.contact_id
LEFT JOIN cred ON cred.tenant_id = k.tenant_id AND cred.contact_id = k.contact_id
LEFT JOIN pkg  ON pkg.tenant_id  = k.tenant_id AND pkg.contact_id  = k.contact_id;

-- ════════════════════════════════════════════════════════════════════
-- 9. RPCs (SECURITY DEFINER + Authz-Guard + Tenant-Check)
-- ════════════════════════════════════════════════════════════════════

-- Paket einlösen (Verbrauch buchen)
CREATE OR REPLACE FUNCTION public.package_redeem(
  p_purchase_id UUID,
  p_units       NUMERIC,
  p_ref_type    TEXT DEFAULT NULL,
  p_ref_id      UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_tenant    UUID;
  v_total     NUMERIC;
  v_expires   DATE;
  v_used      NUMERIC;
  v_redeem    UUID;
  v_actor     UUID;
BEGIN
  IF NOT (public.is_dispatcher() OR public.is_owner()) THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;
  IF p_units <= 0 THEN RAISE EXCEPTION 'units_must_be_positive'; END IF;

  SELECT tenant_id, units_total, expires_at INTO v_tenant, v_total, v_expires
    FROM public.package_purchases WHERE id = p_purchase_id;
  IF v_tenant IS NULL THEN RAISE EXCEPTION 'package_not_found'; END IF;
  IF v_tenant <> public.current_tenant_id() THEN
    RAISE EXCEPTION 'wrong_tenant' USING ERRCODE = '42501';
  END IF;
  IF v_expires IS NOT NULL AND v_expires < current_date THEN
    RAISE EXCEPTION 'package_expired';
  END IF;

  SELECT COALESCE(SUM(units), 0) INTO v_used
    FROM public.package_redemptions WHERE package_purchase_id = p_purchase_id;
  IF p_units > (v_total - v_used) THEN
    RAISE EXCEPTION 'insufficient_units (remaining=%)', (v_total - v_used);
  END IF;

  v_actor := (SELECT contact_id FROM public.contact_instructor WHERE auth_user_id = auth.uid() LIMIT 1);

  INSERT INTO public.package_redemptions (tenant_id, package_purchase_id, units, ref_type, ref_id, created_by)
  VALUES (v_tenant, p_purchase_id, p_units, p_ref_type, p_ref_id, v_actor)
  RETURNING id INTO v_redeem;

  RETURN v_redeem;
END;
$$;

-- Store-Credit buchen (signiert: + Aufladung / − Verbrauch)
CREATE OR REPLACE FUNCTION public.store_credit_post(
  p_contact_id UUID,
  p_amount     NUMERIC,
  p_reason     TEXT,
  p_ref_type   TEXT DEFAULT NULL,
  p_ref_id     UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_tenant UUID := public.current_tenant_id();
  v_entry  UUID;
  v_actor  UUID;
BEGIN
  IF NOT (public.is_dispatcher() OR public.is_owner()) THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;
  IF v_tenant IS NULL THEN RAISE EXCEPTION 'no_tenant' USING ERRCODE = '42501'; END IF;
  IF p_amount = 0 THEN RAISE EXCEPTION 'amount_must_be_nonzero'; END IF;

  v_actor := (SELECT contact_id FROM public.contact_instructor WHERE auth_user_id = auth.uid() LIMIT 1);

  INSERT INTO public.store_credit_entries (tenant_id, contact_id, amount, reason, ref_type, ref_id, created_by)
  VALUES (v_tenant, p_contact_id, p_amount, p_reason, p_ref_type, p_ref_id, v_actor)
  RETURNING id INTO v_entry;

  RETURN v_entry;
END;
$$;

-- Store-Credit auf eine Rechnung anwenden (atomar: Guthaben −, Zahlung +)
CREATE OR REPLACE FUNCTION public.store_credit_redeem_to_invoice(
  p_invoice_id UUID,
  p_amount     NUMERIC
)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_tenant  UUID;
  v_contact UUID;
  v_balance NUMERIC;
  v_payment UUID;
BEGIN
  IF NOT (public.is_dispatcher() OR public.is_owner()) THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;
  IF p_amount <= 0 THEN RAISE EXCEPTION 'amount_must_be_positive'; END IF;

  SELECT tenant_id, contact_id INTO v_tenant, v_contact
    FROM public.invoices WHERE id = p_invoice_id;
  IF v_tenant IS NULL THEN RAISE EXCEPTION 'invoice_not_found'; END IF;
  IF v_tenant <> public.current_tenant_id() THEN
    RAISE EXCEPTION 'wrong_tenant' USING ERRCODE = '42501';
  END IF;

  SELECT COALESCE(SUM(amount), 0) INTO v_balance
    FROM public.store_credit_entries WHERE tenant_id = v_tenant AND contact_id = v_contact;
  IF p_amount > v_balance THEN
    RAISE EXCEPTION 'insufficient_store_credit (balance=%)', v_balance;
  END IF;

  -- Guthaben abbuchen
  INSERT INTO public.store_credit_entries (tenant_id, contact_id, amount, reason, ref_type, ref_id, created_by)
  VALUES (v_tenant, v_contact, -p_amount, 'redeem', 'invoice', p_invoice_id,
          (SELECT contact_id FROM public.contact_instructor WHERE auth_user_id = auth.uid() LIMIT 1));

  -- Zahlung auf die Rechnung buchen (Status + Timeline via payment_record)
  v_payment := public.payment_record(p_invoice_id, 'store_credit', p_amount);

  RETURN v_payment;
END;
$$;

-- Gutschein einlösen → lädt den Wert als Store-Credit auf den Kunden
CREATE OR REPLACE FUNCTION public.gift_card_redeem(
  p_code       TEXT,
  p_contact_id UUID
)
RETURNS NUMERIC
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_tenant  UUID := public.current_tenant_id();
  v_card    UUID;
  v_amount  NUMERIC;
  v_status  TEXT;
  v_expires DATE;
BEGIN
  IF NOT (public.is_dispatcher() OR public.is_owner()) THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;
  IF v_tenant IS NULL THEN RAISE EXCEPTION 'no_tenant' USING ERRCODE = '42501'; END IF;

  SELECT id, initial_amount, status, expires_at
    INTO v_card, v_amount, v_status, v_expires
    FROM public.gift_cards WHERE tenant_id = v_tenant AND code = p_code;
  IF v_card IS NULL THEN RAISE EXCEPTION 'gift_card_not_found'; END IF;
  IF v_status <> 'active' THEN RAISE EXCEPTION 'gift_card_not_active (status=%)', v_status; END IF;
  IF v_expires IS NOT NULL AND v_expires < current_date THEN RAISE EXCEPTION 'gift_card_expired'; END IF;

  PERFORM public.store_credit_post(p_contact_id, v_amount, 'gift', 'gift_card', v_card);
  UPDATE public.gift_cards SET status = 'spent' WHERE id = v_card;

  RETURN v_amount;
END;
$$;

-- ── Grants ─────────────────────────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.package_redeem(UUID, NUMERIC, TEXT, UUID)            FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.store_credit_post(UUID, NUMERIC, TEXT, TEXT, UUID)   FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.store_credit_redeem_to_invoice(UUID, NUMERIC)        FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.gift_card_redeem(TEXT, UUID)                         FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.package_redeem(UUID, NUMERIC, TEXT, UUID)            TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.store_credit_post(UUID, NUMERIC, TEXT, TEXT, UUID)   TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.store_credit_redeem_to_invoice(UUID, NUMERIC)        TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.gift_card_redeem(TEXT, UUID)                         TO authenticated, service_role;

COMMIT;
