-- 0115_contact_saved_views.sql
-- ─────────────────────────────────────────────────────────────────
-- Phase G Foundation: per-User-Custom-Views für AddressbookScreen.
-- Speichert Kombi aus Filter, sichtbaren Columns, Sort, Density.
-- Spec: docs/superpowers/specs/2026-05-27-contacts-crm-redesign.md §6.6
-- ─────────────────────────────────────────────────────────────────

CREATE TABLE public.contact_saved_views (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  filter      JSONB NOT NULL DEFAULT '{}'::jsonb,
  columns     JSONB NOT NULL DEFAULT '[]'::jsonb,
  sort        JSONB NOT NULL DEFAULT '[]'::jsonb,
  -- 'compact' | 'comfortable' — matches DensityToggle in useContactSavedViews
  density     TEXT NOT NULL DEFAULT 'comfortable'
    CHECK (density IN ('compact', 'comfortable')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Unique view-name per user (case-insensitive — 'Hot Leads' und 'hot leads'
-- collidieren). Covered user_id-prefixed queries automatisch; deshalb kein
-- separater idx_contact_saved_views_user nötig.
CREATE UNIQUE INDEX uq_contact_saved_views_user_name
  ON public.contact_saved_views(user_id, lower(name));

-- Auto-touch updated_at bei UPDATE — robuster als App-Layer.
CREATE OR REPLACE FUNCTION public.touch_contact_saved_views_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER tg_contact_saved_views_touch_updated_at
  BEFORE UPDATE ON public.contact_saved_views
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_contact_saved_views_updated_at();

ALTER TABLE public.contact_saved_views ENABLE ROW LEVEL SECURITY;

CREATE POLICY contact_saved_views_owner ON public.contact_saved_views
  FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
