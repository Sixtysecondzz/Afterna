import { AssemblyAI } from "assemblyai";
import { config } from "../config.js";
import type { CanonicalTranscript } from "../types.js";
import { id } from "../lib/ids.js";

export function assemblyClient(): AssemblyAI {
  if (!config.assemblyAiApiKey) {
    throw new Error("ASSEMBLYAI_API_KEY is not set");
  }
  return new AssemblyAI({
    apiKey: config.assemblyAiApiKey,
    baseUrl: config.assemblyAiBaseUrl,
  });
}

export async function submitAssemblyAiTranscription(input: {
  audioUrl: string;
  webhookUrl?: string;
  languageCode?: string;
}): Promise<{ providerJobId: string }> {
  const client = assemblyClient();
  const transcript = await client.transcripts.submit({
    audio_url: input.audioUrl,
    speech_models: ["universal-3-5-pro", "universal-2"],
    speaker_labels: true,
    language_code: input.languageCode,
    webhook_url: input.webhookUrl,
    webhook_auth_header_name: input.webhookUrl ? config.webhookAuthHeaderName : undefined,
    webhook_auth_header_value: input.webhookUrl ? config.webhookAuthSecret : undefined,
  });
  return { providerJobId: transcript.id };
}

export async function fetchAssemblyAiTranscript(providerJobId: string) {
  const client = assemblyClient();
  return client.transcripts.get(providerJobId);
}

export function normalizeAssemblyAi(
  recordingId: string,
  raw: Awaited<ReturnType<typeof fetchAssemblyAiTranscript>>,
): CanonicalTranscript {
  if (raw.status === "error") {
    throw new Error(raw.error ?? "AssemblyAI transcription failed");
  }
  const utterances = raw.utterances ?? [];
  const segments =
    utterances.length > 0
      ? utterances.map((u) => ({
          id: id(),
          speakerLabel: String(u.speaker ?? "A"),
          text: u.text ?? "",
          startMs: u.start ?? 0,
          endMs: u.end ?? 0,
          confidence: u.confidence ?? null,
        }))
      : [
          {
            id: id(),
            speakerLabel: "A",
            text: raw.text ?? "",
            startMs: 0,
            endMs: Math.round((raw.audio_duration ?? 0) * 1000),
            confidence: raw.confidence ?? null,
          },
        ];

  const words =
    raw.words?.map((w) => ({
      text: w.text,
      startMs: w.start,
      endMs: w.end,
      speakerLabel: w.speaker ? String(w.speaker) : null,
      confidence: w.confidence ?? null,
    })) ?? [];

  return {
    recordingId,
    provider: "assemblyai",
    model: Array.isArray(raw.speech_models)
      ? String(raw.speech_models[0] ?? "universal-3-5-pro")
      : "universal-3-5-pro",
    language: raw.language_code ?? "en",
    fullText: raw.text ?? segments.map((s) => s.text).join(" "),
    segments,
    words,
    durationMs: Math.round((raw.audio_duration ?? 0) * 1000),
    createdAt: new Date().toISOString(),
    rawArtifactURI: null,
  };
}
