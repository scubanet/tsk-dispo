# Runbook: AtollCard APNs scharf schalten (Welle B)

**Date:** 2026-05-25
**Spec:** kein voller Spec — Konfigurations-/Deployment-Welle, Detail-Design liegt im Code (PushTokenService, NotificationService, atollcard-lead-push Edge Function, Migrations 0099/0100/0108).
**Voraussetzung:** Welle A (Web-Inbox) gemerged oder mindestens auf dem aktiven Branch.

## Was diese Welle liefert

Echte APNs-Pushes auf dein iPhone wenn ein neuer Lead via Public-Card-Page reinkommt — auch bei komplett geschlossener App. Heute funktionieren nur lokale Notifications wenn die App im Vordergrund/Hintergrund läuft.

## Bekannter Bug (von dieser Welle gefixt)

iOS und Edge Function adressieren `atollcard_device_tokens` (prefixed). Migration 0099 erstellt aber `device_tokens` (unprefixed). Ohne Fix: Token-Upsert schlägt schweigend fehl, Edge Function findet 0 Empfänger. **Migration 0108 in dieser Welle behebt das idempotent** (rename wenn 0099 schon applied, sonst fresh-create).

---

## Schritte

### 1. Migration 0108 anwenden (Dashboard SQL Editor)

**Nur 0108 jetzt** — der Push-Trigger 0100 kommt erst in Schritt 7, nachdem pg_net, GUCs, Secrets und Edge Function alle da sind. Wenn 0100 zu früh läuft, feuert jeder neue Lead einen fehlschlagenden HTTP-Call (Trigger fängt's ab, INSERT funktioniert weiter, aber `net._http_response` füllt sich mit Errors).

- Im Supabase Dashboard → SQL Editor:
  - Inhalt von `supabase/migrations/0108_atollcard_device_tokens_setup.sql` einfügen → Run

Sollte "Success" und ein Notice-Log zeigen (entweder "renamed device_tokens" oder "created atollcard_device_tokens fresh").

**Smoke-Check im selben SQL Editor:**
```sql
SELECT table_name FROM information_schema.tables
WHERE table_schema='public' AND table_name LIKE '%device_tokens%';
-- Soll genau eine Zeile liefern: atollcard_device_tokens
```

### 2. APNs Auth Key generieren

1. [https://developer.apple.com/account](https://developer.apple.com/account) → **Certificates, Identifiers & Profiles** → **Keys** (links) → **+** (oben rechts)
2. **Key Name:** `AtollCard APNs Key`
3. **Services:** ✓ **Apple Push Notifications service (APNs)** → Continue → Register
4. **Download** klicken → die `.p8`-Datei landet in `~/Downloads/AuthKey_XXXXXXXXXX.p8`
   - **Speicher sie sicher** (z.B. in einem 1Password-Eintrag). Apple lässt dich sie nur einmal herunterladen.
5. Notiere zwei Werte:
   - **Key ID** (10-stellig, steht oben auf der Key-Detail-Seite)
   - **Team ID** (`XK8V89P2QV` — oben rechts neben deinem Namen)

### 3. Secrets in Supabase setzen

Terminal:
```bash
cd ~/Desktop/Developer/Dispo

# ABCD123456 ersetzen durch deine Key ID aus Schritt 2
KEY_ID="ABCD123456"
P8_FILE=~/Downloads/AuthKey_${KEY_ID}.p8

supabase secrets set \
  APNS_KEY_ID="$KEY_ID" \
  APNS_TEAM_ID="XK8V89P2QV" \
  APNS_BUNDLE_ID="swiss.atoll.card" \
  APNS_AUTH_KEY_BASE64="$(base64 -i $P8_FILE)"

# Verifizieren:
supabase secrets list | grep APNS
```

Sollte 4 APNS_*-Zeilen anzeigen.

### 4. pg_net Extension aktivieren

Dashboard → **Database** → **Extensions** → Suche `pg_net` → **Enable**.

Smoke-Check im SQL Editor:
```sql
SELECT * FROM pg_extension WHERE extname='pg_net';
-- Soll eine Zeile liefern
```

### 5. GUCs (Custom Settings) konfigurieren

Dashboard → **Database** → **Settings** → unten "Custom Postgres Config" → **Add config**:

| Name | Value |
|---|---|
| `app.edge_function_base_url` | `https://<dein-projektref>.supabase.co/functions/v1` |
| `app.edge_function_anon_key` | (der `anon` key aus Project Settings → API → Project API keys) |

Dann **Save** + **Restart database** wenn Dashboard danach fragt.

Smoke-Check:
```sql
SHOW app.edge_function_base_url;
SHOW app.edge_function_anon_key;
```
Beide sollten Werte liefern (nicht leer).

### 6. Edge Function deployen

```bash
cd ~/Desktop/Developer/Dispo
supabase functions deploy atollcard-lead-push --no-verify-jwt
```

Erwartetes Output: "Deployed Function atollcard-lead-push" mit URL.

### 7. Migration 0100 anwenden (Trigger scharf schalten)

**Jetzt** ist alles bereit (pg_net aktiv, GUCs gesetzt, Edge Function deployed, Secrets da). Erst jetzt darf der Trigger ans Werk.

- Dashboard SQL Editor:
  - Inhalt von `supabase/migrations/0100_atollcard_lead_push_trigger.sql` einfügen → Run

**Smoke-Check:**
```sql
SELECT proname FROM pg_proc WHERE proname='notify_lead_push';
-- Soll eine Zeile liefern

SELECT tgname FROM pg_trigger WHERE tgname='on_card_lead_inserted';
-- Soll eine Zeile liefern
```

### 8. Test auf echtem iPhone

**Wichtig:** Push-Notifications funktionieren **nicht im iOS-Simulator** (Apple-Limitation). Brauchst ein echtes iPhone.

1. **iOS-App auf iPhone bauen + installieren** (Xcode → AtollCard scheme → Run mit angeschlossenem iPhone)
2. **App starten** → Login (`dominik@weckherlin.com`) → Push-Permission-Dialog erlauben
3. **In Supabase Dashboard** `atollcard_device_tokens`-Tabelle öffnen — sollte jetzt 1 Row haben mit deinem iPhone-Device-Token
4. **In Browser** (am Mac, anderer Tab) `http://localhost:5173/c/dominik-cd` öffnen, Lead-Form ausfüllen + senden
5. **Auf iPhone-Lockscreen** sollte innert 2-3 Sekunden eine Push-Notification erscheinen mit dem Lead-Namen
6. **Tap auf Notification** öffnet die iOS-App im Leads-Tab

### 9. Production-Switch (später, vor App-Store-Release)

Heute steht in `AtollCard/AtollCard.entitlements`:
```xml
<key>aps-environment</key>
<string>development</string>
```

Für Production-Build umstellen auf:
```xml
<string>production</string>
```

Sandbox-APNs (heute) und Production-APNs sind getrennte Stacks — TestFlight nutzt schon Production. Wenn du erst direkt über Xcode aufs iPhone lädst, bleib auf development.

---

## Rollback

Wenn nach Schritt 6 alles bricht:

- **Trigger deaktivieren** (Schritt 1 rückgängig):
  ```sql
  DROP TRIGGER IF EXISTS on_card_lead_inserted ON public.card_leads;
  ```
- **Edge Function pausieren** im Dashboard → Functions → atollcard-lead-push → Disable

Lead-INSERTs funktionieren weiter (Trigger ignoriert HTTP-Fehler eh, siehe 0100 Z. 47).

---

## Was danach läuft

- Web-Form füllt aus → Lead in `card_leads`
- Trigger `on_card_lead_inserted` feuert → POST an Edge Function
- Edge Function liest `atollcard_device_tokens` für den Owner der Karte
- Edge Function signiert APNs-JWT mit `.p8`-Key → POST an `api.push.apple.com`
- iPhone bekommt Push, Notification erscheint
- iOS Realtime-Channel (`leadStore.startRealtime()`) zeigt Lead in der iOS-Inbox

---

## Bekannte Limitationen (Out-of-Scope dieser Welle)

- Token-Cleanup wenn Apple einen Token revoked (kommt in einer kleineren Folge-Welle)
- Silent Push für Background-Refresh ohne sichtbare Notification (heute alert-only)
- Multi-Recipient: aktuell pusht die Edge Function nur an Karten-Owner — eine spätere Welle könnte z.B. Tauchschulen-Dispo mit-benachrichtigen, wenn die Dispatcher-Inbox-Erweiterung gebaut wird
