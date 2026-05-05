-- Catalog v2024.7 -- IDC ELEARN/CURR mit scoreSchema 'done' (Checkbox-Toggle)
--
-- User-Anforderung 2026-05-05: Bei eLearning-Komponenten und Curriculum-Workshops
-- ist Pass/Fail zu viel — es reicht ein einfaches "erledigt".

DELETE FROM pr_catalogs WHERE course_type='IDC' AND version='2024.7';

UPDATE pr_catalogs
   SET data = jsonb_set(
     jsonb_set(
       data,
       '{slots}',
       (
         SELECT jsonb_agg(
           CASE
             WHEN slot->>'code' IN ('ELEARN','CURR') THEN
               (slot - 'passThreshold')
                 || jsonb_build_object('scoreSchema', 'done')
                 || jsonb_build_object('kind', 'done')
             ELSE slot
           END
         )
         FROM jsonb_array_elements(data->'slots') AS slot
       )
     ),
     '{version}', '"2024.7"'
   ),
   version = '2024.7'
 WHERE course_type = 'IDC' AND active AND version = '2024.6';

-- Verify:
--   SELECT course_type, language, version,
--          (SELECT jsonb_object_agg(s->>'code', s->>'scoreSchema')
--             FROM jsonb_array_elements(data->'slots') s
--            WHERE s->>'code' IN ('ELEARN','CURR','KD','CW','OW')) AS schemas
--     FROM pr_catalogs WHERE active AND course_type = 'IDC';
