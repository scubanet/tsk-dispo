# Phase G Phase 5 — „Aktivität"-Screen + Sidebar-Rename

**Spec:** `docs/superpowers/specs/2026-05-27-contacts-crm-redesign.md` §7
**Voraussetzungen:** Phase 1-4 ✓ done. `useGlobalActivity` Hook + `v_contact_timeline` View existieren bereits aus Phase 1 Foundation.
**Stand:** 28.05.2026 · Geschätzt 2-3 Tage · 8 Tasks (+1 optional 5b)

## Ziel

Globaler Activity-Feed über alle Contacts unter `/aktivitaet`. Ersetzt den `CommunicationHub`-Screen unter `/communication`. Volle Breite, kein Master-Detail — Click auf Event-Card navigiert zu Contact-Detail mit Event-Highlighting.

## Was bereits da ist

- `useGlobalActivity(filter)` Hook mit Cursor-Pagination (Phase 1).
- `v_contact_timeline` View mit 10 UNION-Branches (Phase 1).
- `EventCard` Component für polymorphes Event-Rendering (Phase 2).
- 6 `EventComposers` (Note/Call/Email/Meeting/Task/WhatsApp) (Phase 2).
- `TimelineFilterBar` mit Bucket-Chips (Phase 2).

## Files (Übersicht)

```
apps/web/src/screens/contacts/activity/
  ActivityScreen.tsx                    # NEU — Top-Level Screen unter /aktivitaet
  ActivityFilterBar.tsx                 # NEU — erweiterte Filter (event-type/channel/owner/date-range/tag/status)
  ActivityEventCard.tsx                 # NEU — wraps EventCard + Contact-Avatar+Name rechts
  ActivityComposer.tsx                  # NEU — global Composer mit Pflicht-Contact-Picker
  ContactPicker.tsx                     # NEU — Autocomplete-Search für Contact-Auswahl
apps/web/src/hooks/
  useActivityFilter.ts                  # NEU — URL-Param-Sync für Activity-Filter
apps/web/src/App.tsx                    # extend — /aktivitaet route + /communication redirect
apps/web/src/layout/AppShell.tsx        # modify — Sidebar-Eintrag „Aktivität" rename + Icon
apps/web/src/i18n/locales/{de,en,fr}.json # extend — nav.activity Keys
apps/web/src/screens/contacts/ContactDetailPanelV2.tsx # modify — ?event=<id> highlighting
```

## Tasks

### Task 0 — ActivityFilterBar

Erweiterter Filter-Set per Spec §7.3:
- Event-Typ (multi-pill, gleiche Werte wie TimelineFilterBar aus Phase 2)
- Channel (Email · Anruf · WhatsApp · Notiz · Meeting · Task)
- Owner: Mein vs. Team (`actor_contact_id == auth.uid()` oder Alle)
- Date-Range (Today · Gestern · Letzte 7 Tage · Letzte 30 Tage · Custom)
- Tag (über contact.tags der zugehörigen Contacts — eventuelle Phase 5.x)
- Status: Unbeantwortet (Heuristik — Mail mit `direction='inbound'` ohne outbound-Response)

**Pragma:** Erstmal die einfachen Filter (event-type, channel, owner-scope „mein/alle", date-range buckets). Tag-Filter + Status-„Unbeantwortet"-Heuristik sind 5.x-Carry-Forward.

**Files:** `useActivityFilter.ts` (URL-Param-Sync ähnlich `useAddressbookFilter`), `ActivityFilterBar.tsx`.
**Tests:** 6-8 Vitest pro Hook + Component.

### Task 1 — ActivityEventCard

Wrapper um `EventCard` + Contact-Link rechts (Avatar + Name). Klick auf Card navigiert via react-router zu `/contacts?contact={contact_id}&event={event_id}`.

**Files:** `ActivityEventCard.tsx`.
**Tests:** 3-4 Vitest (render, click navigates, contact-link rendert).

### Task 2 — ContactPicker (für ActivityComposer)

Search-Autocomplete um Contact auszuwählen. Pattern wie ein „Combobox": Input mit dropdown. Verwendet `useContactList`-Hook (filter searchText) für Live-Search.

**Files:** `ContactPicker.tsx`.
**Tests:** 4-5 Vitest.

### Task 3 — ActivityComposer

Wie der EventComposer aus Phase 2, aber mit dem Pflichtfeld „Welcher Contact?" oben (via ContactPicker). Erst nach Contact-Auswahl: zeigt die 6 Composer-Optionen (Note/Call/Email/Meeting/Task/WhatsApp).

**Files:** `ActivityComposer.tsx`. Wraps der bestehenden 6 Composer aus `apps/web/src/screens/contacts/timeline/composers/`.
**Tests:** 4-5 Vitest.

### Task 4 — ActivityScreen (Top-Level)

Komposition: Filter-Bar oben (sticky) + Composer (sticky-top, collapsible) + EventCard-Feed (infinite-scroll via `useGlobalActivity`).

Layout: full-width, kein Master-Detail.

**Files:** `ActivityScreen.tsx`.
**Tests:** 2-3 Vitest mit useGlobalActivity-Mock.

### Task 5 — Route + Sidebar-Rename + i18n

- App.tsx: `/aktivitaet` registrieren → `<ActivityScreen />`. `/communication` → `<Navigate to="/aktivitaet" replace />` (1-Release-Redirect).
- AppShell.tsx: Sidebar-Eintrag „Communication Hub" → „Aktivität" mit neuem Icon (`ti-activity` oder Inline-SVG).
- i18n: `nav.activity` Keys de/en/fr.

**Tests:** 1 Vitest für AppShell-Sidebar-Item-Label.

### Task 6 — Event-Highlighting in ContactDetailPanelV2

URL-Param `?event=<id>` — wenn gesetzt, scrollt die Timeline zu dem Event und highlightet die Card (background-pulse oder Border-Color).

**Files:** Modify `apps/web/src/screens/contacts/timeline/TimelineFeed.tsx` (scroll-to-event) + `EventCard.tsx` (highlight-prop).
**Tests:** 2-3 Vitest.

### Task 7 — Playwright E2E

`apps/web/tests/e2e/phase-g-activity.spec.ts`: navigate to `/aktivitaet` → click Event-Card → contact-detail mounted with event highlighted in timeline.

### Task 8 — Phase 5 Close-out

- Memory-Update in `project_phase_g.md`.
- Tag `phase-g-phase5`.
- Push origin + tags.

### Task 5b (optional, deferred) — TriageMode

Keyboard shortcuts `j/k/e/r/x` + Cmd+A für Bulk-Selection. Spec §7.5. **Skip in Phase 5**, separate Spec falls gewünscht.

## Carry-Forwards für Phase 5.x

- Tag-Filter im ActivityFilterBar (braucht JOIN auf contacts.tags)
- Status „Unbeantwortet"-Heuristik (braucht Email-Direction-Inferenz)
- TriageMode (5b)

## Verification Gates

| Gate | Wie geprüft |
|---|---|
| ActivityFilterBar URL-Sync | Vitest |
| ActivityScreen Composition | Vitest |
| ContactPicker Autocomplete | Vitest |
| Route + Redirect | manueller Pass + Playwright |
| Event-Highlighting | Vitest + Playwright |
| Full Suite | typecheck + vitest grün |
| Production-Smoke | manueller Pass durch |

## Was bewusst NICHT in Phase 5 ist

- TriageMode (5b)
- Mass-Mail-Composer Wire-up
- CommunicationHub-Datei löschen — bleibt bis Phase 6
- Tag-/Unbeantwortet-Filter (Phase 5.x)
