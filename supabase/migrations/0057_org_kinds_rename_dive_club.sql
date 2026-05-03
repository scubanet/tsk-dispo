-- Organizations: Tauchclub -> Tauchschule (User-Wunsch 2026-05-03)
-- Plus neue Kategorien Partner und Verband sind im Frontend-Dropdown verfügbar.

UPDATE organizations
   SET kind = 'dive_school'
 WHERE kind = 'dive_club';
