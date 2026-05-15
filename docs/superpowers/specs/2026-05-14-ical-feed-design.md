# iCal-Feed pro Instructor

**Status:** Draft (User-Review pending)
**Date:** 2026-05-14
**Author:** Dominik Weckherlin (with Claude)
**Spec Owner:** Dominik
**Target Release:** v1.2 (post-Pitch oder spätes Soft-Live)

---

## 1. Kontext & Problem

### Heutiger Zustand

TL/DM sehen ihre Einsätze ausschließlich in der ATOLL-Web/iOS-App
(`MeineEinsätze`-Screen, `Heute`-Dashboard). Wer seinen Schichtplan auf einen
Blick mit privaten Terminen abgleichen will, muss zwischen ATOLL und Apple
Calendar / Google Calendar / Outlook hin- und herwechseln und manuell
eintragen.

### Pain-Points

1. **Keine Sicht auf Konflikte mit privaten Terminen** ohne manuelles
   Übertragen.
2. **iOS-Push** ist nicht verbunden — Instructor hat nur die App-internen
   „Heute"-Tiles als Reminder.
3. **Familien-/Partner-Sicht:** Wenn der Apple-Kalender mit dem Partner geteilt
   ist, sieht der nicht, an welchen Abenden Tauchen ist.
4. **Wiederkehrende Frage** beim Soft-Live: „Wie kann ich meine ATOLL-Einsätze
   in meinem normalen Kalender sehen?"

### Zielbild

Jeder Instructor abonniert in Apple Calendar (oder Google / Outlook) einen
URL und sieht ab da seine ATOLL-Einsätze automatisch im normalen Kalender —
mit Updates ungefähr stündlich (Apple-Default-Polling), one-way (Read-only).

## 2. Architektur-Entscheidung

**Gewählt: iCal-Feed (RFC 5545) pro Instructor**, ausgeliefert von einer
Supabase Edge Function. Begründung gegenüber Alternativen:

| Aspekt | iCal-Feed (gewählt) | REST-API | CalDAV/Webhook |
|---|---|---|---|
| Implementation | 1 Edge Function (~150 LOC) | mehrere Endpoints + Auth + iOS-Client | eigener Server, sehr aufwändig |
| Apple Calendar (macOS + iOS) | nativ via „Subscribe to Calendar" | braucht extra App | komplex |
| Google / Outlook | universell | jeweils eigene Integration | eingeschränkt |
| Push-Updates | Polling (Default 1h) | Echtzeit | Echtzeit |
| Two-Way Sync | nur Read | möglich | ja |
| Wartung | praktisch null | mittel | hoch |

Two-Way wird nicht gebraucht — TL/DM trägt Verfügbarkeit in ATOLL ein, nicht
im Apple Calendar (siehe AvailabilityTab-Spec). Polling-Latenz von 1h für
Kursplanung ist unkritisch.

## 3. Scope

**In Scope für diese Etappe:**

- Pro Instructor ein iCal-Feed mit allen eigenen `course_assignments` im
  Zeitfenster `now() - 180 Tage` bis `now() + 730 Tage`.
- Token-basierte Auth (rotatable).
- UI im `MyProfileScreen` zum Anzeigen + Kopieren + Rotieren des Feed-URLs.

**Out of Scope (später):**

- Verfügbarkeits-Einträge (Urlaub/Abwesend) im Feed.
- Dispatcher-Master-Feed (alle Kurse des Centers).
- Schüler-Feeds.
- Two-Way Sync.
- Push-Updates über Apple Push.

## 4. Komponenten

Drei Bausteine, die unabhängig testbar sind:

### 4.1 Schema & Token-Lifecycle

Neue Migration `0095_instructor_calendar_token.sql`:

```sql
ALTER TABLE instructors ADD COLUMN calendar_token TEXT UNIQUE;
UPDATE instructors SET calendar_token = encode(gen_random_bytes(24), 'base64')
  WHERE calendar_token IS NULL;
ALTER TABLE instructors ALTER COLUMN calendar_token SET NOT NULL;
CREATE INDEX idx_instructors_calendar_token ON instructors(calendar_token);
```

