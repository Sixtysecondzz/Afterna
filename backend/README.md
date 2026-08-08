# Afterna Backend

Node + TypeScript API for **live streaming captions**, **archive + OpenAI extract**, file-upload async STT (AssemblyAI), embed, and Ask AI.

## Hybrid transcription (live + file upload)

| Path | AssemblyAI | After save |
|------|------------|------------|
| Mic record | Streaming v3 (`universal-3-5-pro`, 16 kHz PCM, `format_turns`) | `POST /v1/conversations/archive` → OpenAI **extract** (summary / key points) |
| File import | Async REST `speech_models: ["universal-3-5-pro","universal-2"]`, `speaker_labels`, `language_detection` | Same OpenAI extract via existing job pipeline |

- API key stays on the server (`ASSEMBLYAI_API_KEY`). Clients call `POST /v1/streaming/token` and open `wss://streaming.assemblyai.com/v3/ws` with the **temporary token** (query `token=`).
- Do **not** use AssemblyAI `summarization` / `speech_understanding` — Afterna extract uses OpenAI.
- Tune live params in `src/providers/assemblyaiStreaming.ts` (`liveStreamingParams`).
- Tune async params in `src/providers/assemblyai.ts`.

### Local streaming token demo

```bash
cp .env.example .env   # FIXTURE_MODE=true is fine
npm install
npm run dev            # API on :8787 (embedded worker ticks jobs)
node scripts/demo-streaming-token.mjs
```

With `FIXTURE_MODE=true` (or missing `ASSEMBLYAI_API_KEY`), the token endpoint returns `fixture: true` and the iOS app simulates captions.

### Production storage (file upload)

File import needs real upload URLs. On Fly set:

- `APP_BASE_URL=https://afterna.fly.dev`
- `SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY` (and anon if used)

If Supabase is missing, uploads fall back to `{APP_BASE_URL}/v1/uploads/local/...` — never leave `APP_BASE_URL` as `localhost` in production.

## Run (local)

```bash
cp .env.example .env
npm install
npm run dev      # API on :8787 (includes embedded worker loop)
```

With `FIXTURE_MODE=true` (default in `.env.example`), transcription/extract/ask use fixtures — no provider keys required.

## Deploy (Fly.io) — monorepo

There is a **root** `Dockerfile` + `fly.toml` so Fly’s GitHub / “Prepare files for launch” flow works from the repo root (it only copies `backend/` into the image).

```bash
# From the Afterna repo ROOT (not backend/)
git pull origin master
fly auth login
fly launch --copy-config --no-deploy
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

**Fly Doctor “not listening on 8080”:** almost always leftover **worker** Machines from an older config. In Fly → **Machines**, destroy every machine whose process group is `worker`. Keep a single `app` machine. The API binds `0.0.0.0:8080` and runs the job loop in-process.

Point iOS `AFTERNA_API_BASE` at that URL when leaving mock upload.

Optional: deploy from `backend/` using `backend/fly.toml` + `backend/Dockerfile` instead.

## Key routes

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/v1/config` | Remote config / quotas |
| POST | `/v1/streaming/token` | Short-lived AssemblyAI streaming token for live captions |
| POST | `/v1/conversations/archive` | Persist live transcript + enqueue OpenAI extract |
| POST | `/v1/uploads/presign` | Create recording + signed upload URL (file import) |
| POST | `/v1/uploads/complete` | Mark uploaded + **auto-enqueue** `transcribe` |
| GET | `/v1/jobs/:id` | Job status |
| POST | `/v1/ask` | Ask AI (SSE stream) |
| POST | `/webhooks/transcription/assemblyai` | AssemblyAI completion webhook |

## Auth

Send `Authorization: Bearer <supabase_jwt>`. In fixture/dev mode, `Authorization: Bearer dev-user` maps to a fixed test user.
