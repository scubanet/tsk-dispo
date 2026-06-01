-- 0129_enforce_unique_contact_phone.sql
-- Erweitert den bestehenden BEFORE-Trigger normalize_contact_phones:
-- (1) normalisiert e164 (Whitespace raus, wie gehabt),
-- (2) erzwingt Eindeutigkeit — eine Nummer darf keinem ANDEREN lebenden
--     (nicht archivierten/gemergten) Kontakt gehören. Sonst Abbruch
--     (unique_violation). Verhindert das Doppelnummer-Problem, durch das
--     eingehende WhatsApp am falschen Kontakt landeten.
CREATE OR REPLACE FUNCTION public.normalize_contact_phones()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_e164 text;
  v_conflict uuid;
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

    FOR v_e164 IN
      SELECT DISTINCT regexp_replace(p->>'e164', '\D', '', 'g')
      FROM jsonb_array_elements(NEW.phones) p
      WHERE COALESCE(p->>'e164', '') <> ''
    LOOP
      IF v_e164 <> '' THEN
        SELECT c.id INTO v_conflict
        FROM public.contacts c
        WHERE c.id <> NEW.id
          AND c.archived_at IS NULL
          AND c.merged_into_id IS NULL
          AND EXISTS (
            SELECT 1 FROM jsonb_array_elements(COALESCE(c.phones, '[]'::jsonb)) p2
            WHERE regexp_replace(p2->>'e164', '\D', '', 'g') = v_e164
          )
        LIMIT 1;
        IF v_conflict IS NOT NULL THEN
          RAISE EXCEPTION 'Telefonnummer % ist bereits einem anderen Kontakt zugeordnet.', v_e164
            USING ERRCODE = 'unique_violation';
        END IF;
      END IF;
    END LOOP;
  END IF;
  RETURN NEW;
END;
$$;
