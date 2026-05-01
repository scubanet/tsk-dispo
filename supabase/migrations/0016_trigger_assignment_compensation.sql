CREATE OR REPLACE FUNCTION write_movement_for_assignment()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_breakdown JSONB;
  v_amount NUMERIC;
  v_course_date DATE;
  v_rate_version INT;
  v_existing NUMERIC;
  v_delta NUMERIC;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_breakdown := calc_compensation(NEW.id);
    v_amount := (v_breakdown->>'amount_chf')::numeric;

    SELECT start_date INTO v_course_date FROM courses WHERE id = NEW.course_id;

    SELECT cr.rate_version INTO v_rate_version
      FROM comp_rates cr
      JOIN instructors i ON i.padi_level = cr.level
      WHERE i.id = NEW.instructor_id AND cr.valid_to IS NULL
      LIMIT 1;

    INSERT INTO account_movements (
      instructor_id, date, amount_chf, kind,
      ref_assignment_id, description, breakdown_json, rate_version
    ) VALUES (
      NEW.instructor_id,
      v_course_date,
      v_amount,
      'vergütung',
      NEW.id,
      (SELECT title FROM courses WHERE id = NEW.course_id),
      v_breakdown,
      COALESCE(v_rate_version, 1)
    );
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    v_breakdown := calc_compensation(NEW.id);
    v_amount := (v_breakdown->>'amount_chf')::numeric;

    SELECT COALESCE(SUM(amount_chf), 0) INTO v_existing
      FROM account_movements WHERE ref_assignment_id = NEW.id;

    v_delta := v_amount - v_existing;

    IF v_delta <> 0 THEN
      SELECT start_date INTO v_course_date FROM courses WHERE id = NEW.course_id;

      INSERT INTO account_movements (
        instructor_id, date, amount_chf, kind,
        ref_assignment_id, description, breakdown_json
      ) VALUES (
        NEW.instructor_id,
        v_course_date,
        v_delta,
        'korrektur',
        NEW.id,
        'Korrektur durch Assignment-Update',
        v_breakdown
      );
    END IF;
    RETURN NEW;
  END IF;

  IF TG_OP = 'DELETE' THEN
    SELECT COALESCE(SUM(amount_chf), 0) INTO v_existing
      FROM account_movements WHERE ref_assignment_id = OLD.id;

    IF v_existing <> 0 THEN
      INSERT INTO account_movements (
        instructor_id, date, amount_chf, kind,
        ref_assignment_id, description
      ) VALUES (
        OLD.instructor_id,
        CURRENT_DATE,
        -v_existing,
        'korrektur',
        NULL,
        'Reversal durch Assignment-DELETE'
      );
    END IF;
    RETURN OLD;
  END IF;

  RETURN NULL;
END;
$$;

CREATE TRIGGER trg_assignment_compensation
  AFTER INSERT OR UPDATE OR DELETE ON course_assignments
  FOR EACH ROW EXECUTE FUNCTION write_movement_for_assignment();

COMMENT ON FUNCTION write_movement_for_assignment IS
  'On INSERT writes vergütung, on UPDATE writes korrektur for delta, on DELETE reverses.';
