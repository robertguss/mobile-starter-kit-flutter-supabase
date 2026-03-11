create table if not exists public.webhook_audit_log (
  event_id text primary key,
  event_type text not null,
  app_user_id uuid not null references auth.users (id) on delete cascade,
  payload jsonb not null,
  status text not null check (status in ('processing', 'processed', 'failed')),
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  last_error text
);

create index if not exists idx_webhook_audit_log_app_user_id
  on public.webhook_audit_log (app_user_id);

create index if not exists idx_webhook_audit_log_received_at
  on public.webhook_audit_log (received_at desc);

alter table public.webhook_audit_log enable row level security;
alter table public.webhook_audit_log force row level security;
