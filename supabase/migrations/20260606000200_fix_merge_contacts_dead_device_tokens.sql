-- 20260606000200_fix_merge_contacts_dead_device_tokens.sql
--
-- ECHTER (latenter) PROD-BUG. public.merge_contacts (zuletzt definiert in
-- 20260604130000_security_lockdown_anon_rpcs_and_contacts.sql) enthält die Zeile
--
--     UPDATE device_tokens SET instructor_id = p_winner WHERE instructor_id = p_loser;
--
-- Die Tabelle `device_tokens` existiert im Endschema NICHT mehr:
--   • 0099 hat sie als auth.users-keyed neu gebaut (ohne Spalte instructor_id),
--   • 0108 hat sie in `atollcard_device_tokens` umbenannt.
-- Weil merge_contacts plpgsql ist, validiert Postgres den Rumpf erst zur Laufzeit
-- (nicht beim CREATE). Die Migration läuft daher sauber durch, aber JEDER Aufruf
-- von merge_contacts (Kontakt-Dedup-UI) scheitert mit
--   ERROR: relation "device_tokens" does not exist.
-- Die Funktion ist seit der device_tokens-Umbenennung produktiv unbenutzbar;
-- auffällig nur, weil der pgTAP-Test contacts_merge die einzige aufrufende Stelle ist.
--
-- FIX: merge_contacts identisch neu definieren — inkl. des Security-Guards und
-- SET search_path aus dem Lockdown — nur ohne die tote device_tokens-Zeile.
-- atollcard_device_tokens ist auth.users-keyed (kein instructor_id); beim Mergen
-- zweier Kontakte gibt es dort nichts umzuhängen, die Zeile war seit 0099/0108
-- gegenstandslos. CREATE OR REPLACE erhält die bestehenden EXECUTE-Grants
-- (authenticated + service_role) aus dem Lockdown.

CREATE OR REPLACE FUNCTION public.merge_contacts(p_winner uuid, p_loser uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_loser_roles TEXT[];
BEGIN
  IF NOT (public.is_dispatcher() OR public.is_owner()) THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;

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

  UPDATE course_assignments         SET instructor_id              = p_winner WHERE instructor_id              = p_loser;
  UPDATE account_movements          SET instructor_id              = p_winner WHERE instructor_id              = p_loser;
  UPDATE account_movements          SET created_by                 = p_winner WHERE created_by                 = p_loser;
  UPDATE instructor_skills          SET instructor_id              = p_winner WHERE instructor_id              = p_loser;
  UPDATE availability               SET instructor_id              = p_winner WHERE instructor_id              = p_loser;
  UPDATE communication_entries      SET created_by                 = p_winner WHERE created_by                 = p_loser;
  -- (entfernt: UPDATE device_tokens SET instructor_id … — Tabelle existiert nicht
  --  mehr: 0099 auth-keyed neu, 0108 → atollcard_device_tokens. War der Prod-Bug.)
  UPDATE intake_checklists          SET checked_by_id              = p_winner WHERE checked_by_id              = p_loser;
  UPDATE performance_records        SET assessed_by_id             = p_winner WHERE assessed_by_id             = p_loser;
  UPDATE course_participants        SET certified_by_instructor_id = p_winner WHERE certified_by_instructor_id = p_loser;
  UPDATE import_logs                SET triggered_by               = p_winner WHERE triggered_by               = p_loser;
  UPDATE courses                    SET created_by                 = p_winner WHERE created_by                 = p_loser;

  UPDATE course_participants    SET student_id = p_winner WHERE student_id = p_loser;
  UPDATE elearning_progress     SET student_id = p_winner WHERE student_id = p_loser;
  UPDATE intake_checklists      SET student_id = p_winner WHERE student_id = p_loser;
  UPDATE performance_records    SET student_id = p_winner WHERE student_id = p_loser;
  UPDATE student_certifications SET student_id = p_winner WHERE student_id = p_loser;
  UPDATE communication_entries  SET contact_id = p_winner WHERE contact_id = p_loser;

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
