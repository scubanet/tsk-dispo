-- AtollTalk Pro fair-use counter (per StoreKit original transaction id, per day).
-- Protects Claude cost on the translate proxy. One row per account+day.
create table if not exists public.atolltalk_usage (
  account text not null,
  day     date not null,
  count   integer not null default 0,
  primary key (account, day)
);

-- Only the service role (Edge Function) touches this table.
alter table public.atolltalk_usage enable row level security;

-- Atomic increment used by the translate function. Returns the new count.
create or replace function public.atolltalk_bump_usage(p_account text, p_day date)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  new_count integer;
begin
  insert into public.atolltalk_usage (account, day, count)
  values (p_account, p_day, 1)
  on conflict (account, day)
  do update set count = public.atolltalk_usage.count + 1
  returning count into new_count;
  return new_count;
end;
$$;
