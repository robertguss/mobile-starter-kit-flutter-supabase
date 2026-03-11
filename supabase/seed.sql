-- Development seed data.
-- Replace the email filter with a real local auth user after `supabase start`.

insert into public.notes (user_id, title, body)
select
  users.id,
  'Welcome to the starter kit',
  'This note verifies that PowerSync can sync seeded note data.'
from auth.users as users
where users.email = 'demo@example.com';
