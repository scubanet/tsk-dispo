-- 0102: Skill catalog — extend with full Specialty (Instructor) set and add SPEI (Trainer) level.
--
-- The `skills` table seeded in 0002 was a partial list extracted from the
-- legacy Excel SkillMatrix. This migration brings the catalog up to the
-- complete inventory the team needs for both:
--
--   1. **Specialty Instructor permits** — what an OWSI is authorised to
--      teach to divers (category `Specialty`).
--   2. **SPEI permits** — the Trainer level: who can teach the Specialty
--      Instructor *workshop* itself. New category `SPEI`.
--
-- Convention:
--   • Specialty (Instructor): `spec_<topic>` (existing pattern from 0002)
--   • SPEI    (Trainer):      `spei_<topic>` — same suffix as the parent
--     Specialty row, prefix swapped, so the pair is visually obvious.
--
-- Existing rows from 0002 are left untouched (ON CONFLICT DO NOTHING).
-- The SPEI rows below cover every Trainer item from the source list;
-- where the corresponding Specialty doesn't yet exist (e.g. Care For
-- Children Trainer has no Instructor counterpart in the list), only the
-- SPEI row is created.
--
-- Mapping notes for items where the existing code differs from the
-- user-supplied label:
--   • Dive Against Debris → spec_dive_fish (legacy code, kept as-is)
--                          → spei_dive_debris (cleaner Trainer code)
--   • Diver Propulsion Vehicle (DPV) → spec_scooter / spei_scooter
--     (PADI's modern name is DPV, but the legacy code is kept for
--     backward-compatibility with existing instructor_skills rows).
--   • Emergency Oxygen Provider → eop / spei_eop
--   • Fish Identification → spec_aware_fish / spei_aware_fish
--     (same course PADI now markets under both names).
--   • EFR Instructor / Trainer → efr_instr / efr_train (Leadership, kept).

-- ─── Specialty (Instructor) — fill the gaps ─────────────────────────
-- Note: scuba_magician, oxygen_fa, multilevel were initially in this list
-- but removed in 0103 because PADI retired them. The Specialty: Medic
-- First Aid (`spec_medic`) row from 0002 is also deleted in 0103.
INSERT INTO public.skills (code, label, category) VALUES
  ('spec_full_face_mask', 'Specialty: Full Face Mask',        'Specialty'),
  ('spec_naturalist',     'Specialty: Underwater Naturalist', 'Specialty'),
  ('spec_video',          'Specialty: Underwater Videographer','Specialty'),
  ('spec_whale_shark',    'Specialty: Whale Shark Awareness', 'Specialty'),
  ('spec_digital_photo',  'Specialty: Digital UW Photography','Specialty'),
  ('spec_aware',          'Specialty: PADI AWARE',            'Specialty')
ON CONFLICT (code) DO NOTHING;

-- ─── SPEI (Trainer level) — new category ────────────────────────────
INSERT INTO public.skills (code, label, category) VALUES
  ('spei_altitude',       'SPEI: Altitude',                       'SPEI'),
  ('spei_aware_coral',    'SPEI: AWARE Coral Reef Conservation',  'SPEI'),
  ('spei_aware_fish',     'SPEI: Fish Identification',            'SPEI'),
  ('spei_aware_shark',    'SPEI: AWARE Shark & Ray Conservation', 'SPEI'),
  ('spei_boat',           'SPEI: Boat',                           'SPEI'),
  ('spei_care_children',  'SPEI: Care For Children',              'SPEI'),
  ('spei_deep',           'SPEI: Deep',                           'SPEI'),
  ('spei_digital_photo',  'SPEI: Digital UW Photography',         'SPEI'),
  ('spei_dive_debris',    'SPEI: Dive Against Debris',            'SPEI'),
  ('spei_drift',          'SPEI: Drift',                          'SPEI'),
  ('spei_dry',            'SPEI: Dry Suit',                       'SPEI'),
  ('spei_dsmb',           'SPEI: Delayed Surface Marker Buoy',    'SPEI'),
  ('spei_eop',            'SPEI: Emergency Oxygen Provider',      'SPEI'),
  ('spei_equipment',      'SPEI: Equipment Specialist',           'SPEI'),
  ('spei_full_face_mask', 'SPEI: Full Face Mask',                 'SPEI'),
  ('spei_ice',            'SPEI: Ice',                            'SPEI'),
  ('spei_naturalist',     'SPEI: Underwater Naturalist',          'SPEI'),
  ('spei_navi',           'SPEI: Underwater Navigator',           'SPEI'),
  ('spei_night',          'SPEI: Night Diver',                    'SPEI'),
  ('spei_nitrox',         'SPEI: Enriched Air',                   'SPEI'),
  ('spei_scooter',        'SPEI: Diver Propulsion Vehicle',       'SPEI'),
  ('spei_search',         'SPEI: Search & Recovery',              'SPEI'),
  ('spei_video',          'SPEI: Underwater Videographer',        'SPEI'),
  ('spei_whale_shark',    'SPEI: Whale Shark Awareness',          'SPEI'),
  ('spei_wreck',          'SPEI: Wreck',                          'SPEI')
ON CONFLICT (code) DO NOTHING;

-- ─── Sanity check view counts ────────────────────────────────────────
-- After 0102 + 0103 run, `skills` should contain:
--   Leadership: 3   (DSD Leader, EFR Instr, EFR Train)
--   Specialty: 29   (24 existing − 1 deleted (spec_medic) + 6 new)
--   Tec:        4
--   SPEI:      25   (new)
-- Total:      61
