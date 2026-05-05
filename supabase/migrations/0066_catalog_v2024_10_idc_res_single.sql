-- Catalog v2024.10 -- IDC RES auf einzelne Übung reduzieren
--
-- User-Korrektur 2026-05-05: Bei Rescue-Bewertung (Übung 7) wird nur EINE Übung
-- geprüft — Rettung eines nicht reagierenden, nicht atmenden Tauchers an der
-- Oberfläche im Freiwasser, mit Vorbildcharakter.

DELETE FROM pr_catalogs WHERE course_type='IDC' AND version='2024.10';

UPDATE pr_catalogs
   SET data = jsonb_set(
     jsonb_set(
       data,
       '{slots}',
       (
         SELECT jsonb_agg(
           CASE
             WHEN slot->>'code' = 'RES' THEN
               jsonb_set(slot, '{skills}',
                 jsonb_build_array(
                   jsonb_build_object(
                     'code','IDC.RES.1',
                     'title', CASE
                       WHEN data->>'language'='de' THEN 'Rettung eines nicht reagierenden, nicht atmenden Tauchers an der Oberfläche (Freiwasser, Vorbildcharakter)'
                       ELSE 'Non-responsive non-breathing surface rescue (open water, demonstration quality)'
                     END,
                     'isActive', true
                   )
                 )
               )
             ELSE slot
           END
         )
         FROM jsonb_array_elements(data->'slots') AS slot
       )
     ),
     '{version}', '"2024.10"'
   ),
   version = '2024.10'
 WHERE course_type = 'IDC' AND active AND version = '2024.9';

-- Verify:
--   SELECT course_type, language, version,
--          (SELECT jsonb_array_length(s->'skills')
--             FROM jsonb_array_elements(data->'slots') s
--            WHERE s->>'code' = 'RES') AS res_skills
--     FROM pr_catalogs WHERE active AND course_type = 'IDC';
