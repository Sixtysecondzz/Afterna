-- Shareable note links: tokenized public snapshots of conversation summaries.
-- Public viewers hit the Hono backend (service role); clients never need anon SELECT.

create table if not exists public.shared_notes (
  id uuid primary key default gen_random_uuid(),
  token text not null unique,
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  revoked_at timestamptz,
  snapshot jsonb not null default '{}'::jsonb
);

create index if not exists shared_notes_token_idx
  on public.shared_notes (token)
  where revoked_at is null;

create index if not exists shared_notes_user_idx
  on public.shared_notes (user_id, created_at desc);

create index if not exists shared_notes_conversation_idx
  on public.shared_notes (conversation_id, created_at desc);

alter table public.shared_notes enable row level security;

-- Owners manage their own share rows. Public HTML is served by the API with service role
-- (bypasses RLS); anon has no SELECT on live private tables via this path.
drop policy if exists shared_notes_owner on public.shared_notes;
create policy shared_notes_owner on public.shared_notes
  for all
  to authenticated
  using ( (select auth.uid()) = user_id )
  with check ( (select auth.uid()) = user_id );
