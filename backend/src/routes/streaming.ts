import { Hono } from "hono";
import { AuthError, resolveUserId } from "../lib/supabase.js";
import { createStreamingTemporaryToken } from "../providers/assemblyaiStreaming.js";

export const streamingRoutes = new Hono();

streamingRoutes.post("/v1/streaming/token", async (c) => {
  try {
    resolveUserId(c.req.header("authorization"));
    const body = (await c.req.json().catch(() => ({}))) as {
      expires_in_seconds?: number;
      max_session_duration_seconds?: number;
    };
    const result = await createStreamingTemporaryToken({
      expiresInSeconds: body.expires_in_seconds,
      maxSessionDurationSeconds: body.max_session_duration_seconds,
    });
    return c.json({
      token: result.token,
      expires_in_seconds: result.expiresInSeconds,
      max_session_duration_seconds: result.maxSessionDurationSeconds,
      ws_url: result.wsUrl,
      params: result.params,
      fixture: result.fixture,
    });
  } catch (err) {
    if (err instanceof AuthError) return c.json({ error: err.message }, 401);
    console.error("[streaming/token]", err);
    return c.json({ error: err instanceof Error ? err.message : "token_failed" }, 500);
  }
});
