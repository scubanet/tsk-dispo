-- 0091: Phase J Etappe 3a — Sidecar-Spalten für StudentEditSheet-Cutover
--
-- Ergänzt fehlende Spalten in contact_student + contact_instructor, sodass
-- der Frontend-Cutover von .from('people') auf .from('contacts') + Sidecars
-- alle bisherigen UI-Felder unterbringt.
--
-- Neue Spalten:
--   • contact_student.level             ← people.level (free-text)
--   • contact_student.photo_url         ← people.photo_url
--   • contact_student.organization_role ← people.organization_role
--   • contact_student.stage_changed_on  ← people.stage_changed_on (TIMESTAMPTZ wie Legacy)
--   • contact_instructor.initials       ← instructors.initials (Stretch für Etappe 3b)
--
-- Nicht ergänzt: contact_student.padi_pro_number — Schüler bis Rescue haben
-- keine fixe PADI-Nummer, sondern wechselnde Zertifikat-Nummern pro Karte
-- (→ student_certifications.certificate_nr). Pro-Nummern leben weiter auf
-- contact_instructor.padi_pro_number.
--
-- Pre-Flight-Befund (14.05.):
--   Die Forward-Sync-Triggers aus 0083 existieren in Production nicht mehr.
--   Aktuell laufen partial-Sync-Triggers (trg_sync_student_name,
--   trg_sync_pipeline_stage_changed, trg_sync_instructor_name) die nur
--   Namen + intra-Tabelle-Bookkeeping spiegeln. Daher KEIN Update der
--   orphan'd Functions sync_people_to_contacts / sync_instructors_to_contacts
--   in dieser Migration — Cleanup kommt in Etappe 3c (0092).
--
-- Backfill: idempotent, IS DISTINCT FROM, kein BEGIN/COMMIT (Studio committed
-- per Statement; partial application wäre tolerierbar).

-- ────────────────────────────────────────────────────────────────────────────
-- 1. Spalten ergänzen
-- ────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.contact_student
  ADD COLUMN IF NOT EXISTS level             TEXT,
  ADD COLUMN IF NOT EXISTS photo_url         TEXT,
  ADD COLUMN IF NOT EXISTS organization_role TEXT,
  ADD COLUMN IF NOT EXISTS stage_changed_on  TIMESTAMPTZ;

ALTER TABLE public.contact_instructor
  ADD COLUMN IF NOT EXISTS initials TEXT;

COMMENT ON COLUMN public.contact_student.level IS
  'Aktueller Tauchgang-Level (free-text, UI validiert gegen LEVELS-Konstante).';
COMMENT ON COLUMN public.contact_student.photo_url IS
  'Profilbild-URL.';
COMMENT ON COLUMN public.contact_student.organization_role IS
  'Rolle innerhalb der verknüpften Organisation (free-text).';
COMMENT ON COLUMN public.contact_student.stage_changed_on IS
  'Zeitpunkt der letzten pipeline_stage-Änderung (Trigger-gesetzt, TIMESTAMPTZ wie Legacy people.stage_changed_on).';
COMMENT ON COLUMN public.contact_instructor.initials IS
  'Kürzel für PADI-Referral-Templates, SkillCheck-Matrix, etc.';

-- ────────────────────────────────────────────────────────────────────────────
-- 2. Backfill aus Legacy-Tabellen
-- ────────────────────────────────────────────────────────────────────────────
UPDATE public.contact_student cs
SET level             = p.level,
    photo_url         = p.photo_url,
    organization_role = p.organization_role,
    stage_changed_on  = p.stage_changed_on
FROM public.people p
WHERE cs.contact_id = p.id
  AND (cs.level             IS DISTINCT FROM p.level
    OR cs.photo_url         IS DISTINCT FROM p.photo_url
    OR cs.organization_role IS DISTINCT FROM p.organization_role
    OR cs.stage_changed_on  IS DISTINCT FROM p.stage_changed_on);

UPDATE public.contact_instructor ci
SET initials = i.initials
FROM public.instructors i
WHERE ci.contact_id = i.id
  AND ci.initials IS DISTINCT FROM i.initials;

