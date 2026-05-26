# Runbook: AtollCard Lock-Screen Widget (Welle D Part 1)

**Spec:** `docs/superpowers/specs/2026-05-26-atollcard-widget-design.md`
**Plan:** `docs/superpowers/plans/2026-05-26-atollcard-widget.md`

## Pre-Implementation

- [ ] Branch `feat/atollcard-widget` ausgecheckt
- [ ] AtollCard auf Branch `main` ist bei letztem Merge (Welle A+B+C)

## Apple Developer Portal (einmalig, ~5 Min)

### App Group registrieren

- [ ] [developer.apple.com](https://developer.apple.com/account) → Identifiers → oben Dropdown auf **App Groups** → **+**
- [ ] Description: "AtollCard shared container"
- [ ] Identifier: `group.swiss.atoll.card`
- [ ] Continue → Register

### App Group beiden Bundle-IDs zuweisen

- [ ] Identifiers → Filter "App IDs" → `swiss.atoll.card` anklicken
- [ ] Capabilities → **App Groups** ankreuzen → **Configure** → `group.swiss.atoll.card` ankreuzen → Save
- [ ] Falls `swiss.atoll.card.widget` nicht in der Liste ist (kommt erst nach erstem Xcode-Build): warten bis nach Schritt "Generate" unten, dann Schritt wiederholen für widget-ID

### Provisioning Profiles

- [ ] In Xcode: Code-Sign-Sektion fürs Widget-Target → "Update Settings" / "Try Again" wenn Cert-Fehler erscheint

## Code-Deploy

- [ ] `xcodegen generate` im `apps/atollcard-native/` Verzeichnis
- [ ] Xcode öffnet sich mit neuem `AtollCardWidget`-Target
- [ ] Schema "AtollCard" wählen, Build (Cmd+B) — beide Targets sollten grün durchbauen
- [ ] Aufs **echte iPhone** deployen (Cmd+R)

## Lock-Screen-Widget hinzufügen

- [ ] Auf iPhone-Lock-Screen: lang drücken
- [ ] Unten "**Anpassen**" tippen
- [ ] "**Sperrbildschirm**" wählen
- [ ] Unter der Uhr auf das `+ Widget`-Slot tippen
- [ ] App-Liste runter scrollen, **AtollCard** wählen
- [ ] Rectangular Widget tippen → wird platziert
- [ ] Oben **Fertig** rechts

## End-to-End-Test

- [ ] Lock-Screen anschauen — Widget zeigt deinen Default-Karten-Title (z.B. "PADI Course Director · PADI CD")
- [ ] Widget tippen → Phone wird entsperrt → AtollCard öffnet → Fullscreen-QR ist sofort sichtbar
- [ ] In der App eine andere Karte als Default setzen (Karten-Editor → "Als Standard")
- [ ] Lock-Screen-Widget zeigt innert 2-3 Sekunden die neue Karte (Apple kann bis zu ~30s delayen falls Drosselung greift)
- [ ] Logout in der App → Widget zeigt "AtollCard / Karte einrichten" als Fallback

## Rollback

Wenn was bricht:

- App-Group-Eintrag in `AtollCard.entitlements` entfernen → Widget kann nicht mehr lesen → zeigt Fallback (kein Crash)
- Widget-Target aus `project.yml` rauswerfen + `xcodegen generate` → Widget verschwindet aus der App-Bundle, Sperrbildschirm-Widget bleibt aber als "leerer Slot" sichtbar bis User es manuell entfernt
