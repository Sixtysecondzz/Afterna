import { Hono } from "hono";
import { z } from "zod";
import {
  checkTranscriptionQuota,
  createRecording,
  createSignedUploadUrl,
  enqueueJob,
  getConversationByRecording,
  getRecording,
  setRecordingStatus,
} from "../lib/store.js";
import { AuthError, memory, resolveUserId } from "../lib/supabase.js";

export const uploadRoutes = new Hono();

const presignSchema = z.object({
  duration_ms: z.number().int().nonnegative().optional(),
  mime_type: z.string().default("audio/mp4"),
  byte_size: z.number().int().nonnegative().optional(),
  checksum_sha256: z.string().regex(/^[a-f0-9]{64}$/i).optional(),
  keep_audio: z.boolean().optional(),
  language_hint: z.string().optional(),
  require_diarization: z.boolean().default(true),
});

uploadRoutes.post("/v1/uploads/presign", async (c) => {
  try {
    const userId = resolveUserId(c.req.header("authorization"));
    const body = presignSchema.parse(await c.req.json());
    const created = await createRecording({
      userId,
      durationMs: body.duration_ms,
      mimeType: body.mime_type,
      byteSize: body.byte_size,
      checksumHex: body.checksum_sha256,
      keepAudio: body.keep_audio,
    });
    const signed = await createSignedUploadUrl(created.storagePath);
    return c.json({
      recording_id: created.recordingId,
      conversation_id: created.conversationId,
      storage_path: created.storagePath,
      upload_url: signed.uploadUrl,
      upload_token: signed.token ?? null,
      upload_mode: signed.mode,
      headers: { "Content-Type": body.mime_type },
    });
  } catch (err) {
    if (err instanceof AuthError) return c.json({ error: err.message }, 401);
    if (err instanceof z.ZodError) return c.json({ error: err.flatten() }, 400);
    console.error(err);
    return c.json({ error: err instanceof Error ? err.message : "presign failed" }, 500);
  }
});

const completeSchema = z.object({
  recording_id: z.string().uuid(),
  checksum_sha256: z.string().regex(/^[a-f0-9]{64}$/i).optional(),
  byte_size: z.number().int().nonnegative().optional(),
  duration_ms: z.number().int().nonnegative().optional(),
});

uploadRoutes.post("/v1/uploads/complete", async (c) => {
  try {
    const userId = resolveUserId(c.req.header("authorization"));
    const body = completeSchema.parse(await c.req.json());
    const recording = await getRecording(body.recording_id);
    if (!recording || recording.user_id !== userId) {
      return c.json({ error: "recording not found" }, 404);
    }

    const durationMs = body.duration_ms ?? Number(recording.duration_ms ?? 0);
    const quota = await checkTranscriptionQuota(userId, durationMs);
    if (!quota.ok) return c.json({ error: quota.reason }, 402);

    const conversation = await getConversationByRecording(body.recording_id);
    if (!conversation) return c.json({ error: "conversation not found" }, 404);

    const checksum = body.checksum_sha256 ?? String(recording.checksum_hex ?? "none");
    const idempotencyKey = `transcribe:${body.recording_id}:${checksum}:diarize`;

    await setRecordingStatus(body.recording_id, "processing", {
      byte_size: body.byte_size ?? recording.byte_size,
      duration_ms: durationMs || recording.duration_ms,
    });

    const job = await enqueueJob({
      userId,
      jobType: "transcribe",
      idempotencyKey,
      recordingId: body.recording_id,
      conversationId: String(conversation.id),
      payload: { checksum, auto: true },
      provider: "assemblyai",
    });

    return c.json({
      recording_id: body.recording_id,
      conversation_id: conversation.id,
      job_id: job.id,
      job_status: job.status,
      transcription_status: "processing",
      message: "Upload complete — transcription enqueued automatically",
    });
  } catch (err) {
    if (err instanceof AuthError) return c.json({ error: err.message }, 401);
    if (err instanceof z.ZodError) return c.json({ error: err.flatten() }, 400);
    console.error(err);
    return c.json({ error: err instanceof Error ? err.message : "complete failed" }, 500);
  }
});

/** Local fixture upload sink when Supabase Storage is not configured. */
uploadRoutes.put("/v1/uploads/local/:path{.+}", async (c) => {
  const storagePath = decodeURIComponent(c.req.param("path"));
  const ab = await c.req.arrayBuffer();
  memory.audioBlobs.set(storagePath, Buffer.from(ab));
  return c.json({ ok: true, storage_path: storagePath, bytes: ab.byteLength });
});

uploadRoutes.get("/v1/uploads/local/:path{.+}", async (c) => {
  const storagePath = decodeURIComponent(c.req.param("path"));
  const buf = memory.audioBlobs.get(storagePath);
  if (!buf) return c.json({ error: "not found" }, 404);
  return new Response(buf, {
    headers: { "Content-Type": "audio/mp4" },
  });
});
