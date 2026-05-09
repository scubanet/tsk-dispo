-- 0085: Fix merge_contacts — correct FK column names throughout
--
-- The original 0081 version had wrong column names:
--   • communication_entries used "person_id" and "instructor_id" — actual cols are
--     "contact_id" (→ people) and "created_by" (→ instructors)
--   • intake_checklists used "person_id" — actual cols are "student_id" (→ people)
--     and "checked_by_id" (→ instructors)
--   • course_participants used "person_id" — actual col is "student_id" (→ people)
--   • Missing tables: elearning_progress, performance_records, student_certifications,
--     device_tokens, import_logs, courses (created_by), account_movements (created_by),
--     course_participants.certified_by_instructor_id
--
-- FK note: at the time this runs, consumer columns still reference the legacy tables
-- (instructors/people/organizations). Since sync triggers keep contacts ↔ legacy in
-- sync, p_winner exists in both contacts and the legacy table, so FK checks pass.

CREATE OR REPLACE FUNCTION public.merge_contacts(p_winner UUID, p_loser UUID)
RETURNS VOID AS $$
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

  -- Capture loser's roles before they're cleared
  SELECT roles INTO v_loser_roles FROM contacts WHERE id = p_loser;

  -- ── FKs that reference instructors(id) ─────────────────────────────────────
  UPDATE course_assignments         SET instructor_id  = p_winner WHERE instructor_id  = p_loser;
  UPDATE account_movements          SET instructor_id  = p_winner WHERE instructor_id  = p_loser;
  UPDATE account_movements          SET created_by     = p_winner WHERE created_by     = p_loser;
  UPDATE instructor_skills          SET instructor_id  = p_winner WHERE instructor_id  = p_loser;
  UPDATE availability_blocks        SET instructor_id  = p_winner WHERE instructor_id  = p_loser;
  UPDATE communication_entries      SET created_by     = p_winner WHERE created_by     = p_loser;
  UPDATE device_tokens              SET instructor_id  = p_winner WHERE instructor_id  = p_loser;
  UPDATE intake_checklists          SET checked_by_id  = p_winner WHERE checked_by_id  = p_loser;
  UPDATE performance_records        SET assessed_by_id = p_winner WHERE assessed_by_id = p_loser;
  UPDATE course_participants        SET certified_by_instructor_id = p_winner WHERE certified_by_instructor_id = p_loser;
  UPDATE import_logs                SET triggered_by   = p_winner WHERE triggered_by   = p_loser;
  UPDATE courses                    SET created_by     = p_winner WHERE created_by     = p_loser;

  -- ── FKs that reference people(id) ──────────────────────────────────────────
  UPDATE course_participants        SET student_id = p_winner WHERE student_id = p_loser;
  UPDATE elearning_progress         SET student_id = p_winner WHERE student_id = p_loser;
  UPDATE intake_checklists          SET student_id = p_winner WHERE student_id = p_loser;
  UPDATE performance_records        SET student_id = p_winner WHERE student_id = p_loser;
  UPDATE student_certifications     SET student_id = p_winner WHERE student_id = p_loser;
  UPDATE communication_entries      SET contact_id = p_winner WHERE contact_id = p_loser;

  -- ── FKs that reference organizations(id) ───────────────────────────────────
  UPDATE people                     SET organization_id = p_winner WHERE organization_id = p_loser;

  -- ── contact_relationships (new contacts schema, 0079) ──────────────────────
  UPDATE contact_relationships
     SET from_contact_id = p_winner
   WHERE from_contact_id = p_loser
     AND to_contact_id   <> p_winner;

  UPDATE contact_relationships
     SET to_contact_id = p_winner
   WHERE to_contact_id   = p_loser
     AND from_contact_id <> p_winner;

  -- Drop self-relationships that would emerge after merge
  DELETE FROM contact_relationships
   WHERE (from_contact_id = p_loser AND to_contact_id = p_winner)
      OR (from_contact_id = p_winner AND to_contact_id = p_loser);

  -- ── Mark loser as merged-into the winner + archive ─────────────────────────
  UPDATE contacts
     SET merged_into_id = p_winner,
         archived_at    = now()
   WHERE id = p_loser;

  -- ── Combine roles (winner keeps own + loser's, deduplicated) ───────────────
  UPDATE contacts
     SET roles = ARRAY(SELECT DISTINCT unnest(roles || v_loser_roles))
   WHERE id = p_winner;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.merge_contacts IS
  'Merges loser into winner: migrates all FKs (student_id, checked_by_id, assessed_by_id, '
  'certified_by_instructor_id, contact_id, created_by, triggered_by, etc.), archives loser, '
  'combines roles. Irreversible. Fixed in 0085 (0081 had wrong column names).';
