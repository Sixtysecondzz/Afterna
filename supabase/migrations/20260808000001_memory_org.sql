-- Memory organization: pins, quotes, global todos

alter table public.conversations
  add column if not exists is_pinned boolean not null default false;

create index if not exists conversations_pinned_idx
  on public.conversations (user_id, is_pinned desc, created_at desc);

-- Allow manual / global todos without a conversation
alter table public.action_items
  alter column conversation_id drop not null;

create table if not exists public.quotes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  segment_id uuid references public.transcript_segments (id) on delete set null,
  text text not null,
  speaker_label text,
  t_start_ms int,
  t_end_ms int,
  created_at timestamptz not null default now()
);

create index if not exists quotes_conversation_idx
  on public.quotes (conversation_id, created_at desc);

create index if not exists quotes_user_idx
  on public.quotes (user_id, created_at desc);

alter table public.quotes enable row level security;

drop policy if exists quotes_owner on public.quotes;
create policy quotes_owner on public.quotes
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
