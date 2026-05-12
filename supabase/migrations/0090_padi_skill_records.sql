-- 0090: PADI OWD Skill-Tracker — per (course, participant, skill) records.
-- Used to track which student completed which PADI form item, on which date,
-- with which instructor — for digital pre-filling of the PADI Referral PDF.

CREATE TABLE IF NOT EXISTS public.padi_skill_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  participant_id UUID NOT NULL REFERENCES public.course_participants(id) ON DELETE CASCADE,
  skill_code TEXT NOT NULL,
  completed_on DATE,
  course_day_kind TEXT,        -- 'cw1'..'cw5' / 'ow1'..'ow4' / 'theory' / 'flex'
  tg_number INT,               -- 1-4 for OW flex skills (which OW dive the skill was done on)
  quiz_passed BOOLEAN,         -- only for KD Teile
  video_watched BOOLEAN,       -- only for KD Teile
  instructor_id UUID REFERENCES public.instructors(id) ON DELETE SET NULL,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(participant_id, skill_code)
);

CREATE INDEX idx_padi_skill_records_course ON public.padi_skill_records(course_id);
CREATE INDEX idx_padi_skill_records_participant ON public.padi_skill_records(participant_id);

ALTER TABLE public.padi_skill_records ENABLE ROW LEVEL SECURITY;
CREATE POLICY padi_skill_records_select ON public.padi_skill_records
  FOR SELECT TO authenticated USING (true);
CREATE POLICY padi_skill_records_insert ON public.padi_skill_records
  FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY padi_skill_records_update ON public.padi_skill_records
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY padi_skill_records_delete ON public.padi_skill_records
  FOR DELETE TO authenticated USING (true);

CREATE TRIGGER trg_padi_skill_records_updated_at
  BEFORE UPDATE ON public.padi_skill_records
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMENT ON TABLE public.padi_skill_records IS
  'Tracks PADI OWD skill completion per (course, participant, skill_code) for the Referral PDF.';
