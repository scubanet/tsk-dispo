-- 0075: per-instructor email/push language
-- Used by edge functions (send-notification, send-assignment-notification) to
-- pick the right language template. Mirrors `people.preferred_language` from 0074.

ALTER TABLE public.instructors
  ADD COLUMN IF NOT EXISTS preferred_language text
    NOT NULL DEFAULT 'de'
    CHECK (preferred_language IN ('de', 'en'));

COMMENT ON COLUMN public.instructors.preferred_language IS
  'Email + APNs notification language. Allowed: de, en. Mirrors people.preferred_language for instructors.';
