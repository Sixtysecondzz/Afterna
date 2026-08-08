import { config } from "../config.js";

const STREAMING_TOKEN_URL = "https://streaming.assemblyai.com/v3/token";
const STREAMING_WS_BASE = "wss://streaming.assemblyai.com/v3/ws";

/** Recommended live session params (AssemblyAI Streaming v3). */
export const liveStreamingParams = {
  speech_model: "universal-3-5-pro",
  sample_rate: 16_000,
  format_turns: true,
  // Accepted when account/model supports it; client may omit on connect errors.
  speaker_labels: true,
} as const;

export type StreamingTokenResult = {
  token: string;
  expiresInSeconds: number;
  maxSessionDurationSeconds: number;
  wsUrl: string;
  params: typeof liveStreamingParams;
  fixture: boolean;
};

/**
 * Mint a one-time temporary token for client → AssemblyAI WebSocket auth.
 * Uses raw HTTP (GET /v3/token) — Authorization is the API key with no Bearer prefix.
 * @see https://www.assemblyai.com/docs/streaming/authenticate-with-a-temporary-token
 */
export async function createStreamingTemporaryToken(input?: {
  expiresInSeconds?: number;
  maxSessionDurationSeconds?: number;
}): Promise<StreamingTokenResult> {
  const expiresInSeconds = Math.min(Math.max(input?.expiresInSeconds ?? 60, 1), 600);
  const maxSessionDurationSeconds = Math.min(
    Math.max(input?.maxSessionDurationSeconds ?? 3600, 60),
    10_800,
  );

  if (config.fixtureMode || !config.assemblyAiApiKey) {
    return {
      token: "fixture-streaming-token",
      expiresInSeconds,
      maxSessionDurationSeconds,
      wsUrl: STREAMING_WS_BASE,
      params: liveStreamingParams,
      fixture: true,
    };
  }

  const url = new URL(STREAMING_TOKEN_URL);
  url.searchParams.set("expires_in_seconds", String(expiresInSeconds));
  url.searchParams.set("max_session_duration_seconds", String(maxSessionDurationSeconds));

  const res = await fetch(url, {
    method: "GET",
    headers: {
      Authorization: config.assemblyAiApiKey,
    },
  });

  if (!res.ok) {
    const body = await res.text();
    throw new Error(`AssemblyAI streaming token failed (${res.status}): ${body}`);
  }

  const data = (await res.json()) as { token?: string; expires_in_seconds?: number };
  if (!data.token) throw new Error("AssemblyAI streaming token response missing token");

  return {
    token: data.token,
    expiresInSeconds: data.expires_in_seconds ?? expiresInSeconds,
    maxSessionDurationSeconds,
    wsUrl: STREAMING_WS_BASE,
    params: liveStreamingParams,
    fixture: false,
  };
}
