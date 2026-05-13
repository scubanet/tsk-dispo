# AvailabilityTab — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Den `AvailabilityTab`-Stub im Dispatcher-Kontakt-Detail durch eine echte gruppierte Anzeige (Aktuell / Zukünftig / Vergangen) ersetzen und dem Dispatcher erlauben, Einträge stellvertretend für TL/DM anzulegen oder zu löschen — durch Wiederverwendung der vorhandenen Self-Service-Komponenten aus `MyProfileScreen`.

**Architecture:** Die Row- und Add-Sheet-Komponenten werden aus `MyProfileScreen.tsx` in ein gemeinsames Modul `apps/web/src/components/availability/` extrahiert und in beiden Aufrufern (MyProfileScreen + neuer AvailabilityTab) wiederverwendet. Der Daten-Helper `fetchMyAvailability` wird zu `fetchAvailability` umbenannt — funktional identisch. Die Gruppierung in drei Sektionen passiert frontend-seitig durch Datums-Vergleich gegen `today`. Kein Schema-Change, keine neuen Migrationen.

**Tech Stack:** React 18 + TypeScript + Vite, Supabase Client (`@supabase/supabase-js`), `react-i18next` für i18n, Foundation-Komponenten (`Pill`, `Icon`, `dateMedium`), Vitest installiert aber keine bestehenden Tests im `apps/web/src` — Verifikation läuft per `npm run typecheck`, `npm run lint`, `npm run build` und manuellem Klick-Test.

**Quellspec:** `docs/superpowers/specs/2026-05-13-availability-tab-design.md`

---

## Pre-Flight: Schema- und RLS-Verifizierung

Vor der ersten Code-Änderung gegen Production absichern, dass die Annahmen aus dem Spec halten (Memory-Feedback: Schema-Drift hat in der Vergangenheit Bugs verursacht).

- [ ] **Step P.1: `contactId === instructors.id`-Annahme prüfen**

In Supabase SQL Editor (Production-Projekt) ausführen:

```sql
SELECT COUNT(*) AS matches
FROM instructors i
JOIN contacts c ON c.id = i.id;

SELECT COUNT(*) AS instructor_total FROM instructors;
```

Expected: `matches === instructor_total`. Wenn nicht: ID-Mapping ist gebrochen, vor weitermachen mit User klären (Phase J FK-Retarget-Status checken).

- [ ] **Step P.2: RLS-Policies auf `availability` prüfen**

```sql
SELECT polname, polcmd, pg_get_expr(polqual, polrelid) AS using_expr
FROM pg_policy
WHERE polrelid = 'public.availability'::regclass;
```

Expected: Mindestens je eine Policy für SELECT, INSERT, DELETE, die für Rolle `dispatcher` (oder über `is_dispatcher()`-Helper) zugreifbar ist. Wenn DELETE/INSERT-Policy fehlt: nach dem Plan eine kleine Folge-Migration `0093_availability_dispatcher_rls.sql` planen — diese **nicht** in diesem Plan implementieren, sondern als separates Stück mit User abstimmen.

- [ ] **Step P.3: Sync-Trigger-Drift-Check seit 10.05. (per Memory-Notiz)**

```sql
SELECT i.id, i.name
FROM instructors i
LEFT JOIN contacts c ON c.id = i.id
WHERE c.id IS NULL;
```

Expected: leere Ergebnismenge. Wenn Drift vorhanden: User informieren, vorher manuell backfillen wie am 10.05.

---

## Task 1: i18n-Keys hinzufügen

**Files:**
- Modify: `apps/web/src/i18n/locales/de.json`
- Modify: `apps/web/src/i18n/locales/en.json`

- [ ] **Step 1.1: Neue Keys in `de.json` einfügen**

Im Block `"contacts"` direkt nach `"availability_stub"` (Zeile 987) ersetzen / ergänzen.

**Alt (`de.json` Zeile 987):**
```json
    "availability_stub": "Availability-Tab — wird in einer späteren Phase implementiert.",
```

**Neu (`de.json` an gleicher Stelle):**
```json
    "availability_section_current": "Aktuell",
    "availability_section_future": "Zukünftig",
    "availability_section_past": "Vergangen",
    "availability_show_past": "Vergangene anzeigen ({{count}})",
    "availability_hide_past": "Vergangene ausblenden",
    "availability_empty_state": "Noch keine Verfügbarkeit eingetragen.",
    "availability_add_button": "+ Eintrag",
```

