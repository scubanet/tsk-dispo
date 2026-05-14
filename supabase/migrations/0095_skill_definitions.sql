-- 0095: skill_definitions — Katalog aller PADI-Skills pro Kurs-Typ.
-- Quelle: apps/web/src/lib/padiOwdSkills.ts (wird post-Pitch in separate Etappe
-- durch Hook ersetzt, der aus dieser Tabelle liest).
-- iOS-SkillCheckStore liest direkt aus dieser Tabelle.

CREATE TABLE public.skill_definitions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_type_code TEXT NOT NULL,
  skill_code TEXT NOT NULL,
  section TEXT NOT NULL,
  label_de TEXT NOT NULL,
  label_en TEXT NOT NULL,
  display_order INT NOT NULL DEFAULT 0,
  has_date BOOLEAN NOT NULL DEFAULT false,
  has_quiz BOOLEAN NOT NULL DEFAULT false,
  has_video BOOLEAN NOT NULL DEFAULT false,
  has_tg_number BOOLEAN NOT NULL DEFAULT false,
  tg_number_options INT[],
  course_day_kind TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(course_type_code, skill_code)
);

CREATE INDEX idx_skill_definitions_course_type ON public.skill_definitions(course_type_code);
CREATE INDEX idx_skill_definitions_section ON public.skill_definitions(course_type_code, section, display_order);

ALTER TABLE public.skill_definitions ENABLE ROW LEVEL SECURITY;
CREATE POLICY skill_definitions_read ON public.skill_definitions
  FOR SELECT TO authenticated USING (true);

COMMENT ON TABLE public.skill_definitions IS
  'Katalog aller trackbaren PADI-Skills pro Kurs-Typ. Seed aus padiOwdSkills.ts.';

-- ─── OWD-Seed (34 rows) ─────────────────────────────────────────────────────

INSERT INTO public.skill_definitions
  (course_type_code, skill_code, section, label_de, label_en, display_order, has_date, has_quiz, has_video, has_tg_number, tg_number_options, course_day_kind)
