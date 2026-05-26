# Runbook: AtollCard Offline-Queue (Welle D Part 2)

**Spec:** `docs/superpowers/specs/2026-05-26-atollcard-offline-queue-design.md`
**Plan:** `docs/superpowers/plans/2026-05-26-atollcard-offline-queue.md`

## Pre-Implementation

- [ ] Branch `feat/atollcard-offline-queue` ausgecheckt
- [ ] Vorherige Wellen A+B+C+D-Part-1 sind auf main

## Code-Deploy

- [ ] `xcodegen generate`
- [ ] Xcode öffnet → AtollCard scheme → Cmd+B Build
- [ ] Apps Tests via Cmd+U laufen lassen — CacheStoreTests + MutationDrainerTests müssen grün
- [ ] Cmd+R aufs echte iPhone

## Manueller End-to-End-Test

- [ ] App starten → Karten + Leads sichtbar (online)
- [ ] **Airplane-Mode an** (Wischen vom oberen Rand → Flugzeug-Symbol)
- [ ] App-Vorschau: Offline-Banner sichtbar oben
- [ ] In Inbox auf einen Lead → Status auf "Spam" setzen → lokal sofort sichtbar
- [ ] Avatar in FloatingActionBar zeigt orangenen "1"-Badge
- [ ] Settings → Synchronisation → "1 Aktion wartet" sichtbar
- [ ] **Airplane-Mode aus**
- [ ] Offline-Banner verschwindet
- [ ] Badge verschwindet (Drainer-Erfolg) — kann ~2-3 Sekunden dauern
- [ ] In Browser (Inbox am Mac) → Lead ist auf "Spam"

## Dead-Letter-Test

- [ ] App im Mock-Modus starten (Config.useMockData=true) — Mock-Repo wirft kontrolliert
- [ ] Mehrere Status-Mutationen offline machen
- [ ] Online gehen — Drainer scheitert, nach 5 Versuchen dead-lettert
- [ ] Roter Banner oben — tippen → DeadLetterView
- [ ] "Erneut versuchen" → erfolgreich (Mock-Repo lässt durch)
- [ ] "Verwerfen" → Mutation weg, Lead-Status springt auf Server-Wert zurück beim nächsten Refresh

## Rollback

Wenn der Cache Probleme macht:
- `Config.useMockData = true` setzen — Cache bypassed
- Oder iOS-App: Settings → "Cache zurücksetzen" (falls hinzugefügt) ODER App löschen + neu installieren — neuer leerer Container

## Pass-Cert Renewal-Reminder Note (von Welle C)

(falls Welle C noch nicht rotiert) — Pass Type ID Cert renewal-Reminder weiterhin gültig.
