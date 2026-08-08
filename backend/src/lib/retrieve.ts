import { embedTexts } from "../providers/openaiLlm.js";
import { getAdminClient, hasSupabase, memory } from "./supabase.js";

export type ContextBlock = {
  conversation_id: string;
  segment_id: string;
  t_start_ms: number;
  t_end_ms: number;
  speaker_label?: string;
  text: string;
  conversation_title?: string;
  similarity?: number;
};

function cosineSimilarity(a: number[], b: number[]): number {
  let dot = 0;
  let na = 0;
  let nb = 0;
  const n = Math.min(a.length, b.length);
  for (let i = 0; i < n; i++) {
    dot += a[i]! * b[i]!;
    na += a[i]! * a[i]!;
    nb += b[i]! * b[i]!;
  }
  if (na === 0 || nb === 0) return 0;
  return dot / (Math.sqrt(na) * Math.sqrt(nb));
}

async function retrieveMemoryMode(input: {
  userId: string;
  question: string;
  scope: "conversation" | "all" | "folder" | "person";
  conversationId?: string;
  folderId?: string;
  personName?: string;
  limit: number;
}): Promise<ContextBlock[]> {
  const [queryVec] = await embedTexts([input.question]);
  type Scored = ContextBlock & { score: number };
  const scored: Scored[] = [];

  for (const [conversationId, chunks] of memory.embeddings.entries()) {
    const conv = memory.conversations.get(conversationId);
    if (!conv || conv.user_id !== input.userId) continue;
    if (input.scope === "conversation" && input.conversationId && conversationId !== input.conversationId) {
      continue;
    }
    if (input.scope === "folder" && input.folderId && String(conv.folder_id ?? "") !== input.folderId) {
      continue;
    }
    if (input.scope === "person" && input.personName) {
      const needle = input.personName.toLowerCase();
      const ents = memory.entities.get(conversationId) ?? [];
      const hitEntity = ents.some(
        (e) =>
          String(e.canonical_name ?? "").toLowerCase().includes(needle) ||
          (Array.isArray(e.aliases) && e.aliases.some((a) => String(a).toLowerCase().includes(needle))),
      );
      const hitText = chunks.some((c) => String(c.text ?? "").toLowerCase().includes(needle));
      if (!hitEntity && !hitText) continue;
    }

    for (const chunk of chunks) {
      const emb = chunk.embedding as number[] | undefined;
      if (!emb || !queryVec) continue;
      const score = cosineSimilarity(queryVec, emb);
      scored.push({
        conversation_id: conversationId,
        segment_id: String(chunk.id ?? `${conversationId}-${chunk.chunk_idx}`),
        t_start_ms: Number(chunk.t_start_ms ?? 0),
        t_end_ms: Number(chunk.t_end_ms ?? 0),
        text: String(chunk.text ?? ""),
        conversation_title: String(conv.title ?? ""),
        similarity: score,
        score,
      });
    }
  }

  // Fallback when embeddings are missing: recent segments.
  if (scored.length === 0) {
    for (const [conversationId, segments] of memory.segments.entries()) {
      const conv = memory.conversations.get(conversationId);
      if (!conv || conv.user_id !== input.userId) continue;
      if (input.scope === "conversation" && input.conversationId && conversationId !== input.conversationId) {
        continue;
      }
      if (input.scope === "folder" && input.folderId && String(conv.folder_id ?? "") !== input.folderId) {
        continue;
      }
      for (const s of segments) {
        scored.push({
          conversation_id: conversationId,
          segment_id: String(s.id),
          t_start_ms: Number(s.t_start_ms),
          t_end_ms: Number(s.t_end_ms),
          speaker_label: s.speaker_label ? String(s.speaker_label) : undefined,
          text: String(s.text),
          conversation_title: String(conv.title ?? ""),
          score: 0,
        });
      }
    }
  }

  return scored
    .sort((a, b) => b.score - a.score)
    .slice(0, input.limit)
    .map(({ score: _s, ...block }) => block);
}

