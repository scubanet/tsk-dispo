-- 0093: Phase J Etappe 3c — Legacy-Tabellen droppen
--
-- Nach 0092 (Pre-Drop Cleanup) sind alle Abhängigkeiten von people +
-- organizations bereinigt. CASCADE räumt nur noch die direkten Trigger
-- auf people weg:
--   • trg_sync_student_name           → Function in 0092 gedroppt
--   • trg_sync_pipeline_stage_changed → Function in 0092 gedroppt
--   • trg_students_updated_at         → Function set_updated_at bleibt (shared)
--
-- instructors bleibt vorerst — Edge-Functions (excel-import,
-- send-assignment-notification, send-notification, weekly-export) und
-- iOS-Auth (apps/ios-native/ATOLL/Services/AuthState.swift) lesen noch davon.
-- Separates Cleanup-Ticket nach Edge-Function- + iOS-Migration.

DROP TABLE IF EXISTS public.people         CASCADE;
DROP TABLE IF EXISTS public.organizations  CASCADE;

-- Sanity-Check als Kommentar:
--   SELECT to_regclass('public.people'), to_regclass('public.organizations');
-- beide sollen NULL liefern nach diesem Apply.
