import { config } from "../config.js";
import { fixtureTranscript } from "../fixtures/canonical.js";
import {
  addTranscriptionUsage,
  enqueueJob,
  getConversationByRecording,
  getRecording,
  getSegments,
  persistTranscript,
  setConversationStatus,
  setRecordingStatus,
  updateJob,
} from "../lib/store.js";
import { getAdminClient, hasSupabase, memory } from "../lib/supabase.js";
import { id } from "../lib/ids.js";
import {
  fetchAssemblyAiTranscript,
  normalizeAssemblyAi,
  submitAssemblyAiTranscription,
} from "../providers/assemblyai.js";
import { transcribeWithOpenAI } from "../providers/openaiStt.js";
import { embedTexts, extractFromTranscript } from "../providers/openaiLlm.js";
import type { AiJobRow, CanonicalTranscript } from "../types.js";

async function loadAudioBuffer(storagePath: string | null | undefined): Promise<Buffer | null> {
  if (!storagePath) return null;
  if (!hasSupabase()) {
    return memory.audioBlobs.get(storagePath) ?? Buffer.from("fixture-audio");
  }
  const { data, error } = await getAdminClient().storage.from("audio-inbox").download(storagePath);
  if (error) throw error;
  return Buffer.from(await data.arrayBuffer());
}

async function signedAudioUrl(storagePath: string): Promise<string> {
  if (!hasSupabase()) {
    return `${config.appBaseUrl}/v1/uploads/local/${encodeURIComponent(storagePath)}`;
  }
  const { data, error } = await getAdminClient().storage
    .from("audio-inbox")
    .createSignedUrl(storagePath, 60 * 60);
  if (error) throw error;
  return data.signedUrl;
}

async function runTranscribe(job: AiJobRow): Promise<void> {
  const recordingId = job.recording_id;
  if (!recordingId) throw new Error("transcribe job missing recording_id");
  const recording = await getRecording(recordingId);
  if (!recording) throw new Error("recording not found");
  const conversation = await getConversationByRecording(recordingId);
  if (!conversation) throw new Error("conversation not found");

  await setRecordingStatus(recordingId, "processing");

  let transcript: CanonicalTranscript;

  if (config.fixtureMode || !config.assemblyAiApiKey) {
    transcript = fixtureTranscript(recordingId);
    await updateJob(job.id, { provider: "fixture", model: "fixture-v1" });
  } else {
    try {
      const audioUrl = await signedAudioUrl(String(recording.storage_path));
      const webhookUrl = `${config.appBaseUrl}/webhooks/transcription/assemblyai`;
      const { providerJobId } = await submitAssemblyAiTranscription({
        audioUrl,
        webhookUrl: config.appBaseUrl.includes("localhost") ? undefined : webhookUrl,
      });
      await updateJob(job.id, {
        provider: "assemblyai",
        model: "universal-3-5-pro",
        payload: { ...job.payload, provider_job_id: providerJobId },
      });

      // Poll when webhook not available (local) or until completed
      let raw = await fetchAssemblyAiTranscript(providerJobId);
      for (let i = 0; i < 120 && (raw.status === "queued" || raw.status === "processing"); i++) {
        await new Promise((r) => setTimeout(r, 3000));
        raw = await fetchAssemblyAiTranscript(providerJobId);
      }
      if (raw.status !== "completed") {
        throw new Error(raw.error ?? `AssemblyAI status ${raw.status}`);
      }
      transcript = normalizeAssemblyAi(recordingId, raw);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      if (!config.openAiApiKey) throw err;
      const audio = await loadAudioBuffer(recording.storage_path as string);
      if (!audio) throw err;
      transcript = await transcribeWithOpenAI({ recordingId, audio, multiSpeaker: true });
      await updateJob(job.id, {
        provider: "openai",
        model: transcript.model,
        error: `assemblyai_failover: ${message}`,
      });
    }
  }

  await persistTranscript(job.user_id, String(conversation.id), transcript);
  await setRecordingStatus(recordingId, "succeeded");
  await addTranscriptionUsage(job.user_id, transcript.durationMs || Number(recording.duration_ms ?? 0));

  const keepAudio = Boolean(recording.keep_audio);
  if (!keepAudio) {
    await enqueueJob({
      userId: job.user_id,
      jobType: "purge_audio",
      idempotencyKey: `purge:${recordingId}`,
      recordingId,
      conversationId: String(conversation.id),
    });
  }

  await enqueueJob({
    userId: job.user_id,
    jobType: "extract",
    idempotencyKey: `extract:${conversation.id}:${config.promptVersion}`,
    recordingId,
    conversationId: String(conversation.id),
  });
  await enqueueJob({
    userId: job.user_id,
    jobType: "embed",
    idempotencyKey: `embed:${conversation.id}:${config.embedModel}`,
    recordingId,
    conversationId: String(conversation.id),
  });
}

