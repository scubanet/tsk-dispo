-- 20260606000400_contact_instructor_default_tenant.sql
--
-- FIX (Tenant-Linkage): contact_instructor.tenant_id (eingeführt in
-- 20260605090000) hatte nur einen EINMALIGEN Backfill zur Migrationszeit. Auf
-- einem frischen `supabase db reset` werden die Nutzerdaten ERST NACH den
-- Migrationen geladen (Login/Import) → die neuen contact_instructor-Zeilen haben
-- tenant_id = NULL → `current_tenant_id()` gibt NULL zurück → ALLE tenant-
-- gescopten Features sind für den User unbrauchbar:
--   • Shop/Retail: leere Kategorien (RLS tenant_id = current_tenant_id()),
--     „Fehler" beim Produkt-Speichern (ProductEditSheet-Guard !tenantId),
--   • POS: `no_tenant`-Exception in pos_checkout,
--   • Verleih/Trips/Finanzen analog.
--
-- Fix: (1) bestehende NULLs erneut backfillen; (2) BEFORE-INSERT-Trigger, der
-- tenant_id automatisch auf den TSK-Tenant setzt, wenn NULL — so bekommen auch
-- künftig angelegte Sidecars (Login, Import, neue Instruktoren) immer einen
-- Tenant, idempotent und reset-fest. Single-tenant TSK: fester Slug 'tsk-zrh'
-- (wie der ursprüngliche Backfill). Multi-Tenant später: pro User auflösen.
-- Explizit gesetzte tenant_id (z. B. in pgTAP) bleibt unangetastet.

-- (1) Re-Backfill bestehender Zeilen.
UPDATE public.contact_instructor
   SET tenant_id = (SELECT id FROM public.tenants WHERE slug = 'tsk-zrh')
 WHERE tenant_id IS NULL;

-- (2) Auto-Default für künftige Inserts.
CREATE OR REPLACE FUNCTION public.set_default_tenant_on_contact_instructor()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.tenant_id IS NULL THEN
    SELECT id INTO NEW.tenant_id FROM public.tenants WHERE slug = 'tsk-zrh';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_ci_default_tenant ON public.contact_instructor;
CREATE TRIGGER trg_ci_default_tenant
  BEFORE INSERT ON public.contact_instructor
  FOR EACH ROW EXECUTE FUNCTION public.set_default_tenant_on_contact_instructor();
