-- CRM v2: contact_relationships + communication_entries
-- Aus CD App Models/ContactRelationship.swift + CommunicationEntry.swift

-- ============================================================
-- contact_relationships
-- ============================================================

CREATE TABLE IF NOT EXISTS contact_relationships (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_id     UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  target_id     UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  kind          TEXT NOT NULL,                         -- 'partner', 'spouse', 'parent', 'child', 'sibling', 'friend', 'colleague', 'mentor', 'mentee', 'referral'
  notes         TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (source_id <> target_id),
  UNIQUE (source_id, target_id, kind)
);

CREATE INDEX IF NOT EXISTS idx_contact_rel_source ON contact_relationships(source_id);
CREATE INDEX IF NOT EXISTS idx_contact_rel_target ON contact_relationships(target_id);

ALTER TABLE contact_relationships ENABLE ROW LEVEL SECURITY;
CREATE POLICY contact_rel_cd_all     ON contact_relationships FOR ALL    USING (is_cd());
CREATE POLICY contact_rel_owner_read ON contact_relationships FOR SELECT USING (is_owner());

-- ============================================================
-- communication_entries
-- ============================================================

CREATE TABLE IF NOT EXISTS communication_entries (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_id   UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  channel      TEXT NOT NULL,                          -- 'email', 'phone', 'whatsapp', 'meeting', 'note', 'other'
  direction    TEXT NOT NULL DEFAULT 'outbound',       -- 'inbound' | 'outbound'
  occurred_on  TIMESTAMPTZ NOT NULL DEFAULT now(),
  subject      TEXT,
  body         TEXT,
  duration_minutes INT,
  outcome      TEXT,                                   -- frei, z.B. 'interested', 'follow-up needed', 'no response'
  created_by   UUID REFERENCES instructors(id) ON DELETE SET NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_comm_contact   ON communication_entries(contact_id);
CREATE INDEX IF NOT EXISTS idx_comm_occurred  ON communication_entries(occurred_on DESC);

ALTER TABLE communication_entries ENABLE ROW LEVEL SECURITY;
CREATE POLICY comm_cd_all     ON communication_entries FOR ALL    USING (is_cd());
CREATE POLICY comm_owner_read ON communication_entries FOR SELECT USING (is_owner());

COMMENT ON TABLE contact_relationships IS
  'CRM v2: Beziehungen zwischen Kontakten (Familie, Empfehlungen, Mentoring etc.)';
COMMENT ON TABLE communication_entries IS
  'CRM v2: Log aller Touchpoints mit Kontakten (Calls, Mails, Meetings).';
