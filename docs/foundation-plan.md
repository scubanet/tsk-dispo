# ATOLL Foundation — Implementation Plan

**Owner:** Dominik · **Stand:** 2026-05-08 · **Status:** Tag 1 in progress

---

## Entscheidungen (locked)

| # | Frage | Entscheidung |
|---|---|---|
| 1 | Stack | **Vite + React + custom CSS** (kein Next.js, kein Tailwind) |
| 2 | Datenmodell | **Cert-First** — `certifications` Table, `deriveTier`/`canTeach` Helpers |
| 3 | Migration | **Big-Bang** in selber Codebase, alte Komponenten parallel bis Cutover |
| 4 | Primary Device | **Desktop**, iPad als Sekundär (kein iPad-First) |
| 5 | canTeach | **Warning, kein Block** — orange Banner bei Assignment-Auswahl |
| 6 | Timeline | egal — sauber statt schnell |
| 7 | i18n | **behalten**, alle bestehenden Keys übernehmen |
| 8 | Testdaten | bestehende DB-Daten sind Test → Schema kann destruktiv sein |
| — | Multi-Tenant | **skip vorerst** — kein Tenant-Pill jetzt |

---

## Phasen

### Tag 1 — Setup + Schema + Tokens + Types ✅
- `docs/foundation-plan.md` (dieses Dokument)
- `supabase/migrations/0076_certifications_brevets.sql` — neue Tabelle, Migration der Altdaten, View für Tier-Backwards-Compat
- `apps/web/src/styles/tokens.css` — alle CSS-Variablen (Farben, Typo, Radien)
- `apps/web/src/styles/globals.css` — Resets, Font-Loading
- `apps/web/src/types/foundation.ts` — Brevet/Tier/CourseType-Typen

### Tag 2 — Lib + Provider + Atome
- `lib/tier.ts` — `deriveDiverTier`, `deriveProTier`, `displayTier`
- `lib/teaching-rules.ts` — `canTeach()` mit allen Kurstypen
- `lib/compensation.ts` — `calculateCompensation()`
- `lib/colors.ts` (avatar-color, course-type-color), `lib/dates.ts` (de-CH), `lib/numbers.ts` (Swiss Apostroph), `lib/icons.ts`
- Provider: ThemeProvider (CSS-Vars-Inject), QueryProvider (TanStack Query optional, sonst leer)
- **Atomare Komponenten:** Avatar, AvatarStack, Pill, SearchInput

### Tag 3 — Layouts + Compounds + Storybook
- **Molekulare Komponenten:** KpiCard, KpiGrid, FilterTabBar, SortDropdown, ChecklistItem, TouchpointCard, CourseRow, PromptCard, EmptyState, Banner, Toast
- **Layouts:** AppShell (neue), Sidebar (neue), SidebarNavItem, PageHeader
- **Master-Detail-Primitives:** ListPane, DetailPane, Tabs, Drawer
- **Compound:** BrevetsView (4-Group)
- Storybook-Setup (vite-plugin-storybook) — Stories für jede Komponente
- Unit-Tests für `tier.ts`, `teaching-rules.ts`

### Tag 4-5 — Erste Screens auf Foundation
- Heute (Cockpit) — KpiGrid + CourseRow
- Kurse — ListPane + DetailPane
- Personen — ListPane + DetailPane + BrevetsView (mit Cert-First-Daten)

---

## DB-Schema — Migration 0076

### Neue Tabellen

```sql
-- Eine zentrale certifications-Tabelle für alle Brevets, Pro-Stufen, Specialty-Teacher, EFR/EFRI/Medical
CREATE TABLE certifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  person_id UUID NOT NULL REFERENCES people(id) ON DELETE CASCADE,
  agency TEXT NOT NULL CHECK (agency IN ('PADI','SSI','CMAS','ANDI','TecRec','Other')),
  category TEXT NOT NULL CHECK (category IN ('diver','pro','specialty-teacher','additional')),
  code TEXT NOT NULL,                    -- 'OWD' | 'OWSI' | 'SPEC_TEACHER_NIGHT' | 'EFRI' | …
  number TEXT,                           -- PADI-Nr, optional bei externen
  issued_at DATE NOT NULL,
  issued_by_person_id UUID REFERENCES instructors(id),  -- Wer ausgestellt hat (TSK-intern)
  origin TEXT NOT NULL DEFAULT 'extern' CHECK (origin IN ('tsk-zurich','tsk-bern','extern','auto-with-owsi')),
  evidence JSONB,                        -- [{url, filename}]
  notes TEXT,
  invalidated_at TIMESTAMPTZ,            -- Soft-delete (NICHT überschreiben — Audit)
  invalidated_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX certifications_person_id_idx ON certifications(person_id);
CREATE INDEX certifications_code_idx ON certifications(code);
CREATE INDEX certifications_category_idx ON certifications(category);

-- Brevets sind immutable — Korrektur = invalidieren + neu erfassen
COMMENT ON COLUMN certifications.invalidated_at IS
  'Soft-delete. Brevet bleibt im Datensatz, wird aber in canTeach()/deriveTier() ignoriert.';
```

