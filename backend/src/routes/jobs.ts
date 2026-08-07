import { Hono } from "hono";
import { getJob, getSegments } from "../lib/store.js";
import { AuthError, memory, resolveUserId, hasSupabase } from "../lib/supabase.js";
import { getAdminClient } from "../lib/supabase.js";

export const jobRoutes = new Hono();

jobRoutes.get("/v1/jobs/:id", async (c) => {
  try {
    const userId = resolveUserId(c.req.header("authorization"));
    const job = await getJob(c.req.param("id"));
    if (!job || job.user_id !== userId) return c.json({ error: "not found" }, 404);
    return c.json({
      id: job.id,
      job_type: job.job_type,
      status: job.status,
      recording_id: job.recording_id,
      conversation_id: job.conversation_id,
      provider: job.provider,
      model: job.model,
      attempts: job.attempts,
      error: job.error,
      created_at: job.created_at,
      started_at: job.started_at,
      finished_at: job.finished_at,
    });
  } catch (err) {
    if (err instanceof AuthError) return c.json({ error: err.message }, 401);
    return c.json({ error: err instanceof Error ? err.message : "error" }, 500);
  }
});

jobRoutes.get("/v1/conversations/:id/transcript", async (c) => {
  try {
    const userId = resolveUserId(c.req.header("authorization"));
    const conversationId = c.req.param("id");

    if (!hasSupabase()) {
      const conv = memory.conversations.get(conversationId);
      if (!conv || conv.user_id !== userId) return c.json({ error: "not found" }, 404);
      const segments = memory.segments.get(conversationId) ?? [];
      const summary = memory.summaries.get(conversationId) ?? null;
      return c.json({
        conversation_id: conversationId,
        status: conv.status,
        has_embeddings: Boolean(conv.has_embeddings),
        segments,
        summary,
        action_items: memory.actionItems.get(conversationId) ?? [],
      });
    }

    const sb = getAdminClient();
    const { data: conv, error } = await sb
      .from("conversations")
      .select("*")
      .eq("id", conversationId)
      .eq("user_id", userId)
      .maybeSingle();
    if (error) throw error;
    if (!conv) return c.json({ error: "not found" }, 404);
    const segments = await getSegments(conversationId);
    const { data: summary } = await sb
      .from("summaries")
      .select("*")
      .eq("conversation_id", conversationId)
      .maybeSingle();
    const { data: actions } = await sb
      .from("action_items")
      .select("*")
      .eq("conversation_id", conversationId);
    return c.json({
      conversation_id: conversationId,
      status: conv.status,
      segments,
      summary,
      action_items: actions ?? [],
    });
  } catch (err) {
    if (err instanceof AuthError) return c.json({ error: err.message }, 401);
    return c.json({ error: err instanceof Error ? err.message : "error" }, 500);
  }
});
