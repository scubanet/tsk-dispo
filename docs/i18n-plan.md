# ATOLL — Internationalization Plan (DE / EN)

**Owner:** Dominik · **Last update:** 2026-05-07 · **Status:** Spec, ready to execute

---

## 1. Strategy decisions (locked)

| # | Decision | Choice |
|---|---|---|
| 1 | PADI domain terminology | **English in both languages** — `Pool`, `Theory`, `Lake`, `Skill`, `Open Water`, `Divemaster`, `IDC`, `OWSI`, `MSDT`, `MI`, `CD`, `IE`, `Rescue`, `Pipeline`, `Touchpoint` … untouched |
| 2 | Role names | **English** in both languages — `Dispatcher`, `Instructor`, `Owner`, `CD` |
| 3 | Date / time format | **Locale-neutral** — `7 May 2026, 14:30` everywhere (no DE-Swiss vs US ambiguity) |
| 4 | Language source | **DB master + localStorage cache** — `people.preferred_language` is truth, browser caches for instant boot |
| 5 | Email language | **Recipient profile decides** — pull `preferred_language` from `people` row before render |
| 6 | iOS native | **Phase 2** — separate sprint after web is shipped |
| 7 | Translation source | **Claude does first pass + final** — no human translator round |

## 2. Stack

```
react-i18next            // de-facto standard, ICU plurals, lazy loading
i18next                  // engine
i18next-browser-languagedetector  // reads localStorage / nav.language
```

No `react-intl` (heavier, less ergonomic), no DIY dictionary (loses plurals + interpolation).

## 3. Folder structure

```
apps/web/src/
├── i18n/
│   ├── index.ts                ← i18next init, language detection, change listener
│   ├── useLanguage.ts          ← React hook: { lang, setLang } — writes DB + localStorage
│   └── locales/
│       ├── de.json             ← Source-of-truth (current strings)
│       └── en.json             ← Translation
├── lib/
│   └── datetime.ts             ← formatDate / formatDateTime / formatTime — uses Intl with locale-neutral DE
└── …
```

## 4. Database migration

```sql
-- 0074_people_preferred_language.sql
ALTER TABLE public.people
  ADD COLUMN preferred_language text
    NOT NULL DEFAULT 'de'
    CHECK (preferred_language IN ('de','en'));

COMMENT ON COLUMN public.people.preferred_language IS
  'Used for UI default + email template selection. Set on first login from browser, editable in profile.';
```

## 5. Date / time format spec

Locale-neutral chosen over locale-native — same string in DE and EN, no ambiguity for international students:

| Token | Output |
|---|---|
| `formatDate('2026-05-07')` | `7 May 2026` (EN) · `7. Mai 2026` (DE — German month names, but day-month-year and 24h) |
| `formatDateTime(...)` | `7 May 2026, 14:30` · `7. Mai 2026, 14:30` |
| `formatTime(...)` | `14:30` (both — 24h always) |
| `formatRelative('2026-05-08')` | `tomorrow` · `morgen` |

Implementation: `Intl.DateTimeFormat('de-CH', { day:'numeric', month:'long', year:'numeric' })`. CH locale because DE-DE would render `7. Mai 2026` identically but stays consistent with Swiss context.

## 6. Language switcher

**Where:** Settings page (top section "Account" / "Language") + sidebar tooltip on the user-block.

**Behavior:**
1. User picks language → `setLang('en')`
2. Hook writes `localStorage['atoll.lang'] = 'en'` (instant)
3. Hook calls `supabase.from('people').update({ preferred_language: 'en' }).eq('id', myId)` (background)
4. `i18next.changeLanguage('en')` → all `t()` calls re-render

**Boot order:**
1. `localStorage['atoll.lang']` if present → use that immediately, no flicker
2. After auth: read `people.preferred_language` → if differs, switch
3. First-time user: detect `navigator.language`, default to `de` if not en/de

## 7. Phase plan

### Phase 1 — Foundation (1.5 d)

**Goal:** Switcher works end-to-end, sidebar + login + settings translated. Rest of app stays DE.

