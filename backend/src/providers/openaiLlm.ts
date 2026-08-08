import OpenAI from "openai";
import { config } from "../config.js";
import { fixtureAskAnswer, fixtureExtract } from "../fixtures/canonical.js";
import type { Citation } from "../types.js";

function client(): OpenAI {
  if (!config.openAiApiKey) throw new Error("OPENAI_API_KEY is not set");
  return new OpenAI({ apiKey: config.openAiApiKey });
}

export type MeetingTemplate = "general" | "one_on_one" | "standup" | "sales" | "interview";

const EXTRACT_SYSTEM = `Extract only what is explicitly supported by the transcript (and user notes when they clarify something already in the transcript). Prefer null over invention.
If user notes conflict with the transcript, trust the transcript and ignore unsupported note claims.
Attach segment_ids for every decision/action/deadline.
Return JSON with keys: summary, key_points, decisions, action_items, deadlines, entities.`;

const TEMPLATE_GUIDANCE: Record<MeetingTemplate, string> = {
  general: "Balanced extract: summary, key points, decisions, and action items.",
  one_on_one:
    "1:1 focus: personal commitments, feedback, growth topics, and follow-ups for each person.",
  standup: "Standup focus: what was done, what's next, and blockers.",
  sales: "Sales focus: customer needs, objections, deal signals, next steps, and owners.",
  interview:
    "Interview focus: candidate strengths/concerns, evidence from answers, and hiring next steps.",
};

function normalizeTemplate(value: unknown): MeetingTemplate {
  if (
    value === "general" ||
    value === "one_on_one" ||
    value === "standup" ||
    value === "sales" ||
    value === "interview"
  ) {
    return value;
  }
  return "general";
}

export async function extractFromTranscript(
  transcriptText: string,
  segmentContext: string,
  options?: { userNotes?: string | null; template?: string | null },
) {
  if (config.fixtureMode || !config.openAiApiKey) {
    return fixtureExtract();
  }
  const template = normalizeTemplate(options?.template);
  const notes = options?.userNotes?.trim() || "";
  const notesBlock = notes
    ? `USER NOTES (weave into summary/key points only when supported by the transcript; do not invent from notes alone):\n${notes}\n\n`
    : "";
  const openai = client();
  const completion = await openai.chat.completions.create({
    model: config.extractModel,
    temperature: 0.2,
    response_format: { type: "json_object" },
    messages: [
      { role: "system", content: EXTRACT_SYSTEM },
      {
        role: "user",
        content:
          `${notesBlock}TEMPLATE: ${template}\nGuidance: ${TEMPLATE_GUIDANCE[template]}\n\n` +
          `TRANSCRIPT:\n${transcriptText}\n\nSEGMENTS:\n${segmentContext}`,
      },
    ],
  });
  const raw = completion.choices[0]?.message?.content ?? "{}";
  return JSON.parse(raw) as ReturnType<typeof fixtureExtract>;
}

export async function embedTexts(texts: string[]): Promise<number[][]> {
  if (config.fixtureMode || !config.openAiApiKey) {
    return texts.map(() => Array.from({ length: 1536 }, (_, i) => ((i % 17) - 8) / 100));
  }
  const openai = client();
  const res = await openai.embeddings.create({
    model: config.embedModel,
    input: texts,
  });
  return res.data.map((d) => d.embedding);
}

export async function askWithContext(input: {
  question: string;
  contextBlocks: Array<{
    conversation_id: string;
    segment_id: string;
    t_start_ms: number;
    t_end_ms: number;
    speaker_label?: string;
    text: string;
    conversation_title?: string;
  }>;
}): Promise<{ answer: string; citations: Citation[] }> {
  if (config.fixtureMode || !config.openAiApiKey || input.contextBlocks.length === 0) {
    const fixture = fixtureAskAnswer(input.question);
    if (input.contextBlocks[0]) {
      fixture.citations = [
        {
          conversation_id: input.contextBlocks[0].conversation_id,
          segment_id: input.contextBlocks[0].segment_id,
          t_start_ms: input.contextBlocks[0].t_start_ms,
          t_end_ms: input.contextBlocks[0].t_end_ms,
          speaker_label: input.contextBlocks[0].speaker_label ?? "A",
          quote: input.contextBlocks[0].text.slice(0, 80),
        },
      ];
    }
    return fixture;
  }

  const openai = client();
  const context = input.contextBlocks
    .map(
      (b, i) =>
        `[${i}] conv=${b.conversation_id} seg=${b.segment_id} t=${b.t_start_ms}-${b.t_end_ms} speaker=${b.speaker_label ?? "?"}\n${b.text}`,
    )
    .join("\n\n");

  const completion = await openai.chat.completions.create({
    model: config.askModel,
    temperature: 0.3,
    messages: [
      {
        role: "system",
        content:
          "Answer only using the provided transcript snippets. Include short verbatim quotes. If insufficient evidence, say you don't know.",
      },
      { role: "user", content: `QUESTION: ${input.question}\n\nCONTEXT:\n${context}` },
    ],
  });

  const answer = completion.choices[0]?.message?.content ?? "I don't know based on the available transcripts.";
  const citations: Citation[] = input.contextBlocks.slice(0, 3).map((b) => ({
    conversation_id: b.conversation_id,
    segment_id: b.segment_id,
    t_start_ms: b.t_start_ms,
    t_end_ms: b.t_end_ms,
    speaker_label: b.speaker_label ?? null,
    quote: b.text.slice(0, 100),
    conversation_title: b.conversation_title ?? null,
  }));
  return { answer, citations };
}
