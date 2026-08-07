import { Hono } from "hono";
import { streamSSE } from "hono/streaming";
import { z } from "zod";
import { askWithContext } from "../providers/openaiLlm.js";
import { AuthError, hasSupabase, memory, resolveUserId } from "../lib/supabase.js";
import { getAdminClient } from "../lib/supabase.js";
import { id, yearMonth } from "../lib/ids.js";
import { config } from "../config.js";

export const askRoutes = new Hono();

const askSchema = z.object({
  question: z.string().min(1).max(2000),
  scope: z.enum(["conversation", "all", "folder"]).default("conversation"),
  conversation_id: z.string().uuid().optional(),
  folder_id: z.string().uuid().optional(),
});

async function retrieveContext(userId: string, body: z.infer<typeof askSchema>) {
  if (!hasSupabase()) {
    const blocks: Array<{
      conversation_id: string;
      segment_id: string;
      t_start_ms: number;
      t_end_ms: number;
      speaker_label?: string;
      text: string;
    }> = [];
    for (const [conversationId, segments] of memory.segments.entries()) {
      const conv = memory.conversations.get(conversationId);
      if (!conv || conv.user_id !== userId) continue;
      if (body.scope === "conversation" && body.conversation_id && conversationId !== body.conversation_id) {
        continue;
      }
      for (const s of segments) {
        blocks.push({
          conversation_id: conversationId,
          segment_id: String(s.id),
          t_start_ms: Number(s.t_start_ms),
          t_end_ms: Number(s.t_end_ms),
          speaker_label: s.speaker_label ? String(s.speaker_label) : undefined,
          text: String(s.text),
        });
      }
    }
    return blocks.slice(0, 12);
  }

  const sb = getAdminClient();
  let q = sb
    .from("transcript_segments")
    .select("id, conversation_id, t_start_ms, t_end_ms, text, speakers(label)")
    .eq("user_id", userId)
    .limit(20);
  if (body.scope === "conversation" && body.conversation_id) {
    q = q.eq("conversation_id", body.conversation_id);
  }
  const { data, error } = await q;
  if (error) throw error;
  return (data ?? []).map((s) => ({
    conversation_id: s.conversation_id as string,
    segment_id: s.id as string,
    t_start_ms: s.t_start_ms as number,
    t_end_ms: s.t_end_ms as number,
    speaker_label: (s.speakers as { label?: string } | null)?.label,
    text: s.text as string,
  }));
}

askRoutes.post("/v1/ask", async (c) => {
  try {
    const userId = resolveUserId(c.req.header("authorization"));
    const body = askSchema.parse(await c.req.json());
    if (body.scope === "conversation" && !body.conversation_id) {
      return c.json({ error: "conversation_id required for conversation scope" }, 400);
    }

    const contextBlocks = await retrieveContext(userId, body);
    if (contextBlocks.length === 0) {
      return c.json({
        answer: "I don't have enough transcript evidence to answer that yet.",
        citations: [],
        refused: true,
      });
    }

    const result = await askWithContext({ question: body.question, contextBlocks });

    const queryId = id();
    if (!hasSupabase()) {
      memory.queries.push({
        id: queryId,
        user_id: userId,
        scope: body.scope,
        conversation_id: body.conversation_id ?? null,
        question: body.question,
        answer: result.answer,
        citations: result.citations,
        created_at: new Date().toISOString(),
      });
    } else {
      await getAdminClient().from("ai_queries").insert({
        id: queryId,
        user_id: userId,
        scope: body.scope,
        conversation_id: body.conversation_id ?? null,
        folder_id: body.folder_id ?? null,
        question: body.question,
        answer: result.answer,
        citations: result.citations,
        model: config.askModel,
        prompt_version: config.promptVersion,
      });
      const ym = yearMonth();
      const sb = getAdminClient();
      const { data } = await sb
        .from("usage_monthly")
        .select("ask_ai_count")
        .eq("user_id", userId)
        .eq("year_month", ym)
        .maybeSingle();
      if (!data) {
        await sb.from("usage_monthly").insert({ user_id: userId, year_month: ym, ask_ai_count: 1 });
      } else {
        await sb
          .from("usage_monthly")
          .update({ ask_ai_count: data.ask_ai_count + 1 })
          .eq("user_id", userId)
          .eq("year_month", ym);
      }
    }

    const accept = c.req.header("accept") ?? "";
    if (accept.includes("text/event-stream")) {
      return streamSSE(c, async (stream) => {
        const words = result.answer.split(" ");
        for (const w of words) {
          await stream.writeSSE({ event: "token", data: w + " " });
        }
        await stream.writeSSE({
          event: "done",
          data: JSON.stringify({ id: queryId, citations: result.citations }),
        });
      });
    }

    return c.json({
      id: queryId,
      answer: result.answer,
      citations: result.citations,
      model: config.fixtureMode ? "fixture" : config.askModel,
    });
  } catch (err) {
    if (err instanceof AuthError) return c.json({ error: err.message }, 401);
    if (err instanceof z.ZodError) return c.json({ error: err.flatten() }, 400);
    console.error(err);
    return c.json({ error: err instanceof Error ? err.message : "ask failed" }, 500);
  }
});
