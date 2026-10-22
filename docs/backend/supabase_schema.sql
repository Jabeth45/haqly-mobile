-- =====================================================================
-- Haqly — PROPOSED target Supabase schema + RLS + sync guard
-- STATUS: PROPOSAL. NOT TESTED against a live project. NOT diffed against the web app.
-- DO NOT RUN on the production project that the web app uses until:
--   OPEN-002 (audit the live schema/RLS), OPEN-003 (web app filters deleted_at).
-- Run first on a throwaway project/branch and execute the RLS matrix in SECURITY.md.
-- If tables already exist, convert this into an ALTER-based migration after diffing.
-- Money: numeric(14,2) (mobile converts to/from integer minor units at the sync boundary).
-- Ids: uuid generated on the client.
-- =====================================================================

-- Sync guard: server-enforced last-write-wins, server cursor timestamp, immutable owner.
create or replace function public.haqly_sync_guard()
returns trigger
language plpgsql
as $$
begin
  -- Never trust far-future client clocks.
  if new.client_updated_at > now() + interval '5 minutes' then
    new.client_updated_at := now() + interval '5 minutes';
  end if;

  if tg_op = 'UPDATE' then
    -- Older or equal write loses: keep the existing row untouched (no cursor bump).
    if new.client_updated_at <= old.client_updated_at then
      return old;
    end if;
    new.user_id := old.user_id;        -- owner is immutable
    new.created_at := old.created_at;  -- creation time is immutable
  end if;

  new.updated_at := now();             -- server clock drives pull cursors
  return new;
end;
$$;

create table if not exists public.expenses (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  amount numeric(14,2) not null check (amount >= 0),
  category text not null default 'Other',
  type text not null default 'expense' check (type in ('expense','income')),
  local_date date not null,
  created_at timestamptz not null default now(),
  client_updated_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.check_items (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  price numeric(14,2) not null check (price >= 0),
  uses numeric(12,3) not null check (uses > 0),
  cost_per_use numeric(18,6) not null,
  verdict text not null check (verdict in ('worth','maybe','not')),
  regret_level smallint not null check (regret_level between 1 and 5),
  local_date date not null,
  created_at timestamptz not null default now(),
  client_updated_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.ledger_entries (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  person text not null,
  amount numeric(14,2) not null check (amount >= 0),
  currency text not null default 'ETB' check (currency in ('ETB','USD')),
  type text not null check (type in ('lent','borrowed')),
  note text,
  settled boolean not null default false,
  local_date date not null,
  created_at timestamptz not null default now(),
  client_updated_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.budgets (
  id uuid primary key,
  user_id uuid not null unique default auth.uid() references auth.users(id) on delete cascade,
  monthly_budget numeric(14,2) check (monthly_budget is null or monthly_budget >= 0),
  weekly_budget numeric(14,2) check (weekly_budget is null or weekly_budget >= 0),
  created_at timestamptz not null default now(),
  client_updated_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.contacts (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  phone text,
  note text,
  created_at timestamptz not null default now(),
  client_updated_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.user_categories (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  kind text not null check (kind in ('expense','income')),
  created_at timestamptz not null default now(),
  client_updated_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- RLS, policies, trigger and pull index on every table.
-- No DELETE policy on purpose: clients soft-delete via deleted_at.
do $$
declare t text;
begin
  foreach t in array array['expenses','check_items','ledger_entries','budgets','contacts','user_categories']
  loop
    execute format('alter table public.%I enable row level security', t);
    execute format('alter table public.%I force row level security', t);

    execute format('drop policy if exists %I on public.%I', t || '_select_own', t);
    execute format('create policy %I on public.%I for select to authenticated using (user_id = (select auth.uid()))', t || '_select_own', t);

    execute format('drop policy if exists %I on public.%I', t || '_insert_own', t);
    execute format('create policy %I on public.%I for insert to authenticated with check (user_id = (select auth.uid()))', t || '_insert_own', t);

    execute format('drop policy if exists %I on public.%I', t || '_update_own', t);
    execute format('create policy %I on public.%I for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()))', t || '_update_own', t);

    execute format('drop trigger if exists %I on public.%I', t || '_sync_guard', t);
    execute format('create trigger %I before insert or update on public.%I for each row execute function public.haqly_sync_guard()', t || '_sync_guard', t);

    execute format('create index if not exists %I on public.%I (user_id, updated_at, id)', t || '_pull_idx', t);
  end loop;
end $$;

-- Optional hardening (decide with OPEN-008): cap rows for anonymous users, e.g. a policy
-- or trigger checking (auth.jwt() ->> 'is_anonymous')::boolean. Not included: needs a product limit.

-- Account deletion is NOT done from the client. Implement an Edge Function that verifies the caller's
-- JWT, then uses the service role to delete the auth user (cascades to all rows above). Never ship the
-- service role key in the app.
