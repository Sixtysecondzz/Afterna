import { randomBytes } from "node:crypto";
import { Hono } from "hono";
import { config } from "../config.js";
import { id } from "../lib/ids.js";
import { getSegments } from "../lib/store.js";
import {
  AuthError,
  getAdminClient,
  hasSupabase,
  memory,
  resolveUserId,
} from "../lib/supabase.js";

export const shareRoutes = new Hono();

const PREVIEW_SEGMENT_LIMIT = 12;

export type SharedNoteSnapshot = {
  title: string | null;
  summary: string | null;
  key_points: string[];
  decisions: string[];
  segments_preview: Array<{
    speaker_label: string;
    text: string;
    t_start_ms: number;
  }>;
};

export type SharedNoteRow = {
  id: string;
  token: string;
  conversation_id: string;
  user_id: string;
  created_at: string;
  revoked_at: string | null;
  snapshot: SharedNoteSnapshot;
};

function newShareToken(): string {
  return randomBytes(24).toString("base64url");
}

function asStringList(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => {
      if (typeof item === "string") return item.trim();
      if (item && typeof item === "object" && "text" in item) {
        const text = (item as { text?: unknown }).text;
        return typeof text === "string" ? text.trim() : "";
      }
      return "";
    })
    .filter(Boolean);
}

