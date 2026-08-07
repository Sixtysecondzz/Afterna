# Master Product Plan — Afterna

**CEO / Principal Architect review**  
**Date:** 2026-08-07  
**Brand:** **Afterna** (ADR-014) — domain/TM pending ([NAMING_PREMIUM_SHORTLIST.md](./NAMING_PREMIUM_SHORTLIST.md))  
**Category:** iPhone-first AI conversation memory

---

## 1. Positioning

**For** Australian freelancers, sole traders, and field/appointment professionals  
**Who** lose decisions, deadlines, and commitments after real conversations  
**Afterna** is the iPhone app that records the conversation, structures the memory, and lets you ask what was said weeks later  
**Unlike** Zoom bots (Otter/Fireflies), Mac-first notepads (Granola), hardware pins (Plaud), or Voice Memos + ChatGPT  
It is bot-free, phone-native, consent-aware, transcript-first (audio deletable), and built for searchable long-term memory.

**One-liner:** Capture the chat. Hold the memory. Delete the audio.

---

## 2. Killer feature (retention)

**Ask across conversations with citations** — “What did we agree about pricing?” → answer + “Based on 03:22–04:15” jump-to-transcript.

Secondary habit loop: one-tap record → structured note (actions/decisions) → follow-up share.

---

## 3. Why not Voice Memos + ChatGPT?

| Voice Memos + ChatGPT | Afterna |
|---|---|
| Manual export/paste | Automatic pipeline |
| No speaker structure | Diarisation + rename |
| No durable library UX for commitments | Action items, decisions, entities |
| No cross-conversation retrieval with citations | Hybrid RAG + memory |
| No consent / retention product controls | Privacy-first defaults |
| No offline capture → later enhance | Offline-first recording |

---

## 4. Red-team findings

| Question | Verdict |
|---|---|
| Overengineering? | Risk yes on knowledge graphs, live streaming, bots — **cut from V1** |
| Technically impossible on iOS? | Phone.app call recording; silent recording; system-audio from Zoom — **do not promise** |
| App Store risks? | Background `audio` must be demonstrable; clear mic indication; account deletion; privacy nutrition labels |
| Hidden recording limits? | Interruptions kill segments; force-quit stops capture; battery ~8–15%/hr |
| Cost assumptions realistic? | Unlimited free fails; **60 min/week + Recording Credits + native + remote caps** required |
| Differentiated enough? | Yes if memory+citations+field capture; no if only “pretty transcript” |
| What retains users? | Successful recall of a real commitment weeks later |
| Remove from V1? | Bots, CRM, teams, live captions, knowledge graph, subscriptions |
| Killer feature? | Cross-conversation Ask with citations |

---

## 5. Manager conflicts resolved

1. **Subscription vs free:** Free + 60 min/week + in-feed native (every 4–6 cards) + Recording Credits + remote caps (ADR-003 / ADR-011). Ads on library/search + resource limits only—not recording or value-detail screens.  
2. **GRDB vs SwiftData:** SwiftData (ADR-007).  
3. **Wedge breadth:** Narrow to AU client-facing solos/field pros, not students-first.  
4. **Streaming vs batch STT:** Batch post-recording for MVP.  
5. **Keep audio vs delete:** Delete by default (ADR-008).

---

## 6. MVP product promise

Record → reliable background capture → transcript + speakers → summary / key points / decisions / action items / entities → searchable history → Ask AI (one + across) → export/delete → privacy controls.

---

## 7. Post-MVP themes

- Context templates (inspection, interview, appointment)
- Live captions (Deepgram)
- Calendar prep briefs
- Team share / light workspace
- Optional subscription only if credits + native model fails after optimisation
- iPad / Mac clients
- On-device ASR draft (SpeechAnalyzer)
