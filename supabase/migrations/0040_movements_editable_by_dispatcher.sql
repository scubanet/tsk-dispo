-- Saldo-Bewegungen editierbar/löschbar für Dispatcher.
--
-- Bisher: Trigger block_account_movement_update verhindert JEDEN UPDATE auf
-- account_movements ("audit-grade integrity"). Pragmatisch für eine Tauchschule
-- mit ~5 Personen ist das übertrieben — der Dispatcher hat ohnehin Vollzugriff
-- auf alle Daten und braucht die Möglichkeit, Tippfehler zu korrigieren.
--
-- Neue Regel:
--   • 'vergütung'  → bleibt immutable. Wird vom Comp-Engine auto-generiert
--                    und beim Recalc neu geschrieben. Manuelles Editieren
--                    wäre verloren.
--   • 'korrektur'  → editierbar/löschbar (manuelle Buchung, Tippfehler-Fix).
--   • 'übertrag'   → editierbar/löschbar (Eröffnungssaldi aus Excel-Import,
--                    falls Korrektur nötig).
--
-- DELETE blockt der Trigger nicht (war schon immer erlaubt für CASCADE-Cleanup
-- wenn ein Assignment gelöscht wird). Wir verlassen uns hier auf RLS:
-- movements_dispatcher_all erlaubt schon DELETE für is_dispatcher().

CREATE OR REPLACE FUNCTION block_account_movement_update()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.kind = 'vergütung' THEN
    RAISE EXCEPTION 'vergütung-Bewegungen sind auto-generiert (Comp-Engine). Statt zu editieren: Assignment ändern oder Korrektur-Buchung anlegen.';
  END IF;
  -- korrektur und übertrag: UPDATE ist erlaubt
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION block_account_movement_update() IS
  'Blockiert UPDATE auf vergütung (auto-generiert). Erlaubt UPDATE auf korrektur und übertrag.';
