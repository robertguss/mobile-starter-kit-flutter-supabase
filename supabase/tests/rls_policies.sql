\set ON_ERROR_STOP on

begin;

insert into auth.users (
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
)
values
  (
    '11111111-1111-1111-1111-111111111111',
    'authenticated',
    'authenticated',
    'owner@example.com',
    crypt('password', gen_salt('bf')),
    now(),
    '{}'::jsonb,
    '{}'::jsonb,
    now(),
    now()
  ),
  (
    '22222222-2222-2222-2222-222222222222',
    'authenticated',
    'authenticated',
    'other@example.com',
    crypt('password', gen_salt('bf')),
    now(),
    '{}'::jsonb,
    '{}'::jsonb,
    now(),
    now()
  )
on conflict (id) do nothing;

insert into public.subscriptions (
  id,
  user_id,
  status,
  product_id,
  expires_at
)
values (
  '33333333-3333-3333-3333-333333333333',
  '11111111-1111-1111-1111-111111111111',
  'active',
  'starter.pro.monthly',
  now() + interval '30 days'
)
on conflict (id) do nothing;

commit;

do $$
declare
  audit_log_count integer;
begin
  update public.subscriptions
     set status = 'trial'
   where id = '33333333-3333-3333-3333-333333333333'::uuid;

  select count(*)
    into audit_log_count
    from public.security_audit_log
   where table_name = 'subscriptions'
     and record_id = '33333333-3333-3333-3333-333333333333'::uuid;

  if audit_log_count <> 2 then
    raise exception 'expected subscription audit log rows for insert and update';
  end if;
end $$;

begin;
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config(
  'request.jwt.claim.sub',
  '11111111-1111-1111-1111-111111111111',
  true
);

do $$
declare
  own_note_count integer;
  own_subscription_count integer;
  visible_audit_rows integer;
begin
  insert into public.notes (title, body)
  values ('Owner note', 'private body');

  select count(*)
    into own_note_count
    from public.notes
   where user_id = '11111111-1111-1111-1111-111111111111'::uuid
     and title = 'Owner note';

  if own_note_count <> 1 then
    raise exception 'owner could not read the note they created';
  end if;

  select count(*)
    into own_subscription_count
    from public.subscriptions
   where user_id = '11111111-1111-1111-1111-111111111111'::uuid;

  if own_subscription_count <> 1 then
    raise exception 'owner could not read their own subscription row';
  end if;

  select count(*)
    into visible_audit_rows
    from public.security_audit_log;

  if visible_audit_rows <> 0 then
    raise exception 'authenticated user unexpectedly saw security audit rows';
  end if;
end $$;

commit;

begin;
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config(
  'request.jwt.claim.sub',
  '22222222-2222-2222-2222-222222222222',
  true
);

do $$
declare
  visible_notes integer;
  visible_subscriptions integer;
  affected_rows integer;
  insert_blocked boolean := false;
begin
  select count(*)
    into visible_notes
    from public.notes
   where user_id = '11111111-1111-1111-1111-111111111111'::uuid;

  if visible_notes <> 0 then
    raise exception 'cross-user note read succeeded';
  end if;

  select count(*)
    into visible_subscriptions
    from public.subscriptions
   where user_id = '11111111-1111-1111-1111-111111111111'::uuid;

  if visible_subscriptions <> 0 then
    raise exception 'cross-user subscription read succeeded';
  end if;

  update public.notes
     set title = 'tampered'
   where user_id = '11111111-1111-1111-1111-111111111111'::uuid;
  get diagnostics affected_rows = row_count;

  if affected_rows <> 0 then
    raise exception 'cross-user note update succeeded';
  end if;

  delete from public.notes
   where user_id = '11111111-1111-1111-1111-111111111111'::uuid;
  get diagnostics affected_rows = row_count;

  if affected_rows <> 0 then
    raise exception 'cross-user note delete succeeded';
  end if;

  begin
    insert into public.subscriptions (
      id,
      user_id,
      status,
      product_id
    )
    values (
      '44444444-4444-4444-4444-444444444444',
      '22222222-2222-2222-2222-222222222222',
      'trial',
      'starter.pro.monthly'
    );
  exception
    when insufficient_privilege then
      insert_blocked := true;
  end;

  if not insert_blocked then
    raise exception 'authenticated subscription insert unexpectedly succeeded';
  end if;
end $$;

commit;
