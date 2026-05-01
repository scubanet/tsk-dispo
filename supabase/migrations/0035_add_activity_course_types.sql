-- Vier weitere Aktivitäts-Kurstypen.
-- Stundensätze sind pragmatische Defaults und in Settings/SQL anpassbar.

INSERT INTO course_types (code, label, theory_units, pool_units, lake_units, ratio_pool, ratio_lake, has_elearning, notes) VALUES
  ('SO_DIVE',  'So-Dive',                0, 0, 6, 'N.A.', 'gemäss PADI', false,
   'Sonntags-Tagesausflug zum See — Default 6h See'),
  ('TSCHIGGI', 'Tschiggi After Work Dive', 0, 0, 3, 'N.A.', 'gemäss PADI', false,
   'Kurzer Abend-Dive nach der Arbeit — Default 3h See'),
  ('CLEANUP',  'Clean Up',               0, 0, 4, 'N.A.', 'gemäss PADI', false,
   'See-Reinigung / Aufräum-Aktion — Default 4h See'),
  ('SPECIAL',  'Special',                0, 0, 0, 'N.A.', 'N.A.',        false,
   'Generischer Eintrag für Sonderveranstaltungen — Stunden je nach Anlass manuell anpassen')
ON CONFLICT (code) DO NOTHING;