Den alten `availability_stub`-Key entfernen — er wird nicht mehr referenziert.

- [ ] **Step 1.2: Gleiche Keys in `en.json` einfügen**

**Alt (`en.json` Zeile 987):**
```json
    "availability_stub": "Availability tab — to be implemented in a later phase.",
```

**Neu (`en.json` an gleicher Stelle):**
```json
    "availability_section_current": "Current",
    "availability_section_future": "Upcoming",
    "availability_section_past": "Past",
    "availability_show_past": "Show past ({{count}})",
    "availability_hide_past": "Hide past",
    "availability_empty_state": "No availability entered yet.",
    "availability_add_button": "+ Entry",
```

`availability_stub` ebenfalls entfernen.

- [ ] **Step 1.3: JSON-Validität prüfen**

Run:
```bash
cd apps/web && node -e "JSON.parse(require('fs').readFileSync('src/i18n/locales/de.json', 'utf-8')); JSON.parse(require('fs').readFileSync('src/i18n/locales/en.json', 'utf-8')); console.log('OK')"
```
Expected: `OK` (keine Syntax-Fehler durch trailing comma o.Ä.).

- [ ] **Step 1.4: Commit**

```bash
git add apps/web/src/i18n/locales/de.json apps/web/src/i18n/locales/en.json
git commit -m "i18n(availability): keys für AvailabilityTab-Gruppierung + Empty-State"
```

---

## Task 2: Daten-Helper umbenennen

**Files:**
- Modify: `apps/web/src/lib/queries.ts:222-239`
- Modify: `apps/web/src/screens/MyProfileScreen.tsx:31-37,72`

- [ ] **Step 2.1: Helper umbenennen in `queries.ts`**

In `apps/web/src/lib/queries.ts` ersetzen:

**Alt (Zeile 231):**
```ts
export async function fetchMyAvailability(instructorId: string): Promise<AvailabilityRow[]> {
```

**Neu:**
```ts
export async function fetchAvailability(instructorId: string): Promise<AvailabilityRow[]> {
```

(Der `AvailabilityRow`-Typ ab Zeile 222 bleibt unverändert.)

- [ ] **Step 2.2: Import + Aufruf in `MyProfileScreen.tsx` anpassen**

In `apps/web/src/screens/MyProfileScreen.tsx`:

**Alt (Zeile 32-37):**
```ts
import {
  fetchMySkills,
  fetchMyAvailability,
  fetchCertifications,
  type MySkill,
  type AvailabilityRow,
} from '@/lib/queries'
```

**Neu:**
```ts
import {
  fetchMySkills,
  fetchAvailability,
  fetchCertifications,
  type MySkill,
  type AvailabilityRow,
} from '@/lib/queries'
```

**Alt (Zeile 72):**
```ts
    fetchMyAvailability(user.instructorId).then(setAvailability)
```

**Neu:**
```ts
    fetchAvailability(user.instructorId).then(setAvailability)
```

- [ ] **Step 2.3: Typecheck und Reststellen finden**

Run:
```bash
cd apps/web && npm run typecheck 2>&1 | head -40
```
Expected: keine Fehler. Falls Fehler vom Typ "Cannot find name 'fetchMyAvailability'" auftauchen, in den genannten Dateien ebenfalls umbenennen.

Run zusätzlich:
```bash
cd apps/web && grep -rn "fetchMyAvailability" src/
```
Expected: keine Treffer (alle Stellen umbenannt).

- [ ] **Step 2.4: Commit**

```bash
git add apps/web/src/lib/queries.ts apps/web/src/screens/MyProfileScreen.tsx
git commit -m "refactor(availability): fetchMyAvailability → fetchAvailability (generisch nutzbar)"
```

---

## Task 3: Shared-Komponenten extrahieren

**Files:**
- Create: `apps/web/src/components/availability/AvailabilityRow.tsx`
- Create: `apps/web/src/components/availability/AvailabilityAddSheet.tsx`
- Create: `apps/web/src/components/availability/index.ts`
- Modify: `apps/web/src/screens/MyProfileScreen.tsx` (Komponenten entfernen, importieren)

