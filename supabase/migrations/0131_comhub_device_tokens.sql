-- comhub_device_tokens — APNs-Tokens fuer ComHub-Push (additiv, getrennt von der
-- instructor-basierten device_tokens-Tabelle). Keyed by auth.users; RLS per auth.uid().
-- Eine Edge Function liest die Tokens (Service-Role) und sendet via APNs HTTP/2.
create table if not exists public.comhub_device_tokens (
  id            uuid primary key default gen_random_uuid(),
  auth_user_id  uuid not null references auth.users(id) on delete cascade,
  apns_token    text not null unique,
  platform      text not null default 'ios' check (platform in ('ios','macos')),
  app_env       text not null default 'development' check (app_env in ('development','production')),
  device_name   text,
  updated_at    timestamptz not null default now(),
  created_at    timestamptz not null default now()
);

create index if not exists idx_comhub_device_tokens_user on public.comhub_device_tokens(auth_user_id);

alter table public.comhub_device_tokens enable row level security;

create policy comhub_tokens_own_select on public.comhub_device_tokens
  for select to authenticated using (auth_user_id = auth.uid());
create policy comhub_tokens_own_insert on public.comhub_device_tokens
  for insert to authenticated with check (auth_user_id = auth.uid());
create policy comhub_tokens_own_update on public.comhub_device_tokens
  for update to authenticated using (auth_user_id = auth.uid()) with check (auth_user_id = auth.uid());
create policy comhub_tokens_own_delete on public.comhub_device_tokens
  for delete to authenticated using (auth_user_id = auth.uid());
