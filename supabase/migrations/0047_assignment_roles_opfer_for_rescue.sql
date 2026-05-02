-- Roles cleanup: 'dmt' wird durch 'assist' ersetzt (war nicht klar definiert).
-- Neu: 'opfer' Rolle für Rescue-Kurse mit fixer 1.5-Punkte Vergütung.
--
-- HINWEIS: ALTER TYPE ADD VALUE kann nicht in einer Transaction laufen.
-- Daher diese Migration manuell im Supabase SQL Editor ausführen, NICHT
-- über `supabase db push` (das würde transaktional fehlschlagen).
--
-- Schritte:
--   1. Neue ENUM-Value 'opfer' hinzufügen
--   2. Bestehende dmt-Assignments → assist (dmt bleibt im ENUM aber wird nirgends mehr verwendet)
--   3. comp_units-Eintrag für RESC × opfer mit 1.5 lake_h einfügen

-- =============================================================
-- 1. ENUM erweitern
-- =============================================================

ALTER TYPE assignment_role ADD VALUE IF NOT EXISTS 'opfer';

-- =============================================================
-- 2. dmt-Assignments migrieren
-- =============================================================
-- Wer als 'dmt' in einem Kurs zugewiesen war, wird zu 'assist'.
-- Bestehende vergütung-Bewegungen bleiben unangetastet (wären zu komplex
-- automatisch zu recalcen — ggf. nachträglich via Recalc-Button im Settings).

UPDATE course_assignments
SET role = 'assist'
WHERE role = 'dmt';

-- =============================================================
-- 3. comp_units für Opfer in Rescue-Kursen
-- =============================================================
-- Opfer kriegt 1.5 Punkte pro Rescue-Kurs (in der See-Phase, da dort
-- die Szenarios mit Opfer-Spielenden stattfinden).
--
-- ON CONFLICT: falls schon vorhanden (idempotent).

INSERT INTO comp_units (course_type_id, role, theory_h, pool_h, lake_h)
SELECT id, 'opfer'::assignment_role, 0, 0, 1.5
FROM course_types
WHERE code = 'RESC'
ON CONFLICT (course_type_id, role) DO UPDATE
  SET theory_h = 0, pool_h = 0, lake_h = 1.5;
