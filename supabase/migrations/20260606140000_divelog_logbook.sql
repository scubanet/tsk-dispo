-- ═══════════════════════════════════════════════════════════════
-- DiveLog × Atoll — Phase 3: Logbuch-Spiegel (Iteration 1)
-- Plan: PKA/Deliverables/2026-06-06-divelog-iteration1-plan.md
-- Architektur: One-Way-Publish (DiveLog → Supabase). CloudKit bleibt
-- SSOT des privaten Logbuchs (E1 Hybrid). Kein Pull in v1.
-- dive_photos bewusst NICHT in v1 (Storage-Thema, eigener Schritt).
-- RLS: owner-only, kein anon-Zugriff. Breitere Lese-Policies (z. B.
-- Instruktor sieht Schüler-Divecount) sind ein EIGENES Vex-Review.
-- ═══════════════════════════════════════════════════════════════

-- ── Tabelle ─────────────────────────────────────────────────────

create table if not exists public.dives (
  id          uuid primary key default gen_random_uuid(),
  owner       uuid not null references auth.users (id) on delete cascade,
  -- SwiftData-ID-Spiegel → idempotente Upserts vom Publisher.
  -- Unique PRO OWNER (nicht global): verhindert, dass ein fremder User
  -- eine client_id "besetzt" und damit Upserts blockiert (Vex-Audit).
  client_id   uuid not null,
  number      integer,
  date        timestamptz,
  site_name   text,
  site_location text,
  latitude    double precision,
  longitude   double precision,
  max_depth   numeric(6,2),
  avg_depth   numeric(6,2),
  bottom_time integer,
  total_time  integer,
  dive_type   text,
  -- Bedingungen gebündelt: weather, current, waves, visibility,
  -- air_temp, water_temp_surface, water_temp_bottom, suit, …
  conditions  jsonb not null default '{}'::jsonb,
  -- Gas/Equipment gebündelt: gas, cylinder, weight, …
  gas         jsonb not null default '{}'::jsonb,
  notes       text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (owner, client_id)
);

comment on table public.dives is
  'DiveLog-Logbuch-Spiegel (One-Way-Publish aus der App). SSOT ist CloudKit; diese Tabelle ist die geteilte Sicht für die Atoll-Welt.';

-- ── updated_at-Trigger ──────────────────────────────────────────

create or replace function public.tg_dives_set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_dives_updated_at on public.dives;
create trigger trg_dives_updated_at
  before update on public.dives
  for each row execute function public.tg_dives_set_updated_at();

-- ── Index ───────────────────────────────────────────────────────

create index if not exists idx_dives_owner_date on public.dives (owner, date desc);

-- ── RLS: owner-only, kein anon ──────────────────────────────────

alter table public.dives enable row level security;

drop policy if exists dives_select_own on public.dives;
create policy dives_select_own on public.dives
  for select to authenticated
  using (owner = (select auth.uid()));

drop policy if exists dives_insert_own on public.dives;
create policy dives_insert_own on public.dives
  for insert to authenticated
  with check (owner = (select auth.uid()));

drop policy if exists dives_update_own on public.dives;
create policy dives_update_own on public.dives
  for update to authenticated
  using (owner = (select auth.uid()))
  with check (owner = (select auth.uid()));

drop policy if exists dives_delete_own on public.dives;
create policy dives_delete_own on public.dives
  for delete to authenticated
  using (owner = (select auth.uid()));

-- anon erhält keinerlei Policy → kein Zugriff. Zusätzlich explizit:
revoke all on public.dives from anon;
