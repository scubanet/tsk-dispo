# Setup-Checkliste vor dem Pitch

Vor dem TSK-Termin abarbeiten, in dieser Reihenfolge.

## 1. Edge Functions deployen

```bash
cd ~/Desktop/Developer/Dispo
supabase functions deploy send-notification
supabase functions deploy weekly-export
supabase db push   # 0024 storage bucket + cron stub
```

## 2. Resend einrichten (für Login + Notification-Mails)

1. Account auf [resend.com](https://resend.com) erstellen
2. **Add Domain** → `course-director.ch`
3. Resend zeigt 3 DNS-Einträge (SPF + DKIM TXT-Records)
4. Bei Infomaniak DNS für `course-director.ch` die 3 TXT-Records einfügen
5. ~10 Min warten, bei Resend "Verify" klicken
6. **API Key** generieren (Dashboard → API Keys → Create)
7. In Supabase Project Settings → **Edge Functions Secrets**:
   - `RESEND_API_KEY` = der Key
   - `NOTIFICATION_FROM_EMAIL` = `no-reply@course-director.ch`
   - `APP_URL` = `https://dispo.course-director.ch`

8. Supabase Auth → URL Configuration → SMTP Settings:
   - Sender Email: `no-reply@course-director.ch`
   - Host: `smtp.resend.com`
   - Port: `465`
   - Username: `resend`
   - Password: der API-Key
   - Save

→ Login-Magic-Links + automatische Notification-Emails laufen jetzt über deine eigene Domain.

## 3. Webhook für Notification konfigurieren

In Supabase Dashboard → **Database → Webhooks**:

- Klick **Create a new webhook**
- Name: `notify-on-assignment`
- Table: `course_assignments`
- Events: ✅ Insert · ✅ Delete
- Type: **HTTP Request**
- URL: `https://axnrilhdokkfujzjifhj.supabase.co/functions/v1/send-notification`
- HTTP Headers:
  - `Authorization`: `Bearer <SERVICE_ROLE_KEY>`
- Save

→ Jeder neue/gestrichene Einsatz triggert automatisch eine Email an den Instructor.

## 4. pg_cron + pg_net aktivieren (für wöchentlichen Excel-Export)

In Supabase Dashboard → **Database → Extensions**:
- ✅ Enable `pg_cron`
- ✅ Enable `pg_net`

Danach in **SQL Editor**:

```sql
ALTER DATABASE postgres SET app.weekly_export_url =
  'https://axnrilhdokkfujzjifhj.supabase.co/functions/v1/weekly-export';
ALTER DATABASE postgres SET app.service_role_key =
  '<your-service-role-key-from-Project-Settings-API>';

-- Cron neu schedulen (falls Migration zu früh lief)
SELECT cron.schedule(
  'tsk-dispo-weekly-export',
  '0 23 * * 0',
  $cron$
    SELECT net.http_post(
      url := current_setting('app.weekly_export_url'),
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || current_setting('app.service_role_key'),
        'Content-Type', 'application/json'
      ),
      body := jsonb_build_object('source', 'cron')
    );
  $cron$
);
```

→ Sonntags 23:00 UTC läuft der Excel-Export automatisch.

**Manuell testen** (jetzt sofort):

```bash
curl -X POST https://axnrilhdokkfujzjifhj.supabase.co/functions/v1/weekly-export \
  -H "Authorization: Bearer <SERVICE_ROLE_KEY>"
```

→ Sollte JSON mit `download_url` zurückgeben. URL im Browser öffnen → Excel lädt.

## 5. Test-Loginer einrichten

Drei TL/DM für Soft-Live einladen. Im Supabase SQL Editor:

```sql
-- Aktualisiere Email-Adressen (falls nicht beim Excel-Import dabei)
UPDATE instructors SET email = 'lukas@example.ch' WHERE name = 'Lukas Bader';
UPDATE instructors SET email = 'annick@example.ch' WHERE name = 'Annick den Harder';
UPDATE instructors SET email = 'niggi@example.ch' WHERE name = 'Niklaus Schaffner';
```

Dann lädst du sie ein indem du:
1. Ihnen den Link `https://dispo.course-director.ch` schickst
2. Sie tippen ihre Email + klicken Magic-Link
3. Du verknüpfst nach ihrem ersten Login:

```sql
UPDATE instructors
SET auth_user_id = (SELECT id FROM auth.users WHERE email = 'lukas@example.ch')
WHERE name = 'Lukas Bader';
-- analog für Annick + Niggi
```

→ Beim nächsten Login sehen sie die Instructor-Sicht (Heute / Meine Einsätze / Mein Saldo / Mein Profil).

## 6. Dry-Run mit Test-Loginer

Bitte einen der drei (z.B. Lukas), 1× durch alle 4 Instructor-Screens zu klicken und Feedback zu geben:
- Verstehen sie was sie sehen?
- Stimmt der Saldo (im Vergleich zum Excel-Eintrag den sie kennen)?
- Können sie eine Verfügbarkeit eintragen?

→ Falls ein Instructor noch unsicher ist: Demo-Anleitung `docs/pitch/instructor-quickstart.md` (TODO).

## 7. Pitch durchspielen

Vor dem echten Termin: **eine Person** des Vertrauens einladen, das Pitch-Skript einmal mit ihr/ihm durchgehen. 10–15 min. Achten auf:
- Welche Punkte sind unklar?
- Wo verheddert sich die Demo?
- Welche Fragen kommen, die nicht in der Q&A-Liste stehen?

## 8. Termin vereinbaren

Wenn alles steht: Inhaber kontaktieren, 30-min-Termin vereinbaren. **Nicht** den Termin ohne vorherigen Soft-Live machen — auch wenn er drängt.
