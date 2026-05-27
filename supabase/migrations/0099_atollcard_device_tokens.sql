-- 0099: AtollCard — device tokens for APNs push.
--
-- iOS registers for remote notifications on launch (when permission is
-- granted) and forwards the APNs device token to this table. The
-- card-lead-INSERT trigger in 0100 (next migration, post-Phase-6 setup)
-- reads this table to know which devices to push to.
--
-- One user can have multiple devices (iPhone + iPad + Mac), so we use
-- `(auth_user_id, device_token)` as the composite primary key. Token
-- rotation: when iOS gives us a new token, we upsert and refresh
-- last_seen_at.

CREATE TABLE public.device_tokens (
  auth_user_id   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  device_token   TEXT NOT NULL,
  platform       TEXT NOT NULL CHECK (platform IN ('ios', 'macos')),
  app_bundle_id  TEXT NOT NULL,  -- swiss.atoll.card
  last_seen_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (auth_user_id, device_token)
);

CREATE INDEX idx_device_tokens_user ON public.device_tokens(auth_user_id);

ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

-- Each user manages only their own tokens.
CREATE POLICY device_tokens_owner ON public.device_tokens
  FOR ALL TO authenticated
  USING (auth_user_id = auth.uid())
  WITH CHECK (auth_user_id = auth.uid());
