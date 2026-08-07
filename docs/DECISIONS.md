# Architecture Decision Records

## ADR-001 — Working product name

- **Status:** Superseded — see ADR-012
- **Prior decision:** Working name Kept
- **Date:** 2026-08-07

## ADR-012 — Drop Kept; hold rename pending clearance

- **Status:** Superseded in part by ADR-013
- **Decision:** Do **not** brand as **Kept**.
- **Date:** 2026-08-07

## ADR-013 — Final shortlist diligence: none clear for global

- **Status:** Accepted (historical — shortlist killed)
- **Decision:** User shortlist **Said / Stillnote / Saidso / Clarion** all **fail** global due diligence.
- **Why (summary):**
  - **Stillnote** — exact App Store diary app (`id6781236577`) + stillnote.com parked + Stillnote LLC
  - **Saidso** — exact App Store blockchain social app + saidso.net; near-homophone SaySo news app
  - **Said** — dictionary word; said.com legacy; SAID Translations / SaidMe / Better Said swarm; unprotectable
  - **Clarion** — Faurecia Clarion car audio, SoftVelocity IDE, bioMérieux medical software, Clarion crime-alerts app
- **Superseded for brand pick by:** ADR-014
- **Date:** 2026-08-07

## ADR-014 — Brand pick: Afterna (pending domains + counsel)

- **Status:** Accepted (product brand intent) — **not yet** legal/domain freeze
- **Decision:** Lead product name is **Afterna**. Marketing frame: after the conversation, still yours. Spot diligence: no exact App Store title; `afterna.ai` + `afterna.app` DNS-empty at check (2026-08-07). Full matrix: [NAMING_PREMIUM_SHORTLIST.md](./NAMING_PREMIUM_SHORTLIST.md).
- **Project path:** `C:\Users\User\Afterna` when implementation starts · bundle `app.afterna.ios` · site `afterna.app` / `afterna.ai`
- **Preferred before bootstrap:** register both domains (+ attorney Class 9/42 AU)
- **Backups if registrar/TM fails:** Seduvia → Verasay → Vowrae → Hushrae
- **Date:** 2026-08-07

## ADR-002 — Initial wedge audience

- **Status:** Accepted
- **Decision:** Australian freelancers, sole traders, and field/appointment professionals (consultants, agents, inspectors, coaches) who need memory of in-person and phone-adjacent conversations.
- **Why:** Clear JTBD (“what did we agree?”), mobile-first gap vs Zoom bots, consent-friendly professional norm.
- **Date:** 2026-08-07

## ADR-003 — Monetisation: free + credits + native + remote caps

- **Status:** Accepted (supersedes earlier “+15 minutes per ad” wording)
- **Decision:** MVP is **100% free / no subscription**, with:
  - **60 free minutes/week** base allotment
  - **In-feed native ads** on Home/History (and occasional Search results)—inserted as a **sponsored native card every 4–6 conversation rows**, not a permanently glued banner
  - **Rewarded Recording Credits** (user-facing): watch ad → **+1 Credit**; internally **1 credit = N minutes** (default **5**), remotely configurable
  - Cap **max 6 rewarded ads/day** (stackable credits; prevents ad-farming hours of STT)
  - **Remote config from day one** for all usage/ad knobs (see ADR-011)
  - **Ad-free value surfaces:** Recording, Live Activity, Processing, Conversation Summary (prefer none), Transcript, Ask AI, Settings
- **Why:** Credits abstract dollar economics; in-feed native preserves premium/private feel vs glued banners; monetise browsing + resource limits, not the moment of consuming Afterna’s value.
- **Conflict resolved:** Product Research suggested $12–15/mo Pro; unit economics + CEO preference lock free + credits + remote caps.
- **Date:** 2026-08-07

## ADR-011 — Remote configuration for usage & ads (day one)

- **Status:** Accepted
- **Decision:** Ship a typed remote config overlay (backend `/v1/config` + disk cache) with at least:
  - `base_free_minutes` (weekly free pool; default 60)
  - `reward_minutes` (minutes per Recording Credit; default 5)
  - `max_daily_rewards` (default 6)
  - `banner_enabled` / native placement toggles (in-feed, not glued banner)
  - `native_feed_interval` (default 4–6; cards between sponsored inserts)
  - `banner_refresh_interval` (or list reuse policy)
  - `ai_daily_limit`
  - `ads_on_summary_enabled` (default **false**)
  - Plus existing feature flags (chunking, cellular upload, etc.)
- **Why:** Economics will move; must tune without shipping a binary. Client never hardcodes minute-per-credit economics in UI copy beyond “1 Credit.”
- **Date:** 2026-08-07

## ADR-004 — Backend: Supabase

- **Status:** Accepted
- **Decision:** Supabase for Auth, Postgres + pgvector, Storage, Realtime; workers on Cloudflare Queues or Fly for long ASR/LLM jobs.
- **Why:** Fastest path to Postgres/RAG/RLS without Firebase’s relational weakness.
- **Date:** 2026-08-07

## ADR-005 — Transcription: AssemblyAI primary, OpenAI fallback

- **Status:** Accepted
- **Decision:** Primary batch provider AssemblyAI Universal-3.5 Pro + diarisation (~$0.23/hr). Fallback OpenAI `gpt-4o-transcribe-diarize` / `gpt-transcribe`. Deepgram Nova-3 warm alternate for eval/streaming later.
- **Why:** Best batch cost/quality/diarisation for conversations; provider protocol keeps vendors swappable.
- **Date:** 2026-08-07

## ADR-006 — LLM: OpenAI primary with modular providers

- **Status:** Accepted
- **Decision:** OpenAI for embeddings (`text-embedding-3-small`) and default extract/Ask models (mini-class); Anthropic as config fallback. Protocol-based `LLMProvider`.
- **Why:** Simple ops; strong structured JSON; easy iOS-adjacent tooling. Keep Anthropic wired for quality A/B.
- **Date:** 2026-08-07

## ADR-007 — Local persistence: SwiftData + file audio

- **Status:** Accepted
- **Decision:** SwiftData for metadata; AAC chunks on disk; not GRDB dual-stack in V1.
- **Why:** iOS Architecture Manager recommendation; resolve AI doc’s GRDB suggestion as optional later if needed.
- **Conflict resolved:** AI/Backend sketches mentioned GRDB; CEO chooses SwiftData for greenfield SwiftUI app.
- **Date:** 2026-08-07

## ADR-008 — Audio retention: delete after successful transcription

- **Status:** Accepted
- **Decision:** Default delete raw audio after transcript verified + synced. User opt-in “Keep audio for playback.”
- **Why:** Privacy + unit economics; matches Granola-like trust posture without claiming legal compliance.
- **Date:** 2026-08-07

## ADR-009 — Capture mode: mic-based, not meeting bots

- **Status:** Accepted
- **Decision:** V1 is user-initiated mic recording only. No Zoom/Teams bots, no Phone.app call interception.
- **Why:** iOS cannot capture other apps’ system audio; bots are saturated and consent-toxic; wedge is in-person/field.
- **Date:** 2026-08-07

## ADR-010 — Search: hybrid FTS + pgvector, no knowledge graph in V1

- **Status:** Accepted
- **Decision:** Postgres full-text + pgvector hybrid search; structured entities tables; defer graph DB.
- **Why:** Simplest architecture that scales; entities cover “Project Phoenix” style queries.
- **Date:** 2026-08-07
