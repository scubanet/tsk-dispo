-- 0108: AtollCard — device tokens for APNs push (Welle B Bug-Fix).
--
-- Fixes a naming mismatch from the v0.4 codebase: iOS PushTokenService
-- and the atollcard-lead-push Edge Function both target the table name
-- `atollcard_device_tokens` (prefixed), but migration 0099 created
-- `device_tokens` (unprefixed). Without this fix, every iOS launch
-- silently fails to register a device token, and the Edge Function
-- returns 0 recipients on every lead.
--
-- This migration is idempotent and handles three cases:
--   1. Fresh install — neither table exists → create atollcard_device_tokens
--   2. 0099 already applied (legacy) → rename device_tokens to atollcard_device_tokens
--   3. Already-correct state → skip (no-op)
--
-- Schema, RLS, and indexes are identical to what 0099 intended, just on
-- the correct table name. Migration 0099 should be considered obsolete
-- once 0108 is applied.

DO $$
DECLARE
  has_legacy   boolean;
  has_prefixed boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'device_tokens'
  ) INTO has_legacy;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'atollcard_device_tokens'
  ) INTO has_prefixed;

  IF has_prefixed THEN
    -- Already correct — nothing to do.
    RAISE NOTICE '0108: atollcard_device_tokens already exists, skipping.';
    RETURN;
  END IF;

  IF has_legacy THEN
    -- Rename legacy table; constraints and indexes follow.
    ALTER TABLE public.device_tokens RENAME TO atollcard_device_tokens;
    RAISE NOTICE '0108: renamed device_tokens to atollcard_device_tokens.';
    RETURN;
  END IF;

  -- Fresh create.
  CREATE TABLE public.atollcard_device_tokens (
    auth_user_id   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_token   TEXT NOT NULL,
    platform       TEXT NOT NULL CHECK (platform IN ('ios', 'macos')),
    app_bundle_id  TEXT NOT NULL,
    last_seen_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (auth_user_id, device_token)
  );
  RAISE NOTICE '0108: created atollcard_device_tokens fresh.';
END $$;

-- Index + RLS — idempotent so they're safe whether table was renamed or fresh-created.
CREATE INDEX IF NOT EXISTS idx_atollcard_device_tokens_user
  ON public.atollcard_device_tokens(auth_user_id);

ALTER TABLE public.atollcard_device_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS atollcard_device_tokens_owner ON public.atollcard_device_tokens;
DROP POLICY IF EXISTS device_tokens_owner          ON public.atollcard_device_tokens;
CREATE POLICY atollcard_device_tokens_owner ON public.atollcard_device_tokens
  FOR ALL TO authenticated
  USING (auth_user_id = auth.uid())
  WITH CHECK (auth_user_id = auth.uid());
