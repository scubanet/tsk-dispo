-- Recalc-Funktion: alle vergütung-Bewegungen aus aktuellen Sätzen + Punkten
-- neu berechnen. Aufrufbar vom Dispatcher via RPC nach Tarif/Punkte-Änderung.
--
-- Identische Logik wie Migration 0038, nur als wiederverwendbare Function.
-- SECURITY DEFINER damit RLS umgangen wird (sonst würde DELETE auf eigene
-- Policy stoßen, die nur 'is_dispatcher' erlaubt — passt zwar, ist aber sauberer
-- so explizit).

CREATE OR REPLACE FUNCTION recalc_all_compensations()
RETURNS TABLE (deleted_count INT, inserted_count INT)
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deleted INT;
  v_inserted INT;
BEGIN
  -- Nur Dispatcher dürfen das auslösen
  IF NOT is_dispatcher() THEN
    RAISE EXCEPTION 'Nur Dispatcher dürfen Vergütungen neu berechnen.';
  END IF;

  -- 1. Alte vergütung-Bewegungen löschen
  DELETE FROM account_movements
  WHERE kind = 'vergütung' AND ref_assignment_id IS NOT NULL;
  GET DIAGNOSTICS v_deleted = ROW_COUNT;

  -- 2. Frische vergütung-Bewegungen aus den aktuellen Sätzen schreiben
  WITH recalc AS (
    SELECT
      ca.instructor_id,
      c.start_date AS d,
      c.title AS title,
      ca.id AS aid,
      calc_compensation(ca.id) AS breakdown
    FROM course_assignments ca
    JOIN courses c ON c.id = ca.course_id
  )
  INSERT INTO account_movements (
    instructor_id, date, amount_chf, kind,
    ref_assignment_id, description, breakdown_json, rate_version
  )
  SELECT
    instructor_id,
    d,
    (breakdown->>'amount_chf')::numeric,
    'vergütung',
    aid,
    title,
    breakdown,
    -- Version hochzählen damit nachvollziehbar ist wann recalc lief
    COALESCE((SELECT MAX(rate_version) FROM account_movements), 1) + 1
  FROM recalc
  WHERE (breakdown->>'amount_chf')::numeric <> 0;
  GET DIAGNOSTICS v_inserted = ROW_COUNT;

  RETURN QUERY SELECT v_deleted, v_inserted;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION recalc_all_compensations() IS
  'Recalc aller assignment-basierten Vergütungen mit aktuellen comp_rates + course_types/comp_units. Nur Dispatcher.';

GRANT EXECUTE ON FUNCTION recalc_all_compensations() TO authenticated;
