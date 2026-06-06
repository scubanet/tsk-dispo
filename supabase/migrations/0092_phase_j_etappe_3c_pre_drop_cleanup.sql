-- 0092: Phase J Etappe 3c — Pre-Drop Cleanup für people + organizations
--
-- Bereitet 0093 (DROP TABLE) vor, indem alle Abhängigkeiten von people/organizations
-- bereinigt oder umgelenkt werden:
--   1. FK-Validation (no orphans referencing people.id)
--   2. 6 FKs von people(id) → contacts(id) umlenken (selbe UUIDs seit 0080)
--   3. public.students-View droppen (war Convenience-SELECT auf people)
--   4. merge_contacts-Funktion: people-Ref entfernen
--   5. Orphan'd Sync-Functions (sync_people_to_contacts, sync_instructors_to_contacts)
--      und partial-Sync-Trigger-Functions (sync_first_last_name, sync_pipeline_stage_changed)
--      droppen — set_updated_at NICHT (shared)
--
-- Etappe 3c ist limited scope: instructors-Tabelle bleibt vorerst (Edge-Functions
-- + iOS-Auth lesen noch davon — separates Cleanup-Ticket).

-- ────────────────────────────────────────────────────────────────────────────
-- 1. FK-Validation: gibt es Zeilen, die auf people.id zeigen, deren ID aber
--    nicht in contacts existiert? Falls ja, würde das FK-Re-Target scheitern.
-- ────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
  v_orphans INTEGER;
BEGIN
  SELECT
    (SELECT count(*) FROM communication_entries ce
       LEFT JOIN contacts c ON c.id = ce.contact_id
       WHERE ce.contact_id IS NOT NULL AND c.id IS NULL)
    + (SELECT count(*) FROM course_participants cp
       LEFT JOIN contacts c ON c.id = cp.student_id
       WHERE cp.student_id IS NOT NULL AND c.id IS NULL)
    + (SELECT count(*) FROM elearning_progress ep
       LEFT JOIN contacts c ON c.id = ep.student_id
       WHERE ep.student_id IS NOT NULL AND c.id IS NULL)
    + (SELECT count(*) FROM intake_checklists ic
       LEFT JOIN contacts c ON c.id = ic.student_id
       WHERE ic.student_id IS NOT NULL AND c.id IS NULL)
    + (SELECT count(*) FROM performance_records pr
       LEFT JOIN contacts c ON c.id = pr.student_id
       WHERE pr.student_id IS NOT NULL AND c.id IS NULL)
    + (SELECT count(*) FROM student_certifications sc
       LEFT JOIN contacts c ON c.id = sc.student_id
       WHERE sc.student_id IS NOT NULL AND c.id IS NULL)
  INTO v_orphans;

  IF v_orphans > 0 THEN
    RAISE EXCEPTION '0092 abort: % rows reference people.id but not contacts.id — manual cleanup required', v_orphans;
  END IF;
END $$;

-- ────────────────────────────────────────────────────────────────────────────
-- 2. FK-Constraints umlenken people(id) → contacts(id)
-- ────────────────────────────────────────────────────────────────────────────

-- communication_entries.contact_id (ON DELETE CASCADE)
ALTER TABLE public.communication_entries
  DROP CONSTRAINT IF EXISTS communication_entries_contact_id_fkey;
ALTER TABLE public.communication_entries
  ADD CONSTRAINT communication_entries_contact_id_fkey
  FOREIGN KEY (contact_id) REFERENCES public.contacts(id) ON DELETE CASCADE;

-- course_participants.student_id (ON DELETE RESTRICT)
ALTER TABLE public.course_participants
  DROP CONSTRAINT IF EXISTS course_participants_student_id_fkey;
ALTER TABLE public.course_participants
  ADD CONSTRAINT course_participants_student_id_fkey
  FOREIGN KEY (student_id) REFERENCES public.contacts(id) ON DELETE RESTRICT;

-- elearning_progress.student_id (ON DELETE CASCADE)
ALTER TABLE public.elearning_progress
  DROP CONSTRAINT IF EXISTS elearning_progress_student_id_fkey;
ALTER TABLE public.elearning_progress
  ADD CONSTRAINT elearning_progress_student_id_fkey
  FOREIGN KEY (student_id) REFERENCES public.contacts(id) ON DELETE CASCADE;

-- intake_checklists.student_id (ON DELETE CASCADE)
ALTER TABLE public.intake_checklists
  DROP CONSTRAINT IF EXISTS intake_checklists_student_id_fkey;
ALTER TABLE public.intake_checklists
  ADD CONSTRAINT intake_checklists_student_id_fkey
  FOREIGN KEY (student_id) REFERENCES public.contacts(id) ON DELETE CASCADE;

-- performance_records.student_id (ON DELETE CASCADE)
ALTER TABLE public.performance_records
  DROP CONSTRAINT IF EXISTS performance_records_student_id_fkey;
ALTER TABLE public.performance_records
  ADD CONSTRAINT performance_records_student_id_fkey
  FOREIGN KEY (student_id) REFERENCES public.contacts(id) ON DELETE CASCADE;

-- student_certifications.student_id (ON DELETE CASCADE)
ALTER TABLE public.student_certifications
  DROP CONSTRAINT IF EXISTS student_certifications_student_id_fkey;
ALTER TABLE public.student_certifications
  ADD CONSTRAINT student_certifications_student_id_fkey
  FOREIGN KEY (student_id) REFERENCES public.contacts(id) ON DELETE CASCADE;

-- ────────────────────────────────────────────────────────────────────────────
-- 3. public.students-View droppen
-- ────────────────────────────────────────────────────────────────────────────
-- War ein straight SELECT auf people. Frontend liest seit Phase J Etappe 3a
-- via listStudents (contacts JOIN contact_student). View wird nicht mehr
-- benötigt.
DROP VIEW IF EXISTS public.students;