24 Bytes Base64 → 32 Zeichen URL-sicher (z.B. `Qz7vGq8mNk2pXr5tYwH9LjKf3aBcDeFg`).
`gen_random_bytes` ist part of `pgcrypto` extension — bereits in Migration 0001
aktiviert.

**Rotate-RPC** `rotate_calendar_token()`:

```sql
CREATE OR REPLACE FUNCTION rotate_calendar_token()
RETURNS TEXT
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_new_token TEXT;
  v_instructor_id UUID;
BEGIN
  SELECT id INTO v_instructor_id
  FROM instructors WHERE auth_user_id = auth.uid();

  IF v_instructor_id IS NULL THEN
    RAISE EXCEPTION 'No instructor record for current user';
  END IF;

  v_new_token := encode(gen_random_bytes(24), 'base64');
  UPDATE instructors SET calendar_token = v_new_token
   WHERE id = v_instructor_id;
  RETURN v_new_token;
END;
$$;

GRANT EXECUTE ON FUNCTION rotate_calendar_token() TO authenticated;
```

Sicherheit: Funktion läuft als `SECURITY DEFINER`, prüft `auth.uid()` selbst,
gibt nur den eigenen Token zurück.

### 4.2 Edge Function `ical-feed`

Pfad: `supabase/functions/ical-feed/index.ts`. Pattern wie existierende
Functions (`weekly-export`, `send-notification`): Deno + `serve()` aus
std/http, Supabase JS Client mit Service-Role-Key.

**Routing:** Einsteiger-Variante: direkt die Supabase-Function-URL,
`https://<project>.supabase.co/functions/v1/ical-feed?token=<token>`. Später
optional Vercel-Rewrite `/ical?token=...` für hübschere URL.

**Logik:**

1. Token aus Query-Param lesen → wenn fehlend: 400 plain-text.
2. Service-Role-Client erstellen.
3. `SELECT id, name FROM instructors WHERE calendar_token = ?` → 404 wenn
   nicht gefunden.
4. Assignments + Courses + Course-Dates laden:
   ```sql
   SELECT ca.id, ca.role, ca.confirmed, ca.assigned_for_dates, ca.updated_at,
          c.id, c.title, c.status, c.location, c.start_date,
          c.additional_dates, c.notes,
          ct.code AS course_type
   FROM course_assignments ca
   JOIN courses c ON c.id = ca.course_id
   LEFT JOIN course_types ct ON ct.id = c.type_id
   WHERE ca.instructor_id = $1
     AND c.start_date >= now()::date - INTERVAL '180 days'
     AND c.start_date <= now()::date + INTERVAL '730 days'
     AND c.status != 'cancelled'
   ```
5. Pro Assignment alle relevanten Daten aufzählen:
   - Wenn `assigned_for_dates` leer → alle Daten = `[start_date]` ∪
     `additional_dates`.
   - Sonst nur die explizit gelisteten Daten.
6. Pro `(assignment, date)` die optionalen Zeitslots aus `course_dates` lesen
   (eigene Query, gebatcht über IN-Klausel).
7. .ics-String bauen (siehe 4.3).
8. Response: `Content-Type: text/calendar; charset=utf-8`, `Cache-Control:
   no-cache, must-revalidate`.

**Fehlerbehandlung:** Token nicht gefunden → 404. DB-Fehler → 500. Logs
dürfen den Token nicht im Klartext enthalten — nur die Instructor-ID nach
Auflösung.

### 4.3 .ics-Format

**Calendar-Header:**

```
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//ATOLL//ical-feed//DE
METHOD:PUBLISH
X-WR-CALNAME:ATOLL — <Instructor Name>
X-WR-TIMEZONE:Europe/Zurich
REFRESH-INTERVAL;VALUE=DURATION:PT1H
X-PUBLISHED-TTL:PT1H
```