### Migration der Altdaten

```sql
-- Aus instructors.padi_level → Pro-Brevets
INSERT INTO certifications (person_id, agency, category, code, number, issued_at, origin)
SELECT
  i.id,
  'PADI',
  'pro',
  CASE i.padi_level
    WHEN 'DM'        THEN 'DM'
    WHEN 'AI'        THEN 'OWSI'  -- AI gibt's im neuen Modell nicht, mappt auf OWSI
    WHEN 'OWSI'      THEN 'OWSI'
    WHEN 'MSDT'      THEN 'OWSI'  -- MSDT als OWSI im neuen Modell
    WHEN 'IDC Staff' THEN 'IDC_STAFF'
    WHEN 'MI'        THEN 'MI'
    WHEN 'CD'        THEN 'CD'
  END,
  '—',
  COALESCE(i.created_at::date, '2024-01-01'::date),
  'extern'
FROM instructors i
WHERE i.padi_level IS NOT NULL
  AND i.padi_level NOT IN ('Shop Staff', 'Andere');

-- Aus student_certifications → Diver-Brevets / Additional
-- (Mapping pro Zeile, je nach c.certification String)
-- Skipped hier — wird im Migration-Script implementiert

-- Auto-Specialty-Brevets bei OWSI (3 Stk: AWARE, DEBRIS, PPB)
INSERT INTO certifications (person_id, agency, category, code, number, issued_at, origin)
SELECT
  c.person_id, 'PADI', 'specialty-teacher', sp.code, '—', c.issued_at, 'auto-with-owsi'
FROM certifications c
CROSS JOIN (VALUES ('SPEC_TEACHER_AWARE'), ('SPEC_TEACHER_DEBRIS'), ('SPEC_TEACHER_PPB')) AS sp(code)
WHERE c.code = 'OWSI'
  AND c.invalidated_at IS NULL
ON CONFLICT DO NOTHING;
```

### Backwards-Compat Views

```sql
-- View die das alte instructors.padi_level via deriveProTier-Logik berechnet
CREATE OR REPLACE VIEW v_instructor_tiers AS
SELECT
  i.id,
  i.name,
  COALESCE(
    (SELECT 'CD' FROM certifications WHERE person_id = i.id AND code = 'CD' AND invalidated_at IS NULL LIMIT 1),
    (SELECT 'MI' FROM certifications WHERE person_id = i.id AND code = 'MI' AND invalidated_at IS NULL LIMIT 1),
    (SELECT 'IDC Staff' FROM certifications WHERE person_id = i.id AND code = 'IDC_STAFF' AND invalidated_at IS NULL LIMIT 1),
    (SELECT 'OWSI' FROM certifications WHERE person_id = i.id AND code = 'OWSI' AND invalidated_at IS NULL LIMIT 1),
    (SELECT 'DM'   FROM certifications WHERE person_id = i.id AND code = 'DM'   AND invalidated_at IS NULL LIMIT 1)
  ) AS pro_tier;
```

---

## Komponenten-Liste (23)

### Atome (Tag 2)
1. Avatar
2. AvatarStack
3. Pill
4. SearchInput

### Moleküle (Tag 3, Vormittag)
5. KpiCard (`hero | stat | alert`)
6. KpiGrid
7. FilterTabBar
8. SortDropdown
9. ChecklistItem
10. TouchpointCard
11. CourseRow
12. PromptCard
13. EmptyState
14. Banner
15. Toast

### Layouts (Tag 3, Nachmittag)
16. AppShell
17. Sidebar + SidebarNavItem
18. PageHeader
19. ListPane
20. DetailPane
21. Tabs
22. Drawer

### Compound (Tag 3)
23. BrevetsView

---

## Acceptance Criteria

- [ ] Tokens via CSS-Vars (`--brand-blue`, `--text-primary`, etc.) verfügbar in allen Komponenten
- [ ] `canTeach()` Unit-Tests für alle 12 Kurstypen × 5 Pro-Tiers
- [ ] `deriveDiverTier()` + `deriveProTier()` Unit-Tests inkl. Edge-Cases (kein Brevet, mehrere)
- [ ] Avatar deterministisch (gleiche `id` → gleiche Farbe), nie rot
- [ ] Tabular-Numbers visuell aligned bei verschieden langen Zahlen
- [ ] WCAG AA für Text-Kontrast
- [ ] Storybook-A11y-Panel ohne Errors
- [ ] Keyboard-navigierbar (Tab/Enter/Esc)
- [ ] `prefers-reduced-motion` respektiert
- [ ] Migration 0076 idempotent (mehrfach ausführbar, keine Doubletten)
- [ ] i18n-Keys aus bestehender App weiterverwendet (nichts geht verloren)

---

## Out of Scope

- Multi-Tenant (Tenant-Pill, Tenant-Switcher) — kommt wenn 2. Tenant da ist
- Next.js-Migration
- Tailwind 4
- Dark Mode (Stub vorbereitet, nicht implementiert)
- iOS Native App (eigener Sprint)
- Vergangene Komponenten löschen — passiert erst nach Screen-Cutover (Tag 4-5)
