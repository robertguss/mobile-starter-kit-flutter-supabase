drop publication if exists powersync;
create publication powersync for table public.notes, public.subscriptions;
