# comhub-push

APNs-Push fuer die native ComHub-App. Sendet an alle Geraete der **Owner** eines
Kontakts (`contact_instructor.auth_user_id` → `comhub_device_tokens`).

Status: **Code fertig, NICHT deployed.** Braucht APNs-Credentials + Deploy (Betreiber).

## 1. Secrets setzen (einmalig)

```bash
supabase secrets set \
  COMHUB_PUSH_SECRET="$(openssl rand -hex 24)" \
  APNS_KEY_ID="XXXXXXXXXX" \
  APNS_TEAM_ID="YYYYYYYYYY" \
  APNS_BUNDLE_ID="swiss.atoll.hub" \
  APNS_PRODUCTION="false"
# .p8-Inhalt (mehrzeilig) separat:
supabase secrets set APNS_KEY_P8="$(cat AuthKey_XXXXXXXXXX.p8)"
```

- `APNS_KEY_*` / `.p8` = Apple-Developer → Keys → APNs Auth Key (ES256).
- `APNS_PRODUCTION=false` → APNs-Sandbox (passt zu `aps-environment=development` der App).
  Fuer Release-Builds: App-Entitlement auf `production` + `APNS_PRODUCTION=true`.

## 2. Deploy

```bash
supabase functions deploy comhub-push --no-verify-jwt
```

## 3. In `comms-inbound` einhaengen (nach dem Event-Insert)

Nach dem erfolgreichen `insert` eines eingehenden `contact_events` (gematchter
Kontakt) — fire-and-forget, darf den Webhook nie scheitern lassen:

```ts
// am Anfang der Datei:
const COMHUB_PUSH_SECRET = Deno.env.get('COMHUB_PUSH_SECRET') ?? ''

// nach erfolgreichem Event-Insert (contactId bekannt, NUR inbound):
if (COMHUB_PUSH_SECRET && contactId) {
  try {
    await fetch(`${SUPABASE_URL}/functions/v1/comhub-push`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'x-comhub-push-secret': COMHUB_PUSH_SECRET },
      body: JSON.stringify({
        contact_id: contactId,
        title: senderName ?? 'Neue Nachricht',
        body: summary ?? '',          // Klartext-Vorschau
        threadKey: contactId,
      }),
    })
  } catch (_) { /* Push-Fehler ignorieren */ }
}
```

(Bewusst NICHT automatisch eingebaut, um den laufenden Inbound-Webhook nicht zu
riskieren — beim Deploy zusammen mit den Secrets einfuegen + testen.)

## Request-API

`POST /functions/v1/comhub-push` · Header `x-comhub-push-secret`
```json
{ "contact_id": "uuid", "title": "Anna Muster", "body": "Hallo!", "threadKey": "uuid" }
```
Antwort `{ "sent": N, "total": M }`. Ungueltige Tokens (410/400) werden entfernt.

## App-Seite (bereits gebaut)

- Tabelle `comhub_device_tokens` (Migration `0131`).
- `PushService` (Permission + APNs-Registrierung + Token-Upsert), `PushAppDelegate`,
  Push-Schalter in den Einstellungen.
- Entitlement `aps-environment=development`. Token kommt am echten Geraet erst mit
  push-faehigem Provisioning-Profil + APNs-Cert.