-- ────────────────────────────────────────────────────────────────────────────
-- 3. stage_changed_on-Trigger auf contact_student
-- ────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION tg_contact_student_stage_changed()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.pipeline_stage IS DISTINCT FROM NEW.pipeline_stage THEN
    NEW.stage_changed_on := now();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_contact_student_stage_changed ON public.contact_student;
CREATE TRIGGER trg_contact_student_stage_changed
  BEFORE UPDATE ON public.contact_student
  FOR EACH ROW EXECUTE FUNCTION tg_contact_student_stage_changed();

-- ────────────────────────────────────────────────────────────────────────────
-- 4. student_upsert RPC — atomarer Write auf contacts + contact_student
--    + optional works_at-Relationship
-- ────────────────────────────────────────────────────────────────────────────
--
-- Signatur:
--   student_upsert(
--     p_contact_id UUID,        -- NULL = Insert, gesetzt = Update
--     p_contact    JSONB,       -- Stammdaten für contacts
--     p_student    JSONB,       -- Sidecar-Felder für contact_student
--     p_org_id     UUID         -- NULL = kein Org-Link, gesetzt = works_at
--   ) RETURNS UUID
--
-- p_contact-Schema (alles optional ausser first_name beim Insert):
--   { first_name, last_name, primary_email, phone, birthday, notes,
--     address: {street, postal_code, city, country}, tags, languages,
--     is_student (bool), is_candidate (bool) }
--
-- p_student-Schema (alles optional):
--   { pipeline_stage, lead_source, is_candidate, level,
--     photo_url, organization_role }
--
-- p_org_id: UUID der Organisation (contact_id). Wenn gesetzt → works_at
-- Relationship sicherstellen. Wenn NULL → bestehende works_at-Relationship
-- für diesen Schüler löschen.
--
-- Implementierungs-Note: photo_url lebt ausschliesslich auf contact_student
-- (neu in 0091). Im RPC wird p_contact->'photo_url' ignoriert; das Feld
-- aus dem p_student-Payload gelesen.

CREATE OR REPLACE FUNCTION student_upsert(
  p_contact_id UUID,
  p_contact    JSONB,
  p_student    JSONB,
  p_org_id     UUID DEFAULT NULL
) RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_contact_id UUID;
  v_roles      TEXT[];
  v_phones     JSONB;
  v_emails     JSONB;
  v_addresses  JSONB;
  v_languages  TEXT[];
  v_tags       TEXT[];
