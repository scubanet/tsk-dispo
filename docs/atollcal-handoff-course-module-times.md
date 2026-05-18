# Module-Zeiten pro Kursdatum — Handoff für AtollCal

> **Status:** live in Production seit 18.05.2026 (Migration `0095_course_dates_per_type_times.sql`)
> **Audience:** AtollCal-Team — Calendar-App, die Kurs-Tage als zeitlich verortete Events darstellt
> **Source-of-Truth:** Supabase `public.course_dates`

---

## 1. Hintergrund

Vor der Migration hatte `course_dates` **ein** Zeitfenster pro Tag (`time_from`, `time_to`). Das reichte nicht, weil ein Kurstag mehrere Module kombinieren kann — z. B. Theorie 18:00–21:00 + Pool 19:30–22:00 am selben Datum.

Lösung: pro Type (Theorie / Pool / See) eigene Start- und Endzeit als separate Spalten.

## 2. Schema (post-Migration 0095)

`public.course_dates` Spalten relevant für Calendar:

| Spalte | Typ | Bedeutung |
|---|---|---|
| `id` | UUID | Row-PK |
| `course_id` | UUID | FK → `courses(id)` |
| `date` | DATE | Kurstag |
| `has_theory` | BOOLEAN | Tag enthält Theorie-Block |
| `has_pool` | BOOLEAN | Tag enthält Pool-Block |
| `has_lake` | BOOLEAN | Tag enthält See-Block |
| **`theory_from`** | TIME | Theorie-Start (nullable) |
| **`theory_to`** | TIME | Theorie-Ende (nullable) |
| **`pool_from`** | TIME | Pool-Start (nullable) |
| **`pool_to`** | TIME | Pool-Ende (nullable) |
| **`lake_from`** | TIME | See-Start (nullable) |
| **`lake_to`** | TIME | See-Ende (nullable) |
| `pool_location` | TEXT (enum) | Pool-Ort (mooesli/langnau/kloten/…) |
| `pool_reserved` | BOOLEAN | Pool-Slot bestätigt |
| `note` | TEXT | Freitext |
| `type` | course_date_type | Legacy primary type ('theorie'/'pool'/'see') — bleibt für Backwards-Compat |
| `time_from` / `time_to` | TIME | Legacy single-time — wird durch die per-type-Zeiten abgelöst |

**Constraints:**
- Pro Type-Paar: `*_to > *_from` (CHECK, nullable-tolerant)
- UNIQUE auf `(course_id, date)` — eine Row pro Kurs+Datum

**Schreib-Konvention der Web-App:**
Wenn `has_theory = false` → `theory_from = NULL` und `theory_to = NULL`. Analog für `pool_*` und `lake_*`. AtollCal kann sich auf die Konvention verlassen, sollte aber defensiv beide Flags + Zeiten checken (siehe Calendar-Event-Aufteilung unten).

## 3. Read-Query (Supabase)

### SQL

```sql
SELECT id, course_id, date,
       has_theory, theory_from, theory_to,
       has_pool,   pool_from,   pool_to,
       has_lake,   lake_from,   lake_to,
       pool_location, pool_reserved, note
FROM course_dates
WHERE course_id = $1
ORDER BY date;
```

### Supabase-JS (TypeScript)

```typescript
interface CourseDateRow {
  id: string
  course_id: string
  date: string             // ISO date "YYYY-MM-DD"
  has_theory: boolean
  has_pool: boolean
  has_lake: boolean
  theory_from: string | null   // "HH:MM:SS" (PostgREST-Format)
  theory_to:   string | null
  pool_from:   string | null
  pool_to:     string | null
  lake_from:   string | null
  lake_to:     string | null
  pool_location: string | null
  pool_reserved: boolean
  note: string | null
}

const { data, error } = await supabase
  .from('course_dates')
  .select(
    'id, course_id, date, has_theory, has_pool, has_lake, ' +
    'theory_from, theory_to, pool_from, pool_to, lake_from, lake_to, ' +
    'pool_location, pool_reserved, note',
  )
  .eq('course_id', courseId)
  .order('date')
```

