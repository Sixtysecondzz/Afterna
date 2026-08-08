import { Hono } from "hono";
import { z } from "zod";
import { config } from "../config.js";
import { AuthError, resolveUserId } from "../lib/supabase.js";
import { id } from "../lib/ids.js";
import {
  addTranscriptionUsage,
  createRecording,
  enqueueJob,
  persistTranscript,
  setRecordingStatus,
} from "../lib/store.js";
import type { CanonicalTranscript } from "../types.js";

export const archiveRoutes = new Hono();

const segmentSchema = z.object({
  speaker_label: z.string().default("A"),
  text: z.string().min(1),
  start_ms: z.number().int().nonnegative().default(0),
  end_ms: z.number().int().nonnegative().default(0),
  confidence: z.number().nullable().optional(),
});

const bodySchema = z.object({
  client_session_id: z.string().min(1),
  duration_ms: z.number().int().nonnegative().default(0),
  title: z.string().optional(),
  language: z.string().optional(),
  segments: z.array(segmentSchema).min(1),
});

/**
 * Archive a live-streamed transcript (no AssemblyAI async pass).
 * Persists segments and enqueues OpenAI extract + embed for key points.
 */
archiveRoutes.post("/v1/conversations/archive", async (c) => {
  try {
    const userId = resolveUserId(c.req.header("authorization"));
    const parsed = bodySchema.safeParse(await c.req.json());
    if (!parsed.success) {
      return c.json({ error: "invalid_body", details: parsed.error.flatten() }, 400);
    }
    const body = parsed.data;

    const { recordingId, conversationId } = await createRecording({
      userId,
      durationMs: body.duration_ms,
      mimeType: "audio/pcm",
      keepAudio: false,
    });

    const segments = body.segments.map((s) => ({
      id: id(),
      speakerLabel: s.speaker_label || "A",
      text: s.text.trim(),
      startMs: s.start_ms,
      endMs: Math.max(s.end_ms, s.start_ms),
      confidence: s.confidence ?? null,
    }));

    const fullText = segments.map((s) => s.text).join(" ");
    const transcript: CanonicalTranscript = {
      recordingId,
      provider: "assemblyai-streaming",
      model: "universal-3-5-pro",
      language: body.language ?? "en",
      fullText,
      segments,
      words: [],
      durationMs: body.duration_ms,
      createdAt: new Date().toISOString(),
      rawArtifactURI: null,
    };

    await persistTranscript(userId, conversationId, transcript);
    await setRecordingStatus(recordingId, "succeeded", {
      provider: "assemblyai-streaming",
      model: "universal-3-5-pro",
      client_session_id: body.client_session_id,
    });
    await addTranscriptionUsage(userId, body.duration_ms);

    const extractJob = await enqueueJob({
      userId,
      jobType: "extract",
      idempotencyKey: `extract:${conversationId}:${config.promptVersion}`,
      recordingId,
      conversationId,
    });
    await enqueueJob({
      userId,
      jobType: "embed",
      idempotencyKey: `embed:${conversationId}:${config.embedModel}`,
      recordingId,
      conversationId,
    });

    return c.json({
      recording_id: recordingId,
      conversation_id: conversationId,
      extract_job_id: extractJob.id,
      status: "ready",
      title: body.title ?? fullText.slice(0, 80),
      message: "Archived live transcript; extract queued for key points",
    });
  } catch (err) {
    if (err instanceof AuthError) return c.json({ error: err.message }, 401);
    console.error("[conversations/archive]", err);
    return c.json({ error: err instanceof Error ? err.message : "archive_failed" }, 500);
  }
});