function speakerFromSegment(seg: Record<string, unknown>): string {
  if (typeof seg.speaker_label === "string" && seg.speaker_label) return seg.speaker_label;
  const speakers = seg.speakers as { label?: string } | null | undefined;
  if (speakers?.label) return speakers.label;
  return "Speaker";
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function formatMs(ms: number): string {
  const s = Math.max(0, Math.floor(ms / 1000));
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
}

function shareUrl(token: string): string {
  const base = config.appBaseUrl.replace(/\/$/, "");
  return `${base}/n/${token}`;
}

async function buildSnapshot(conversationId: string, userId: string): Promise<SharedNoteSnapshot | null> {
  if (!hasSupabase()) {
    const conv = memory.conversations.get(conversationId);
    if (!conv || conv.user_id !== userId) return null;
    const summary = memory.summaries.get(conversationId) ?? null;
    const segments = (memory.segments.get(conversationId) ?? []) as Record<string, unknown>[];
    return {
      title: typeof conv.title === "string" ? conv.title : null,
      summary: summary && typeof summary.summary === "string" ? summary.summary : null,
      key_points: asStringList(summary?.key_points),
      decisions: asStringList(summary?.decisions),
      segments_preview: segments.slice(0, PREVIEW_SEGMENT_LIMIT).map((seg) => ({
        speaker_label: speakerFromSegment(seg),
        text: typeof seg.text === "string" ? seg.text : "",
        t_start_ms: typeof seg.t_start_ms === "number" ? seg.t_start_ms : 0,
      })),
    };
  }

  const sb = getAdminClient();
  const { data: conv, error } = await sb
    .from("conversations")
    .select("id, title, user_id")
    .eq("id", conversationId)
    .eq("user_id", userId)
    .maybeSingle();
  if (error) throw error;
  if (!conv) return null;

  const { data: summary } = await sb
    .from("summaries")
    .select("summary, key_points, decisions")
    .eq("conversation_id", conversationId)
    .maybeSingle();

  const segments = (await getSegments(conversationId)) as Record<string, unknown>[];
  return {
    title: typeof conv.title === "string" ? conv.title : null,
    summary: summary && typeof summary.summary === "string" ? summary.summary : null,
    key_points: asStringList(summary?.key_points),
    decisions: asStringList(summary?.decisions),
    segments_preview: segments.slice(0, PREVIEW_SEGMENT_LIMIT).map((seg) => ({
      speaker_label: speakerFromSegment(seg),
      text: typeof seg.text === "string" ? seg.text : "",
      t_start_ms: typeof seg.t_start_ms === "number" ? seg.t_start_ms : 0,
    })),
  };
}

function renderSharedNoteHtml(snapshot: SharedNoteSnapshot): string {
  const title = snapshot.title?.trim() || "Shared memory";
  const summary = snapshot.summary?.trim() || "No summary yet.";
  const keyPoints = snapshot.key_points
    .map((p) => `<li>${escapeHtml(p)}</li>`)
    .join("");
  const decisions = snapshot.decisions
    .map((p) => `<li>${escapeHtml(p)}</li>`)
    .join("");
  const segments = snapshot.segments_preview
    .map(
      (seg) => `<article class="seg">
  <div class="meta">${escapeHtml(seg.speaker_label)} · ${escapeHtml(formatMs(seg.t_start_ms))}</div>
  <p>${escapeHtml(seg.text)}</p>
</article>`,
    )
    .join("\n");

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>${escapeHtml(title)} · Afterna</title>
  <style>
    :root {
      --paper: #f5f2ed;
      --mist: #e6edea;
      --ink: #1a1f24;
      --muted: #6b7278;
      --accent: #2e7069;
      --line: rgba(26, 31, 36, 0.08);
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      min-height: 100vh;
      font-family: "Iowan Old Style", "Palatino Linotype", Palatino, Georgia, serif;
      color: var(--ink);
      background:
        radial-gradient(1200px 600px at 10% -10%, rgba(46, 112, 105, 0.12), transparent 55%),
        linear-gradient(180deg, var(--mist), var(--paper) 40%);
    }
    main {
      max-width: 40rem;
      margin: 0 auto;
      padding: 2.5rem 1.25rem 4rem;
    }
    .brand {
      font-size: 0.85rem;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      color: var(--accent);
      font-family: ui-sans-serif, system-ui, sans-serif;
      font-weight: 600;
      margin-bottom: 1.25rem;
    }
    h1 {
      font-size: clamp(1.75rem, 4vw, 2.35rem);
      font-weight: 600;
      line-height: 1.2;
      margin: 0 0 1rem;
    }
    .summary {
      font-size: 1.05rem;
      line-height: 1.65;
      margin: 0 0 1.75rem;
    }
    h2 {
      font-size: 0.95rem;
      letter-spacing: 0.04em;
      text-transform: uppercase;
      color: var(--accent);
      font-family: ui-sans-serif, system-ui, sans-serif;
      margin: 1.75rem 0 0.75rem;
    }
    ul {
      margin: 0;
      padding-left: 1.15rem;
      line-height: 1.55;
    }
    li + li { margin-top: 0.4rem; }
    .seg {
      padding: 0.85rem 0;
      border-top: 1px solid var(--line);
    }
    .seg:first-of-type { border-top: none; }
    .meta {
      font-family: ui-sans-serif, system-ui, sans-serif;
      font-size: 0.75rem;
      color: var(--accent);
      margin-bottom: 0.35rem;
    }
    .seg p {
      margin: 0;
      font-family: ui-sans-serif, system-ui, sans-serif;
      font-size: 0.95rem;
      line-height: 1.55;
    }
    footer {
      margin-top: 2.5rem;
      padding-top: 1rem;
      border-top: 1px solid var(--line);
      font-family: ui-sans-serif, system-ui, sans-serif;
      font-size: 0.8rem;
      color: var(--muted);
    }
    .empty { color: var(--muted); font-family: ui-sans-serif, system-ui, sans-serif; }
  </style>
</head>
<body>
  <main>
    <div class="brand">Afterna</div>
    <h1>${escapeHtml(title)}</h1>
    <p class="summary">${escapeHtml(summary)}</p>
    ${
      keyPoints
        ? `<h2>Key points</h2><ul>${keyPoints}</ul>`
        : ""
    }
    ${
      decisions
        ? `<h2>Decisions</h2><ul>${decisions}</ul>`
        : ""
    }
    ${
      segments
        ? `<h2>Transcript excerpt</h2>${segments}`
        : `<p class="empty">No transcript excerpt.</p>`
    }
    <footer>Shared from Afterna · Link may be revoked by the owner</footer>
  </main>
</body>
</html>`;
}

function renderNotFoundHtml(): string {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Link unavailable · Afterna</title>
  <style>
    body {
      margin: 0; min-height: 100vh; display: grid; place-items: center;
      font-family: Georgia, serif; color: #1a1f24;
      background: linear-gradient(180deg, #e6edea, #f5f2ed);
    }
    main { text-align: center; padding: 2rem; }
    .brand { color: #2e7069; letter-spacing: 0.08em; text-transform: uppercase;
      font-family: ui-sans-serif, system-ui, sans-serif; font-size: 0.85rem; font-weight: 600; }
    h1 { font-size: 1.6rem; margin: 0.75rem 0; }
    p { color: #6b7278; font-family: ui-sans-serif, system-ui, sans-serif; }
  </style>
</head>
<body>
  <main>
    <div class="brand">Afterna</div>
    <h1>This link is unavailable</h1>
    <p>It may have been revoked or never existed.</p>
  </main>
</body>
</html>`;
}

async function getActiveShareByToken(token: string): Promise<SharedNoteRow | null> {
  if (!hasSupabase()) {
    const row = memory.sharedNotes.get(token) as SharedNoteRow | undefined;
    if (!row || row.revoked_at) return null;
    return row;
  }
  const { data, error } = await getAdminClient()
    .from("shared_notes")
    .select("*")
    .eq("token", token)
    .is("revoked_at", null)
    .maybeSingle();
  if (error) throw error;
  return (data as SharedNoteRow | null) ?? null;
}

/** POST /v1/conversations/:id/share — create a tokenized share link with snapshot. */
shareRoutes.post("/v1/conversations/:id/share", async (c) => {
  try {
    const userId = resolveUserId(c.req.header("authorization"));
    const conversationId = c.req.param("id");
    const snapshot = await buildSnapshot(conversationId, userId);
    if (!snapshot) return c.json({ error: "not found" }, 404);

    const row: SharedNoteRow = {
      id: id(),
      token: newShareToken(),
      conversation_id: conversationId,
      user_id: userId,
      created_at: new Date().toISOString(),
      revoked_at: null,
      snapshot,
    };

    if (!hasSupabase()) {
      memory.sharedNotes.set(row.token, row as unknown as Record<string, unknown>);
    } else {
      const { error } = await getAdminClient().from("shared_notes").insert({
        id: row.id,
        token: row.token,
        conversation_id: row.conversation_id,
        user_id: row.user_id,
        created_at: row.created_at,
        snapshot: row.snapshot,
      });
      if (error) throw error;
    }

    return c.json({ url: shareUrl(row.token), token: row.token });
  } catch (err) {
    if (err instanceof AuthError) return c.json({ error: err.message }, 401);
    return c.json({ error: err instanceof Error ? err.message : "error" }, 500);
  }
});

/** GET /n/:token — public HTML (or JSON with Accept: application/json). */
shareRoutes.get("/n/:token", async (c) => {
  try {
    const token = c.req.param("token");
    const accept = c.req.header("accept") ?? "";
    const wantsJson = accept.includes("application/json") && !accept.includes("text/html");
    const row = await getActiveShareByToken(token);
    if (!row) {
      if (wantsJson) return c.json({ error: "not found" }, 404);
      return c.html(renderNotFoundHtml(), 404);
    }

    if (wantsJson) {
      return c.json({
        token: row.token,
        created_at: row.created_at,
        snapshot: row.snapshot,
      });
    }

    return c.html(renderSharedNoteHtml(row.snapshot));
  } catch (err) {
    return c.json({ error: err instanceof Error ? err.message : "error" }, 500);
  }
});

/** DELETE /v1/share/:token — revoke a share link. */
shareRoutes.delete("/v1/share/:token", async (c) => {
  try {
    const userId = resolveUserId(c.req.header("authorization"));
    const token = c.req.param("token");
    const revokedAt = new Date().toISOString();

    if (!hasSupabase()) {
      const row = memory.sharedNotes.get(token);
      if (!row || row.user_id !== userId) return c.json({ error: "not found" }, 404);
      memory.sharedNotes.set(token, { ...row, revoked_at: revokedAt });
      return c.json({ ok: true, token, revoked_at: revokedAt });
    }

    const { data, error } = await getAdminClient()
      .from("shared_notes")
      .update({ revoked_at: revokedAt })
      .eq("token", token)
      .eq("user_id", userId)
      .is("revoked_at", null)
      .select("token")
      .maybeSingle();
    if (error) throw error;
    if (!data) return c.json({ error: "not found" }, 404);
    return c.json({ ok: true, token, revoked_at: revokedAt });
  } catch (err) {
    if (err instanceof AuthError) return c.json({ error: err.message }, 401);
    return c.json({ error: err instanceof Error ? err.message : "error" }, 500);
  }
});
