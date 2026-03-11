create table if not exists public.security_audit_log (
  id bigint generated always as identity primary key,
  table_name text not null,
  action text not null check (action in ('INSERT', 'UPDATE', 'DELETE')),
  record_id uuid not null,
  user_id uuid references auth.users (id) on delete set null,
  actor_user_id uuid,
  old_data jsonb,
  new_data jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_security_audit_log_table_record
  on public.security_audit_log (table_name, record_id, created_at desc);

create index if not exists idx_security_audit_log_user_id
  on public.security_audit_log (user_id, created_at desc);

create or replace function public.capture_subscription_audit_log()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  affected_user_id uuid;
  affected_record_id uuid;
begin
  if tg_op = 'DELETE' then
    affected_user_id := old.user_id;
    affected_record_id := old.id;
  else
    affected_user_id := new.user_id;
    affected_record_id := new.id;
  end if;

  insert into public.security_audit_log (
    table_name,
    action,
    record_id,
    user_id,
    actor_user_id,
    old_data,
    new_data
  )
  values (
    tg_table_name,
    tg_op,
    affected_record_id,
    affected_user_id,
    nullif(current_setting('request.jwt.claim.sub', true), '')::uuid,
    case when tg_op = 'INSERT' then null else to_jsonb(old) end,
    case when tg_op = 'DELETE' then null else to_jsonb(new) end
  );

  if tg_op = 'DELETE' then
    return old;
  end if;

  return new;
end;
$$;

drop trigger if exists subscriptions_audit_log on public.subscriptions;
create trigger subscriptions_audit_log
after insert or update or delete on public.subscriptions
for each row
execute function public.capture_subscription_audit_log();

alter table public.security_audit_log enable row level security;
alter table public.security_audit_log force row level security;
