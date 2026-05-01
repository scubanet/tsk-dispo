-- Helper: get the instructor row for the currently authenticated user
CREATE OR REPLACE FUNCTION current_instructor()
RETURNS instructors
LANGUAGE SQL STABLE SECURITY DEFINER AS $$
  SELECT * FROM instructors WHERE auth_user_id = auth.uid() LIMIT 1
$$;

CREATE OR REPLACE FUNCTION is_dispatcher()
RETURNS BOOLEAN
LANGUAGE SQL STABLE SECURITY DEFINER AS $$
  SELECT EXISTS (
    SELECT 1 FROM instructors
    WHERE auth_user_id = auth.uid() AND role = 'dispatcher'
  )
$$;

-- Enable RLS on every table
ALTER TABLE instructors          ENABLE ROW LEVEL SECURITY;
ALTER TABLE skills               ENABLE ROW LEVEL SECURITY;
ALTER TABLE instructor_skills    ENABLE ROW LEVEL SECURITY;
ALTER TABLE availability         ENABLE ROW LEVEL SECURITY;
ALTER TABLE course_types         ENABLE ROW LEVEL SECURITY;
ALTER TABLE courses              ENABLE ROW LEVEL SECURITY;
ALTER TABLE course_assignments   ENABLE ROW LEVEL SECURITY;
ALTER TABLE pool_bookings        ENABLE ROW LEVEL SECURITY;
ALTER TABLE comp_rates           ENABLE ROW LEVEL SECURITY;
ALTER TABLE comp_units           ENABLE ROW LEVEL SECURITY;
ALTER TABLE account_movements    ENABLE ROW LEVEL SECURITY;
ALTER TABLE import_logs          ENABLE ROW LEVEL SECURITY;

-- Policies: instructors (read all, write own, dispatcher all)
CREATE POLICY instructors_read_all       ON instructors FOR SELECT USING (true);
CREATE POLICY instructors_write_own      ON instructors FOR UPDATE USING (auth_user_id = auth.uid());
CREATE POLICY instructors_dispatcher_all ON instructors FOR ALL    USING (is_dispatcher());

-- Skills + instructor_skills: read all, dispatcher writes
CREATE POLICY skills_read_all            ON skills FOR SELECT USING (true);
CREATE POLICY skills_dispatcher_all      ON skills FOR ALL    USING (is_dispatcher());

CREATE POLICY iskills_read_all           ON instructor_skills FOR SELECT USING (true);
CREATE POLICY iskills_dispatcher_all     ON instructor_skills FOR ALL    USING (is_dispatcher());

-- Availability: read all, write own; dispatcher all
CREATE POLICY availability_read_all       ON availability FOR SELECT USING (true);
CREATE POLICY availability_write_own      ON availability FOR ALL
  USING (instructor_id = (SELECT id FROM current_instructor()));
CREATE POLICY availability_dispatcher_all ON availability FOR ALL USING (is_dispatcher());

-- Courses: read all, dispatcher writes
CREATE POLICY courses_read_all            ON courses FOR SELECT USING (true);
CREATE POLICY courses_dispatcher_all      ON courses FOR ALL    USING (is_dispatcher());

-- Course assignments: read all, dispatcher writes
CREATE POLICY assignments_read_all        ON course_assignments FOR SELECT USING (true);
CREATE POLICY assignments_dispatcher_all  ON course_assignments FOR ALL    USING (is_dispatcher());

-- Pool bookings: read all, dispatcher writes
CREATE POLICY pool_read_all               ON pool_bookings FOR SELECT USING (true);
CREATE POLICY pool_dispatcher_all         ON pool_bookings FOR ALL    USING (is_dispatcher());

-- Course types, comp_rates, comp_units: read all, dispatcher writes
CREATE POLICY ctypes_read_all             ON course_types FOR SELECT USING (true);
CREATE POLICY ctypes_dispatcher_all       ON course_types FOR ALL    USING (is_dispatcher());

CREATE POLICY crates_read_all             ON comp_rates FOR SELECT USING (true);
CREATE POLICY crates_dispatcher_all       ON comp_rates FOR ALL    USING (is_dispatcher());

CREATE POLICY cunits_read_all             ON comp_units FOR SELECT USING (true);
CREATE POLICY cunits_dispatcher_all       ON comp_units FOR ALL    USING (is_dispatcher());

-- Account movements: PRIVATE — instructor sees own, dispatcher sees all
-- Note: only SELECT is exposed to instructors. INSERT/UPDATE/DELETE are denied
-- by default (RLS default-deny). This is intentional — Saldo-Bewegungen werden
-- ausschließlich vom Trigger geschrieben, nicht direkt vom User.
-- Combined with the immutability trigger (block_account_movement_update),
-- this gives us audit-grade integrity: even a dispatcher cannot edit history.
CREATE POLICY movements_read_own          ON account_movements FOR SELECT
  USING (instructor_id = (SELECT id FROM current_instructor()));
CREATE POLICY movements_dispatcher_all    ON account_movements FOR ALL USING (is_dispatcher());

-- Import logs: dispatcher only
CREATE POLICY import_logs_dispatcher      ON import_logs FOR ALL USING (is_dispatcher());
