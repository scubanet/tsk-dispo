-- Bug-Fix: Assignment-Delete schlägt fehl wegen Immutability-Trigger.
--
-- Hintergrund:
--   account_movements.ref_assignment_id hat FK ON DELETE SET NULL.
--   Wird ein course_assignment gelöscht, versucht Postgres die zugehörige
--   vergütung-Bewegung zu UPDATEn (ref_assignment_id := NULL).
--   Der Immutability-Trigger aus Migration 0040 blockt diese UPDATE.
--   → Assignment-Delete bricht ab, Dispatcher kann TL/DM nicht entfernen.
--
-- Fix: Trigger erlaubt jetzt UPDATEs die NUR `ref_assignment_id` von einem
-- Wert auf NULL setzen (= reine FK-Cascade-Operation, sonst alles identisch).
-- Inhaltliche Änderungen an vergütung-Bewegungen bleiben weiterhin geblockt.

CREATE OR REPLACE FUNCTION block_account_movement_update()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.kind = 'vergütung' THEN
    -- Spezialfall: FK-Cascade SET NULL beim Assignment-Delete
    -- ref_assignment_id wird von <uuid> auf NULL gesetzt, sonst ist alles unverändert.
    IF OLD.ref_assignment_id IS NOT NULL
       AND NEW.ref_assignment_id IS NULL
       AND NEW.amount_chf      = OLD.amount_chf
       AND NEW.kind            = OLD.kind
       AND NEW.instructor_id   = OLD.instructor_id
       AND NEW.date            = OLD.date THEN
      RETURN NEW;  -- Cascade durchlassen
    END IF;

    RAISE EXCEPTION 'vergütung-Bewegungen sind auto-generiert (Comp-Engine). Statt zu editieren: Assignment ändern oder Korrektur-Buchung anlegen.';
  END IF;
  -- korrektur und übertrag: UPDATE ist erlaubt
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION block_account_movement_update() IS
  'Blockiert UPDATE auf vergütung außer reinem FK-Cascade (ref_assignment_id → NULL). Erlaubt UPDATE auf korrektur/übertrag.';
