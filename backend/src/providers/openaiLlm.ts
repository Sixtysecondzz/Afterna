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
Attach segment_ids for every decision/action/deadline when possible.
Always populate entities with every person named or clearly referred to in the transcript (speakers and people talked about), plus notable companies/projects when explicit.
Each entity must be { "name": string, "type": "person"|"company"|"project"|"topic"|"place"|"other", "aliases": string[], "mentions": [{ "segment_id"?: string, "t_start_ms"?: number, "t_end_ms"?: number }] }.
Use type "person" for people names (e.g. Luke, Sarah). Prefer given names as canonical name; put speaker labels like "A" or "Speaker A" in aliases when linked.
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
    const fixture = fixtureExtract();
    return {
      ...fixture,
      entities: normalizeEntities(fixture.entities, transcriptText || fixture.summary),
    };
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
  const parsed = JSON.parse(raw) as ReturnType<typeof fixtureExtract>;
  const keyPoints = Array.isArray(parsed.key_points)
    ? parsed.key_points.map((k) => String(k)).join(" ")
    : "";
  const harvestText = [transcriptText, String(parsed.summary ?? ""), keyPoints].join("\n");
  return {
    ...parsed,
    entities: normalizeEntities(parsed?.entities, harvestText),
  };
}

type RawEntity = {
  name?: unknown;
  canonical_name?: unknown;
  entity?: unknown;
  type?: unknown;
  aliases?: unknown;
  mentions?: unknown;
};

/** Normalize model entity shapes and backfill obvious person names from the transcript. */
export function normalizeEntities(raw: unknown, transcriptText: string): ReturnType<typeof fixtureExtract>["entities"] {
  const out: ReturnType<typeof fixtureExtract>["entities"] = [];
  const seen = new Set<string>();

  const push = (name: string, type: string, aliases: string[] = [], mentions: Array<Record<string, unknown>> = []) => {
    const trimmed = name.trim();
    if (!trimmed) return;
    const key = `${type}:${trimmed.toLowerCase()}`;
    if (seen.has(key)) return;
    seen.add(key);
    out.push({
      name: trimmed,
      type,
      aliases,
      mentions: mentions as ReturnType<typeof fixtureExtract>["entities"][number]["mentions"],
    });
  };

  if (Array.isArray(raw)) {
    for (const item of raw) {
      const e = item as RawEntity;
      const name = String(e.name ?? e.canonical_name ?? e.entity ?? "").trim();
      if (!name) continue;
      const type = ["person", "company", "project", "topic", "place", "other"].includes(String(e.type))
        ? String(e.type)
        : "other";
      const aliases = Array.isArray(e.aliases)
        ? e.aliases.map((a) => String(a).trim()).filter(Boolean)
        : [];
      const mentions = Array.isArray(e.mentions) ? (e.mentions as Array<Record<string, unknown>>) : [];
      push(name, type, aliases, mentions);
    }
  }

  // Fallback: harvest likely person names mentioned in dialogue when the model omitted entities.
  const personCount = out.filter((e) => e.type === "person").length;
  if (personCount === 0 && transcriptText.trim()) {
    const stop = new Set([
      "The",
      "This",
      "That",
      "Then",
      "There",
      "They",
      "We",
      "I",
      "And",
      "But",
      "So",
      "Okay",
      "Ok",
      "Yeah",
      "Yes",
      "No",
      "Hi",
      "Hello",
      "Thanks",
      "Thank",
      "Today",
      "Tomorrow",
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday",
      "Sunday",
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
      "Speaker",
      "Afterna",
    ]);
    const hits = transcriptText.match(/\b[A-Z][a-z]{2,24}\b/g) ?? [];
    const counts = new Map<string, number>();
    for (const hit of hits) {
      if (stop.has(hit)) continue;
      counts.set(hit, (counts.get(hit) ?? 0) + 1);
    }
    for (const [name, count] of counts) {
      if (count >= 1) push(name, "person");
    }
  }

  return out;
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