- [ ] **Step 3.1: `AvailabilityRow.tsx` anlegen**

Datei `apps/web/src/components/availability/AvailabilityRow.tsx` mit folgendem Inhalt erstellen:

```tsx
/**
 * AvailabilityRow — Einzelner Eintrag mit Kind-Pill, Zeitraum, Notiz, Delete.
 * Wird sowohl im MyProfileScreen (TL/DM-Self-Service) als auch im
 * AvailabilityTab (Dispatcher-Sicht) verwendet.
 */

import { useTranslation } from 'react-i18next'
import { Pill, Icon, dateMedium } from '@/foundation'
import { supabase } from '@/lib/supabase'
import type { AvailabilityRow as AvailabilityRowData } from '@/lib/queries'

interface Props {
  row: AvailabilityRowData
  onDeleted: () => void
}

export function AvailabilityRow({ row, onDeleted }: Props) {
  const { t } = useTranslation()
  const tone =
    row.kind === 'urlaub' ? 'brand' :
    row.kind === 'abwesend' ? 'warning' :
    'success'

  async function del() {
    if (!confirm(t('my_profile.confirm_delete', { kind: t(`my_profile.kind_${row.kind}`) }))) return
    await supabase.from('availability').delete().eq('id', row.id)
    onDeleted()
  }

  return (
    <div className="atoll-myprofile__avail-row">
      <Pill tone={tone} size="sm">{t(`my_profile.kind_${row.kind}`)}</Pill>
      <div className="atoll-myprofile__avail-body">
        <div className="atoll-myprofile__avail-date tabular-nums">
          {dateMedium(row.from_date)}
          {row.from_date !== row.to_date && ` – ${dateMedium(row.to_date)}`}
        </div>
        {row.note && <div className="atoll-myprofile__avail-note">{row.note}</div>}
      </div>
      <button
        type="button"
        className="atoll-iconbtn"
        onClick={del}
        title={t('common.delete')}
        aria-label={t('common.delete')}
      >
        <Icon.Close size={14} />
      </button>
    </div>
  )
}
```

- [ ] **Step 3.2: `AvailabilityAddSheet.tsx` anlegen**

Datei `apps/web/src/components/availability/AvailabilityAddSheet.tsx` mit folgendem Inhalt erstellen:

```tsx
/**
 * AvailabilityAddSheet — Sheet zum Anlegen eines neuen Verfügbarkeits-Eintrags.
 * Identisch genutzt vom MyProfileScreen (TL/DM trägt sich selbst ein) und
 * AvailabilityTab (Dispatcher trägt stellvertretend ein).
 */

import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Sheet } from '@/components/Sheet'
import { supabase } from '@/lib/supabase'

const sheetInputStyle = {
  padding: '8px 10px',
  borderRadius: 8,
  border: '1px solid var(--border-tertiary)',
  background: 'var(--bg-card)',
  color: 'var(--text-primary)',
  font: 'inherit',
  fontSize: 13.5,
  width: '100%',
}

interface Props {
  open: boolean
  onClose: () => void
  onCreated: () => void
  instructorId: string
}

export function AvailabilityAddSheet({ open, onClose, onCreated, instructorId }: Props) {
  const { t } = useTranslation()
  const [kind, setKind] = useState<'urlaub' | 'abwesend' | 'verfügbar'>('urlaub')
  const [fromDate, setFromDate] = useState(new Date().toISOString().slice(0, 10))
  const [toDate, setToDate] = useState(new Date().toISOString().slice(0, 10))
  const [note, setNote] = useState('')
  const [saving, setSaving] = useState(false)

  async function save() {
    setSaving(true)
    const { error } = await supabase.from('availability').insert({
      instructor_id: instructorId,
      from_date: fromDate,
      to_date: toDate,
      kind,
      note: note.trim() || null,
    })
    setSaving(false)
    if (error) {
      alert(t('settings.recalc.error_prefix') + error.message)
      return
    }
    onCreated()
    onClose()
    setKind('urlaub')
    setNote('')
  }

  return (
    <Sheet open={open} onClose={onClose} title={t('my_profile.add_availability')}>
      <div style={{ display: 'grid', gap: 14 }}>
        <div>
          <div className="caption-2" style={{ marginBottom: 4 }}>{t('my_profile.label_kind')}</div>
          <select
            value={kind}
            onChange={(e) => setKind(e.target.value as typeof kind)}
            style={sheetInputStyle}
          >
            <option value="urlaub">{t('my_profile.kind_urlaub')}</option>
            <option value="abwesend">{t('my_profile.kind_abwesend')}</option>
            <option value="verfügbar">{t('my_profile.kind_verfügbar_long')}</option>
          </select>
        </div>

        <div>
          <div className="caption-2" style={{ marginBottom: 4 }}>{t('my_profile.label_from')}</div>
          <input
            type="date"
            value={fromDate}
            onChange={(e) => setFromDate(e.target.value)}
            style={sheetInputStyle}
          />
        </div>

        <div>
          <div className="caption-2" style={{ marginBottom: 4 }}>{t('my_profile.label_to')}</div>
          <input
            type="date"
            value={toDate}
            onChange={(e) => setToDate(e.target.value)}
            style={sheetInputStyle}
          />
        </div>

        <div>
          <div className="caption-2" style={{ marginBottom: 4 }}>{t('my_profile.label_note')}</div>
          <input
            value={note}
            onChange={(e) => setNote(e.target.value)}
            placeholder={t('my_profile.note_placeholder')}
            style={sheetInputStyle}
          />
        </div>

        <div style={{ display: 'flex', gap: 8 }}>
          <button className="atoll-btn" onClick={onClose}>{t('common.cancel')}</button>
          <button
            className="atoll-btn atoll-btn--primary"
            onClick={save}
            disabled={saving}
            style={{ flex: 1 }}
          >
            {saving ? t('common.saving') : t('my_profile.add_entry')}
          </button>
        </div>
      </div>
    </Sheet>
  )
}
```

