-- Add Basic Open Water Swimming as a new course type.
-- Default-Stunden: 1h Theorie, 1h Pool, 2h See — bei Bedarf in Settings/SQL anpassen.

INSERT INTO course_types (code, label, theory_units, pool_units, lake_units, ratio_pool, ratio_lake, has_elearning, notes) VALUES
  ('BOWS', 'Basic Open Water Swimming', 1, 1, 2, 'gemäss PADI', 'gemäss PADI', false,
   'Grundlagen-Schwimmen im offenen Wasser. Default-Stunden 1/1/2 — anpassen falls anders üblich.')
ON CONFLICT (code) DO NOTHING;