-- ────────────────────────────────────────────────────────────────────────────
-- 4. merge_contacts neu definieren — ohne people-Referenz
-- ────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.merge_contacts(p_winner uuid, p_loser uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_loser_roles TEXT[];
BEGIN
  IF p_winner = p_loser THEN
    RAISE EXCEPTION 'Cannot merge contact with itself';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM contacts WHERE id = p_winner) THEN
    RAISE EXCEPTION 'Winner contact % not found', p_winner;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM contacts WHERE id = p_loser) THEN
    RAISE EXCEPTION 'Loser contact % not found', p_loser;
  END IF;
  SELECT roles INTO v_loser_roles FROM contacts WHERE id = p_loser;

  -- ── FKs that reference instructors(id) — instructors-Tabelle bleibt
  -- vorerst (Edge-Functions + iOS-Auth) ─────────────────────────────────────
  UPDATE course_assignments         SET instructor_id              = p_winner WHERE instructor_id              = p_loser;
  UPDATE account_movements          SET instructor_id              = p_winner WHERE instructor_id              = p_loser;
  UPDATE account_movements          SET created_by                 = p_winner WHERE created_by                 = p_loser;
  UPDATE instructor_skills          SET instructor_id              = p_winner WHERE instructor_id              = p_loser;
  UPDATE availability               SET instructor_id              = p_winner WHERE instructor_id              = p_loser;
  UPDATE communication_entries      SET created_by                 = p_winner WHERE created_by                 = p_loser;
  UPDATE device_tokens              SET instructor_id              = p_winner WHERE instructor_id              = p_loser;
  UPDATE intake_checklists          SET checked_by_id              = p_winner WHERE checked_by_id              = p_loser;
  UPDATE performance_records        SET assessed_by_id             = p_winner WHERE assessed_by_id             = p_loser;
  UPDATE course_participants        SET certified_by_instructor_id = p_winner WHERE certified_by_instructor_id = p_loser;
  UPDATE import_logs                SET triggered_by               = p_winner WHERE triggered_by               = p_loser;
  UPDATE courses                    SET created_by                 = p_winner WHERE created_by                 = p_loser;

  -- ── FKs that referenced people(id) — jetzt auf contacts(id) gemappt ──────
  UPDATE course_participants    SET student_id = p_winner WHERE student_id = p_loser;
  UPDATE elearning_progress     SET student_id = p_winner WHERE student_id = p_loser;
  UPDATE intake_checklists      SET student_id = p_winner WHERE student_id = p_loser;
  UPDATE performance_records    SET student_id = p_winner WHERE student_id = p_loser;
  UPDATE student_certifications SET student_id = p_winner WHERE student_id = p_loser;
  UPDATE communication_entries  SET contact_id = p_winner WHERE contact_id = p_loser;

  -- (entfernt: UPDATE people SET organization_id — Tabelle wird in 0093 gedroppt;
  -- Org-Beziehungen leben jetzt in contact_relationships kind='works_at'.)

  -- ── contact_relationships ─────────────────────────────────────────────────
  UPDATE contact_relationships
     SET from_contact_id = p_winner
   WHERE from_contact_id = p_loser AND to_contact_id <> p_winner;
  UPDATE contact_relationships
     SET to_contact_id   = p_winner
   WHERE to_contact_id   = p_loser AND from_contact_id <> p_winner;
  DELETE FROM contact_relationships
   WHERE (from_contact_id = p_loser AND to_contact_id = p_winner)
      OR (from_contact_id = p_winner AND to_contact_id = p_loser);

  UPDATE contacts
     SET merged_into_id = p_winner, archived_at = now()
   WHERE id = p_loser;
  UPDATE contacts
     SET roles = ARRAY(SELECT DISTINCT unnest(roles || v_loser_roles))
   WHERE id = p_winner;
END;
$function$;

-- ────────────────────────────────────────────────────────────────────────────
-- 5. Orphan'd Sync-Functions droppen + partial-sync trigger-functions
-- ────────────────────────────────────────────────────────────────────────────

-- Orphan'd Forward-Sync-Functions aus 0083 (Triggers waren bereits gedroppt;
-- bestätigt durch Pre-Flight in Etappe 3a)
-- FIX (db reset): Auf einem frischen Reset hängen die Forward-Sync-Trigger
-- (trg_sync_people_to_contacts auf people, trg_sync_instructors_to_contacts auf
-- instructors) noch an diesen Functions (0091 hat sie hier nicht gedroppt).
-- CASCADE entfernt die Trigger gleich mit — entspricht der Phase-J-Absicht.
DROP FUNCTION IF EXISTS public.sync_people_to_contacts() CASCADE;
DROP FUNCTION IF EXISTS public.sync_instructors_to_contacts() CASCADE;

-- Partial-sync trigger functions auf people — die Triggers selbst gehen mit
-- der Tabelle in 0093 weg, aber die Functions würden als Leichen bleiben.
DROP FUNCTION IF EXISTS public.sync_first_last_name() CASCADE;
DROP FUNCTION IF EXISTS public.sync_pipeline_stage_changed() CASCADE;

-- NOTE: set_updated_at NICHT droppen — shared mit allen *_updated_at triggers
-- auf contact_*, courses, etc.

-- Final state nach 0092:
--   • Frontend-FKs zeigen auf contacts(id), nicht mehr people(id)
--   • students-View weg
--   • merge_contacts berührt people nicht mehr
--   • orphan'd Functions weg
--   • people-Tabelle ist jetzt nur noch ein Daten-Ghost (Triggers + Daten),
--     der in 0093 sauber gedroppt werden kann
