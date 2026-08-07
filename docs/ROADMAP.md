# Implementation Roadmap — Afterna

## Phase 0 — Project foundation
- **Objective:** Xcode project, packages, CI skeleton, docs hygiene, remote-config client stub (`base_free_minutes`, `reward_minutes`, `max_daily_rewards`, `native_feed_interval`, banner/AI caps)
- **Deps:** none
- **Accept:** App launches on simulator; folders match architecture; config defaults load offline

## Phase 1 — Navigation + design system
- **Objective:** Tokens, core components, tab/stack navigation, empty states
- **Deps:** Phase 0
- **Accept:** All primary screens navigable with placeholder content

## Phase 2 — Recording engine
- **Objective:** AVAudioEngine chunked capture, interruptions, Live Activity
- **Deps:** Phase 1
- **Accept:** Background/lock recording on device; recover after crash

## Phase 3 — Local conversation storage
- **Objective:** SwiftData models, library list, local detail shell
- **Deps:** Phase 2
- **Accept:** Offline library persists across launches

## Phase 4 — Backend / authentication
- **Objective:** Supabase project, Sign in with Apple, RLS stubs
- **Deps:** Phase 0
- **Accept:** Sign in/out; authenticated API calls; Keychain tokens

## Phase 5 — Audio upload pipeline
- **Objective:** Presigned uploads, outbox, background URLSession
- **Deps:** Phases 2–4
- **Accept:** Airplane → online resume upload; idempotent complete

## Phase 6 — Transcription pipeline
- **Objective:** AssemblyAI adapter + OpenAI fallback + canonical transcript
- **Deps:** Phase 5
- **Accept:** End-to-end transcript with speakers/timestamps

## Phase 7 — AI summaries
- **Objective:** Extract summary/key points/decisions/actions/entities
- **Deps:** Phase 6
- **Accept:** Structured JSON persisted and shown in UI

## Phase 8 — Conversation detail UX
- **Objective:** Summary / Transcript / Actions / People tabs; polish
- **Deps:** Phases 3, 6, 7
- **Accept:** Premium native detail with all states

## Phase 9 — Ask AI (single conversation)
- **Objective:** RAG over one transcript; citations to timestamps
- **Deps:** Phases 6–7
- **Accept:** Answer + tappable “Based on mm:ss–mm:ss”

## Phase 10 — Cross-conversation memory / search
- **Objective:** Hybrid search + Ask across library
- **Deps:** Phase 9 + embeddings
- **Accept:** Query finds commitments across multiple sessions

## Phase 11 — Reliability / error handling
- **Objective:** Harden retries, banners, resume UX, disk/battery edges
- **Deps:** Phases 2–10
- **Accept:** Hardware stress matrix green for P0 cases

## Phase 12 — Privacy / export / delete
- **Objective:** Consent notice, audio purge default, export, account delete
- **Deps:** Phases 4, 8
- **Accept:** App Store account-deletion compliant

## Phase 13 — Analytics + monetisation instrumentation
- **Objective:** Privacy-safe analytics; cost metering; credit earn/spend events; remote-config exposure
- **Deps:** Phase 4
- **Accept:** Funnel events without raw transcript logging; zero ad impressions on recording screen in telemetry asserts

## Phase 14 — Testing
- **Objective:** Unit/integration/UI + audio stress suite
- **Deps:** Features complete
- **Accept:** CI green; device checklist signed off

## Phase 15 — App Store preparation
- **Objective:** Screenshots, privacy labels, review notes, TestFlight
- **Deps:** Phases 11–14
- **Accept:** Submission-ready build

Each phase during implementation must expand with: tasks, files affected, test plan, rollback notes.
