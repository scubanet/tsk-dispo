-- 0078: Orphan-Vergütungen säubern + verhindern
--
-- Hintergrund:
--   Der TL/DM-Detail-Saldo-Tab filtert account_movements wie folgt:
--     - kein ref_assignment_id → IMMER anzeigen (gedacht für übertrag/korrektur)
--     - mit  ref_assignment_id → nur wenn Kurs status='completed'
--
--   Problem: Es existieren account_movements mit kind='vergütung' UND
--   ref_assignment_id IS NULL — diese rutschen durch den Filter und werden
--   wie manuelle Korrekturen behandelt, obwohl sie *automatisch* generierte
--   Vergütungen sind, deren Assignment irgendwann gelöscht wurde (oder
--   nie gelinkt war, z.B. Excel-Import).
--
-- Fix:
--   1. Audit: liste alle orphan vergütungen für Review auf
--   2. Cleanup: setze invalidated_at + invalidated_reason (kein hartes
--      DELETE — Audit-Trail bleibt erhalten)
--   3. Prevention: CHECK-Constraint sodass kind='vergütung' immer eine
--      ref_assignment_id haben muss (für neue Inserts)
--
-- ⚠ Vor dem Run: Backup anlegen (Pro-Plan: PITR aktiv).
-- ⚠ Schritt 2 ist destruktiv-soft (UPDATE). Falls du die Beträge behalten
--   willst (z.B. weil der Excel-Import sie absichtlich so eingespielt hat),
--   kommentiere Schritt 2 aus und konvertiere sie stattdessen in 'übertrag'
--   oder 'korrektur'.

-- ─────────────── Voraussetzung: invalidated_at-Spalte existiert? ───────────────
-- Falls noch nicht (legacy-Schema): Spalten anlegen.
ALTER TABLE public.account_movements
  ADD COLUMN IF NOT EXISTS invalidated_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS invalidated_reason TEXT;

-- ─────────────── 1. AUDIT (vor Cleanup) ───────────────
-- Zeigt alle orphan-Kandidaten. Die Migration läuft trotzdem durch — die
-- NOTICE ist nur informativ.
DO $$
DECLARE
  orphan_count INT;
  orphan_sum   NUMERIC;
BEGIN
  SELECT COUNT(*), COALESCE(SUM(amount_chf), 0)
  INTO orphan_count, orphan_sum
  FROM public.account_movements
  WHERE kind = 'vergütung'
    AND ref_assignment_id IS NULL
    AND invalidated_at IS NULL;

  RAISE NOTICE '0078: % orphan vergütungen (CHF % gesamt) werden invalidiert',
    orphan_count, orphan_sum;
END $$;

-- ─────────────── 2. CLEANUP (soft-delete via invalidated_at) ───────────────
UPDATE public.account_movements
   SET invalidated_at = now(),
       invalidated_reason = '0078: orphan vergütung — kein ref_assignment_id'
 WHERE kind = 'vergütung'
   AND ref_assignment_id IS NULL
   AND invalidated_at IS NULL;

-- ─────────────── 3. PREVENTION ───────────────
-- Trigger: bei DELETE eines course_assignment werden die zugehörigen
-- vergütung-Movements automatisch invalidiert (statt orphan zu werden).
CREATE OR REPLACE FUNCTION invalidate_movements_on_assignment_delete()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.account_movements
     SET invalidated_at = now(),
         invalidated_reason = 'Assignment ' || OLD.id || ' wurde gelöscht'
   WHERE ref_assignment_id = OLD.id
     AND invalidated_at IS NULL;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_invalidate_movements_on_assignment_delete
  ON public.course_assignments;

CREATE TRIGGER trg_invalidate_movements_on_assignment_delete
  BEFORE DELETE ON public.course_assignments
  FOR EACH ROW EXECUTE FUNCTION invalidate_movements_on_assignment_delete();

COMMENT ON FUNCTION invalidate_movements_on_assignment_delete IS
  'Invalidiert account_movements automatisch wenn ihr course_assignment gelöscht wird (verhindert orphan vergütungen).';

-- ─────────────── 4. VERIFICATION ───────────────
DO $$
DECLARE
  remaining INT;
BEGIN
  SELECT COUNT(*) INTO remaining
  FROM public.account_movements
  WHERE kind = 'vergütung'
    AND ref_assignment_id IS NULL
    AND invalidated_at IS NULL;

  RAISE NOTICE '0078: nach Cleanup verbleiben % orphan vergütungen (sollte 0 sein)', remaining;
END $$;
