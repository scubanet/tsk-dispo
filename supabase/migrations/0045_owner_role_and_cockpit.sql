-- Owner-Rolle aktivieren + Cockpit-Dashboard für Owner und Dispatcher.
--
-- Bisher war 'owner' im role-ENUM aber funktional identisch zu 'instructor'.
-- Jetzt: Owner hat Read-All-Zugriff auf alle Operations-Daten + sieht das Cockpit.
-- Edit-Permissions bleiben weiterhin nur beim Dispatcher.

-- =============================================================
-- Helper Functions
-- =============================================================

CREATE OR REPLACE FUNCTION is_owner()
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM instructors
    WHERE auth_user_id = auth.uid() AND role = 'owner'
  );
$$;

CREATE OR REPLACE FUNCTION is_owner_or_dispatcher()
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM instructors
    WHERE auth_user_id = auth.uid() AND role IN ('owner', 'dispatcher')
  );
$$;

GRANT EXECUTE ON FUNCTION is_owner() TO authenticated;
GRANT EXECUTE ON FUNCTION is_owner_or_dispatcher() TO authenticated;

-- =============================================================
-- Owner Read-All Policies
-- =============================================================
-- Owner darf SELECT auf alle Tabellen haben (für's Cockpit + Read-Only-Views).
-- Tabellen wo "read_all" schon offen ist (course_types, comp_rates, etc.) brauchen nichts.
-- Tabellen wo's restricted ist (account_movements, instructors filtered) bekommen
-- eine zusätzliche Owner-SELECT-Policy.

-- account_movements: dispatcher sieht alle, instructor nur eigene → owner soll auch alle sehen
CREATE POLICY movements_owner_read ON account_movements FOR SELECT
  USING (is_owner());

-- instructors: row-level RLS hier eher schwach — falls eingeschränkt, hier öffnen
-- (instructors hat schon instructors_dispatcher_all für FOR ALL, plus implizite SELECT für eigene Person)
-- Owner braucht SELECT auf alle:
CREATE POLICY instructors_owner_read ON instructors FOR SELECT
  USING (is_owner());

-- students: dispatcher full, instructor sieht nichts → owner soll alle sehen
CREATE POLICY students_owner_read ON students FOR SELECT
  USING (is_owner());

-- course_assignments: ditto
CREATE POLICY assignments_owner_read ON course_assignments FOR SELECT
  USING (is_owner());

-- =============================================================
-- Cockpit Data RPC
-- =============================================================

CREATE OR REPLACE FUNCTION cockpit_data(p_start DATE, p_end DATE)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_kpis JSON;
  v_monthly JSON;
  v_top_tls JSON;
  v_pipeline JSON;
  v_attention JSON;
BEGIN
  IF NOT is_owner_or_dispatcher() THEN
    RAISE EXCEPTION 'Cockpit nur für Owner und Dispatcher.';
  END IF;

  -- KPIs für gewählten Zeitraum
  SELECT json_build_object(
    'payments_chf', COALESCE((
      SELECT SUM(am.amount_chf)
      FROM account_movements am
      JOIN course_assignments ca ON ca.id = am.ref_assignment_id
      JOIN courses c ON c.id = ca.course_id
      WHERE am.kind = 'vergütung'
        AND c.status = 'completed'
        AND am.date >= p_start AND am.date <= p_end
    ), 0),
    'payments_count', COALESCE((
      SELECT COUNT(*)
      FROM account_movements am
      JOIN course_assignments ca ON ca.id = am.ref_assignment_id
      JOIN courses c ON c.id = ca.course_id
      WHERE am.kind = 'vergütung'
        AND c.status = 'completed'
        AND am.date >= p_start AND am.date <= p_end
    ), 0),
    'courses_in_period', (
      SELECT COUNT(*) FROM courses
      WHERE start_date >= p_start AND start_date <= p_end
        AND status != 'cancelled'
    ),
    'active_instructors_in_period', (
      SELECT COUNT(DISTINCT ca.instructor_id) FROM course_assignments ca
      JOIN courses c ON c.id = ca.course_id
      WHERE c.start_date >= p_start AND c.start_date <= p_end
        AND c.status != 'cancelled'
    ),
    'total_active_instructors', (SELECT COUNT(*) FROM instructors WHERE active),
    'active_students',          (SELECT COUNT(*) FROM students WHERE active)
  ) INTO v_kpis;

  -- Monthly payments — letzte 12 Monate
  SELECT COALESCE(json_agg(row_to_json(m) ORDER BY m.month), '[]'::json)
  INTO v_monthly
  FROM (
    SELECT
      to_char(date_trunc('month', am.date), 'YYYY-MM') AS month,
      SUM(am.amount_chf)::numeric(10,2) AS total
    FROM account_movements am
    JOIN course_assignments ca ON ca.id = am.ref_assignment_id
    JOIN courses c ON c.id = ca.course_id
    WHERE am.kind = 'vergütung'
      AND c.status = 'completed'
      AND am.date >= (CURRENT_DATE - INTERVAL '12 months')
    GROUP BY date_trunc('month', am.date)
    ORDER BY date_trunc('month', am.date)
  ) m;

  -- Top-10 TLs nach Vergütung im Zeitraum
  SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)
  INTO v_top_tls
  FROM (
    SELECT
      i.id, i.name, i.padi_level, i.color, i.initials,
      SUM(am.amount_chf)::numeric(10,2) AS total_chf,
      COUNT(DISTINCT c.id) AS course_count
    FROM account_movements am
    JOIN instructors i ON i.id = am.instructor_id
    JOIN course_assignments ca ON ca.id = am.ref_assignment_id
    JOIN courses c ON c.id = ca.course_id
    WHERE am.kind = 'vergütung'
      AND c.status = 'completed'
      AND am.date >= p_start AND am.date <= p_end
    GROUP BY i.id, i.name, i.padi_level, i.color, i.initials
    ORDER BY total_chf DESC
    LIMIT 10
  ) t;

  -- Pipeline: heute / diese Woche / nächste 30 Tage
  SELECT json_build_object(
    'today', (
      SELECT COUNT(DISTINCT c.id) FROM courses c
      LEFT JOIN course_dates cd ON cd.course_id = c.id
      WHERE c.status IN ('confirmed', 'tentative')
        AND (c.start_date = CURRENT_DATE OR cd.date = CURRENT_DATE)
    ),
    'this_week', (
      SELECT COUNT(*) FROM courses
      WHERE start_date >= CURRENT_DATE
        AND start_date <  CURRENT_DATE + INTERVAL '7 days'
        AND status IN ('confirmed', 'tentative')
    ),
    'next_30_days', (
      SELECT COUNT(*) FROM courses
      WHERE start_date >= CURRENT_DATE
        AND start_date <  CURRENT_DATE + INTERVAL '30 days'
        AND status IN ('confirmed', 'tentative')
    )
  ) INTO v_pipeline;

  -- Achtung-Items
  SELECT json_build_object(
    'courses_without_haupt', (
      SELECT COUNT(*) FROM courses c
      WHERE c.status IN ('confirmed', 'tentative')
        AND c.start_date >= CURRENT_DATE
        AND NOT EXISTS (
          SELECT 1 FROM course_assignments ca
          WHERE ca.course_id = c.id AND ca.role = 'haupt'
        )
    ),
    'long_tentative', (
      SELECT COUNT(*) FROM courses
      WHERE status = 'tentative'
        AND start_date >= CURRENT_DATE
        AND start_date <= CURRENT_DATE + INTERVAL '30 days'
    ),
    'idle_instructors_6w', (
      SELECT COUNT(*) FROM instructors i
      WHERE i.active
        AND NOT EXISTS (
          SELECT 1 FROM course_assignments ca
          JOIN courses c ON c.id = ca.course_id
          WHERE ca.instructor_id = i.id
            AND c.start_date >= CURRENT_DATE - INTERVAL '6 weeks'
        )
    )
  ) INTO v_attention;

  RETURN json_build_object(
    'kpis',             v_kpis,
    'monthly_payments', v_monthly,
    'top_instructors',  v_top_tls,
    'pipeline',         v_pipeline,
    'attention',        v_attention
  );
END;
$$;

GRANT EXECUTE ON FUNCTION cockpit_data(DATE, DATE) TO authenticated;

COMMENT ON FUNCTION cockpit_data(DATE, DATE) IS
  'Liefert alle Daten für das Owner/Dispatcher-Cockpit in einem JSON-Blob. Period via p_start, p_end.';
