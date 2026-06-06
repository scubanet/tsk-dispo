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
-- VERSCHOBEN (2026-06-06): Der Seed nutzt den oben frisch hinzugefügten
-- ENUM-Wert 'opfer'. Postgres verbietet die Verwendung eines neuen Enum-Werts
-- in derselben Transaction (SQLSTATE 55P04), weshalb diese Migration früher nur
-- manuell im SQL-Editor lief. Damit `supabase db reset` (transaktional, je
-- Datei) sauber durchläuft, liegt der Seed jetzt in der Folgemigration
-- 20260606000000_seed_opfer_comp_units.sql, die nach dem Commit dieses ALTER
-- TYPE ausgeführt wird. Inhalt unverändert + idempotent.