- [ ] **Step 3.3: Barrel-Export `index.ts` anlegen**

Datei `apps/web/src/components/availability/index.ts`:

```ts
export { AvailabilityRow } from './AvailabilityRow'
export { AvailabilityAddSheet } from './AvailabilityAddSheet'
```

- [ ] **Step 3.4: `MyProfileScreen.tsx` umstellen**

In `apps/web/src/screens/MyProfileScreen.tsx` zwei Dinge:

(a) Neuen Import oben einfügen (nach den bestehenden Imports, vor `interface Profile`):

```ts
import { AvailabilityRow, AvailabilityAddSheet } from '@/components/availability'
```

(b) Die lokalen Funktionen `AvailabilityRowView` (ab Zeile ~247) und `AvailabilityAddSheet` (ab Zeile ~382) komplett aus der Datei entfernen — inklusive ihrer Header-Kommentar-Linien (`// ──── Availability Row ────` und `// ──── Availability Add Sheet ────`).

(c) Im JSX-Body alle Verwendungen von `<AvailabilityRowView` zu `<AvailabilityRow` umbenennen. Aktuelle Stelle: Zeile ~220:

**Alt:**
```tsx
<AvailabilityRowView key={a.id} row={a} onDeleted={refetchAvail} />
```

**Neu:**
```tsx
<AvailabilityRow key={a.id} row={a} onDeleted={refetchAvail} />
```

(d) Wenn das Entfernen der lokalen `AvailabilityAddSheet`-Funktion dazu führt, dass die `Sheet`-Import-Zeile (`import { Sheet } from '@/components/Sheet'`) nicht mehr genutzt wird (weil nur noch `ProfileEditSheet` sie braucht — prüfen!): unbenutzte Imports erst nach Typecheck entfernen. Da `ProfileEditSheet` (Zeile ~291) ebenfalls `Sheet` nutzt, bleibt der Import wahrscheinlich nötig — typecheck zeigt es.

- [ ] **Step 3.5: Typecheck**

Run:
```bash
cd apps/web && npm run typecheck 2>&1 | head -40
```
Expected: keine Fehler. Bei `unused import`-Warnings: relevant für lint, nicht typecheck — kommt in Step 3.6.

- [ ] **Step 3.6: Lint**

Run:
```bash
cd apps/web && npm run lint 2>&1 | head -40
```
Expected: keine Fehler. Bei `no-unused-vars`/`no-unused-imports` in MyProfileScreen den unbenutzten Import entfernen.

- [ ] **Step 3.7: Manueller Regression-Check auf MyProfileScreen**

