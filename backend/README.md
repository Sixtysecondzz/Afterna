# Afterna Backend

Node + TypeScript API for upload auto-enqueue, AssemblyAI transcription, extract/embed, and Ask AI.

## Run

```bash
cp .env.example .env
npm install
npm run dev      # API on :8787
npm run worker   # job processor (separate terminal)
```

With `FIXTURE_MODE=true` (default), transcription/extract/ask use fixtures — no provider keys required.

## Key routes

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/v1/config` | Remote config / quotas |
| POST | `/v1/uploads/presign` | Create recording + signed upload URL |
| POST | `/v1/uploads/complete` | Mark uploaded + **auto-enqueue** `transcribe` |
| GET | `/v1/jobs/:id` | Job status |
| POST | `/v1/ask` | Ask AI (SSE stream) |
| POST | `/webhooks/transcription/assemblyai` | AssemblyAI completion webhook |

## Auth

Send `Authorization: Bearer <supabase_jwt>`. In fixture/dev mode, `Authorization: Bearer dev-user` maps to a fixed test user.