### Zeit-Format

PostgREST liefert TIME-Felder als `"HH:MM:SS"` (z. B. `"18:00:00"`). Für UI-Display auf `"HH:MM"` slicen:

```typescript
const hm = (s: string | null) => (s ? s.slice(0, 5) : '')
```

## 4. Calendar-Event-Aufteilung

Eine `course_dates`-Row erzeugt **0 bis 3 Calendar-Events** (eines pro aktivem Type mit gesetzter Zeit). Empfohlene Expand-Funktion:

```typescript
type CalendarEvent = {
  course_date_id: string
  date: string                    // "YYYY-MM-DD"
  type: 'theory' | 'pool' | 'lake'
  start: string                   // "HH:MM:SS"
  end: string                     // "HH:MM:SS"
  location?: string | null        // nur bei 'pool'
  reserved?: boolean              // nur bei 'pool'
}

function expandCourseDate(cd: CourseDateRow): CalendarEvent[] {
  const events: CalendarEvent[] = []

  if (cd.has_theory && cd.theory_from) {
    events.push({
      course_date_id: cd.id,
      date:  cd.date,
      type:  'theory',
      start: cd.theory_from,
      end:   cd.theory_to ?? cd.theory_from,
    })
  }
  if (cd.has_pool && cd.pool_from) {
    events.push({
      course_date_id: cd.id,
      date:  cd.date,
      type:  'pool',
      start: cd.pool_from,
      end:   cd.pool_to ?? cd.pool_from,
      location: cd.pool_location,
      reserved: cd.pool_reserved,
    })
  }
  if (cd.has_lake && cd.lake_from) {
    events.push({
      course_date_id: cd.id,
      date:  cd.date,
      type:  'lake',
      start: cd.lake_from,
      end:   cd.lake_to ?? cd.lake_from,
    })
  }

  return events
}
```

### Edge-Cases & Behaviors

- **Type aktiv, aber Zeit nicht gesetzt** (`has_theory = true` && `theory_from IS NULL`):
  Dispatcher hat den Type-Toggle angeklickt, aber keine Zeit eingegeben. AtollCal kann das als **All-Day-Event** rendern (mit Type-Label) oder im Calendar überspringen — eure Wahl, je nach UX. Web-App rendert in dem Fall einen Pill ohne Zeit.

- **Nur start, kein end** (`theory_from = '18:00'`, `theory_to = NULL`):
  DB-Constraint erlaubt das. Fallback `end = start` gibt ein Null-Duration-Event. UI kann das als „ab 18:00" markieren statt als Block.

- **Mehrere Events am gleichen Tag überlappen** (Theorie + Pool zeitgleich):
  Möglich und durch UNIQUE nicht verboten. Calendar muss das visuell trennen (z. B. nebeneinander statt übereinander).

- **`time_from` / `time_to` (Legacy):**
  Diese Spalten existieren noch, sind aber für neue Logik nicht zu nutzen. Backfill hat existierende Werte in den primary-Type-Slot kopiert. Sie werden in einer späteren Cleanup-Migration entfernt.

## 5. Cross-Reference: Web-App-Konsumenten

Falls Fragen zum erwarteten Verhalten kommen, sind das die Web-App-Stellen:

| Datei | Rolle |
|---|---|
| `apps/web/src/screens/CourseEditSheet.tsx` | Write-Pfad, `TimeRange`-Component pro Type-Toggle |
| `apps/web/src/screens/CourseDetailPanel.tsx` | Display in Type-Pills |
| `apps/web/src/lib/queries.ts` | `interface CourseDate` (TypeScript-Typen) + `fetchCourseDates` |
| `supabase/migrations/0095_course_dates_per_type_times.sql` | Schema-Definition |

## 6. Change-Log

| Datum | Migration | Änderung |
|---|---|---|
| 18.05.2026 | `0095` | 6 TIME-Spalten ergänzt, Backfill aus `time_from`/`time_to`, CHECK-Constraints |

---

**Kontakt bei Fragen:** Dominik (Atoll-Owner) bzw. Atoll-Repo Issues.
