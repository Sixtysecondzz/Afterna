import { Hono } from "hono";
import { z } from "zod";
import { AuthError, getAdminClient, hasSupabase, memory, resolveUserId } from "../lib/supabase.js";
import { id } from "../lib/ids.js";

export const peopleRoutes = new Hono();

peopleRoutes.get("/v1/people", async (c) => {
  try {
    const userId = resolveUserId(c.req.header("authorization"));
    if (!hasSupabase()) {
      const byName = new Map<string, { id: string; name: string; type: string; mention_count: number }>();
      for (const ents of memory.entities.values()) {
        for (const e of ents) {
          if (String(e.type) !== "person") continue;
          const name = String(e.canonical_name ?? "").trim();
          if (!name) continue;
          const key = name.toLowerCase();
          const prev = byName.get(key);
          byName.set(key, {
            id: String(e.id ?? id()),
            name,
            type: "person",
            mention_count: (prev?.mention_count ?? 0) + 1,
          });
        }
      }
      return c.json({
        people: [...byName.values()].sort((a, b) => b.mention_count - a.mention_count),
      });
    }

    const sb = getAdminClient();
    const { data, error } = await sb
      .from("entities")
      .select("id, canonical_name, type, mention_count, updated_at")
      .eq("user_id", userId)
      .eq("type", "person")
      .order("mention_count", { ascending: false })
      .limit(100);
    if (error) throw error;
    return c.json({
      people: (data ?? []).map((p) => ({
        id: p.id,
        name: p.canonical_name,
        type: p.type,
        mention_count: p.mention_count,
        updated_at: p.updated_at,
      })),
    });
  } catch (err) {
    if (err instanceof AuthError) return c.json({ error: err.message }, 401);
    console.error("[people]", err);
    return c.json({ error: err instanceof Error ? err.message : "error" }, 500);
  }
});

peopleRoutes.get("/v1/people/:id", async (c) => {
  try {
    const userId = resolveUserId(c.req.header("authorization"));
    const entityId = c.req.param("id");

    if (!hasSupabase()) {
      for (const [conversationId, ents] of memory.entities.entries()) {
        const match = ents.find((e) => String(e.id) === entityId);
        if (!match) continue;
        const todos = (memory.actionItems.get(conversationId) ?? [])
          .filter((a) => a.status === "open")
          .map((a) => String(a.text));
        return c.json({
          id: entityId,
          name: match.canonical_name,
          type: match.type,
          open_todos: todos,
          related_conversation_ids: [conversationId],
        });
      }
      return c.json({ error: "not found" }, 404);
    }

    const sb = getAdminClient();
    const { data: entity, error } = await sb
      .from("entities")
      .select("*")
      .eq("id", entityId)
      .eq("user_id", userId)
      .maybeSingle();
    if (error) throw error;
    if (!entity) return c.json({ error: "not found" }, 404);

    const { data: mentions } = await sb
      .from("entity_mentions")
      .select("conversation_id")
      .eq("entity_id", entityId)
      .eq("user_id", userId)
      .limit(40);
    const convIds = [...new Set((mentions ?? []).map((m) => m.conversation_id as string))];

    let openTodos: string[] = [];
    if (convIds.length > 0) {
      const { data: actions } = await sb
        .from("action_items")
        .select("text")
        .eq("user_id", userId)
        .eq("status", "open")
        .in("conversation_id", convIds)
        .limit(20);
      openTodos = (actions ?? []).map((a) => String(a.text));
    }

    return c.json({
      id: entity.id,
      name: entity.canonical_name,
      type: entity.type,
      mention_count: entity.mention_count,
      open_todos: openTodos,
      related_conversation_ids: convIds,
    });
  } catch (err) {
    if (err instanceof AuthError) return c.json({ error: err.message }, 401);
    return c.json({ error: err instanceof Error ? err.message : "error" }, 500);
  }
});

const renameSchema = z.object({
  conversation_id: z.string().uuid(),
  from_label: z.string().min(1).max(40),
  to_name: z.string().min(1).max(120),
});

/** Rename a speaker label in a conversation and link/create a person entity. */
peopleRoutes.post("/v1/speakers/rename", async (c) => {
  try {
    const userId = resolveUserId(c.req.header("authorization"));
    const body = renameSchema.parse(await c.req.json());
    const toName = body.to_name.trim();

    if (!hasSupabase()) {
      const segments = memory.segments.get(body.conversation_id) ?? [];
      for (const s of segments) {
        if (String(s.speaker_label) === body.from_label) {
          s.speaker_label = toName;
        }
      }
      const ents = memory.entities.get(body.conversation_id) ?? [];
      ents.push({
        id: id(),
        user_id: userId,
        type: "person",
        canonical_name: toName,
        aliases: [body.from_label],
        mentions: [],
      });
      memory.entities.set(body.conversation_id, ents);
      return c.json({ ok: true, name: toName });
    }

    const sb = getAdminClient();
    const { data: entity, error: upsertErr } = await sb
      .from("entities")
      .upsert(
        {
          user_id: userId,
          type: "person",
          canonical_name: toName,
          mention_count: 1,
          updated_at: new Date().toISOString(),
        },
        { onConflict: "user_id,type,canonical_name" },
      )
      .select("*")
      .single();
    if (upsertErr) throw upsertErr;

    await sb.from("entity_aliases").upsert(
      { user_id: userId, entity_id: entity.id, alias: body.from_label },
      { onConflict: "user_id,alias" },
    );

    const { data: speakers } = await sb
      .from("speakers")
      .select("id")
      .eq("conversation_id", body.conversation_id)
      .eq("user_id", userId)
      .eq("label", body.from_label);

    for (const sp of speakers ?? []) {
      await sb.from("speakers").update({ label: toName, entity_id: entity.id }).eq("id", sp.id);
    }

    // Also update any local-facing label stored only on joined reads — speakers.label is canonical.
    return c.json({ ok: true, name: toName, entity_id: entity.id });
  } catch (err) {
    if (err instanceof AuthError) return c.json({ error: err.message }, 401);
    if (err instanceof z.ZodError) return c.json({ error: err.flatten() }, 400);
    console.error("[speakers/rename]", err);
    return c.json({ error: err instanceof Error ? err.message : "rename_failed" }, 500);
  }
});
