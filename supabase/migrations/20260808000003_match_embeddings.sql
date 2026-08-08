-- Semantic Ask: cosine similarity over embedding_chunks (pgvector).
-- Called by the API with the service role; RLS still protects direct client access.

create or replace function public.match_embedding_chunks(
  query_embedding vector(1536),
  match_user_id uuid,
  match_count int default 12,
  filter_conversation_id uuid default null,
  filter_folder_id uuid default null,
  filter_entity_name text default null
)
returns table (
  id uuid,
  conversation_id uuid,
  user_id uuid,
  chunk_idx int,
  t_start_ms int,
  t_end_ms int,
  text text,
  similarity float,
  conversation_title text
)
language sql
stable
as $$
  select
    c.id,
    c.conversation_id,
    c.user_id,
    c.chunk_idx,
    c.t_start_ms,
    c.t_end_ms,
    c.text,
    (1 - (c.embedding <=> query_embedding))::float as similarity,
    coalesce(conv.title, '') as conversation_title
  from public.embedding_chunks c
  join public.conversations conv on conv.id = c.conversation_id
  where c.user_id = match_user_id
    and (filter_conversation_id is null or c.conversation_id = filter_conversation_id)
    and (
      filter_folder_id is null
      or conv.folder_id = filter_folder_id
    )
    and (
      filter_entity_name is null
      or exists (
        select 1
        from public.entity_mentions em
        join public.entities e on e.id = em.entity_id
        where em.conversation_id = c.conversation_id
          and e.user_id = match_user_id
          and (
            e.canonical_name ilike '%' || filter_entity_name || '%'
            or exists (
              select 1 from public.entity_aliases ea
              where ea.entity_id = e.id
                and ea.alias ilike '%' || filter_entity_name || '%'
            )
          )
      )
      or c.text ilike '%' || filter_entity_name || '%'
    )
  order by c.embedding <=> query_embedding
  limit greatest(match_count, 1);
$$;

revoke all on function public.match_embedding_chunks(vector, uuid, int, uuid, uuid, text) from public;
grant execute on function public.match_embedding_chunks(vector, uuid, int, uuid, uuid, text) to service_role;
