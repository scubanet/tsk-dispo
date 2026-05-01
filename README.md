# TSK Dispo

Dispo-, Skill- und Saldo-App für Tauchsport Käge Zürich (TSK ZRH) — Pitch-Prototyp.

## Status

Plan 1 (Foundation & Data) implementiert.

## Spec & Pläne

- Spec: [`docs/superpowers/specs/2026-04-30-tsk-dispo-app-design.md`](docs/superpowers/specs/2026-04-30-tsk-dispo-app-design.md)
- Plan 1: [`docs/superpowers/plans/2026-04-30-tsk-dispo-foundation-and-data.md`](docs/superpowers/plans/2026-04-30-tsk-dispo-foundation-and-data.md)

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