BEGIN
  -- Phones jsonb bauen aus simplem phone-Feld
  v_phones := CASE
    WHEN p_contact->>'phone' IS NOT NULL AND p_contact->>'phone' <> ''
    THEN jsonb_build_array(jsonb_build_object(
      'label','mobile','e164',p_contact->>'phone','primary',true))
    ELSE '[]'::jsonb
  END;

  -- Emails jsonb bauen aus primary_email (Konsistenz Liste ↔ Detail-Ansicht)
  v_emails := CASE
    WHEN p_contact->>'primary_email' IS NOT NULL AND p_contact->>'primary_email' <> ''
    THEN jsonb_build_array(jsonb_build_object(
      'label','work','email',p_contact->>'primary_email','primary',true))
    ELSE '[]'::jsonb
  END;

  -- Addresses jsonb bauen aus Adress-Sub-Objekt
  v_addresses := CASE
    WHEN p_contact->'address' IS NOT NULL
     AND (COALESCE(p_contact->'address'->>'street','') <> ''
       OR COALESCE(p_contact->'address'->>'city','')   <> '')
    THEN jsonb_build_array(jsonb_build_object(
      'label','home',
      'street',     COALESCE(p_contact->'address'->>'street',''),
      'postal_code',COALESCE(p_contact->'address'->>'postal_code',''),
      'city',       COALESCE(p_contact->'address'->>'city',''),
      'country',    COALESCE(p_contact->'address'->>'country',''),
      'primary',true))
    ELSE '[]'::jsonb
  END;

  -- Tags + languages aus jsonb-Arrays zu TEXT[]
  v_tags      := COALESCE(ARRAY(SELECT jsonb_array_elements_text(p_contact->'tags')),     '{}');
  v_languages := COALESCE(ARRAY(SELECT jsonb_array_elements_text(p_contact->'languages')),'{}');

  -- Roles bauen aus Flags
  v_roles := ARRAY[]::TEXT[];
  IF (p_contact->>'is_student')::BOOLEAN   THEN v_roles := array_append(v_roles, 'student');   END IF;
  IF (p_contact->>'is_candidate')::BOOLEAN THEN v_roles := array_append(v_roles, 'candidate'); END IF;

  IF p_contact_id IS NULL THEN
    -- ─── INSERT-Pfad ────────────────────────────────────────────────────
    INSERT INTO contacts (
      kind, first_name, last_name, primary_email, emails, phones, addresses,
      languages, roles, tags, notes, birth_date, source
    ) VALUES (
      'person',
      p_contact->>'first_name',
      COALESCE(NULLIF(p_contact->>'last_name',''), '-'),
      NULLIF(p_contact->>'primary_email',''),
      v_emails,
      v_phones,
      v_addresses,
      v_languages,
      v_roles,
      v_tags,
      NULLIF(p_contact->>'notes',''),
      NULLIF(p_contact->>'birthday','')::DATE,
      'student_upsert'
    )
    RETURNING id INTO v_contact_id;

    INSERT INTO contact_student (
      contact_id, pipeline_stage, lead_source, is_candidate,
      level, photo_url, organization_role
    ) VALUES (
      v_contact_id,
      NULLIF(p_student->>'pipeline_stage','none'),
      NULLIF(p_student->>'lead_source',''),
      COALESCE((p_student->>'is_candidate')::BOOLEAN, false),
      NULLIF(p_student->>'level',''),
      NULLIF(p_student->>'photo_url',''),
      NULLIF(p_student->>'organization_role','')
    );

  ELSE
    -- ─── UPDATE-Pfad ────────────────────────────────────────────────────
    v_contact_id := p_contact_id;

    UPDATE contacts SET
      first_name    = p_contact->>'first_name',
      last_name     = COALESCE(NULLIF(p_contact->>'last_name',''), '-'),
      primary_email = NULLIF(p_contact->>'primary_email',''),
      emails        = v_emails,
      phones        = v_phones,
      addresses     = v_addresses,
      languages     = v_languages,
      roles         = v_roles,
      tags          = v_tags,
      notes         = NULLIF(p_contact->>'notes',''),
      birth_date    = NULLIF(p_contact->>'birthday','')::DATE,
      updated_at    = now()
    WHERE id = v_contact_id;

    -- Sidecar upsert (Schüler ohne bisherigen Sidecar → erstellen)
    INSERT INTO contact_student (
      contact_id, pipeline_stage, lead_source, is_candidate,
      level, photo_url, organization_role
    ) VALUES (
      v_contact_id,
      NULLIF(p_student->>'pipeline_stage','none'),
      NULLIF(p_student->>'lead_source',''),
      COALESCE((p_student->>'is_candidate')::BOOLEAN, false),
      NULLIF(p_student->>'level',''),
      NULLIF(p_student->>'photo_url',''),
      NULLIF(p_student->>'organization_role','')
    )
    ON CONFLICT (contact_id) DO UPDATE SET
      pipeline_stage    = EXCLUDED.pipeline_stage,
      lead_source       = EXCLUDED.lead_source,
      is_candidate      = EXCLUDED.is_candidate,
      level             = EXCLUDED.level,
      photo_url         = EXCLUDED.photo_url,
      organization_role = EXCLUDED.organization_role,
      updated_at        = now();
  END IF;

  -- ─── Org-Link (works_at) ──────────────────────────────────────────────
  IF p_org_id IS NOT NULL THEN
    INSERT INTO contact_relationships (from_contact_id, to_contact_id, kind)
    VALUES (v_contact_id, p_org_id, 'works_at')
    ON CONFLICT DO NOTHING;
    -- Andere works_at-Relationships dieses Schülers entfernen (1:1-Annahme für Pitch)
    DELETE FROM contact_relationships
    WHERE from_contact_id = v_contact_id
      AND kind = 'works_at'
      AND to_contact_id <> p_org_id;
  ELSE
    DELETE FROM contact_relationships
    WHERE from_contact_id = v_contact_id
      AND kind = 'works_at';
  END IF;

  RETURN v_contact_id;
END;
$$;

-- RLS: alle authenticated dürfen aufrufen (analog mergeContacts-Pattern)
GRANT EXECUTE ON FUNCTION student_upsert(UUID, JSONB, JSONB, UUID) TO authenticated;