VALUES
  ('owd', 'cw_1', 'cw_dive', 'CW Tauchgang 1', 'CW Dive 1', 10, true, false, false, false, NULL, 'cw1'),
  ('owd', 'cw_2', 'cw_dive', 'CW Tauchgang 2', 'CW Dive 2', 20, true, false, false, false, NULL, 'cw2'),
  ('owd', 'cw_3', 'cw_dive', 'CW Tauchgang 3', 'CW Dive 3', 30, true, false, false, false, NULL, 'cw3'),
  ('owd', 'cw_4', 'cw_dive', 'CW Tauchgang 4', 'CW Dive 4', 40, true, false, false, false, NULL, 'cw4'),
  ('owd', 'cw_5', 'cw_dive', 'CW Tauchgang 5', 'CW Dive 5', 50, true, false, false, false, NULL, 'cw5'),
  ('owd', 'assessment_swim',  'assessment', '200m / 300m schwimmen',      '200m / 300m swim',    60, true, false, false, false, NULL, NULL),
  ('owd', 'assessment_float', 'assessment', '10 Min Oberfläche treiben',  '10 min float/tread',  70, true, false, false, false, NULL, NULL),
  ('owd', 'cw_flex_prep_gear',        'cw_flex', 'Vorbereitung und Pflege der Ausrüstung*',                'Gear preparation & care*',                  80,  true, false, false, false, NULL, NULL),
  ('owd', 'cw_flex_inflator',         'cw_flex', 'Abkoppeln des Inflatorschlauchs vom Tarierjacket*',      'Disconnecting inflator hose*',              90,  true, false, false, false, NULL, NULL),
  ('owd', 'cw_flex_band',             'cw_flex', 'Lockeres Band einer Flaschenhalterung',                  'Loose tank band',                           100, true, false, false, false, NULL, NULL),
  ('owd', 'cw_flex_weight_off_surf',  'cw_flex', 'Ablegen und Anlegen Gewichtssystem (Oberfläche)*',       'Weight system off/on at surface*',          110, true, false, false, false, NULL, NULL),
  ('owd', 'cw_flex_emergency_weight', 'cw_flex', 'Abwerfen von Bleigewichten im Notfall*',                 'Emergency weight drop*',                    120, true, false, false, false, NULL, NULL),
  ('owd', 'cw_flex_snorkel',          'cw_flex', 'Schnorcheltauchen',                                      'Snorkel diving',                            130, true, false, false, false, NULL, NULL),
  ('owd', 'cw_flex_drysuit_orient',   'cw_flex', 'Orientierung zum Tauchen im Trockentauchanzug',          'Dry suit orientation',                      140, true, false, false, false, NULL, NULL),
  ('owd', 'kd_teil_1',       'kd', 'Teil 1',                  'Part 1',                  150, true, true, true, false, NULL, NULL),
  ('owd', 'kd_teil_2',       'kd', 'Teil 2',                  'Part 2',                  160, true, true, true, false, NULL, NULL),
  ('owd', 'kd_teil_3',       'kd', 'Teil 3',                  'Part 3',                  170, true, true, true, false, NULL, NULL),
  ('owd', 'kd_teil_4',       'kd', 'Teil 4',                  'Part 4',                  180, true, true, true, false, NULL, NULL),
  ('owd', 'kd_teil_5',       'kd', 'Teil 5',                  'Part 5',                  190, true, true, true, false, NULL, NULL),
  ('owd', 'kd_quick_review', 'kd', 'Quick Review (eLearning)','Quick Review (eLearning)',200, true, true, true, false, NULL, NULL),
  ('owd', 'ow_1', 'ow_dive', 'OW Tauchgang 1', 'OW Dive 1', 210, true, false, false, false, NULL, 'ow1'),
  ('owd', 'ow_2', 'ow_dive', 'OW Tauchgang 2', 'OW Dive 2', 220, true, false, false, false, NULL, 'ow2'),
  ('owd', 'ow_3', 'ow_dive', 'OW Tauchgang 3', 'OW Dive 3', 230, true, false, false, false, NULL, 'ow3'),
  ('owd', 'ow_4', 'ow_dive', 'OW Tauchgang 4', 'OW Dive 4', 240, true, false, false, false, NULL, 'ow4'),
  ('owd', 'ow_flex_cramp',            'ow_flex', 'Einen Krampf lösen*',                       'Release a cramp*',                      250, false, false, false, true, NULL,         NULL),
  ('owd', 'ow_flex_tow',              'ow_flex', 'Ermüdeten Taucher schleppen/schieben*',     'Tow/push tired diver*',                 260, false, false, false, true, NULL,         NULL),
  ('owd', 'ow_flex_dsmb',             'ow_flex', 'Signalboje/DSMB einsetzen*',                'Use DSMB/marker buoy*',                 270, false, false, false, true, NULL,         NULL),
  ('owd', 'ow_flex_compass_straight', 'ow_flex', 'Gerade Strecke mit Kompass*',               'Straight line w/ compass*',             280, false, false, false, true, NULL,         NULL),
  ('owd', 'ow_flex_snorkel_reg',      'ow_flex', 'Wechsel Schnorchel/Lungenautomat*',         'Snorkel/regulator exchange*',           290, false, false, false, true, NULL,         NULL),
  ('owd', 'ow_flex_weight_drop',      'ow_flex', 'Bleigewichte im Notfall abwerfen*',         'Emergency weight drop*',                300, false, false, false, true, NULL,         NULL),
  ('owd', 'ow_flex_scuba_off_surf',   'ow_flex', 'Tauchgerät ab-/anlegen (Oberfläche)*',      'Scuba off/on at surface*',              310, false, false, false, true, NULL,         NULL),
  ('owd', 'ow_flex_weight_off_surf',  'ow_flex', 'Gewichtssystem ab-/anlegen (Oberfläche)*',  'Weight system off/on at surface*',      320, false, false, false, true, NULL,         NULL),
  ('owd', 'ow_flex_uw_compass',       'ow_flex', 'U/W-Navigation mit Kompass (TG 2, 3 oder 4)','U/W navigation with compass (TG 2, 3 or 4)', 330, false, false, false, true, ARRAY[2,3,4], NULL),
  ('owd', 'ow_flex_cesa',             'ow_flex', 'CESA (TG 2, 3 oder 4)',                     'CESA (TG 2, 3 or 4)',                   340, false, false, false, true, ARRAY[2,3,4], NULL);
