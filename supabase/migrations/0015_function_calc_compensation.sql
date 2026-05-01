-- Pure function: given an assignment, returns the breakdown JSON.
-- Used both by the trigger and by future "preview" UI.
CREATE OR REPLACE FUNCTION calc_compensation(
  p_assignment_id UUID
) RETURNS JSONB
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_assignment RECORD;
  v_course RECORD;
  v_instructor RECORD;
  v_units RECORD;
  v_rate NUMERIC;
  v_total_dates INT;
  v_assigned_dates INT;
  v_share NUMERIC;
  v_amount NUMERIC;
  v_breakdown JSONB;
BEGIN
  SELECT * INTO v_assignment FROM course_assignments WHERE id = p_assignment_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'assignment not found: %', p_assignment_id;
  END IF;

  SELECT * INTO v_course     FROM courses     WHERE id = v_assignment.course_id;
  SELECT * INTO v_instructor FROM instructors WHERE id = v_assignment.instructor_id;
  SELECT * INTO v_units      FROM comp_units
    WHERE course_type_id = v_course.type_id AND role = v_assignment.role;

  IF v_units IS NULL THEN
    RAISE EXCEPTION 'no comp_units for course_type % role %', v_course.type_id, v_assignment.role;
  END IF;

  v_rate := current_rate(v_instructor.padi_level);

  -- Compute share based on assigned_for_dates
  v_total_dates := 1 + jsonb_array_length(COALESCE(v_course.additional_dates, '[]'::jsonb));
  v_assigned_dates := jsonb_array_length(COALESCE(v_assignment.assigned_for_dates, '[]'::jsonb));

  IF v_assigned_dates = 0 THEN
    -- Empty array means "all dates"
    v_share := 1;
    v_assigned_dates := v_total_dates;
  ELSE
    v_share := v_assigned_dates::numeric / v_total_dates;
  END IF;

  v_amount := round((v_units.total_h * v_share * v_rate)::numeric, 2);

  v_breakdown := jsonb_build_object(
    'course_type_code', (SELECT code FROM course_types WHERE id = v_course.type_id),
    'course_id',        v_course.id,
    'role',             v_assignment.role,
    'padi_level',       v_instructor.padi_level,
    'theory_h',         v_units.theory_h,
    'pool_h',           v_units.pool_h,
    'lake_h',           v_units.lake_h,
    'total_h',          round((v_units.total_h * v_share)::numeric, 2),
    'share',            round(v_share, 4),
    'total_dates',      v_total_dates,
    'assigned_dates',   v_assigned_dates,
    'hourly_rate',      v_rate,
    'amount_chf',       v_amount,
    'calculated_at',    now()
  );

  RETURN v_breakdown;
END;
$$;

COMMENT ON FUNCTION calc_compensation IS
  'Pure: computes compensation breakdown for an assignment. Does NOT write.';
