-- Catalog v2024.9 -- IDC OW: 4 Präsentationen in 2 Pärchen
--
-- Pass-Rule: mindestens ein Pärchen mit Schnitt ≥3.4
-- Pärchen 1 = OW.1 + OW.2, Pärchen 2 = OW.3 + OW.4
-- Jede Präsentation hat Score 1.00-5.00 mit Assistent-Toggle.

DELETE FROM pr_catalogs WHERE course_type='IDC' AND version='2024.9';

UPDATE pr_catalogs
   SET data = jsonb_set(
     jsonb_set(
       data,
       '{slots}',
       (
         SELECT jsonb_agg(
           CASE
             WHEN slot->>'code' = 'OW' THEN
               jsonb_set(
                 jsonb_set(
                   jsonb_set(slot, '{passRule}', '"minOnePairPassed"'),
                   '{pairAverageThreshold}', '3.4'
                 ),
                 '{skills}',
                 jsonb_build_array(
                   jsonb_build_object('code','IDC.OW.1','title', CASE WHEN data->>'language'='de' THEN 'OW-Lehrprobe 1 (Pärchen 1)' ELSE 'OW Presentation 1 (Pair 1)' END,'isActive',true,'showAssistantToggle',true,'pairGroup',1),
                   jsonb_build_object('code','IDC.OW.2','title', CASE WHEN data->>'language'='de' THEN 'OW-Lehrprobe 2 (Pärchen 1)' ELSE 'OW Presentation 2 (Pair 1)' END,'isActive',true,'showAssistantToggle',true,'pairGroup',1),
                   jsonb_build_object('code','IDC.OW.3','title', CASE WHEN data->>'language'='de' THEN 'OW-Lehrprobe 3 (Pärchen 2)' ELSE 'OW Presentation 3 (Pair 2)' END,'isActive',true,'showAssistantToggle',true,'pairGroup',2),
                   jsonb_build_object('code','IDC.OW.4','title', CASE WHEN data->>'language'='de' THEN 'OW-Lehrprobe 4 (Pärchen 2)' ELSE 'OW Presentation 4 (Pair 2)' END,'isActive',true,'showAssistantToggle',true,'pairGroup',2)
                 )
               )
             ELSE slot
           END
         )
         FROM jsonb_array_elements(data->'slots') AS slot
       )
     ),
     '{version}', '"2024.9"'
   ),
   version = '2024.9'
 WHERE course_type = 'IDC' AND active AND version = '2024.8';

-- Verify:
--   SELECT course_type, language, version,
--          (SELECT s->'skills'
--             FROM jsonb_array_elements(data->'slots') s
--            WHERE s->>'code' = 'OW') AS ow_skills
--     FROM pr_catalogs WHERE active AND course_type = 'IDC';
