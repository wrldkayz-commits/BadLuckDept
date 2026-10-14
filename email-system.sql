-- BadLuckDept email-system support. Safe to run more than once.
-- Stores only whether a welcome email has already been sent; never stores tokens or passwords.
create table if not exists public.email_events (
  user_id uuid not null references auth.users(id) on delete cascade,
  event_type text not null check (event_type in ('welcome')),
  sent_at timestamptz not null default now(),
  primary key (user_id, event_type)
);

alter table public.email_events enable row level security;
-- Intentionally no client-facing policies. Only the Edge Function's service role may access this table.
revoke all on table public.email_events from anon, authenticated;