async function retrieveSupabase(input: {
  userId: string;
  question: string;
  scope: "conversation" | "all" | "folder" | "person";
  conversationId?: string;
  folderId?: string;
  personName?: string;
  limit: number;
}): Promise<ContextBlock[]> {
  const [queryVec] = await embedTexts([input.question]);
  if (!queryVec) return [];

  const sb = getAdminClient();
  const { data, error } = await sb.rpc("match_embedding_chunks", {
    query_embedding: queryVec,
    match_user_id: input.userId,
    match_count: input.limit,
    filter_conversation_id: input.scope === "conversation" ? input.conversationId ?? null : null,
    filter_folder_id: input.scope === "folder" ? input.folderId ?? null : null,
    filter_entity_name: input.scope === "person" ? input.personName ?? null : null,
  });

  if (error) {
    console.warn("[retrieve] match_embedding_chunks failed, falling back:", error.message);
    // Fallback to recent segments
    let q = sb
      .from("transcript_segments")
      .select("id, conversation_id, t_start_ms, t_end_ms, text, speakers(label), conversations(title)")
      .eq("user_id", input.userId)
      .limit(input.limit);
    if (input.scope === "conversation" && input.conversationId) {
      q = q.eq("conversation_id", input.conversationId);
    }
    const { data: segs } = await q;
    return (segs ?? []).map((s) => ({
      conversation_id: s.conversation_id as string,
      segment_id: s.id as string,
      t_start_ms: s.t_start_ms as number,
      t_end_ms: s.t_end_ms as number,
      speaker_label: (s.speakers as { label?: string } | null)?.label,
      text: s.text as string,
      conversation_title: (s.conversations as { title?: string } | null)?.title,
    }));
  }

  return (data ?? []).map((row: Record<string, unknown>) => ({
    conversation_id: String(row.conversation_id),
    segment_id: String(row.id),
    t_start_ms: Number(row.t_start_ms ?? 0),
    t_end_ms: Number(row.t_end_ms ?? 0),
    text: String(row.text ?? ""),
    conversation_title: String(row.conversation_title ?? ""),
    similarity: typeof row.similarity === "number" ? row.similarity : undefined,
  }));
}

export async function retrieveContextForAsk(input: {
  userId: string;
  question: string;
  scope: "conversation" | "all" | "folder" | "person";
  conversationId?: string;
  folderId?: string;
  personName?: string;
  limit?: number;
}): Promise<ContextBlock[]> {
  const limit = input.limit ?? 12;
  if (!hasSupabase()) {
    return retrieveMemoryMode({ ...input, limit });
  }
  return retrieveSupabase({ ...input, limit });
}

export async function buildMeetingBrief(input: {
  userId: string;
  title?: string;
  attendeeNames?: string[];
}): Promise<{
  title: string;
  prior_decisions: string[];
  open_todos: string[];
  suggested_questions: string[];
  related_conversation_ids: string[];
  summary_snippets: string[];
}> {
  const title = input.title?.trim() || "Upcoming meeting";
  const names = (input.attendeeNames ?? []).map((n) => n.trim()).filter(Boolean);
  const query = [title, ...names].filter(Boolean).join(" ");

  const blocks = query
    ? await retrieveContextForAsk({
        userId: input.userId,
        question: `Prior context for meeting: ${query}`,
        scope: names[0] ? "person" : "all",
        personName: names[0],
        limit: 8,
      })
    : [];

  const relatedIds = [...new Set(blocks.map((b) => b.conversation_id))];
  const priorDecisions: string[] = [];
  const openTodos: string[] = [];
  const snippets: string[] = [];

  if (!hasSupabase()) {
    for (const cid of relatedIds.slice(0, 5)) {
      const summary = memory.summaries.get(cid);
      if (summary?.summary) snippets.push(String(summary.summary).slice(0, 180));
      const decisions = Array.isArray(summary?.decisions) ? summary.decisions : [];
      for (const d of decisions) {
        const text = typeof d === "string" ? d : (d as { text?: string })?.text;
        if (text) priorDecisions.push(text);
      }
      const actions = memory.actionItems.get(cid) ?? [];
      for (const a of actions) {
        if (a.status === "open" && a.text) openTodos.push(String(a.text));
      }
    }
  } else {
    const sb = getAdminClient();
    if (relatedIds.length > 0) {
      const { data: summaries } = await sb
        .from("summaries")
        .select("conversation_id, summary, decisions")
        .in("conversation_id", relatedIds.slice(0, 8));
      for (const s of summaries ?? []) {
        if (s.summary) snippets.push(String(s.summary).slice(0, 180));
        const decisions = Array.isArray(s.decisions) ? s.decisions : [];
        for (const d of decisions) {
          const text = typeof d === "string" ? d : (d as { text?: string })?.text;
          if (text) priorDecisions.push(text);
        }
      }
      const { data: actions } = await sb
        .from("action_items")
        .select("text")
        .eq("user_id", input.userId)
        .eq("status", "open")
        .in("conversation_id", relatedIds.slice(0, 8))
        .limit(12);
      for (const a of actions ?? []) {
        if (a.text) openTodos.push(String(a.text));
      }
    }
  }

  const suggested = [
    names[0] ? `Any open follow-ups with ${names[0]}?` : "What decisions are still open from last time?",
    openTodos[0] ? `Status on: ${openTodos[0]}` : "What should we decide today?",
    priorDecisions[0] ? `Confirm last decision: ${priorDecisions[0]}` : `Goals for ${title}?`,
  ];

  return {
    title,
    prior_decisions: priorDecisions.slice(0, 5),
    open_todos: openTodos.slice(0, 8),
    suggested_questions: suggested,
    related_conversation_ids: relatedIds.slice(0, 8),
    summary_snippets: snippets.slice(0, 4),
  };
}
