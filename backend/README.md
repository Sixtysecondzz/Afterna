# Afterna Backend

Node + TypeScript API for upload auto-enqueue, AssemblyAI transcription, extract/embed, and Ask AI.

## Run (local)

```bash
cp .env.example .env
npm install
npm run dev      # API on :8787
npm run worker   # job processor (separate terminal)
```

With `FIXTURE_MODE=true` (default in `.env.example`), transcription/extract/ask use fixtures — no provider keys required.

## Deploy (Fly.io) — monorepo

Fly must be run from **`backend/`**, not the repo root (the root has no Node app / Dockerfile).

```bash
cd backend
fly auth login
fly launch --copy-config --no-deploy   # uses existing fly.toml; skip if app already exists
fly secrets set \
  SUPABASE_URL="https://YOUR_PROJECT.supabase.co" \
  SUPABASE_ANON_KEY="..." \
  SUPABASE_SERVICE_ROLE_KEY="..." \
  ASSEMBLYAI_API_KEY="..." \
  OPENAI_API_KEY="..." \
  WEBHOOK_AUTH_SECRET="..." \
  APP_BASE_URL="https://afterna.fly.dev" \
  FIXTURE_MODE="false"
fly deploy
```

Health check: `https://afterna.fly.dev/health`

Point iOS `AFTERNA_API_BASE` at that URL when leaving mock upload.

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
