# Runbook: AtollCard Web-Inbox Rollout

**Spec:** docs/superpowers/specs/2026-05-25-atollcard-web-inbox-design.md
**Plan:** docs/superpowers/plans/2026-05-25-atollcard-web-inbox.md

## Pre-Deployment

- [ ] Migrations 0102/0103/0104 in Staging-DB anwenden, mit psql verifizieren
- [ ] `tags='card-inbox'`-Kollisions-Check in Production:
      `SELECT count(*) FROM contacts WHERE 'card-inbox' = ANY(tags);` → muss 0 sein
- [ ] Web-Build erfolgreich (`npm run build`), Bundle-Size-Check nicht über +50kB

## Deployment Schritt 1 — Feature-Flag aus

- [ ] Migrations auf Produktion: `supabase db push`
- [ ] Web-Code deployen via `vercel --prod`
- [ ] Smoke-Check: `/contacts/card-inbox` ist reachable (200 OK), kein Sidebar-Eintrag

## Deployment Schritt 2 — Feature-Flag an

- [ ] Sidebar-Eintrag für die User-Role `owner` aktivieren (Code-Change oder DB-Flag)
- [ ] Dominik testet selber: Public-Form → Lead erscheint → Import erstellt Contact
- [ ] iOS-Build mit neuem CTA-Text in TestFlight pushen (separater Build)

## Rollback

- [ ] Sidebar-Eintrag entfernen (Code-Revert)
- [ ] Migrations behalten — Bridge-Spalte ist NULL-default, schadet keinem Bestand
- [ ] Bei kritischem Bug der Daten korrumpiert: Restore card_leads + contacts
      auf den Pre-Deployment-Snapshot
