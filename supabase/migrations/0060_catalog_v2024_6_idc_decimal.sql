-- Catalog v2024.6 -- IDC KD/CW/OW Lehrproben mit Decimal-Score 1.00-5.00, Threshold 3.40
--
-- User-Anforderung 2026-05-05: PADI bewertet Lehrproben mit Mittelwert auf 2 Nachkommastellen
-- (z.B. 3.42). Daten sind bereits Numeric, nur das scoreSchema im Catalog wird angepasst.

-- Wir patchen die JSONB-Datenstruktur der aktiven IDC-Catalogs in-place,
-- ohne neue Version anzulegen (die v2024.5 Daten bleiben unverändert).

UPDATE pr_catalogs
   SET data = jsonb_set(
     jsonb_set(
       jsonb_set(
         data,
         '{slots}',
         (
           SELECT jsonb_agg(
             CASE
               WHEN slot->>'code' IN ('KD','CW','OW') THEN
                 slot
                   || jsonb_build_object('scoreSchema', 'score1to5_decimal')
                   || jsonb_build_object('passThreshold', 3.4)
               ELSE slot
             END
           )
           FROM jsonb_array_elements(data->'slots') AS slot
         )
       ),
       '{version}', '"2024.6"'
     ),
     '{patchNote}', '"v2024.6: KD/CW/OW Lehrproben mit Decimal-Score (2 Nachkommastellen)"'
   ),
   version = '2024.6'
 WHERE course_type = 'IDC'
   AND active
   AND version = '2024.5';

-- Verify:
--   SELECT course_type, language, version,
--          (SELECT jsonb_object_agg(s->>'code', s->>'scoreSchema')
--             FROM jsonb_array_elements(data->'slots') s
--            WHERE s->>'code' IN ('KD','CW','OW')) AS lehrprobe_schemas
--     FROM pr_catalogs WHERE active AND course_type = 'IDC';
