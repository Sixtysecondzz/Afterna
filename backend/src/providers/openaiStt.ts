import OpenAI from "openai";
import { config } from "../config.js";
import type { CanonicalTranscript } from "../types.js";
import { id } from "../lib/ids.js";

function client(): OpenAI {
  if (!config.openAiApiKey) throw new Error("OPENAI_API_KEY is not set");
  return new OpenAI({ apiKey: config.openAiApiKey });
}

export async function transcribeWithOpenAI(input: {
  recordingId: string;
  audio: Buffer;
  filename?: string;
  multiSpeaker?: boolean;
}): Promise<CanonicalTranscript> {
  const openai = client();
  const file = new File([input.audio], input.filename ?? "audio.m4a", {
    type: "audio/mp4",
  });

  const model = input.multiSpeaker !== false ? "gpt-4o-transcribe-diarize" : "gpt-transcribe";

  // SDK typing varies by model; use loose cast for diarized JSON.
  const result = (await openai.audio.transcriptions.create({
    file,
    model,
    response_format: input.multiSpeaker !== false ? "diarized_json" : "verbose_json",
  } as unknown as Parameters<typeof openai.audio.transcriptions.create>[0])) as unknown as {
    text?: string;
    duration?: number;
    language?: string;
    segments?: Array<{
      speaker?: string;
      start?: number;
      end?: number;
      text?: string;
    }>;
  };

  const segments =
    result.segments?.map((s) => ({
      id: id(),
      speakerLabel: String(s.speaker ?? "A"),
      text: s.text ?? "",
      startMs: Math.round((s.start ?? 0) * 1000),
      endMs: Math.round((s.end ?? 0) * 1000),
      confidence: null as number | null,
    })) ?? [
      {
        id: id(),
        speakerLabel: "A",
        text: result.text ?? "",
        startMs: 0,
        endMs: Math.round((result.duration ?? 0) * 1000),
        confidence: null,
      },
    ];

  return {
    recordingId: input.recordingId,
    provider: "openai",
    model,
    language: result.language ?? "en",
    fullText: result.text ?? segments.map((s) => s.text).join(" "),
    segments,
    words: [],
    durationMs: Math.round((result.duration ?? 0) * 1000),
    createdAt: new Date().toISOString(),
    rawArtifactURI: null,
  };
}
