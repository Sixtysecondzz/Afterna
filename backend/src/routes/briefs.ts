import { Hono } from "hono";
import { z } from "zod";
import { AuthError, resolveUserId } from "../lib/supabase.js";
import { buildMeetingBrief } from "../lib/retrieve.js";

export const briefRoutes = new Hono();

const bodySchema = z.object({
  title: z.string().max(200).optional(),
  attendee_names: z.array(z.string().max(120)).max(20).optional(),
});

briefRoutes.post("/v1/briefs/meeting", async (c) => {
  try {
    const userId = resolveUserId(c.req.header("authorization"));
    const body = bodySchema.parse(await c.req.json().catch(() => ({})));
    const brief = await buildMeetingBrief({
      userId,
      title: body.title,
      attendeeNames: body.attendee_names,
    });
    return c.json(brief);
  } catch (err) {
    if (err instanceof AuthError) return c.json({ error: err.message }, 401);
    if (err instanceof z.ZodError) return c.json({ error: err.flatten() }, 400);
    console.error("[briefs/meeting]", err);
    return c.json({ error: err instanceof Error ? err.message : "brief_failed" }, 500);
  }
});
