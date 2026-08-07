# Project Status — Afterna

**Current phase:** Research complete → brand **Afterna** locked (ADR-014) → register domains + plan approval → Phase 0  
**Last updated:** 2026-08-07

## Completed work

- Multi-manager research organisation executed in parallel (all five research tracks done)
- Research docs under `/docs` (full set):
  - PRODUCT_RESEARCH, IOS_ARCHITECTURE, AUDIO_ARCHITECTURE
  - TRANSCRIPTION_RESEARCH, TRANSCRIPTION_ARCHITECTURE
  - AI_ARCHITECTURE, MEMORY_SEARCH_ARCHITECTURE
  - BACKEND_ARCHITECTURE (includes DATABASE_SCHEMA DDL)
  - PRIVACY_SECURITY, UX_SPEC, DESIGN_SYSTEM
  - UNIT_ECONOMICS, TEST_STRATEGY, GO_TO_MARKET
- CEO red-team + ADRs + master plans:
  - DECISIONS, MASTER_PRODUCT_PLAN, MASTER_TECHNICAL_PLAN
  - MVP_SCOPE, ROADMAP
- Conflicts closed: free+credits+native+remote-caps over subscription; SwiftData over GRDB; AssemblyAI primary
- Monetisation iteration: Recording Credits + in-feed native every 4–6 cards; value screens ad-free (ADR-003/011)
- Naming: **Afterna** selected — [NAMING_PREMIUM_SHORTLIST.md](./NAMING_PREMIUM_SHORTLIST.md)
- Full compilation: [COMPILED.md](./COMPILED.md) + [README.md](./README.md) index

## In-progress work

- Register `afterna.ai` + `afterna.app`; attorney Class 9/42
- User approval of master plan → Phase 0 bootstrap

## Blocked work

- Implementation blocked until plan approval
- Project create at `C:\Users\User\Afterna` + move agent root (after domains owned preferred)

## Major architecture decisions

See [DECISIONS.md](./DECISIONS.md) — Supabase, AssemblyAI, OpenAI LLM, SwiftData, free+limits+ads, mic-only capture, audio delete-by-default.

## Open questions

1. ~~Brand name~~ → **Afterna**
2. Apple Developer Team / bundle ID (`app.afterna.ios`) for Phase 0
3. Supabase region preference (AU proximity vs US default)

## Known issues

- Product Research suggested subscriptions; overridden by unit economics (ADR-003).
- AI doc mentioned GRDB; overridden by SwiftData (ADR-007).
- Cannot record Phone.app calls or Zoom system audio on iOS.

## Next 10 tasks

1. Register `afterna.ai` + `afterna.app`
2. Approve master plan in Cursor
3. Create project at `C:\Users\User\Afterna` + move agent root
4. Phase 0: Xcode/SwiftPM foundation
5. Wire continuous doc updates into Phase 0 README
6. Phase 1: Design system + navigation
7. Phase 2: Recording engine (device testing)
8. Phase 4: Supabase + Sign in with Apple (can parallel Phase 2–3)
9. Phase 3: SwiftData library
10. Phase 5–6: Upload + AssemblyAI pipeline
