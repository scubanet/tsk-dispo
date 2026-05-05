-- performance_records: Flag "mit Assistent"
--
-- Bei IDC CW/OW-Lehrproben muss der Kandidat zeigen, dass er auch ohne Assistenten
-- arbeiten kann. Pro PR-Record halten wir fest, ob ein Assistent dabei war.

ALTER TABLE performance_records
  ADD COLUMN IF NOT EXISTS with_assistant BOOLEAN;

COMMENT ON COLUMN performance_records.with_assistant IS
  'Bei Lehrproben (CW/OW im IDC): true wenn ein Assistent dabei war, false ohne Assistent. NULL falls nicht relevant.';
