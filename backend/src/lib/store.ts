import { config } from "../config.js";
import { id, yearMonth } from "./ids.js";
import { getAdminClient, hasSupabase, memory } from "./supabase.js";
import type { AiJobRow, CanonicalTranscript, JobType } from "../types.js";

export async function createRecording(input: {
  userId: string;
  durationMs?: number;
  mimeType?: string;
  byteSize?: number;
  checksumHex?: string;
  keepAudio?: boolean;
}): Promise<{ recordingId: string; conversationId: string; storagePath: string }> {
  const recordingId = id();
  const conversationId = id();
  const storagePath = `${input.userId}/${recordingId}.m4a`;

  if (!hasSupabase()) {
    memory.recordings.set(recordingId, {
      id: recordingId,
      user_id: input.userId,
      storage_path: storagePath,
      duration_ms: input.durationMs ?? null,
      mime_type: input.mimeType ?? "audio/mp4",
      byte_size: input.byteSize ?? null,
      checksum_hex: input.checksumHex ?? null,
      keep_audio: input.keepAudio ?? false,
      transcription_status: "pending",
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    });
    memory.conversations.set(conversationId, {
      id: conversationId,
      user_id: input.userId,
      recording_id: recordingId,
      title: null,
      status: "processing",
      source: "recording",
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
      has_embeddings: false,
    });
    return { recordingId, conversationId, storagePath };
  }

  const sb = getAdminClient();
  const { error: rErr } = await sb.from("recordings").insert({
    id: recordingId,
    user_id: input.userId,
    storage_path: storagePath,
    duration_ms: input.durationMs ?? null,
    mime_type: input.mimeType ?? "audio/mp4",
    byte_size: input.byteSize ?? null,
    checksum: input.checksumHex ? Buffer.from(input.checksumHex, "hex") : null,
    keep_audio: input.keepAudio ?? false,
    transcription_status: "pending",
  });
  if (rErr) throw rErr;

  const { error: cErr } = await sb.from("conversations").insert({
    id: conversationId,
    user_id: input.userId,
    recording_id: recordingId,
    status: "processing",
    source: "recording",
  });
  if (cErr) throw cErr;

  return { recordingId, conversationId, storagePath };
}

export async function getRecording(recordingId: string) {
  if (!hasSupabase()) return memory.recordings.get(recordingId) ?? null;
  const { data, error } = await getAdminClient().from("recordings").select("*").eq("id", recordingId).maybeSingle();
  if (error) throw error;
  return data;
}

export async function getConversationByRecording(recordingId: string) {
  if (!hasSupabase()) {
    for (const c of memory.conversations.values()) {
      if (c.recording_id === recordingId) return c;
    }
    return null;
  }
  const { data, error } = await getAdminClient()
    .from("conversations")
    .select("*")
    .eq("recording_id", recordingId)
    .maybeSingle();
  if (error) throw error;
  return data;
}

export async function createSignedUploadUrl(storagePath: string): Promise<{
  uploadUrl: string;
  token?: string;
  mode: "supabase" | "local";
}> {
  if (!hasSupabase()) {
    const encoded = storagePath.split("/").map(encodeURIComponent).join("/");
    return {
      uploadUrl: `${config.appBaseUrl}/v1/uploads/local/${encoded}`,
      mode: "local",
    };
  }
  const sb = getAdminClient();
  const { data, error } = await sb.storage.from("audio-inbox").createSignedUploadUrl(storagePath);
  if (error) throw error;
  return { uploadUrl: data.signedUrl, token: data.token, mode: "supabase" };
}

