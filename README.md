# Afterna

iPhone AI conversation memory — local-first capture, cloud transcription + Ask AI.

| Path | Purpose |
|------|---------|
| [`ios/`](./ios) | SwiftUI app + `ConversationCore` (Phases 0–5) |
| [`backend/`](./backend) | Node API + AssemblyAI / OpenAI workers |
| [`supabase/`](./supabase) | Schema, RLS, storage, Edge Function stubs |
| [`contracts/`](./contracts) | OpenAPI + JSON fixtures for iOS |
| [`web/`](./web) | Marketing site |
| [`docs/`](./docs) | Architecture research |

## Quick start

```bash
# API (fixture mode works without live keys)
cd backend && cp .env.example .env && npm install && npm run dev

# Worker loop (separate terminal)
npm run worker

# Marketing site
cd web && npm install && npm run dev
```

Open the iOS project: `ios/Afterna.xcodeproj` (or `ios/Package.swift` for ConversationCore).

## Secrets

Never commit API keys. Set `ASSEMBLYAI_API_KEY` / `OPENAI_API_KEY` in `backend/.env` only. iOS never receives provider keys.

## Bundle / domains

- Bundle ID: `app.afterna.ios`
- Sites: `afterna.ai` · `afterna.app`
