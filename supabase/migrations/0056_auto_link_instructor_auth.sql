-- Auto-Link Instructor ↔ Auth-User per E-Mail
--
-- Statt manuelle SQL-Updates läuft jetzt:
--   1. Wenn ein Instructor angelegt/geändert wird (mit Email) und noch kein auth_user_id hat
--      → suche in auth.users nach Match per Email, setze auth_user_id automatisch.
--   2. Wenn ein neuer Auth-User in auth.users entsteht (z.B. nach erstem Login via Magic Link)
--      → suche in instructors nach Email-Match, setze dort auth_user_id automatisch.
--
-- Damit muss der Dispatcher nur sicherstellen, dass die Email im Instructor-Profil
-- mit der Login-Email übereinstimmt — der Link entsteht von selbst.

-- ============================================================
-- 1. Trigger BEFORE INSERT/UPDATE auf instructors
-- ============================================================

CREATE OR REPLACE FUNCTION auto_link_instructor_to_auth()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  -- Nur wenn Email gesetzt und auth_user_id leer
  IF NEW.email IS NOT NULL AND NEW.email <> '' AND NEW.auth_user_id IS NULL THEN
    SELECT id INTO NEW.auth_user_id
      FROM auth.users
     WHERE LOWER(email) = LOWER(NEW.email)
     LIMIT 1;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_auto_link_instructor ON instructors;
CREATE TRIGGER trg_auto_link_instructor
  BEFORE INSERT OR UPDATE OF email, auth_user_id ON instructors
  FOR EACH ROW EXECUTE FUNCTION auto_link_instructor_to_auth();

-- ============================================================
-- 2. Trigger AFTER INSERT auf auth.users
-- ============================================================

CREATE OR REPLACE FUNCTION auto_link_auth_to_instructor()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  IF NEW.email IS NOT NULL AND NEW.email <> '' THEN
    UPDATE public.instructors
       SET auth_user_id = NEW.id
     WHERE LOWER(email) = LOWER(NEW.email)
       AND auth_user_id IS NULL;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_auto_link_auth ON auth.users;
CREATE TRIGGER trg_auto_link_auth
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION auto_link_auth_to_instructor();

-- ============================================================
-- 3. Backfill für bestehende Daten
-- ============================================================

-- Alle existierenden Instructors mit Email aber ohne auth_user_id linken
UPDATE instructors i
   SET auth_user_id = u.id
  FROM auth.users u
 WHERE LOWER(i.email) = LOWER(u.email)
   AND i.auth_user_id IS NULL
   AND i.email IS NOT NULL
   AND i.email <> '';

COMMENT ON FUNCTION auto_link_instructor_to_auth() IS
  'BEFORE-Trigger auf instructors: setzt auth_user_id automatisch via Email-Match auf auth.users.';
COMMENT ON FUNCTION auto_link_auth_to_instructor() IS
  'AFTER-Trigger auf auth.users: setzt auth_user_id im Instructor wenn Email matcht.';
