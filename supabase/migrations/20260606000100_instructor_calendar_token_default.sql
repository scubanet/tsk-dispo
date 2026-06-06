-- 20260606000100_instructor_calendar_token_default.sql
--
-- FIX (db reset / pgTAP): 0104 hat instructors.calendar_token als NOT NULL + UNIQUE
-- eingeführt, aber OHNE DEFAULT. Der Backfill in 0104 setzt nur die zum Migrations-
-- zeitpunkt bestehenden Zeilen — jeder SPÄTERE `INSERT INTO instructors`, der die
-- Spalte nicht explizit mitliefert, schlägt mit NOT-NULL-Verletzung fehl. Das trifft
-- u.a. alle pgTAP-Fixtures (01/02/03 sowie 06–11), die einen Test-Instructor anlegen.
--
-- Ein DEFAULT im selben Format wie der 0104-Backfill (24 Byte Random, Base64-kodiert)
-- schließt die Lücke: neue Instructors bekommen automatisch einen eindeutigen Token,
-- die UNIQUE-Constraint bleibt erfüllt (192 Bit Zufall → Kollision vernachlässigbar).
-- Forward-only, idempotent, prod-tauglich (gen_random_bytes stammt aus pgcrypto, in
-- 0001 aktiviert). Behebt zugleich einen latenten Prod-Bug: ein Instructor-Insert ohne
-- explizit gesetzten Token wäre auch dort gescheitert.

ALTER TABLE public.instructors
  ALTER COLUMN calendar_token SET DEFAULT encode(gen_random_bytes(24), 'base64');
