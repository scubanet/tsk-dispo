# Phase G Phase 4 — AddressbookScreen Liste-Refresh

**Spec:** `docs/superpowers/specs/2026-05-27-contacts-crm-redesign.md` §6 (AddressbookScreen)
**Voraussetzungen:** Phase 1-3 ✓ done. Tabelle `contact_saved_views` + Hook `useContactSavedViews` existieren.
**Stand:** 28.05.2026 · Geschätzt 3-4 Tage · 12 Tasks

## Ziel

Aktuelle `AddressbookScreen.tsx` zeigt eine Single-Column-Button-Liste (Avatar + Name + Email + Role-Dots) mit 8 Built-in Saved-Views als Chips und Search-Input. Phase 4 erweitert das zu einer **vollwertigen CRM-Liste** mit konfigurierbaren Spalten, Filter-Chips, Sort, Bulk-Selection, Density-Toggle und User-Custom-Saved-Views.

## Files (Übersicht)

```
apps/web/src/screens/contacts/
  AddressbookScreen.tsx                 # refactor — Toolbar erweitert
  AddressbookTable.tsx                  # NEU — Table-Komponente mit Columns/Sort/Bulk
  AddressbookFilterBar.tsx              # NEU — Filter-Chips
  AddressbookBulkActionBar.tsx          # NEU — Slide-in Bulk-Actions
  ColumnPicker.tsx                      # NEU — Dropdown mit Column-Checkboxes
  DensityToggle.tsx                     # NEU — Compact / Comfortable
  SaveViewDialog.tsx                    # NEU — „Diese Ansicht speichern"
  RowQuickActions.tsx                   # NEU — Hover-Icons (Mail, Note)
apps/web/src/hooks/
  useAddressbookColumns.ts              # NEU — localStorage column-config
  useAddressbookDensity.ts              # NEU — localStorage density
  useAddressbookFilter.ts               # NEU — URL-Param-Sync
  useAddressbookSort.ts                 # NEU — URL-Param-Sync
  useContactList.ts                     # extend — Sort/Pagination/Filter-Erweiterungen
```

## Tasks

### Task 0 — useContactList erweitern für Sort + erweiterte Filter

`useContactList` heute nimmt `ContactListFilter` (kind, roles, searchText, archivedOnly, ownerId). Phase 4 erweitert um:

- Sort-Argument: `{ field: 'name'|'last_contact'|'balance'|'created_at', direction: 'asc'|'desc' }[]` (Multi-Sort)
- Filter-Felder dazu: `tags: string[]`, `pipeline_stages: string[]`, `last_contact_bucket: 'lt_7d'|'lt_30d'|'gt_30d'`, `saldo_bucket: 'positive'|'negative'|'zero'`, `languages: string[]`, `sources: string[]`

**Files:** `apps/web/src/hooks/useContactList.ts` + `apps/web/src/lib/contactQueries.ts` (Filter-Type + Query-Builder)

**Tests:** Vitest extension — 5-7 cases pro neuer Filter-Dim + Sort-Permutation.

### Task 1 — AddressbookTable Foundation (Columns + Layout)