```bash
cd apps/web && npm run dev
```

Im Browser als TL/DM einloggen → Mein Profil → Verfügbarkeit. Prüfen:
- Liste rendert wie vorher (gleiches Layout)
- `+ Eintrag` öffnet Sheet, Speichern legt Eintrag an, Liste refresht
- Delete-X öffnet Confirm-Dialog, Bestätigen löscht den Eintrag

Wenn ein Verhalten abweicht: zurückrollen, Diff durchgehen.

- [ ] **Step 3.8: Commit**

```bash
git add apps/web/src/components/availability/ apps/web/src/screens/MyProfileScreen.tsx
git commit -m "refactor(availability): Row + AddSheet in shared components/availability/ extrahiert"
```

---

## Task 4: AvailabilityTab implementieren

**Files:**
- Modify: `apps/web/src/screens/contacts/tabs/AvailabilityTab.tsx` (komplett ersetzen)

- [ ] **Step 4.1: AvailabilityTab komplett neu schreiben**

`apps/web/src/screens/contacts/tabs/AvailabilityTab.tsx` mit folgendem Inhalt **vollständig ersetzen**:

```tsx
/**
 * AvailabilityTab — Dispatcher-Sicht auf TL/DM-Verfügbarkeit im
 * Kontakt-Detail-Panel. Gruppiert nach Status (Aktuell / Zukünftig /
 * Vergangen). Dispatcher hat Vollrechte: anlegen + löschen.
 *
 * Sichtbarkeit (kontrolliert in ContactDetailPanel.tsx Zeile ~80):
 * nur bei contact.roles enthält 'instructor'.
 */

import { useEffect, useState, useMemo } from 'react'
import { useTranslation } from 'react-i18next'
import { Icon } from '@/foundation'
import {
  AvailabilityRow as AvailabilityRowView,
  AvailabilityAddSheet,
} from '@/components/availability'
import { fetchAvailability, type AvailabilityRow } from '@/lib/queries'

interface Props {
  contactId: string
}

interface Grouped {
  current: AvailabilityRow[]
  future: AvailabilityRow[]
  past: AvailabilityRow[]
}

function groupByStatus(rows: AvailabilityRow[]): Grouped {
  const today = new Date().toISOString().slice(0, 10)
  const current: AvailabilityRow[] = []
  const future: AvailabilityRow[] = []
  const past: AvailabilityRow[] = []
  for (const r of rows) {
    if (r.to_date < today) past.push(r)
    else if (r.from_date > today) future.push(r)
    else current.push(r)
  }
  // current + future: from_date ASC, past: from_date DESC
  current.sort((a, b) => a.from_date.localeCompare(b.from_date))
  future.sort((a, b) => a.from_date.localeCompare(b.from_date))
  past.sort((a, b) => b.from_date.localeCompare(a.from_date))
  return { current, future, past }
}

export function AvailabilityTab({ contactId }: Props) {
  const { t } = useTranslation()
  const [rows, setRows] = useState<AvailabilityRow[]>([])
  const [loading, setLoading] = useState(true)
  const [showAdd, setShowAdd] = useState(false)
  const [showPast, setShowPast] = useState(false)

  function load() {
    setLoading(true)
    fetchAvailability(contactId)
      .then((data) => setRows(data))
      .catch((err) => console.error('[availability-tab] load failed', err))
      .finally(() => setLoading(false))
  }

  useEffect(() => {
    load()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [contactId])

  const grouped = useMemo(() => groupByStatus(rows), [rows])
  const totalCount = grouped.current.length + grouped.future.length + grouped.past.length

  if (loading) {
    return <div className="contact-tab-body tab-stub">{t('common.loading')}</div>
  }

  return (
    <div className="contact-tab-body">
      {/* Header: Plus-Button rechts */}
      <div
        style={{
          display: 'flex',
          justifyContent: 'flex-end',
          marginBottom: 12,
        }}
      >
        <button
          type="button"
          className="atoll-btn atoll-btn--primary"
          onClick={() => setShowAdd(true)}
        >
          <Icon.Plus size={14} /> {t('contacts.availability_add_button')}
        </button>
      </div>

      {totalCount === 0 ? (
        <div className="tab-stub" style={{ textAlign: 'center', padding: '24px 0' }}>
          {t('contacts.availability_empty_state')}
        </div>
      ) : (
        <>
          {grouped.current.length > 0 && (
            <section className="contact-section">
              <h2 className="contact-section__title">
                {t('contacts.availability_section_current')} ({grouped.current.length})
              </h2>
              <div className="atoll-myprofile__avail-list">
                {grouped.current.map((r) => (
                  <AvailabilityRowView key={r.id} row={r} onDeleted={load} />
                ))}
              </div>
            </section>
          )}

          {grouped.future.length > 0 && (
            <section className="contact-section">
              <h2 className="contact-section__title">
                {t('contacts.availability_section_future')} ({grouped.future.length})
              </h2>
              <div className="atoll-myprofile__avail-list">
                {grouped.future.map((r) => (
                  <AvailabilityRowView key={r.id} row={r} onDeleted={load} />
                ))}
              </div>
            </section>
          )}

          {grouped.past.length > 0 && (
            <section className="contact-section">
              <div
                style={{
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'center',
                }}
              >
                <h2 className="contact-section__title">
                  {t('contacts.availability_section_past')} ({grouped.past.length})
                </h2>
                <button
                  type="button"
                  className="atoll-btn"
                  onClick={() => setShowPast((v) => !v)}
                  style={{ fontSize: 12 }}
                >
                  {showPast
                    ? t('contacts.availability_hide_past')
                    : t('contacts.availability_show_past', { count: grouped.past.length })}
                </button>
              </div>
              {showPast && (
                <div className="atoll-myprofile__avail-list">
                  {grouped.past.map((r) => (
                    <AvailabilityRowView key={r.id} row={r} onDeleted={load} />
                  ))}
                </div>
              )}
            </section>
          )}
        </>
      )}

      <AvailabilityAddSheet
        open={showAdd}
        onClose={() => setShowAdd(false)}
        onCreated={load}
        instructorId={contactId}
      />
    </div>
  )
}
```

