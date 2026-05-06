-- Organizations: Dispatcher darf jetzt auch RW (vorher nur CD)
-- User-Wunsch 2026-05-06: Orgs sind allgemeine Adressverwaltung, nicht nur CD-spezifisch.

DROP POLICY IF EXISTS orgs_dispatcher_all ON organizations;

CREATE POLICY orgs_dispatcher_all
  ON organizations FOR ALL
  USING (is_dispatcher() OR is_cd());