- [ ] `npm i react-i18next i18next i18next-browser-languagedetector`
- [ ] `src/i18n/index.ts` — init with `de` + `en` resources
- [ ] `src/i18n/useLanguage.ts` — hook with DB write + localStorage cache
- [ ] `src/i18n/locales/de.json` — seed with sidebar, login, settings keys
- [ ] `src/i18n/locales/en.json` — translate same keys
- [ ] `src/lib/datetime.ts` — formatDate/formatDateTime/formatTime/formatRelative
- [ ] Migration `0074_people_preferred_language.sql`
- [ ] Wire `<I18nextProvider>` in `main.tsx`
- [ ] Translate **Sidebar.tsx** (~15 strings)
- [ ] Translate **LoginScreen.tsx** (~8 strings)
- [ ] Translate **SettingsScreen.tsx** + add language switcher (~16 strings + new section)
- [ ] Acceptance: switch → sidebar/login/settings flip, refresh keeps choice, second device after login picks up DB choice

### Phase 2 — Core screens (2 d)

Translate the 12 highest-traffic screens. Order by daily usage:

1. CockpitScreen
2. HeuteScreen (today dashboard)
3. CalendarScreen
4. KurseScreen + CourseDetailPanel + CourseEditSheet
5. PoolScreen
6. SaldiScreen + SaldoScreen
7. PeopleScreen + StudentEditSheet + StudentDetailPanel
8. CommunicationScreen + CommunicationEditSheet
9. SkillsScreen
10. InstructorListScreen + InstructorEditSheet + InstructorDetailPanel
11. MyProfileScreen + MyEinsaetzeScreen + MySaldoScreen
12. AuthCallbackScreen + LoadingScreen + ErrorScreen

Each follows the same recipe — extract literals → key in `de.json` → translate to `en.json`.

### Phase 3 — CD module (1 d)

CD-specific screens — terminology already heavily English (Pipeline, IDC, etc.), so volume is lower but precision matters:

- CDOrganizationsScreen + OrganizationEditSheet
- CDCandidatesScreen + CDOnlyCandidatesScreen
- IntakeChecklistSheet
- CertificationEditSheet
- All the PR/skill check-off sheets

### Phase 4 — Email templates (0.5 d)

- `supabase/functions/send-assignment-notification/`
- `supabase/functions/send-magic-link/` (if customized — Supabase default is i18n-aware)
- `supabase/functions/send-saldo-export/`

Each function reads `recipient.preferred_language` then picks the matching template. Templates as `email-templates/<name>.<lang>.html`.

### Phase 5 — Polish & QA (0.5 d)

- Layout sweep — long EN words break some chips/buttons (typical: "Reservieren" ~10ch → "Reserve" ~7ch · "Speichern" ~9ch → "Save" ~4ch · most EN is shorter, but watch "Nicht erfasst" → "Not recorded")
- Pluralization audit — `t('students_count', { count })` with ICU plural rules
- Number formatting — `Intl.NumberFormat` for currency (`CHF 120.00` / `CHF 120.00` — same Swiss format)
- Lighthouse / a11y — `<html lang>` attribute reactive on switch
- Smoke test on each role (Dispatcher / Instructor / Owner / CD)

**Total Phase 1–5: 5.5 days**

## 8. Translation conventions

- **Casing:** EN sentence case (`Save changes`, not `Save Changes`)
- **Punctuation:** keep `…` for loading states ("Sende…" → "Sending…")
- **Tone:** semi-formal, friendly — match current DE warmth ("Magic-Link an deine Email" → "Magic link to your email")
- **You-form:** EN "you" maps to DE informal "du" (already used everywhere)
- **PADI brand terms:** never translate (see decision #1)
- **Errors:** start with the problem, then the action — "No internet connection — try again in a moment."

## 9. Out of scope (this plan)

- iOS native app (separate plan)
- French / Italian / Spanish (despite the language checkboxes existing on people — those are *student languages* for matching with instructors, not UI languages)
- RTL support
- Right-side translation memory tool (every change goes through code review)

## 10. Acceptance criteria

- [ ] Switcher in Settings flips entire app, no flicker
- [ ] Refresh preserves choice (localStorage)
- [ ] Login on a second device picks up DB-stored preference
- [ ] All dates render `7 May 2026, 14:30` style in both languages
- [ ] All 28 currently-German files contain zero raw German literals (verified by grep for typical DE words / Umlauts)
- [ ] Magic-link email arrives in user's preferred language
- [ ] No layout breakage on the 12 core screens at 1024×768 + iPhone 13 viewport
- [ ] `<html lang>` attribute correct after switch (a11y)
- [ ] Storybook of all status pills / chips renders both languages without overflow

---

**Next step:** kick off Phase 1. ETA 1.5 days. Deliverable: switcher + sidebar/login/settings translated, foundation in place.
