-- Returns instructors that have a given skill, ordered by least-recently assigned.
CREATE OR REPLACE FUNCTION skill_match(
  p_skill_codes TEXT[],
  p_for_dates DATE[]
)
RETURNS TABLE (
  instructor_id UUID,
  name TEXT,
  padi_level padi_level,
  has_conflict BOOLEAN,
  last_assigned DATE
)
LANGUAGE plpgsql STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT
    i.id,
    i.name,
    i.padi_level,
    EXISTS (
      SELECT 1 FROM conflict_check(i.id, p_for_dates)
    ) AS has_conflict,
    (SELECT MAX(c.start_date) FROM course_assignments ca
       JOIN courses c ON c.id = ca.course_id
       WHERE ca.instructor_id = i.id) AS last_assigned
  FROM instructors i
  WHERE i.active = true
    AND (
      array_length(p_skill_codes, 1) IS NULL
      OR EXISTS (
        SELECT 1 FROM instructor_skills isk
        JOIN skills s ON s.id = isk.skill_id
        WHERE isk.instructor_id = i.id
          AND s.code = ANY(p_skill_codes)
      )
    )
  ORDER BY has_conflict ASC, last_assigned ASC NULLS FIRST;
END;
$$;

GRANT EXECUTE ON FUNCTION skill_match(TEXT[], DATE[]) TO authenticated;
