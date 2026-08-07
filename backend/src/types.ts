export type TranscriptionStatus = "pending" | "processing" | "succeeded" | "failed";
export type JobType = "transcribe" | "extract" | "embed" | "purge_audio" | "reindex";
export type JobStatus = "queued" | "running" | "succeeded" | "failed" | "dead";

export interface CanonicalSegment {
  id: string;
  speakerLabel: string;
  speakerPersonId?: string | null;
  text: string;
  startMs: number;
  endMs: number;
  confidence?: number | null;
}

export interface CanonicalWord {
  text: string;
  startMs: number;
  endMs: number;
  speakerLabel?: string | null;
  confidence?: number | null;
}

export interface CanonicalTranscript {
  recordingId: string;
  provider: string;
  model: string;
  language: string;
  fullText: string;
  segments: CanonicalSegment[];
  words: CanonicalWord[];
  durationMs: number;
  createdAt: string;
  rawArtifactURI?: string | null;
}

export interface Citation {
  conversation_id: string;
  segment_id: string;
  t_start_ms: number;
  t_end_ms: number;
  speaker_label?: string | null;
  quote: string;
}

export interface RemoteConfig {
  base_free_minutes: number;
  reward_minutes: number;
  max_daily_rewards: number;
  banner_enabled: boolean;
  native_feed_interval: number;
  banner_refresh_interval: number;
  ai_daily_limit: number;
  ads_on_summary_enabled: boolean;
  feature_flags: {
    fixture_mode: boolean;
    ask_ai: boolean;
    cross_conversation_search: boolean;
  };
}

export interface AiJobRow {
  id: string;
  user_id: string;
  job_type: JobType;
  status: JobStatus;
  recording_id: string | null;
  conversation_id: string | null;
  idempotency_key: string;
  attempts: number;
  provider: string | null;
  model: string | null;
  error: string | null;
  payload: Record<string, unknown>;
  created_at: string;
  started_at: string | null;
  finished_at: string | null;
}
