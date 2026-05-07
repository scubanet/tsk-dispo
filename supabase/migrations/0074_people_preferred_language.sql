-- 0074: per-user UI language
-- Drives both UI default after login and email template selection.
-- Set on first login from browser locale; user can change it in Settings.

ALTER TABLE public.people
  ADD COLUMN IF NOT EXISTS preferred_language text
    NOT NULL DEFAULT 'de'
    CHECK (preferred_language IN ('de', 'en'));

COMMENT ON COLUMN public.people.preferred_language IS
  'User UI language. Used for app UI default and outbound email template selection. Allowed: de, en.';

-- backwards-compat: students view auto-inherits new column via SELECT *
