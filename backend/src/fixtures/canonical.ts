import type { CanonicalTranscript } from "../types.js";

export function fixtureTranscript(recordingId: string): CanonicalTranscript {
  const now = new Date().toISOString();
  return {
    recordingId,
    provider: "fixture",
    model: "fixture-v1",
    language: "en",
    fullText:
      "Alex: Let's ship the Afterna upload pipeline this week. Sam: Agreed — auto-transcribe after complete, then extract action items.",
    segments: [
      {
        id: "seg-1",
        speakerLabel: "A",
        text: "Let's ship the Afterna upload pipeline this week.",
        startMs: 0,
        endMs: 4200,
        confidence: 0.94,
      },
      {
        id: "seg-2",
        speakerLabel: "B",
        text: "Agreed — auto-transcribe after complete, then extract action items.",
        startMs: 4300,
        endMs: 9100,
        confidence: 0.92,
      },
    ],
    words: [],
    durationMs: 9200,
    createdAt: now,
    rawArtifactURI: null,
  };
}

export function fixtureExtract() {
  return {
    summary: "Team agreed to ship Afterna's upload → auto-transcribe → extract pipeline this week.",
    key_points: [
      "Upload complete should enqueue transcription automatically",
      "Extract action items after transcript is ready",
    ],
    decisions: [
      {
        text: "Ship upload pipeline this week",
        decided_by: "Alex",
        segment_ids: ["seg-1"],
        t_start_ms: 0,
        t_end_ms: 4200,
      },
    ],
    action_items: [
      {
        text: "Implement auto-transcribe after upload complete",
        assignee: "Sam",
        due_date: null,
        confidence: 0.9,
        segment_ids: ["seg-2"],
        t_start_ms: 4300,
        t_end_ms: 9100,
      },
    ],
    deadlines: [],
    entities: [
      {
        name: "Afterna",
        type: "project",
        aliases: [],
        mentions: [{ segment_id: "seg-1", t_start_ms: 0, t_end_ms: 4200 }],
      },
    ],
  };
}

export function fixtureAskAnswer(question: string) {
  return {
    answer: `Based on your conversation, the team planned to ship auto-transcription after upload. (Asked: ${question})`,
    citations: [
      {
        conversation_id: "fixture-conversation",
        segment_id: "seg-1",
        t_start_ms: 0,
        t_end_ms: 4200,
        speaker_label: "A",
        quote: "ship the Afterna upload pipeline this week",
      },
    ],
  };
}
