import { Hono } from "hono";
import { streamSSE } from "hono/streaming";
import { z } from "zod";
import { askWithContext } from "../providers/openaiLlm.js";
import { AuthError, hasSupabase, memory, resolveUserId } from "../lib/supabase.js";
import { getAdminClient } from "../lib/supabase.js";
import { id, yearMonth } from "../lib/ids.js";
import { config } from "../config.js";
import { retrieveContextForAsk } from "../lib/retrieve.js";

export const askRoutes = new Hono();

const askSchema = z.object({
  question: z.string().min(1).max(2000),
  scope: z.enum(["conversation", "all", "folder", "person"]).default("conversation"),
  conversation_id: z.string().uuid().optional(),
  folder_id: z.string().uuid().optional(),
  person_name: z.string().min(1).max(120).optional(),
});

askRoutes.post("/v1/ask", async (c) => {
  try {
    const userId = resolveUserId(c.req.header("authorization"));
    const body = askSchema.parse(await c.req.json());
    if (body.scope === "conversation" && !body.conversation_id) {
      return c.json({ error: "conversation_id required for conversation scope" }, 400);
    }
    if (body.scope === "folder" && !body.folder_id) {
      return c.json({ error: "folder_id required for folder scope" }, 400);
    }
    if (body.scope === "person" && !body.person_name) {
      return c.json({ error: "person_name required for person scope" }, 400);
    }

    const contextBlocks = await retrieveContextForAsk({
      userId,
      question: body.question,
      scope: body.scope,
      conversationId: body.conversation_id,
      folderId: body.folder_id,
      personName: body.person_name,
      limit: 12,
    });

    if (contextBlocks.length === 0) {
      return c.json({
        answer: "I don't have enough transcript evidence to answer that yet.",
        citations: [],
        refused: true,
      });
    }

    const result = await askWithContext({ question: body.question, contextBlocks });

    // Enrich citations with conversation titles when available.
    const titleByConv = new Map(
      contextBlocks
        .filter((b) => b.conversation_title)
        .map((b) => [b.conversation_id, b.conversation_title!] as const),
    );
    const citations = result.citations.map((cit) => ({
      ...cit,
      conversation_title: titleByConv.get(cit.conversation_id) ?? null,
    }));

    const queryId = id();
    if (!hasSupabase()) {
      memory.queries.push({
        id: queryId,
        user_id: userId,
        scope: body.scope,
        conversation_id: body.conversation_id ?? null,
        question: body.question,
        answer: result.answer,
        citations,
        created_at: new Date().toISOString(),
      });
    } else {
      await getAdminClient().from("ai_queries").insert({
        id: queryId,
        user_id: userId,
        scope: body.scope === "person" ? "all" : body.scope,
        conversation_id: body.conversation_id ?? null,
        folder_id: body.folder_id ?? null,
        question: body.question,
        answer: result.answer,
        citations,
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
          data: JSON.stringify({ id: queryId, citations }),
        });
      });
    }

    return c.json({
      id: queryId,
      answer: result.answer,
      citations,
      model: config.fixtureMode ? "fixture" : config.askModel,
    });
  } catch (err) {
    if (err instanceof AuthError) return c.json({ error: err.message }, 401);
    if (err instanceof z.ZodError) return c.json({ error: err.flatten() }, 400);
    console.error(err);
    return c.json({ error: err instanceof Error ? err.message : "ask failed" }, 500);
  }
});
