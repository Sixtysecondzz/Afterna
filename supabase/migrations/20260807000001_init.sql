-- Afterna V1 schema (from docs/BACKEND_ARCHITECTURE.md)
create extension if not exists vector;
create extension if not exists pg_trgm;

-- ========== users & billing ==========
create table public.users (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  locale text default 'en',
  keep_audio_default boolean not null default false,
  revenuecat_app_user_id text unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  provider text not null default 'revenuecat',
  product_id text not null,
  status text not null check (status in ('active','canceled','expired','trialing','grace')),
  starts_at timestamptz,
  expires_at timestamptz,
  raw jsonb not null default '{}',
  updated_at timestamptz not null default now(),
  unique (user_id, provider)
);

create table public.usage_monthly (
  user_id uuid not null references public.users (id) on delete cascade,
  year_month int not null,
  transcription_seconds int not null default 0,
  ask_ai_count int not null default 0,
  llm_cost_usd numeric(12,6) not null default 0,
  asr_cost_usd numeric(12,6) not null default 0,
  primary key (user_id, year_month)
);

-- ========== taxonomy ==========
create table public.folders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  name text not null,
  parent_id uuid references public.folders (id) on delete set null,
  created_at timestamptz not null default now(),
  unique (user_id, name, parent_id)
);

create table public.tags (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  unique (user_id, name)
);

-- ========== recordings & conversations ==========
create table public.recordings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  local_path text,
  storage_path text,
  duration_ms int,
  mime_type text,
  byte_size bigint,
  checksum bytea,
  keep_audio boolean not null default false,
  transcription_status text not null default 'pending'
    check (transcription_status in ('pending','processing','succeeded','failed')),
  audio_deleted_at timestamptz,
  captured_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  recording_id uuid references public.recordings (id) on delete set null,
  folder_id uuid references public.folders (id) on delete set null,
  title text,
  language text,
  started_at timestamptz,
  ended_at timestamptz,
  status text not null default 'processing'
    check (status in ('processing','ready','failed','archived')),
  source text not null default 'recording'
    check (source in ('recording','import','manual_notes')),
  has_embeddings boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.conversation_tags (
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  tag_id uuid not null references public.tags (id) on delete cascade,
  primary key (conversation_id, tag_id)
);

create table public.speakers (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  label text not null,
  entity_id uuid,
  is_user boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.transcript_segments (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  speaker_id uuid references public.speakers (id) on delete set null,
  idx int not null,
  t_start_ms int not null,
  t_end_ms int not null,
  text text not null,
  confidence real,
  created_at timestamptz not null default now(),
  unique (conversation_id, idx)
);

alter table public.transcript_segments
  add column text_tsv tsvector
  generated always as (to_tsvector('english', coalesce(text, ''))) stored;

create index transcript_segments_tsv_idx on public.transcript_segments using gin (text_tsv);
create index transcript_segments_conv_time_idx on public.transcript_segments (conversation_id, t_start_ms);
create index transcript_segments_user_idx on public.transcript_segments (user_id);

create table public.summaries (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  prompt_version text not null,
  summary text not null,
  key_points jsonb not null default '[]',
  decisions jsonb not null default '[]',
  deadlines jsonb not null default '[]',
  model text not null,
  token_input int,
  token_output int,
  cost_usd_estimate numeric(12,6),
  created_at timestamptz not null default now(),
  unique (conversation_id, prompt_version)
);

create table public.action_items (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  text text not null,
  assignee_text text,
  assignee_entity_id uuid,
  due_date date,
  status text not null default 'open'
    check (status in ('open','done','dismissed')),
  confidence real,
  source_segment_ids uuid[] not null default '{}',
  t_start_ms int,
  t_end_ms int,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index action_items_open_idx on public.action_items (user_id, due_date) where status = 'open';

create table public.entities (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  type text not null check (type in ('person','company','project','topic','place','other')),
  canonical_name text not null,
  properties jsonb not null default '{}',
  mention_count int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, type, canonical_name)
);

create index entities_name_trgm_idx on public.entities using gin (canonical_name gin_trgm_ops);

alter table public.speakers
  add constraint speakers_entity_fk
  foreign key (entity_id) references public.entities (id) on delete set null;

alter table public.action_items
  add constraint action_items_assignee_fk
  foreign key (assignee_entity_id) references public.entities (id) on delete set null;

create table public.entity_aliases (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.entities (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  alias text not null,
  unique (user_id, alias)
);

create table public.entity_mentions (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.entities (id) on delete cascade,
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  segment_id uuid not null references public.transcript_segments (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  confidence real,
  created_at timestamptz not null default now()
);

create index entity_mentions_entity_idx on public.entity_mentions (entity_id, conversation_id);

create table public.embedding_chunks (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  chunk_idx int not null,
  t_start_ms int not null,
  t_end_ms int not null,
  segment_id_start uuid references public.transcript_segments (id) on delete set null,
  segment_id_end uuid references public.transcript_segments (id) on delete set null,
  text text not null,
  embedding vector(1536) not null,
  embedding_model text not null,
  created_at timestamptz not null default now(),
  unique (conversation_id, embedding_model, chunk_idx)
);

create index embedding_chunks_user_hnsw_idx
  on public.embedding_chunks using hnsw (embedding vector_cosine_ops);
create index embedding_chunks_user_conv_idx
  on public.embedding_chunks (user_id, conversation_id);

create table public.ai_queries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  scope text not null check (scope in ('conversation','all','folder')),
  conversation_id uuid references public.conversations (id) on delete set null,
  folder_id uuid references public.folders (id) on delete set null,
  question text not null,
  answer text,
  citations jsonb not null default '[]',
  retrieved_chunk_ids uuid[] not null default '{}',
  model text,
  prompt_version text,
  token_input int,
  token_output int,
  cost_usd_estimate numeric(12,6),
  latency_ms int,
  created_at timestamptz not null default now()
);

create table public.ai_jobs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  job_type text not null
    check (job_type in ('transcribe','extract','embed','purge_audio','reindex')),
  status text not null default 'queued'
    check (status in ('queued','running','succeeded','failed','dead')),
  recording_id uuid references public.recordings (id) on delete cascade,
  conversation_id uuid references public.conversations (id) on delete cascade,
  idempotency_key text not null,
  attempts int not null default 0,
  provider text,
  model text,
  token_input int,
  token_output int,
  cost_usd_estimate numeric(12,6),
  error text,
  payload jsonb not null default '{}',
  created_at timestamptz not null default now(),
  started_at timestamptz,
  finished_at timestamptz,
  unique (idempotency_key)
);

create index ai_jobs_status_idx on public.ai_jobs (status, created_at);

-- Auto-create public.users row on signup
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', new.email))
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
