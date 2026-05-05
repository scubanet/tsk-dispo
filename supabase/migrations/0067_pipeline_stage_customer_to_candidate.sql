-- Pipeline-Stage 'customer' → 'candidate'
--
-- Im CD-Kontext ist "Kunde" missverständlich — wer den Lead/Qualifiziert/Opportunity-Funnel
-- durchlaufen hat und nun einen Kurs absolviert, ist ein "Kandidat".

UPDATE students
   SET pipeline_stage = 'candidate'
 WHERE pipeline_stage = 'customer';

COMMENT ON COLUMN students.pipeline_stage IS
  'CRM-Pipeline-Stage. Werte: none, lead, qualified, opportunity, candidate, lost.';
