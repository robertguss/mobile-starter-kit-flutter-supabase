create table if not exists public.subscriptions (
  id uuid primary key,
  user_id uuid not null unique references auth.users (id) on delete cascade,
  status text not null check (status in ('active', 'expired', 'cancelled', 'trial')),
  product_id text not null,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_subscriptions_user_id
  on public.subscriptions (user_id);

create index if not exists idx_subscriptions_active
  on public.subscriptions (expires_at)
  where status = 'active';

drop trigger if exists subscriptions_set_updated_at on public.subscriptions;
create trigger subscriptions_set_updated_at
before update on public.subscriptions
for each row
execute function public.set_updated_at();

alter table public.subscriptions enable row level security;
alter table public.subscriptions force row level security;

drop policy if exists "subscriptions_select_own" on public.subscriptions;
create policy "subscriptions_select_own"
on public.subscriptions
for select
using (auth.uid() = user_id);

grant select on public.subscriptions to authenticated;
