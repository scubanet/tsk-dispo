-- 20260605090000_tenants_and_tenant_helper.sql
-- Phase-1 (Kundenfinanzen + Compliance) — Schritt 1: Multi-Tenant-Anker.
--
-- Entscheidung D-1: voll Multi-Tenant. Atoll ist HEUTE Single-Tenant (kein
-- tenant_id). Diese Migration legt die tenants-Tabelle an, hängt eine additive
-- tenant_id an contact_instructor, backfilled den Bestand auf 'tsk-zrh' und
-- stellt current_tenant_id() bereit (Konvention analog is_dispatcher()/
-- is_contact_owner() — SQL STABLE SECURITY DEFINER, search_path gepinnt).
-- Bestehende Atoll-Tabellen bleiben vorerst Single-Tenant (Brücke später).

BEGIN;

CREATE TABLE public.tenants (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug             TEXT NOT NULL UNIQUE,
  name             TEXT NOT NULL,
  default_currency CHAR(3) NOT NULL DEFAULT 'CHF',
  country          CHAR(2) NOT NULL DEFAULT 'CH',
  invoice_prefix   TEXT NOT NULL DEFAULT 'R',
  is_active        BOOLEAN NOT NULL DEFAULT true,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.tenants IS
  'Mandant (Betrieb). Phase-1-Tabellen sind tenant-scoped; Bestands-Tabellen folgen später.';

-- Additive Tenant-Zuordnung für Mitarbeitende (nullable, damit Bestands-Inserts nicht brechen).
ALTER TABLE public.contact_instructor
  ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES public.tenants(id);

CREATE INDEX IF NOT EXISTS idx_contact_instructor_tenant
  ON public.contact_instructor(tenant_id);

-- Default-Mandant + Backfill des Bestands.
INSERT INTO public.tenants (slug, name)
  VALUES ('tsk-zrh', 'Tauchsport Käge Zürich')
  ON CONFLICT (slug) DO NOTHING;

UPDATE public.contact_instructor
   SET tenant_id = (SELECT id FROM public.tenants WHERE slug = 'tsk-zrh')
 WHERE tenant_id IS NULL;

-- Helper: Tenant des eingeloggten Users. Liest aus dem contact_instructor-Sidecar
-- (dort lebt auth_user_id). Gibt NULL für nicht zugeordnete Accounts → RLS verweigert
-- dann sicher (fail-closed).
CREATE OR REPLACE FUNCTION public.current_tenant_id()
RETURNS UUID
LANGUAGE SQL STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT ci.tenant_id
  FROM public.contact_instructor ci
  WHERE ci.auth_user_id = auth.uid()
  LIMIT 1
$$;

REVOKE ALL ON FUNCTION public.current_tenant_id() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.current_tenant_id() TO authenticated, service_role;

COMMENT ON FUNCTION public.current_tenant_id() IS
  'Tenant des eingeloggten Users (aus contact_instructor). Basis aller Phase-1-RLS-Policies.';

-- RLS auf tenants: jeder Staff sieht nur den eigenen Mandanten; nur Owner darf ändern.
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenants_select ON public.tenants
  FOR SELECT TO authenticated
  USING (id = public.current_tenant_id());

CREATE POLICY tenants_update ON public.tenants
  FOR UPDATE TO authenticated
  USING (id = public.current_tenant_id() AND public.is_owner())
  WITH CHECK (id = public.current_tenant_id() AND public.is_owner());
-- INSERT/DELETE bewusst nur via Service-Role/Seed — kein Self-Service-Mandantenanlegen.

COMMIT;
