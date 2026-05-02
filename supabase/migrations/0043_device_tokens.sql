-- device_tokens — APNs / FCM Tokens für Push-Notifications.
--
-- Wird vom iOS-Client gefüllt sobald der User Push-Permissions erteilt.
-- Eine Edge Function (send-assignment-notification) liest die Tokens beim
-- Insert eines Assignment und sendet via APNs HTTP/2 mit JWT-Auth.
--
-- 1 User kann mehrere Tokens haben (mehrere Devices). UNIQUE auf token verhindert
-- Duplikate; Upsert via ON CONFLICT (apns_token) DO UPDATE updated_at.

CREATE TABLE IF NOT EXISTS device_tokens (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  instructor_id   UUID NOT NULL REFERENCES instructors(id) ON DELETE CASCADE,
  apns_token      TEXT NOT NULL UNIQUE,
  platform        TEXT NOT NULL DEFAULT 'ios' CHECK (platform IN ('ios', 'android')),
  app_version     TEXT,
  os_version      TEXT,
  device_name     TEXT,
  last_seen       TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_device_tokens_instructor ON device_tokens(instructor_id);

COMMENT ON TABLE device_tokens IS
  'APNs (iOS) und FCM (Android) Tokens für Push-Notifications. Vom Client gefüllt nach Push-Permission.';

-- =============================================================
-- RLS
-- =============================================================

ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;

-- Instructor: nur eigene Tokens lesen/schreiben/löschen
CREATE POLICY tokens_own_select ON device_tokens FOR SELECT
  USING (instructor_id = (SELECT id FROM current_instructor()));

CREATE POLICY tokens_own_insert ON device_tokens FOR INSERT
  WITH CHECK (instructor_id = (SELECT id FROM current_instructor()));

CREATE POLICY tokens_own_update ON device_tokens FOR UPDATE
  USING (instructor_id = (SELECT id FROM current_instructor()));

CREATE POLICY tokens_own_delete ON device_tokens FOR DELETE
  USING (instructor_id = (SELECT id FROM current_instructor()));

-- Dispatcher: alle Tokens (zum Senden / Admin-Übersicht)
CREATE POLICY tokens_dispatcher_all ON device_tokens FOR ALL
  USING (is_dispatcher());
