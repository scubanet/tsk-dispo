-- 0081: Contacts RPCs (duplicate detection, merge, GDPR anonymisation)

-- Find potential duplicates by email/phone/name+birth
CREATE OR REPLACE FUNCTION public.find_potential_duplicates(p_contact_id UUID)
RETURNS TABLE(
  candidate_id UUID,
  match_reason TEXT,
  display_name TEXT
) AS $$
DECLARE
  v_self contacts%ROWTYPE;
BEGIN
  SELECT * INTO v_self FROM contacts WHERE id = p_contact_id;
  IF NOT FOUND THEN RETURN; END IF;

  -- Same email
  RETURN QUERY
    SELECT c.id, ('email match: ' || v_self.primary_email)::TEXT, c.display_name
    FROM contacts c
    WHERE c.id <> p_contact_id
      AND c.archived_at IS NULL
      AND v_self.primary_email IS NOT NULL
      AND lower(c.primary_email) = lower(v_self.primary_email);

  -- Same phone (any of the JSON entries)
  RETURN QUERY
    SELECT DISTINCT c.id, 'phone match'::TEXT, c.display_name
    FROM contacts c, jsonb_array_elements(v_self.phones) p_self,
         jsonb_array_elements(c.phones) p_other
    WHERE c.id <> p_contact_id
      AND c.archived_at IS NULL
      AND p_self->>'e164' IS NOT NULL
      AND p_self->>'e164' = p_other->>'e164';

  -- Same name + birth_date (persons only)
  IF v_self.kind = 'person' THEN
    RETURN QUERY
      SELECT c.id, 'name + birth match'::TEXT, c.display_name
      FROM contacts c
      WHERE c.id <> p_contact_id
        AND c.kind = 'person'
        AND c.archived_at IS NULL
        AND lower(c.first_name) = lower(v_self.first_name)
        AND lower(c.last_name)  = lower(v_self.last_name)
        AND v_self.birth_date IS NOT NULL
        AND c.birth_date = v_self.birth_date;
  END IF;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Merge two contacts: winner keeps id, loser's FKs migrate to winner
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

  -- Migrate FKs in every consumer table
  UPDATE course_assignments      SET instructor_id = p_winner WHERE instructor_id = p_loser;
  UPDATE course_participants     SET person_id     = p_winner WHERE person_id     = p_loser;
  UPDATE account_movements       SET instructor_id = p_winner WHERE instructor_id = p_loser;
  UPDATE communication_entries   SET person_id     = p_winner WHERE person_id     = p_loser;
  UPDATE communication_entries   SET instructor_id = p_winner WHERE instructor_id = p_loser;
  UPDATE instructor_skills       SET instructor_id = p_winner WHERE instructor_id = p_loser;
  UPDATE availability_blocks     SET instructor_id = p_winner WHERE instructor_id = p_loser;
  UPDATE intake_checklists       SET person_id     = p_winner WHERE person_id     = p_loser;

  UPDATE contact_relationships
     SET from_contact_id = p_winner
   WHERE from_contact_id = p_loser
     AND to_contact_id <> p_winner;
  UPDATE contact_relationships
     SET to_contact_id = p_winner
   WHERE to_contact_id = p_loser
     AND from_contact_id <> p_winner;
  -- Drop self-relationships that would emerge after merge
  DELETE FROM contact_relationships
   WHERE (from_contact_id = p_loser AND to_contact_id = p_winner)
      OR (from_contact_id = p_winner AND to_contact_id = p_loser);

  -- Mark loser as merged-into the winner + archive
  UPDATE contacts
     SET merged_into_id = p_winner,
         archived_at    = now()
   WHERE id = p_loser;

  -- Combine roles (winner keeps own + loser's, deduplicated)
  UPDATE contacts
     SET roles = ARRAY(SELECT DISTINCT unnest(roles || v_loser_roles))
   WHERE id = p_winner;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- GDPR anonymisation: replace PII, keep id + activity history
CREATE OR REPLACE FUNCTION public.gdpr_anonymize_contact(p_contact_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE contacts
     SET first_name   = 'Gelöscht',
         last_name    = '#' || substr(id::text, 1, 8),
         legal_name   = CASE WHEN kind = 'organization'
                             THEN 'Gelöschte Organisation #' || substr(id::text, 1, 8)
                             ELSE NULL END,
         trading_name = NULL,
         birth_date   = NULL,
         gender       = NULL,
         primary_email = NULL,
         emails       = '[]'::jsonb,
         phones       = '[]'::jsonb,
         addresses    = '[]'::jsonb,
         notes        = NULL,
         tags         = '{}',
         consent_marketing = false,
         archived_at  = now()
   WHERE id = p_contact_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION find_potential_duplicates IS
  'Returns contacts that may be duplicates of the given one (email/phone/name+birth match).';
COMMENT ON FUNCTION merge_contacts IS
  'Merges loser into winner: migrates all FKs, archives loser, combines roles. Irreversible.';
COMMENT ON FUNCTION gdpr_anonymize_contact IS
  'GDPR Art. 17 — replaces PII with placeholders, keeps id + activity history for accounting.';
