-- Catalog v2024.8 -- IDC KD/CW/OW als konkrete Präsentationen
--
-- KD: 4 Lehrproben — Pass wenn mindestens eine ≥3.4
-- CW: 4 Lehrproben — Pass wenn mindestens eine ≥3.4, Assistent-Toggle pro Lehrprobe
-- OW: 2 integrierte Lehrproben (je 2 Fertigkeiten) — Pass wenn mindestens eine Schnitt ≥3.4, Assistent-Toggle pro Lehrprobe

DELETE FROM pr_catalogs WHERE course_type='IDC' AND version='2024.8';

UPDATE pr_catalogs
   SET data = jsonb_set(
     jsonb_set(
       data,
       '{slots}',
       (
         SELECT jsonb_agg(
           CASE
             -- KD: 4 Präsentationen
             WHEN slot->>'code' = 'KD' THEN
               jsonb_set(
                 jsonb_set(slot, '{passRule}', '"minOnePassed"'),
                 '{skills}',
                 jsonb_build_array(
                   jsonb_build_object('code','IDC.KD.1','title', CASE WHEN data->>'language'='de' THEN 'KD-Präsentation 1' ELSE 'KD Presentation 1' END,'isActive',true),
                   jsonb_build_object('code','IDC.KD.2','title', CASE WHEN data->>'language'='de' THEN 'KD-Präsentation 2' ELSE 'KD Presentation 2' END,'isActive',true),
                   jsonb_build_object('code','IDC.KD.3','title', CASE WHEN data->>'language'='de' THEN 'KD-Präsentation 3' ELSE 'KD Presentation 3' END,'isActive',true),
                   jsonb_build_object('code','IDC.KD.4','title', CASE WHEN data->>'language'='de' THEN 'KD-Präsentation 4' ELSE 'KD Presentation 4' END,'isActive',true)
                 )
               )
             -- CW: 4 Präsentationen mit Assistent-Toggle
             WHEN slot->>'code' = 'CW' THEN
               jsonb_set(
                 jsonb_set(slot, '{passRule}', '"minOnePassed"'),
                 '{skills}',
                 jsonb_build_array(
                   jsonb_build_object('code','IDC.CW.1','title', CASE WHEN data->>'language'='de' THEN 'CW-Lehrprobe 1' ELSE 'CW Presentation 1' END,'isActive',true,'showAssistantToggle',true),
                   jsonb_build_object('code','IDC.CW.2','title', CASE WHEN data->>'language'='de' THEN 'CW-Lehrprobe 2' ELSE 'CW Presentation 2' END,'isActive',true,'showAssistantToggle',true),
                   jsonb_build_object('code','IDC.CW.3','title', CASE WHEN data->>'language'='de' THEN 'CW-Lehrprobe 3' ELSE 'CW Presentation 3' END,'isActive',true,'showAssistantToggle',true),
                   jsonb_build_object('code','IDC.CW.4','title', CASE WHEN data->>'language'='de' THEN 'CW-Lehrprobe 4' ELSE 'CW Presentation 4' END,'isActive',true,'showAssistantToggle',true)
                 )
               )
             -- OW: 2 integrierte Lehrproben mit Assistent-Toggle
             WHEN slot->>'code' = 'OW' THEN
               jsonb_set(
                 jsonb_set(slot, '{passRule}', '"minOnePassed"'),
                 '{skills}',
                 jsonb_build_array(
                   jsonb_build_object('code','IDC.OW.1','title', CASE WHEN data->>'language'='de' THEN 'OW integrierte Lehrprobe 1 (Schnitt aus 2 Fertigkeiten)' ELSE 'OW integrated presentation 1 (avg of 2 skills)' END,'isActive',true,'showAssistantToggle',true),
                   jsonb_build_object('code','IDC.OW.2','title', CASE WHEN data->>'language'='de' THEN 'OW integrierte Lehrprobe 2 (Schnitt aus 2 Fertigkeiten)' ELSE 'OW integrated presentation 2 (avg of 2 skills)' END,'isActive',true,'showAssistantToggle',true)
                 )
               )
             ELSE slot
           END
         )
         FROM jsonb_array_elements(data->'slots') AS slot
       )
     ),
     '{version}', '"2024.8"'
   ),
   version = '2024.8'
 WHERE course_type = 'IDC' AND active AND version = '2024.7';

-- Verify:
-- SELECT course_type, language, version,
--        (SELECT jsonb_object_agg(s->>'code', jsonb_array_length(s->'skills'))
--           FROM jsonb_array_elements(data->'slots') s
--          WHERE s->>'code' IN ('KD','CW','OW')) AS skill_counts
--   FROM pr_catalogs WHERE active AND course_type = 'IDC';
