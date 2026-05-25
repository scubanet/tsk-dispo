# Runbook: AtollCard Wallet-Pass-Signing (Welle C)

**Spec:** `docs/superpowers/specs/2026-05-25-atollcard-wallet-design.md`
**Plan:** `docs/superpowers/plans/2026-05-25-atollcard-wallet.md`

## Pre-Implementation

- [ ] Echte ATOLL-Logo-Assets in den 6 Dimensionen besorgen (29/58/87 für icon, 160×50 / 320×100 / 480×150 für logo) — Placeholder-PNGs durch echte ersetzen
- [ ] Code-Review der Edge-Function (Tasks 1-12)

## Apple Developer Portal (einmalig, ~30 Min)

### Pass Type ID registrieren

- [ ] developer.apple.com → Identifiers → Pass Type IDs → +
- [ ] Description: "AtollCard Persona Pass"
- [ ] Identifier: `pass.swiss.atoll.card.persona`
- [ ] Continue → Register

### Pass Type ID Certificate erstellen

- [ ] Auf der neu angelegten Pass-Type-ID den Button "Create Certificate"
- [ ] CSR via Keychain Access generieren (Email = deine, CN = "AtollCard Pass", 2048-bit RSA)
- [ ] CSR-File hochladen → Download `pass.cer`
- [ ] `pass.cer` doppelklicken → wird in Keychain importiert
- [ ] In Keychain Access: Private Key + Cert markieren → Rechtsklick → Export 2 items → `.p12` → Passwort vergeben (1Password) → speichern als `~/Downloads/PassTypeId_Persona.p12`

### Apple WWDR G4 Cert

- [ ] https://www.apple.com/certificateauthority/ → "Worldwide Developer Relations - G4" → `.cer` herunterladen
- [ ] Speichern als `~/Downloads/AppleWWDRCAG4.cer`

## Supabase Secrets

```bash
cd ~/Desktop/Developer/Dispo

P12=~/Downloads/PassTypeId_Persona.p12
WWDR=~/Downloads/AppleWWDRCAG4.cer

supabase secrets set \
  WALLET_PASS_CERT_BASE64="$(base64 -i $P12)" \
  WALLET_PASS_CERT_PASSWORD="<dein-passwort>" \
  WALLET_WWDR_CERT_BASE64="$(base64 -i $WWDR)" \
  WALLET_PASS_TYPE_ID="pass.swiss.atoll.card.persona" \
  WALLET_TEAM_ID="XK8V89P2QV"

supabase secrets list | grep WALLET
```

## Deploy

```bash
supabase functions deploy atollcard-wallet-pass
# Wichtig: kein --no-verify-jwt — Owner-Auth braucht JWT-Verifikation
```

## Smoke

```bash
# CARD_ID + JWT besorgen (aus Browser-DevTools nach Login)
export CARD_ID=<uuid>
export JWT=<jwt-string>
export SUPABASE_URL=https://axnrilhdokkfujzjifhj.supabase.co

bash supabase/functions/atollcard-wallet-pass/__tests__/smoke.sh
```

Expected:
- File ~5-10 KB gross
- `pass.json`, `manifest.json`, `signature`, 6 PNGs im Zip
- "✓ Signature verification: SUCCESS"

## iPhone-Test

- [ ] iOS-Build via Xcode aufs echte iPhone (Push-Notifications & Wallet brauchen echte Hardware)
- [ ] App öffnen → eine Karte → "In Wallet speichern"-Button
- [ ] `PKAddPassesViewController` zeigt sich → "Hinzufügen" → Pass im Wallet sichtbar
- [ ] QR scannen → öffnet `https://atoll-os.com/c/<slug>` im Browser

## Pass-Cert Renewal-Reminder

- [ ] Captain's Log Eintrag: "Pass Type ID Cert läuft <datum + 1 Jahr> — vor Ablauf neu generieren"

## Rollback

Wenn nach Deploy alles bricht:

```bash
# Function pausieren (Dashboard → Edge Functions → atollcard-wallet-pass → Disable)
# oder vorherige Version restoren:
supabase functions list
supabase functions undeploy atollcard-wallet-pass
```

iOS-Seite bleibt: Wallet-Button zeigt Server-Error-Toast, kein Crash.
