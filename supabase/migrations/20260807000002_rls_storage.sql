-- RLS: owner-only on user tables; ai_jobs select-only for owners
alter table public.users enable row level security;
alter table public.subscriptions enable row level security;
alter table public.usage_monthly enable row level security;
alter table public.folders enable row level security;
alter table public.tags enable row level security;
alter table public.recordings enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_tags enable row level security;
alter table public.speakers enable row level security;
alter table public.transcript_segments enable row level security;
alter table public.summaries enable row level security;
alter table public.action_items enable row level security;
alter table public.entities enable row level security;
alter table public.entity_aliases enable row level security;
alter table public.entity_mentions enable row level security;
alter table public.embedding_chunks enable row level security;
alter table public.ai_queries enable row level security;
alter table public.ai_jobs enable row level security;

create policy users_owner on public.users for all using (auth.uid() = id) with check (auth.uid() = id);
create policy subscriptions_owner on public.subscriptions for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy usage_monthly_owner on public.usage_monthly for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy folders_owner on public.folders for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy tags_owner on public.tags for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy recordings_owner on public.recordings for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy conversations_owner on public.conversations for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy speakers_owner on public.speakers for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy transcript_segments_owner on public.transcript_segments for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy summaries_owner on public.summaries for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy action_items_owner on public.action_items for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy entities_owner on public.entities for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy entity_aliases_owner on public.entity_aliases for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy entity_mentions_owner on public.entity_mentions for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy embedding_chunks_owner on public.embedding_chunks for select using (auth.uid() = user_id);
create policy ai_queries_owner on public.ai_queries for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy ai_jobs_select_owner on public.ai_jobs for select using (auth.uid() = user_id);

create policy conversation_tags_owner on public.conversation_tags for all
  using (
    exists (
      select 1 from public.conversations c
      where c.id = conversation_id and c.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.conversations c
      where c.id = conversation_id and c.user_id = auth.uid()
    )
  );

-- Storage bucket: ephemeral audio inbox
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'audio-inbox',
  'audio-inbox',
  false,
  104857600,
  array['audio/mp4', 'audio/m4a', 'audio/aac', 'audio/mpeg', 'audio/wav', 'audio/x-m4a']
)
on conflict (id) do nothing;

create policy audio_inbox_owner_read on storage.objects
  for select to authenticated
  using (bucket_id = 'audio-inbox' and (storage.foldername(name))[1] = auth.uid()::text);

create policy audio_inbox_owner_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'audio-inbox' and (storage.foldername(name))[1] = auth.uid()::text);

create policy audio_inbox_owner_update on storage.objects
  for update to authenticated
  using (bucket_id = 'audio-inbox' and (storage.foldername(name))[1] = auth.uid()::text);

create policy audio_inbox_owner_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'audio-inbox' and (storage.foldername(name))[1] = auth.uid()::text);