export async function enqueueJob(input: {
  userId: string;
  jobType: JobType;
  idempotencyKey: string;
  recordingId?: string | null;
  conversationId?: string | null;
  payload?: Record<string, unknown>;
  provider?: string | null;
}): Promise<AiJobRow> {
  const existing = await getJobByIdempotency(input.idempotencyKey);
  if (existing) return existing;

  const job: AiJobRow = {
    id: id(),
    user_id: input.userId,
    job_type: input.jobType,
    status: "queued",
    recording_id: input.recordingId ?? null,
    conversation_id: input.conversationId ?? null,
    idempotency_key: input.idempotencyKey,
    attempts: 0,
    provider: input.provider ?? null,
    model: null,
    error: null,
    payload: input.payload ?? {},
    created_at: new Date().toISOString(),
    started_at: null,
    finished_at: null,
  };

  if (!hasSupabase()) {
    memory.jobs.set(job.id, job as unknown as Record<string, unknown>);
    return job;
  }

  const { data, error } = await getAdminClient()
    .from("ai_jobs")
    .insert({
      id: job.id,
      user_id: job.user_id,
      job_type: job.job_type,
      status: job.status,
      recording_id: job.recording_id,
      conversation_id: job.conversation_id,
      idempotency_key: job.idempotency_key,
      payload: job.payload,
      provider: job.provider,
    })
    .select("*")
    .single();
  if (error) throw error;
  return data as AiJobRow;
}

export async function getJob(jobId: string): Promise<AiJobRow | null> {
  if (!hasSupabase()) return (memory.jobs.get(jobId) as AiJobRow | undefined) ?? null;
  const { data, error } = await getAdminClient().from("ai_jobs").select("*").eq("id", jobId).maybeSingle();
  if (error) throw error;
  return data as AiJobRow | null;
}

export async function getJobByIdempotency(key: string): Promise<AiJobRow | null> {
  if (!hasSupabase()) {
    for (const j of memory.jobs.values()) {
      if (j.idempotency_key === key) return j as unknown as AiJobRow;
    }
    return null;
  }
  const { data, error } = await getAdminClient().from("ai_jobs").select("*").eq("idempotency_key", key).maybeSingle();
  if (error) throw error;
  return data as AiJobRow | null;
}

export async function claimQueuedJobs(limit = 5): Promise<AiJobRow[]> {
  if (!hasSupabase()) {
    const queued = [...memory.jobs.values()]
      .filter((j) => j.status === "queued")
      .slice(0, limit) as unknown as AiJobRow[];
    for (const j of queued) {
      j.status = "running";
      j.started_at = new Date().toISOString();
      j.attempts += 1;
      memory.jobs.set(j.id, j as unknown as Record<string, unknown>);
    }
    return queued;
  }

  const sb = getAdminClient();
  const { data, error } = await sb
    .from("ai_jobs")
    .select("*")
    .eq("status", "queued")
    .order("created_at", { ascending: true })
    .limit(limit);
  if (error) throw error;
  const jobs = (data ?? []) as AiJobRow[];
  const claimed: AiJobRow[] = [];
  for (const job of jobs) {
    const { data: updated, error: uErr } = await sb
      .from("ai_jobs")
      .update({
        status: "running",
        started_at: new Date().toISOString(),
        attempts: job.attempts + 1,
      })
      .eq("id", job.id)
      .eq("status", "queued")
      .select("*")
      .maybeSingle();
    if (uErr) throw uErr;
    if (updated) claimed.push(updated as AiJobRow);
  }
  return claimed;
}

export async function updateJob(
  jobId: string,
  patch: Partial<AiJobRow> & { status?: AiJobRow["status"] },
): Promise<void> {
  if (!hasSupabase()) {
    const cur = memory.jobs.get(jobId);
    if (!cur) return;
    memory.jobs.set(jobId, { ...cur, ...patch });
    return;
  }
  const { error } = await getAdminClient().from("ai_jobs").update(patch).eq("id", jobId);
  if (error) throw error;
}

export async function setRecordingStatus(recordingId: string, status: string, extra: Record<string, unknown> = {}) {
  if (!hasSupabase()) {
    const cur = memory.recordings.get(recordingId);
    if (!cur) return;
    memory.recordings.set(recordingId, {
      ...cur,
      transcription_status: status,
      updated_at: new Date().toISOString(),
      ...extra,
    });
    return;
  }
  const { error } = await getAdminClient()
    .from("recordings")
    .update({ transcription_status: status, updated_at: new Date().toISOString(), ...extra })
    .eq("id", recordingId);
  if (error) throw error;
}

export async function setConversationStatus(conversationId: string, status: string, extra: Record<string, unknown> = {}) {
  if (!hasSupabase()) {
    const cur = memory.conversations.get(conversationId);
    if (!cur) return;
    memory.conversations.set(conversationId, {
      ...cur,
      status,
      updated_at: new Date().toISOString(),
      ...extra,
    });
    return;
  }
  const { error } = await getAdminClient()
    .from("conversations")
    .update({ status, updated_at: new Date().toISOString(), ...extra })
    .eq("id", conversationId);
  if (error) throw error;
}