- [ ] **Step 4.2: Typecheck**

Run:
```bash
cd apps/web && npm run typecheck 2>&1 | head -40
```
Expected: keine Fehler.

- [ ] **Step 4.3: Lint**

Run:
```bash
cd apps/web && npm run lint 2>&1 | head -40
```
Expected: keine Fehler. Falls `useEffect` exhaustive-deps trotz `eslint-disable`-Comment meckert: Comment-Position prüfen.

- [ ] **Step 4.4: Build**

Run:
```bash
cd apps/web && npm run build 2>&1 | tail -20
```
Expected: Build succeeds, kein Bundle-Fehler.

- [ ] **Step 4.5: Manueller Klick-Test als Dispatcher**

```bash
cd apps/web && npm run dev
```

Im Browser als Dispatcher einloggen. Dann:

1. **Empty-State testen:**
   - Adressbuch → einen Instructor wählen, der **keine** Availability-Einträge hat (z.B. eine Test-Person)
   - Tab "Verfügbarkeit" öffnen
   - Erwartet: Header mit `+ Eintrag`-Button, darunter zentrierter „Noch keine Verfügbarkeit eingetragen."

2. **Eintrag anlegen (Etappe 2):**
   - Klick auf `+ Eintrag`
   - Sheet öffnet — Kind `Urlaub` vorausgewählt, From/To = heute
   - Kind auf `Abwesend`, To-Date 7 Tage in die Zukunft, Notiz „Test-Eintrag Dispatcher"
   - Speichern
   - Erwartet: Sheet schließt, Eintrag erscheint in Sektion „Zukünftig" mit roter Pill, korrektem Datum, Notiz darunter

3. **Aktuell-Sektion:**
   - Nochmal `+ Eintrag`, Kind `Urlaub`, From = gestern, To = morgen
   - Speichern
   - Erwartet: Eintrag erscheint in Sektion „Aktuell" (gelb)

4. **Vergangen-Sektion + Toggle:**
   - Nochmal `+ Eintrag`, From + To beide in der Vergangenheit
   - Speichern
   - Erwartet: Sektion „Vergangen" erscheint mit Toggle „Vergangene anzeigen (1)"
   - Toggle klicken → Eintrag wird sichtbar
   - Toggle nochmal klicken → wird wieder ausgeblendet

