-- 0113_v_contact_balance.sql
-- ─────────────────────────────────────────────────────────────────
-- Phase G Foundation: Saldo-View für unified Contacts.
-- Sibling zu v_instructor_balance (0014/0039) — Logik 1:1 portiert,
-- aber JOIN über contacts statt instructors. account_movements.instructor_id
-- speichert UUIDs die auch in contacts(id) leben (Phase F1 unified ID-Space).
-- Legacy v_instructor_balance bleibt vorerst — Edge-Functions lesen noch davon.
-- Spec: §5.2 Stat-Band "Saldo". Audit-Doc §3.
-- ─────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW public.v_contact_balance AS
SELECT
  c.id                  AS contact_id,
  c.display_name,
  ci.padi_level,
  COALESCE(SUM(
    CASE
      WHEN am.ref_assignment_id IS NULL THEN am.amount_chf
      WHEN cr.status = 'completed'      THEN am.amount_chf
      ELSE 0
    END
  ), 0)::NUMERIC(10,2)  AS balance_chf,
  MAX(
    CASE
      WHEN am.ref_assignment_id IS NULL THEN am.date
      WHEN cr.status = 'completed'      THEN am.date
      ELSE NULL
    END
  ) AS last_movement_date,
  COUNT(
    CASE
      WHEN am.ref_assignment_id IS NULL THEN am.id
      WHEN cr.status = 'completed'      THEN am.id
      ELSE NULL
    END
  ) AS movement_count
FROM public.contacts c
JOIN public.contact_instructor ci ON ci.contact_id = c.id
LEFT JOIN public.account_movements  am ON am.instructor_id      = c.id
LEFT JOIN public.course_assignments ca ON ca.id                 = am.ref_assignment_id
LEFT JOIN public.courses            cr ON cr.id                 = ca.course_id
GROUP BY c.id, c.display_name, ci.padi_level;

ALTER VIEW public.v_contact_balance SET (security_invoker = on);
GRANT SELECT ON public.v_contact_balance TO authenticated;

-- v_instructor_balance bleibt unangetastet (legacy Edge-Functions).
-- Deprecation-Marker:
COMMENT ON VIEW public.v_instructor_balance IS
  'DEPRECATED — use v_contact_balance. Kept for legacy Edge-Functions still reading via instructor_id.';
