-- 0095: course_dates — Anfangs- und Endzeit pro Programmpunkt
--
-- Bisher hatte course_dates EIN time_from/time_to-Paar pro Tag. Da ein Tag
-- aber kombinierte Types haben kann (z.B. Theorie + Pool), reicht eine
-- einzelne Zeitangabe nicht.
--
-- Variante A (Inline-Spalten): 6 neue Spalten — theory_from/to, pool_from/to,
-- lake_from/to. Backfill aus bestehendem time_from/time_to in den passenden
-- Type-Slot (basierend auf has_theory/has_pool/has_lake). time_from/time_to
-- bleibt als „legacy general time" stehen, kann später entfernt werden.

-- ────────────────────────────────────────────────────────────────────────────
-- 1. Spalten ergänzen
-- ────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.course_dates
  ADD COLUMN IF NOT EXISTS theory_from TIME,
  ADD COLUMN IF NOT EXISTS theory_to   TIME,
  ADD COLUMN IF NOT EXISTS pool_from   TIME,
  ADD COLUMN IF NOT EXISTS pool_to     TIME,
  ADD COLUMN IF NOT EXISTS lake_from   TIME,
  ADD COLUMN IF NOT EXISTS lake_to     TIME;

COMMENT ON COLUMN public.course_dates.theory_from IS 'Theorie-Start an diesem Tag (nur sinnvoll wenn has_theory).';
COMMENT ON COLUMN public.course_dates.theory_to   IS 'Theorie-Ende.';
COMMENT ON COLUMN public.course_dates.pool_from   IS 'Pool-Start an diesem Tag (nur sinnvoll wenn has_pool).';
COMMENT ON COLUMN public.course_dates.pool_to     IS 'Pool-Ende.';
COMMENT ON COLUMN public.course_dates.lake_from   IS 'See-Start an diesem Tag (nur sinnvoll wenn has_lake).';
COMMENT ON COLUMN public.course_dates.lake_to     IS 'See-Ende.';

-- ────────────────────────────────────────────────────────────────────────────
-- 2. Backfill: bestehendes time_from/time_to in den primary-type-Slot kopieren
-- ────────────────────────────────────────────────────────────────────────────
UPDATE public.course_dates
SET theory_from = time_from,
    theory_to   = time_to
WHERE time_from IS NOT NULL
  AND has_theory = true
  AND theory_from IS NULL;

UPDATE public.course_dates
SET pool_from = time_from,
    pool_to   = time_to
WHERE time_from IS NOT NULL
  AND has_pool = true
  AND pool_from IS NULL;

UPDATE public.course_dates
SET lake_from = time_from,
    lake_to   = time_to
WHERE time_from IS NOT NULL
  AND has_lake = true
  AND lake_from IS NULL;

-- ────────────────────────────────────────────────────────────────────────────
-- 3. CHECK-Constraints: Ende > Anfang pro Type
-- ────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.course_dates
  DROP CONSTRAINT IF EXISTS course_dates_theory_time_check,
  DROP CONSTRAINT IF EXISTS course_dates_pool_time_check,
  DROP CONSTRAINT IF EXISTS course_dates_lake_time_check;

ALTER TABLE public.course_dates
  ADD CONSTRAINT course_dates_theory_time_check
    CHECK (theory_to IS NULL OR theory_from IS NULL OR theory_to > theory_from),
  ADD CONSTRAINT course_dates_pool_time_check
    CHECK (pool_to   IS NULL OR pool_from   IS NULL OR pool_to   > pool_from),
  ADD CONSTRAINT course_dates_lake_time_check
    CHECK (lake_to   IS NULL OR lake_from   IS NULL OR lake_to   > lake_from);

-- NOTE: time_from / time_to bleiben (Legacy). Bei vollständiger Konsumenten-
-- Migration kann eine separate Cleanup-Migration die Spalten droppen.
