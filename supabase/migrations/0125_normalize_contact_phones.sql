-- 0125_normalize_contact_phones.sql
-- Telefonnummern standardmässig ohne Leerzeichen: strippt Whitespace aus
-- jedem phones[].e164 bei jedem Insert/Update (deckt UI, Schnellanlage,
-- Profil und Importe ab). Bestehende Daten wurden einmalig bereinigt.
-- Entscheidung 2026-05-30 (Dominik): Nummern standardmässig ohne Leerzeichen.
CREATE OR REPLACE FUNCTION public.normalize_contact_phones()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.phones IS NOT NULL AND jsonb_typeof(NEW.phones) = 'array' THEN
    NEW.phones := (
      SELECT COALESCE(jsonb_agg(
        CASE WHEN jsonb_typeof(elem) = 'object' AND elem ? 'e164'
             THEN jsonb_set(elem, '{e164}', to_jsonb(regexp_replace(elem->>'e164', '\s', '', 'g')))
             ELSE elem END
      ), '[]'::jsonb)
      FROM jsonb_array_elements(NEW.phones) elem
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_normalize_contact_phones ON public.contacts;
CREATE TRIGGER trg_normalize_contact_phones
  BEFORE INSERT OR UPDATE OF phones ON public.contacts
  FOR EACH ROW EXECUTE FUNCTION public.normalize_contact_phones();
