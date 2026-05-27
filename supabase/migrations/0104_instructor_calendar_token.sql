-- 0104 (renamed from 0095): instructors.calendar_token für iCal-Feed-Subscription
-- Rename-Grund: Version 0095 hatte drei kollidierende Files (course_dates_per_type_times,
-- instructor_calendar_token, skill_definitions). Inhalt war bereits via Studio auf Prod
-- applied; nur der Tracker war out of sync. Umbenannt auf freie Slots 0104 + 0116.
--
-- Pro Instructor ein 24-Byte-Random-Token (32 Zeichen Base64), der als URL-Param
-- für die Edge Function ical-feed dient. Rotierbar via RPC rotate_calendar_token
-- (siehe 0096).

ALTER TABLE instructors ADD COLUMN IF NOT EXISTS calendar_token TEXT;

-- Backfill für bestehende Instructors (idempotent: nur wo noch NULL)
UPDATE instructors
SET calendar_token = encode(gen_random_bytes(24), 'base64')
WHERE calendar_token IS NULL;

-- NOT NULL + UNIQUE erst nach Backfill
ALTER TABLE instructors ALTER COLUMN calendar_token SET NOT NULL;

-- UNIQUE-Constraint nur anlegen wenn nicht schon vorhanden
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'instructors_calendar_token_key'
  ) THEN
    ALTER TABLE instructors ADD CONSTRAINT instructors_calendar_token_key UNIQUE (calendar_token);
  END IF;
END $$;

-- Index für Lookup in der Edge Function
CREATE INDEX IF NOT EXISTS idx_instructors_calendar_token
  ON instructors(calendar_token);

COMMENT ON COLUMN instructors.calendar_token IS
  'Random token (24 bytes Base64) für iCal-Feed-Subscription. Rotierbar via RPC.';