Plus VTIMEZONE-Block für Europe/Zurich (Standard-Definition mit DST-Regeln,
einmalig im Modul vordefiniert).

**Event-Block (Ganztags):**

```
BEGIN:VEVENT
UID:assignment-<assignment_id>-<YYYYMMDD>@dispo.course-director.ch
DTSTAMP:<jetzt-UTC>
DTSTART;VALUE=DATE:<YYYYMMDD>
DTEND;VALUE=DATE:<YYYYMMDD+1>
SUMMARY:<course title> (<role>)
LOCATION:<courses.location wenn gesetzt>
DESCRIPTION:Status: <status>\\nKurstyp: <course_type>\\nTeilnehmer: <num>
STATUS:CONFIRMED|TENTATIVE
LAST-MODIFIED:<assignments.updated_at-UTC>
SEQUENCE:0
END:VEVENT
```

**Event-Block (mit Zeitslot aus `course_dates`):**

```
DTSTART;TZID=Europe/Zurich:<YYYYMMDDTHHMMSS>
DTEND;TZID=Europe/Zurich:<YYYYMMDDTHHMMSS>
```

statt der `VALUE=DATE`-Variante.

**UID-Strategie** ist deterministisch: `assignment-<id>-<date>`. Bei Updates
am Assignment → gleiche UID, neuer `LAST-MODIFIED` + `SEQUENCE`. Apple
Calendar erkennt das als Update. Wenn ein Datum aus `assigned_for_dates`
rausfliegt oder das Assignment gelöscht wird → Event taucht im nächsten Pull
nicht mehr auf, Calendar entfernt es.

**Status-Mapping:**

- `course.status = 'confirmed'` → `STATUS:CONFIRMED`
- `course.status = 'tentative'` → `STATUS:TENTATIVE`
- `course.status = 'cancelled'` → Event komplett weglassen (sauberer als
  STATUS:CANCELLED, da Apple das nicht zuverlässig rendert).

**Line Folding:** RFC 5545 verlangt max. 75 Bytes pro Zeile. Lange
SUMMARY/DESCRIPTION müssen mit `\r\n ` (CRLF + space) gefaltet werden.
Helper-Funktion im Modul.

**Escaping:** Backslash, Komma, Semikolon, Newline in Text-Werten escapen.
Helper-Funktion.

### 4.4 MyProfileScreen-Erweiterung

Neue Sektion zwischen „Skills" und „Verfügbarkeit":

```
┌─ Kalender-Sync ───────────────────────────────────────────────┐
│  Abonniere deine Einsätze in Apple Calendar / Google /        │
│  Outlook — Updates ~stündlich automatisch.                    │
│                                                               │
│  [https://...supabase.co/.../ical-feed?token=Qz7vGq8m...] [📋]│
│                                                               │
│  Anleitung Apple Calendar ▾                                   │
│    macOS: Datei → Neues Kalender-Abo → URL einfügen           │
│    iOS: Einstellungen → Kalender → Accounts → Hinzufügen      │
│         → Anderer → Kalender-Abo                              │
│                                                               │
│  [ Token zurücksetzen ]   ← klein, danger-styling             │
└───────────────────────────────────────────────────────────────┘
```

**Daten-Layer:** neuer Helper `fetchMyCalendarToken(instructorId)` in
`lib/queries.ts` (`SELECT calendar_token FROM instructors WHERE id = ?`),
neuer Helper `rotateMyCalendarToken()` ruft die RPC auf.

**Copy-Button:** `navigator.clipboard.writeText()`, Toast „URL kopiert" über
das bestehende Toast-System.