5. **Delete:**
   - Auf X eines Eintrags klicken → Confirm-Dialog erscheint
   - Bestätigen → Eintrag verschwindet, Liste refresht

6. **Sprachwechsel:**
   - Settings → Sprache auf Englisch wechseln
   - Erwartet: Sektionen heißen Current/Upcoming/Past, Button „+ Entry"

Wenn ein Punkt scheitert: vor Commit beheben.

- [ ] **Step 4.6: MyProfileScreen-Regression nochmal kurz prüfen**

Nach allen Dispatcher-Tests: als TL/DM einloggen, Profil-Screen → Verfügbarkeit checken — soll genauso aussehen und funktionieren wie vor Task 3.

- [ ] **Step 4.7: Commit**

```bash
git add apps/web/src/screens/contacts/tabs/AvailabilityTab.tsx
git commit -m "feat(availability): AvailabilityTab — gruppierte Dispatcher-Sicht + stellvertretendes Eintragen"
```

---

## Task 5: Acceptance-Walkthrough & Spec-Häkchen

Diese Aufgabe schreibt keinen Code, sondern hakt die Akzeptanzkriterien aus dem Spec ab und commitet den aktualisierten Spec-Status.

**Files:**
- Modify: `docs/superpowers/specs/2026-05-13-availability-tab-design.md` (Status + Checklist)

- [ ] **Step 5.1: Akzeptanzkriterien durchgehen**

Spec öffnen, Kapitel 9 (Akzeptanzkriterien). Jeden Punkt einmal manuell verifizieren:

- [ ] Tab zeigt Einträge gruppiert in drei Sektionen ✓ (Step 4.5 #2-4)
- [ ] Dispatcher kann Eintrag anlegen, Liste refresht ✓ (Step 4.5 #2)
- [ ] Dispatcher kann jeden Eintrag löschen, Confirm vor Delete ✓ (Step 4.5 #5)
- [ ] MyProfileScreen identisch wie vorher ✓ (Step 3.7 + 4.6)
- [ ] Vergangene Einträge default eingeklappt, Toggle funktioniert ✓ (Step 4.5 #4)
- [ ] Leerer Tab zeigt Empty-State mit Eintrag-Möglichkeit ✓ (Step 4.5 #1)
- [ ] Alle Strings haben de + en Keys ✓ (Step 4.5 #6)

- [ ] **Step 5.2: Spec-Status aktualisieren**

Im Spec-Header `Status: Draft (User-Review pending)` → `Status: Implementiert (YYYY-MM-DD)` setzen, mit heutigem Datum.

In Kapitel 9 alle Checkboxen abhaken (`- [ ]` → `- [x]`).

- [ ] **Step 5.3: Spec commiten**

```bash
git add docs/superpowers/specs/2026-05-13-availability-tab-design.md
git commit -m "docs(spec): AvailabilityTab — Status auf Implementiert + Akzeptanzkriterien abgehakt"
```

- [ ] **Step 5.4: Aufräum-Reste der Testdaten**

Die im Step 4.5 angelegten Test-Verfügbarkeits-Einträge löschen, damit sie nicht im Pitch-Demo auftauchen.

```sql
-- Im Supabase SQL Editor
DELETE FROM availability WHERE note = 'Test-Eintrag Dispatcher';
```

(Andere Test-Einträge ohne diese Notiz ggf. ebenfalls manuell entfernen.)

---

## Out of Scope für diesen Plan

Diese Punkte sind im Spec als „Out of Scope" markiert und kommen als eigene Pläne:

- **Etappe 3 — Konflikt-Erkennung beim Kurs-Zuweisen** (gegen `availability` kind `urlaub`/`abwesend`)
- **Etappe 4 — Globale Wer-ist-wann-da-Matrix** (eigener Screen)
- **`created_by`-Audit-Spalte** (würde Migration + Schema-Erweiterung benötigen)
- **Edit-Funktion** (aktuell: Delete + neu anlegen)
- **Recurring Availability** (z.B. „jeden Donnerstag")
- **Notification-Trigger** bei stellvertretender Eintragung (Email an betroffenen TL/DM)
- **Folge-Migration `0093_availability_dispatcher_rls.sql`** falls Pre-Flight Step P.2 zeigt, dass Policies fehlen — wird separat mit User abgestimmt