export async function persistTranscript(
  userId: string,
  conversationId: string,
  transcript: CanonicalTranscript,
): Promise<void> {
  const speakerMap = new Map<string, string>();
  const speakers = [...new Set(transcript.segments.map((s) => s.speakerLabel))];
  const speakerRows = speakers.map((label) => {
    const sid = id();
    speakerMap.set(label, sid);
    return {
      id: sid,
      conversation_id: conversationId,
      user_id: userId,
      label: label.startsWith("Speaker") ? label : `Speaker ${label}`,
      is_user: false,
    };
  });

  const segmentRows = transcript.segments.map((seg, idx) => ({
    id: seg.id.includes("-") && seg.id.length > 10 ? seg.id : id(),
    conversation_id: conversationId,
    user_id: userId,
    speaker_id: speakerMap.get(seg.speakerLabel) ?? null,
    idx,
    t_start_ms: seg.startMs,
    t_end_ms: seg.endMs,
    text: seg.text,
    confidence: seg.confidence ?? null,
  }));

  if (!hasSupabase()) {
    memory.speakers.set(conversationId, speakerRows);
    memory.segments.set(
      conversationId,
      segmentRows.map((s) => ({
        ...s,
        speaker_label: transcript.segments.find((x) => x.startMs === s.t_start_ms)?.speakerLabel,
      })),
    );
    const conv = memory.conversations.get(conversationId);
    if (conv) {
      memory.conversations.set(conversationId, {
        ...conv,
        title: transcript.fullText.slice(0, 80),
        language: transcript.language,
        status: "ready",
      });
    }
    return;
  }

  const sb = getAdminClient();
  const { error: sErr } = await sb.from("speakers").insert(speakerRows);
  if (sErr) throw sErr;
  const { error: tErr } = await sb.from("transcript_segments").insert(segmentRows);
  if (tErr) throw tErr;
  await setConversationStatus(conversationId, "ready", {
    language: transcript.language,
    title: transcript.fullText.slice(0, 80),
  });
}

export async function getSegments(conversationId: string) {
  if (!hasSupabase()) return memory.segments.get(conversationId) ?? [];
  const { data, error } = await getAdminClient()
    .from("transcript_segments")
    .select("*, speakers(label)")
    .eq("conversation_id", conversationId)
    .order("idx");
  if (error) throw error;
  return data ?? [];
}

export async function checkTranscriptionQuota(userId: string, durationMs: number): Promise<{ ok: boolean; reason?: string }> {
  const seconds = Math.ceil(durationMs / 1000);
  const limitSeconds = config.baseFreeMinutes * 60;
  if (!hasSupabase()) {
    // Soft check in memory — always allow in fixture
    if (config.fixtureMode) return { ok: true };
    void userId;
    void seconds;
    return { ok: true };
  }
  const ym = yearMonth();
  const { data, error } = await getAdminClient()
    .from("usage_monthly")
    .select("transcription_seconds")
    .eq("user_id", userId)
    .eq("year_month", ym)
    .maybeSingle();
  if (error) throw error;
  const used = data?.transcription_seconds ?? 0;
  if (used + seconds > limitSeconds) {
    return { ok: false, reason: `Monthly transcription limit (${config.baseFreeMinutes} min) exceeded` };
  }
  return { ok: true };
}

export async function addTranscriptionUsage(userId: string, durationMs: number) {
  const seconds = Math.ceil(durationMs / 1000);
  if (!hasSupabase()) return;
  const ym = yearMonth();
  const sb = getAdminClient();
  const { data } = await sb
    .from("usage_monthly")
    .select("transcription_seconds")
    .eq("user_id", userId)
    .eq("year_month", ym)
    .maybeSingle();
  if (!data) {
    await sb.from("usage_monthly").insert({
      user_id: userId,
      year_month: ym,
      transcription_seconds: seconds,
    });
  } else {
    await sb
      .from("usage_monthly")
      .update({ transcription_seconds: data.transcription_seconds + seconds })
      .eq("user_id", userId)
      .eq("year_month", ym);
  }
}