**Rotate-Button:** `confirm()`-Dialog („Alte Subscription wird ungültig —
sicher?"), dann RPC, dann Token-State neu setzen.

**Edge-Function-URL bauen:** Konstante `ICAL_FEED_BASE_URL` in
`lib/config.ts` (oder analog zu existierenden Konstanten), zusammensetzen mit
`?token=<token>`.

**i18n:** Neue Keys unter `my_profile.calendar_*` (DE + EN), Liste:
`calendar_section_title`, `calendar_subtitle`, `calendar_copy_button`,
`calendar_copied_toast`, `calendar_rotate_button`, `calendar_rotate_confirm`,
`calendar_apple_help_title`, `calendar_apple_help_macos`,
`calendar_apple_help_ios`.

## 5. Sicherheit

- **Token-URL:** lange Random-Strings (24 Bytes ≈ 192 bit Entropie). Für
  Pitch-Soft-Live mit ~5 Instructors keine Brute-Force-Bedrohung.
- **Token-Leak via Logs:** Edge-Function darf nur die Instructor-ID nach
  Auth-Auflösung loggen, nie den Token.
- **HTTPS-only:** Supabase erzwingt TLS, kein zusätzlicher Aufwand.
- **Token rotieren:** möglich via UI-Button — alte Subscription wird sofort
  ungültig.
- **RLS:** `calendar_token`-Spalte muss über RLS so geschützt sein, dass nur
  der eigene Instructor (und der Service-Role-Key in der Edge Function) den
  eigenen Token lesen kann. Andere Instructors sollen den Token nicht
  zufällig durch eine `SELECT *`-Query mitkriegen.

## 6. Akzeptanzkriterien

- [ ] Migration `0095` ist applied: alle Instructors haben einen
      `calendar_token`, Spalte ist NOT NULL UNIQUE.
- [ ] RPC `rotate_calendar_token()` existiert und gibt für den eingeloggten
      Instructor einen neuen Token zurück.
- [ ] Edge Function `ical-feed` antwortet auf
      `?token=<valid>` mit `200 text/calendar` und einem RFC-5545-konformen
      .ics-Body.
- [ ] Edge Function antwortet mit `404` bei unbekanntem Token, mit `400` bei
      fehlendem Token-Param.
- [ ] In Apple Calendar (macOS) lässt sich der URL als „Neues Kalender-Abo"
      hinzufügen, alle eigenen Einsätze tauchen auf.
- [ ] In Apple Calendar (iOS) lässt sich der URL ebenfalls hinzufügen.
- [ ] Bei einer Änderung an einem Assignment in ATOLL erscheint die Änderung
      nach dem nächsten Pull (manuell ausgelöst via Pull-Down-Refresh) im
      Kalender.
- [ ] Bei Token-Rotation wird die alte Subscription beim nächsten Pull
      ungültig (404 → Apple Calendar zeigt Fehler).
- [ ] MyProfileScreen zeigt den URL mit Copy-Button. Copy funktioniert.
- [ ] MyProfileScreen-Rotate-Button erzeugt einen neuen Token, alter URL
      wird ungültig.
- [ ] Alle Strings haben DE + EN-Keys.

## 7. Risiken / Verifizieren vor Implementierung

1. **Edge-Function Cold-Start** — erster Pull nach Idle dauert 1-2 Sek.
   Apple Calendar hat 30-Sek Timeout, also unkritisch.
2. **iOS Calendar Refresh-Frequenz** — Apple ignoriert `REFRESH-INTERVAL`
   manchmal und macht eigene Heuristik (1-4h). User-Setting in iOS:
   Einstellungen → Kalender → Synchronisieren = „Push" oder „Alle 15 Min".
3. **Supabase Edge-Function-Logs** — überprüfen, ob Query-String automatisch
   geloggt wird (kann Token leaken). Falls ja: Function muss vor jedem Log
   Token redacten.
4. **Multiple Instructor-Identitäten** — wenn ein User später mehrere
   Instructor-Records hat (z.B. nach merge_contacts), muss `auth.uid() →
   instructor_id` eindeutig bleiben. Heute ist das via
   `instructors.auth_user_id` UNIQUE garantiert.
5. **`pgcrypto`-Verfügbarkeit** — `gen_random_bytes` ist Teil von pgcrypto.
   Vor Apply der Migration prüfen: `SELECT * FROM pg_extension WHERE extname
   = 'pgcrypto'` muss eine Zeile zurückgeben.