async function runExtract(job: AiJobRow): Promise<void> {
  const conversationId = job.conversation_id;
  if (!conversationId) throw new Error("extract job missing conversation_id");
  const segments = await getSegments(conversationId);
  const transcriptText = segments.map((s) => String(s.text ?? "")).join("\n");
  const segmentContext = segments
    .map((s) => `${s.id}|${s.t_start_ms}-${s.t_end_ms}|${s.text}`)
    .join("\n");
  const payload = (job.payload ?? {}) as Record<string, unknown>;
  const userNotes = typeof payload.user_notes === "string" ? payload.user_notes : null;
  const template = typeof payload.template === "string" ? payload.template : null;
  const extracted = await extractFromTranscript(transcriptText, segmentContext, {
    userNotes,
    template,
  });

  if (!hasSupabase()) {
    memory.summaries.set(conversationId, {
      id: id(),
      conversation_id: conversationId,
      user_id: job.user_id,
      prompt_version: config.promptVersion,
      summary: extracted.summary,
      key_points: extracted.key_points,
      decisions: extracted.decisions,
      deadlines: extracted.deadlines,
      model: config.fixtureMode ? "fixture" : config.extractModel,
    });
    memory.actionItems.set(
      conversationId,
      extracted.action_items.map((a) => ({
        id: id(),
        conversation_id: conversationId,
        user_id: job.user_id,
        text: a.text,
        assignee_text: a.assignee,
        due_date: a.due_date,
        confidence: a.confidence,
        status: "open",
        t_start_ms: a.t_start_ms,
        t_end_ms: a.t_end_ms,
      })),
    );
    memory.entities.set(
      conversationId,
      extracted.entities.map((e) => ({
        id: id(),
        user_id: job.user_id,
        type: e.type,
        canonical_name: e.name,
        aliases: e.aliases,
        mentions: e.mentions,
      })),
    );
    await setConversationStatus(conversationId, "ready");
    return;
  }

  const sb = getAdminClient();
  await sb.from("summaries").upsert(
    {
      conversation_id: conversationId,
      user_id: job.user_id,
      prompt_version: config.promptVersion,
      summary: extracted.summary,
      key_points: extracted.key_points,
      decisions: extracted.decisions,
      deadlines: extracted.deadlines,
      model: config.extractModel,
    },
    { onConflict: "conversation_id,prompt_version" },
  );
  for (const a of extracted.action_items) {
    await sb.from("action_items").insert({
      conversation_id: conversationId,
      user_id: job.user_id,
      text: a.text,
      assignee_text: a.assignee,
      due_date: a.due_date,
      confidence: a.confidence,
      t_start_ms: a.t_start_ms,
      t_end_ms: a.t_end_ms,
    });
  }
}