Refactor List-Pane von `<ul.atoll-people-list>` zu einer Table-Komponente. Spalten:
- ☑ Checkbox (Bulk)
- Avatar + Name + Primary-Role
- Role-Dots
- Email
- Telefon
- Letzter Kontakt (relative time)
- Saldo (CHF, color-coded, rechtsbündig)
- Tags (max 3 + „+N")
- ⋯ Row-Action

Layout: CSS-Grid `grid-template-columns` für gleichbreite Spalten. Header-Row sticky-top. Row klickbar (öffnet Detail wie heute), aber Checkbox + ⋯ stoppen propagation.

**Files:** `apps/web/src/screens/contacts/AddressbookTable.tsx` + CSS-Inline

**Tests:** 4-5 Vitest — renders header, rows, click selektiert, checkbox-click independent von row-click.

### Task 2 — Density-Toggle (klein, polish)

Topbar-Icon `ti-baseline-density-medium` ↔ `ti-line-height`. Compact 32px / Comfortable 44px Row-Height. Persistiert in localStorage `addressbook.density`.

**Files:** `apps/web/src/hooks/useAddressbookDensity.ts` + `apps/web/src/screens/contacts/DensityToggle.tsx` + AddressbookScreen-Toolbar.

**Tests:** Hook-Test (3 cases), Toggle-Component-Test.

### Task 3 — ColumnPicker

Dropdown mit verfügbaren Columns als Checkboxes. Default-Set: Avatar/Name (immer), Email, Phone, Last-Contact, Saldo, Tags, Roles, Actions. Zusätzlich verfügbar: Org-Zugehörigkeit, Pipeline-Stage, Sprache, Quelle, Geburtstag, Nächster Follow-up, PADI-Nummer, Skills, Erstellt.

**Files:** `apps/web/src/hooks/useAddressbookColumns.ts` + `apps/web/src/screens/contacts/ColumnPicker.tsx`.

**Tests:** Hook (3), Picker (3).

### Task 4 — Sort-Header (Multi-Sort + URL-Param)

Klick auf Spaltenkopf → asc/desc. Shift-Klick → Multi-Sort. Pfeil-Icon im Header. URL: `?sort=last_contact:desc,name:asc`. Sortierbar: Name · Letzter Kontakt · Saldo · Erstellt.

**Files:** `apps/web/src/hooks/useAddressbookSort.ts` + AddressbookTable extension.

**Tests:** Hook (4-5), Header-click (2).

### Task 5 — AddressbookFilterBar (8 Chips)

Über der Liste, zusätzlich zu Saved-View-Tabs:
`Rolle ▾ · Tag ▾ · Status ▾ · Pipeline ▾ · Letzter Kontakt ▾ · Saldo ▾ · Sprache ▾ · Quelle ▾ · [Zurücksetzen]`

Pro Chip Dropdown-Multi-Select. Aktive Filter farbig, inaktive grau-outline. URL-Param: `?filter=role:instructor,tag:vip,saldo:negative`.

**Files:** `apps/web/src/hooks/useAddressbookFilter.ts` + `apps/web/src/screens/contacts/AddressbookFilterBar.tsx` + (small) `FilterChipDropdown.tsx`.

**Tests:** Hook URL-Sync (5-6), Bar-rendering (3).

### Task 6 — Bulk-Selection (Header + Row Checkboxes)

Checkbox-Spalte pro Row + Header-Checkbox selektiert alle gefilterten. Confirm wenn >100. State in lokalem `useState<Set<string>>`. Beim Filter/View-Wechsel: clear.

**Files:** AddressbookTable extension + `useBulkSelection` (inline hook or separate).

**Tests:** 4-6 Vitest.

### Task 7 — AddressbookBulkActionBar (Slide-in)

Erscheint wenn ≥1 selektiert. Layout: `[3 ausgewählt] [+ Tags ▾] [Pipeline ▾] [✉ Massen-Mail] [⋯] [✕]`.

Mass-Mail ist Phase 4.x-Stub (öffnet Modal mit „TODO"). Tags + Pipeline triggern Bulk-Mutation. ⋯ enthält: Aktiv/Inaktiv, Export CSV (Stub), Zu Saved View hinzufügen, Archivieren.

**Files:** `apps/web/src/screens/contacts/AddressbookBulkActionBar.tsx` + `useBulkContactMutation` Hook.

**Tests:** 5-6 Vitest — UI-States + Mutation-Calls.

### Task 8 — User-Custom-Saved-Views UI

„Diese Ansicht speichern"-Button rechts oben. Öffnet Dialog: Name eingeben + speichern (snapshot von filter + columns + sort + density). Dropdown neben den Built-in-Tabs zeigt Custom-Views. Delete via Hover-Icon im Dropdown.

**Files:** `apps/web/src/screens/contacts/SaveViewDialog.tsx` + AddressbookScreen-Toolbar-Erweiterung. `useContactSavedViews` ist da; nur `useUpdateSavedView` evtl. ergänzen.

**Tests:** 4-5 Vitest — Dialog-State + create-Mutation.

### Task 9 — Row-Hover Quick-Actions

Bei Hover rechts in der Row (vor ⋯) zwei Icon-Buttons:
- `ti-mail` Quick-Mail → öffnet EventComposer mit Empfänger vorbefüllt (Phase 4.x-Hook)
- `ti-note` Quick-Note → öffnet inline Notiz-Form

Für jetzt: stub Click-Handler die `console.log` machen und Toast zeigen. Wire-up in Phase 4.x.

**Files:** `apps/web/src/screens/contacts/RowQuickActions.tsx` + AddressbookTable-Row-Integration.

**Tests:** 3 Vitest — visibility + click-handler.

### Task 10 — Playwright E2E

`apps/web/tests/e2e/phase-g-addressbook.spec.ts` — Flow: load addressbook → select 3 contacts → click Bulk „+ Tag" → enter „E2E_VIP" → all 3 contacts haben Tag → reload → tag persistiert.

### Task 11 — Manual-Smoke + Production-Verification

Smoke-Checkliste:
- [ ] Tabelle rendert mit Default-Columns
- [ ] Column-Picker hide/show persistiert
- [ ] Density-Toggle wirkt
- [ ] Filter-Chip „Rolle = Student" filtert, URL-Param erscheint
- [ ] Sort-Klick auf „Letzter Kontakt" sortiert + URL-Param
- [ ] Bulk-Checkbox 3 selektieren → Action-Bar erscheint
- [ ] „+ Tag E2E" auf 3 anwenden → alle 3 haben Tag
- [ ] „Diese Ansicht speichern" → Custom-View erscheint im Dropdown → wieder anwendbar
- [ ] Refresh → URL-State bleibt, localStorage-State bleibt

### Task 12 — Phase 4 abschliessen

- [ ] Memory-Update in `project_phase_g.md`: Phase 4 done
- [ ] Tag `phase-g-phase4`
- [ ] Push origin + tags

## Verification Gates

| Gate | Wie geprüft |
|---|---|
| useContactList Erweiterung | Vitest sort + filter |
| Table-Foundation | Vitest header/rows/click |
| Density / ColumnPicker / Sort / Filter | je 3-5 Vitest |
| BulkSelection + ActionBar | Vitest UI + Mutation |
| SavedViews | Vitest Dialog + persist |
| Full Suite | typecheck + vitest grün |
| E2E | Playwright phase-g-addressbook.spec.ts |
| Production-Smoke | manueller Pass durch |

## Was bewusst NICHT in Phase 4 ist

- **`/aktivitaet` globaler Screen** — Phase 5
- **CommunicationHub-Auflösung** — Phase 5
- **Flag-Flip + Cleanup** — Phase 6
- **Mass-Mail-Composer Wire-up** — Stub-Modal, Implementation später (braucht Resend-Setup)
- **Row-Hover Quick-Actions Wire-up** — Stub, Implementation in Phase 5
- **Realtime-Subscriptions** auf die Liste — out of scope

## Open Questions

1. **Column-Default-Set:** sollen alle 9 Spalten initial sichtbar sein oder nur 6? → Default 6 (Checkbox, Avatar+Name, Roles, Email, Last-Contact, Actions). Rest opt-in via Picker.
2. **Bulk-Mail-Stub:** Modal mit „TODO Phase 5" oder gar nichts? → Modal mit „TODO" damit UI komplett wirkt.
3. **Custom-View overwrite:** wenn User „Diese Ansicht speichern" mit existierendem Namen drückt — überschreiben oder error? → Error mit „Name existiert bereits".
