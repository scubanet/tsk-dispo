# ATOLL — The Scuba OS

Dispo-, Skill- und Saldo-App für Tauchsport Käge Zürich (TSK ZRH) — Pitch-Prototyp.
Codebasis: Web (React/Vite/TS) + iOS-native (Swift) + Supabase.

## Status (Stand 10. Mai 2026)

- **Plan 1 — Foundation & Data** (30.04.) — ✅ implementiert
- **Plan 2 — Dispatcher Views** (01.05.) — ✅ live (Cockpit, Kurse, Pool, Skill-Matrix, Saldi, Kalender)
- **Plan 3 — CD-Integration** (03.05.) — ✅ live (`screens/cd/` mit Pipeline + Communication Hub)
- **Plan 4 — Adressverwaltung Redesign** (09.05.) — 🔄 in Arbeit
  - Migrations 0079–0086 gemerged (unified `contacts`-Tabelle + Sidecars + n:m-Relationships)
  - Universeller `ContactDetailPanel` mit 12 adaptiven Tabs
  - Volle DE/EN-i18n-Abdeckung (Stand 10.05.)
  - 6 Playwright-E2E-Specs für Contacts-CRUD

## Spec & Pläne

- Master-Spec: [`docs/superpowers/specs/2026-04-30-tsk-dispo-app-design.md`](docs/superpowers/specs/2026-04-30-tsk-dispo-app-design.md)
- Adressbuch-Spec: [`docs/superpowers/specs/2026-05-09-adressverwaltung-design.md`](docs/superpowers/specs/2026-05-09-adressverwaltung-design.md)
- Pläne: [`docs/superpowers/plans/`](docs/superpowers/plans/)
- Runbooks: [`docs/superpowers/runbooks/`](docs/superpowers/runbooks/)

## Quickstart

```bash
# 1. Install
npm install

# 2. Set up Supabase locally
supabase init        # if not already done
supabase start       # boots local Postgres + Auth + Storage

# 3. Apply schema
supabase db reset    # runs all migrations

# 4. Configure env
cp apps/web/.env.example apps/web/.env
# fill in VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY

# 5. Run dev server
npm run dev
```

Open [http://localhost:5173/login](http://localhost:5173/login).

## Live

- App: https://dispo.course-director.ch _(once deployed)_
- Supabase: https://axnrilhdokkfujzjifhj.supabase.co

## Tech Stack

- **Frontend**: React 18 + Vite + TypeScript, plain CSS (Liquid-Glass-Stil)
- **Backend**: Supabase Managed (Postgres + Auth + Storage + Realtime + Edge Functions)
- **Email**: Resend
- **Hosting**: Vercel + Infomaniak (DNS)

## Lizenz

Privat / TSK ZRH internal — siehe LICENSE (kommt in Plan 3).