async function runEmbed(job: AiJobRow): Promise<void> {
  const conversationId = job.conversation_id;
  if (!conversationId) throw new Error("embed job missing conversation_id");
  const segments = await getSegments(conversationId);
  if (segments.length === 0) return;

  const chunkSize = 4;
  const chunks: Array<{ text: string; t_start_ms: number; t_end_ms: number; idx: number }> = [];
  for (let i = 0; i < segments.length; i += chunkSize) {
    const slice = segments.slice(i, i + chunkSize);
    chunks.push({
      idx: chunks.length,
      text: slice.map((s) => String(s.text)).join(" "),
      t_start_ms: Number(slice[0]?.t_start_ms ?? 0),
      t_end_ms: Number(slice[slice.length - 1]?.t_end_ms ?? 0),
    });
  }
  const vectors = await embedTexts(chunks.map((c) => c.text));

  if (!hasSupabase()) {
    memory.embeddings.set(
      conversationId,
      chunks.map((c, i) => ({
        id: id(),
        conversation_id: conversationId,
        user_id: job.user_id,
        chunk_idx: c.idx,
        t_start_ms: c.t_start_ms,
        t_end_ms: c.t_end_ms,
        text: c.text,
        embedding: vectors[i],
        embedding_model: config.embedModel,
      })),
    );
    await setConversationStatus(conversationId, "ready", { has_embeddings: true });
    return;
  }

  const sb = getAdminClient();
  for (let i = 0; i < chunks.length; i++) {
    await sb.from("embedding_chunks").upsert(
      {
        conversation_id: conversationId,
        user_id: job.user_id,
        chunk_idx: chunks[i].idx,
        t_start_ms: chunks[i].t_start_ms,
        t_end_ms: chunks[i].t_end_ms,
        text: chunks[i].text,
        embedding: vectors[i],
        embedding_model: config.embedModel,
      },
      { onConflict: "conversation_id,embedding_model,chunk_idx" },
    );
  }
}

async function runPurge(job: AiJobRow): Promise<void> {
  const recordingId = job.recording_id;
  if (!recordingId) return;
  const recording = await getRecording(recordingId);
  if (!recording?.storage_path) return;
  if (!hasSupabase()) {
    memory.audioBlobs.delete(String(recording.storage_path));
    await setRecordingStatus(recordingId, String(recording.transcription_status ?? "succeeded"), {
      storage_path: null,
      audio_deleted_at: new Date().toISOString(),
    });
    return;
  }
  await getAdminClient().storage.from("audio-inbox").remove([String(recording.storage_path)]);
  await setRecordingStatus(recordingId, String(recording.transcription_status ?? "succeeded"), {
    storage_path: null,
    audio_deleted_at: new Date().toISOString(),
  });
}

export async function processJob(job: AiJobRow): Promise<void> {
  try {
    switch (job.job_type) {
      case "transcribe":
        await runTranscribe(job);
        break;
      case "extract":
        await runExtract(job);
        break;
      case "embed":
        await runEmbed(job);
        break;
      case "purge_audio":
        await runPurge(job);
        break;
      case "reindex":
        await runEmbed(job);
        break;
      default:
        throw new Error(`Unknown job type ${job.job_type}`);
    }
    await updateJob(job.id, {
      status: "succeeded",
      finished_at: new Date().toISOString(),
      error: null,
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    const dead = job.attempts >= 5;
    await updateJob(job.id, {
      status: dead ? "dead" : "failed",
      finished_at: new Date().toISOString(),
      error: message,
    });
    if (job.recording_id && job.job_type === "transcribe") {
      await setRecordingStatus(job.recording_id, "failed");
      if (job.conversation_id) await setConversationStatus(job.conversation_id, "failed");
    }
    throw err;
  }
}

export async function processAvailableJobs(limit = 5): Promise<number> {
  const { claimQueuedJobs } = await import("../lib/store.js");
  const jobs = await claimQueuedJobs(limit);
  for (const job of jobs) {
    try {
      await processJob(job);
    } catch (err) {
      console.error(`[worker] job ${job.id} failed`, err);
    }
  }
  return jobs.length;
}
