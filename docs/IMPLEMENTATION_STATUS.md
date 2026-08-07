# Implementation status — 2026-08-07

Greenfield monorepo landed at `C:\Users\User\Afterna`.

## Done

- Monorepo: `ios/`, `backend/`, `supabase/`, `contracts/`, `web/`, `docs/`
- Supabase migrations: schema, RLS, `audio-inbox` bucket, Sign in with Apple stub docs
- Node API: `/v1/config`, presign, **complete → auto-enqueue transcribe**, jobs, transcript, Ask AI, AssemblyAI webhook
- Worker: fixture / AssemblyAI primary / OpenAI STT failover → extract + embed + purge
- Contracts: OpenAPI + JSON fixtures
- iOS Phases 0–3 + Phase 5 outbox wiring (mock by default; set `useMockUpload: false` for live API)

## Local verify

```bash
cd backend && npm run start
# other terminal: npm run worker   # or POST /v1/worker/tick
```

Auth for fixture mode: `Authorization: Bearer dev-user`.
