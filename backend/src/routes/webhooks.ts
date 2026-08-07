import { Hono } from "hono";
import { config } from "../config.js";
import { fetchAssemblyAiTranscript, normalizeAssemblyAi } from "../providers/assemblyai.js";
import {
  addTranscriptionUsage,
  enqueueJob,
  getConversationByRecording,
  getJobByIdempotency,
  persistTranscript,
  setRecordingStatus,
  updateJob,
} from "../lib/store.js";
import { memory } from "../lib/supabase.js";

export const webhookRoutes = new Hono();

webhookRoutes.post("/webhooks/transcription/assemblyai", async (c) => {
  const secret = c.req.header(config.webhookAuthHeaderName.toLowerCase()) ?? c.req.header(config.webhookAuthHeaderName);
  if (secret !== config.webhookAuthSecret) {
    return c.json({ error: "unauthorized" }, 401);
  }

  const body = (await c.req.json()) as { transcript_id?: string; status?: string };
  // Return 2xx quickly; finish work async (or inline if small).
  if (!body.transcript_id) return c.json({ ok: false }, 400);

  // Find job by provider_job_id in payload
  let jobId: string | null = null;
  let recordingId: string | null = null;
  for (const j of memory.jobs.values()) {
    const payload = j.payload as Record<string, unknown> | undefined;
    if (payload?.provider_job_id === body.transcript_id) {
      jobId = String(j.id);
      recordingId = j.recording_id ? String(j.recording_id) : null;
      break;
    }
  }

  // Best-effort lookup via idempotent scan is memory-only; with Supabase, store provider_job_id indexed later.
  void getJobByIdempotency;

  try {
    const raw = await fetchAssemblyAiTranscript(body.transcript_id);
    if (raw.status !== "completed") {
      return c.json({ ok: true, ignored: true, status: raw.status });
    }
    if (!recordingId) {
      // Persist raw for debugging when mapping missing
      return c.json({ ok: true, warning: "recording mapping not found" });
    }
    const conversation = await getConversationByRecording(recordingId);
    if (!conversation) return c.json({ ok: true, warning: "conversation missing" });

    const transcript = normalizeAssemblyAi(recordingId, raw);
    await persistTranscript(String(conversation.user_id), String(conversation.id), transcript);
    await setRecordingStatus(recordingId, "succeeded");
    await addTranscriptionUsage(String(conversation.user_id), transcript.durationMs);
    if (jobId) {
      await updateJob(jobId, {
        status: "succeeded",
        finished_at: new Date().toISOString(),
        provider: "assemblyai",
        model: transcript.model,
      });
    }
    await enqueueJob({
      userId: String(conversation.user_id),
      jobType: "extract",
      idempotencyKey: `extract:${conversation.id}:${config.promptVersion}`,
      recordingId,
      conversationId: String(conversation.id),
    });
    await enqueueJob({
      userId: String(conversation.user_id),
      jobType: "embed",
      idempotencyKey: `embed:${conversation.id}:${config.embedModel}`,
      recordingId,
      conversationId: String(conversation.id),
    });
    return c.json({ ok: true });
  } catch (err) {
    console.error("[webhook] assemblyai", err);
    // Still 200 to avoid endless retries on permanent mapping issues; log for ops.
    return c.json({ ok: false, error: err instanceof Error ? err.message : "error" }, 200);
  }
});
