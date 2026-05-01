-- Returns conflicting assignments for a given (instructor, set of dates).
-- A conflict is "another assignment for this instructor on the same date(s)".
CREATE OR REPLACE FUNCTION conflict_check(
  p_instructor_id UUID,
  p_dates DATE[]
)
RETURNS TABLE (
  conflicting_course_id UUID,
  conflicting_course_title TEXT,
  conflicting_role assignment_role,
  conflict_dates DATE[]
)
LANGUAGE plpgsql STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT
    c.id,
    c.title,
    ca.role,
    ARRAY(
      SELECT DISTINCT d::date
      FROM unnest(p_dates) d
      WHERE d = c.start_date
         OR d::text IN (
           SELECT jsonb_array_elements_text(c.additional_dates)
         )
    ) AS conflict_dates
  FROM course_assignments ca
  JOIN courses c ON c.id = ca.course_id
  WHERE ca.instructor_id = p_instructor_id
    AND c.status <> 'cancelled'
    AND (
      c.start_date = ANY(p_dates)
      OR EXISTS (
        SELECT 1 FROM jsonb_array_elements_text(c.additional_dates) AS ad(d)
        WHERE ad.d::date = ANY(p_dates)
      )
    );
END;
$$;

COMMENT ON FUNCTION conflict_check IS
  'Returns courses on the same dates for a given instructor (excludes cancelled).';

GRANT EXECUTE ON FUNCTION conflict_check(UUID, DATE[]) TO authenticated;
